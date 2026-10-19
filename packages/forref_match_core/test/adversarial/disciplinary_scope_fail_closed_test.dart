import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

void main() {
  final resolver = ProductionSemanticsResolver();
  final projector = DeterministicMatchProjector(resolver);
  const context = ProjectionContext(evaluatedAuthorityGeneration: 1);

  group('Disciplinary scope stays fail-closed', () {
    test('production v1 codes exclude disciplinary and shootout wires', () {
      final wires =
          V1SemanticTypeCode.values.map((code) => code.wireValue).toSet();
      for (final wire in const [
        'YELLOW',
        'RED',
        'SUBSTITUTION',
        'SHOOTOUT',
        'SECOND_YELLOW',
        'SHOOTOUT_CAUTION',
      ]) {
        expect(wires, isNot(contains(wire)), reason: wire);
        expect(V1SemanticTypeCodeWire.parseWire(wire), isNull, reason: wire);
      }
      expect(wires, contains('GOAL'));

      for (final code in V1SemanticTypeCode.values) {
        final contract = V1SemanticContract.byCode[code]!;
        if (code == V1SemanticTypeCode.goal ||
            code == V1SemanticTypeCode.yellowCard) {
          expect(contract.createsSportingState, isTrue, reason: code.wireValue);
        } else {
          expect(contract.createsSportingState, isFalse, reason: code.wireValue);
        }
        expect(
          contract.projectionFacets,
          isNot(contains(ProjectionFacet.disciplinary)),
          reason: code.wireValue,
        );
        expect(code.wireValue.contains('SHOOTOUT'), isFalse,
            reason: code.wireValue);
      }
    });

    test('each committed v1 semantic leaves disciplinary untrusted', () {
      for (final code in V1SemanticTypeCode.values) {
        final record = _vocabularyRecord(code);
        final contribution = resolver.resolve(record);

        expect(
          contribution.status,
          SemanticSupportStatus.supported,
          reason: code.wireValue,
        );
        expect(
          contribution.supportedFacets,
          isNot(contains(ProjectionFacet.disciplinary)),
          reason: code.wireValue,
        );

        final projection = projector.projectRecords(
          matchId: 'match-1',
          records: [record],
          context: context,
        );

        expect(
          projection.committedRecordIds,
          [record.recordId],
          reason: code.wireValue,
        );
        expect(
          projection.unsupportedSemanticRecordIds,
          isEmpty,
          reason: code.wireValue,
        );
        expect(
          projection.trustFor(ProjectionFacet.disciplinary),
          ProjectionTrust.untrusted,
          reason: code.wireValue,
        );

        final isCompleteTemporalTransition =
            code.category == SemanticTypeCategory.temporal &&
                code != V1SemanticTypeCode.temporalCorrection;
        if (isCompleteTemporalTransition) {
          expect(
            projection.trustFor(ProjectionFacet.temporal),
            ProjectionTrust.trusted,
            reason: code.wireValue,
          );
        }
      }
    });

    test('a committed temporal vocabulary does not trust disciplinary', () {
      const temporalCodes = [
        V1SemanticTypeCode.matchStarted,
        V1SemanticTypeCode.periodStarted,
        V1SemanticTypeCode.periodEnded,
        V1SemanticTypeCode.temporarySuspensionStarted,
        V1SemanticTypeCode.temporarySuspensionEnded,
        V1SemanticTypeCode.matchAbandoned,
        V1SemanticTypeCode.matchEnded,
      ];
      final records = [
        for (var i = 0; i < temporalCodes.length; i++)
          _vocabularyRecord(temporalCodes[i], originSequence: i + 1),
      ];

      final projection = projector.projectRecords(
        matchId: 'match-1',
        records: records,
        context: context,
      );

      expect(projection.unsupportedSemanticRecordIds, isEmpty);
      expect(projection.trustFor(ProjectionFacet.temporal),
          ProjectionTrust.trusted);
      expect(projection.trustFor(ProjectionFacet.score),
          ProjectionTrust.untrusted);
      expect(
        projection.trustFor(ProjectionFacet.disciplinary),
        ProjectionTrust.untrusted,
      );
    });

    test('a complete temporal correction still leaves disciplinary untrusted',
        () {
      final started = _vocabularyRecord(V1SemanticTypeCode.matchStarted);
      final correction = _record(
        recordId: 'tcorr-1',
        originSequence: 2,
        recordKind: RecordKind.correction,
        payload: const TemporalCorrectionPayload(),
        relationships: [CorrectionTarget(targetRecordId: started.recordId)],
      );

      final contribution = resolver.resolve(correction);
      expect(contribution.status, SemanticSupportStatus.supported);
      expect(contribution.supportedFacets, [ProjectionFacet.temporal]);
      expect(contribution.missingRequiredRelationship, isFalse);

      final projection = projector.projectRecords(
        matchId: 'match-1',
        records: [started, correction],
        context: context,
      );

      expect(projection.unsupportedSemanticRecordIds, isEmpty);
      expect(projection.trustFor(ProjectionFacet.temporal),
          ProjectionTrust.trusted);
      expect(
        projection.trustFor(ProjectionFacet.disciplinary),
        ProjectionTrust.untrusted,
      );
    });

    test('unregistered disciplinary wires stay unsupported and untrusted', () {
      for (final wire in const [
        'YELLOW',
        'RED',
        'SECOND_YELLOW',
        'SHOOTOUT_CAUTION',
      ]) {
        expect(V1SemanticTypeCodeWire.parseWire(wire), isNull, reason: wire);
        for (final kind in [RecordKind.action, RecordKind.temporalFact]) {
          final record = _wireRecord(
            recordId: '${kind.name}-$wire',
            recordKind: kind,
            wire: wire,
          );
          final contribution = resolver.resolve(record);
          final label = '${kind.name} $wire';

          expect(
            contribution.status,
            SemanticSupportStatus.unsupported,
            reason: label,
          );
          expect(contribution.isSupported, isFalse, reason: label);
          expect(contribution.supportedFacets, isEmpty, reason: label);

          final projection = projector.projectRecords(
            matchId: 'match-1',
            records: [record],
            context: context,
          );

          expect(
            projection.unsupportedSemanticRecordIds,
            [record.recordId],
            reason: label,
          );
          expect(
            projection.trustFor(ProjectionFacet.disciplinary),
            ProjectionTrust.untrusted,
            reason: label,
          );
        }
      }
    });

    test('two YELLOW payloads do not synthesize a disciplinary record', () {
      final records = [
        _wireRecord(
          recordId: 'y1',
          recordKind: RecordKind.action,
          wire: 'YELLOW',
        ),
        _wireRecord(
          recordId: 'y2',
          originSequence: 2,
          recordKind: RecordKind.action,
          wire: 'YELLOW',
        ),
      ];

      final projection = projector.projectRecords(
        matchId: 'match-1',
        records: records,
        context: context,
      );

      expect(projection.committedRecordIds, ['y1', 'y2']);
      expect(projection.unsupportedSemanticRecordIds, ['y1', 'y2']);
      expect(
        projection.trustFor(ProjectionFacet.disciplinary),
        ProjectionTrust.untrusted,
      );
    });

    test('MATCH and SHOOTOUT_CAUTION do not collapse into trusted discipline',
        () {
      for (final wire in const [
        'SHOOTOUT',
        'SHOOTOUT_CAUTION',
        'MATCH_SHOOTOUT',
        'PENALTY_SHOOTOUT',
      ]) {
        expect(V1SemanticTypeCodeWire.parseWire(wire), isNull, reason: wire);
      }

      const shootOutRules = CompetitionRulesContext(
        rulesetId: 'cup-shoot-out',
        additionalPlayingPhase: AdditionalPlayingPhaseDisposition.noneRequired,
        penaltyShootOutAfterMatchEnd: true,
      );
      final plain = resolver.resolve(
        _transition(
            recordId: 'ended-plain', code: V1SemanticTypeCode.matchEnded),
      );
      final withShootOutRules = resolver.resolve(
        _transition(
          recordId: 'ended-so',
          code: V1SemanticTypeCode.matchEnded,
          competitionRulesContext: shootOutRules,
        ),
      );
      final caution = _wireRecord(
        recordId: 'so-caution',
        originSequence: 2,
        recordKind: RecordKind.action,
        wire: 'SHOOTOUT_CAUTION',
      );
      final cautionContribution = resolver.resolve(caution);

      expect(withShootOutRules, equals(plain));
      expect(withShootOutRules.status, SemanticSupportStatus.supported);
      expect(withShootOutRules.supportedFacets, [ProjectionFacet.temporal]);
      expect(
        withShootOutRules.supportedFacets,
        isNot(contains(ProjectionFacet.disciplinary)),
      );
      expect(cautionContribution.status, SemanticSupportStatus.unsupported);
      expect(cautionContribution, isNot(equals(withShootOutRules)));

      final projection = projector.projectRecords(
        matchId: 'match-1',
        records: [
          _transition(
            recordId: 'ended-so',
            code: V1SemanticTypeCode.matchEnded,
            competitionRulesContext: shootOutRules,
          ),
          caution,
        ],
        context: context,
      );

      expect(projection.committedRecordIds, ['ended-so', 'so-caution']);
      expect(projection.unsupportedSemanticRecordIds, ['so-caution']);
      expect(projection.trustFor(ProjectionFacet.temporal),
          ProjectionTrust.trusted);
      expect(
        projection.trustFor(ProjectionFacet.disciplinary),
        ProjectionTrust.untrusted,
      );
      expect(projection.facetTrust.containsKey('shootout'), isFalse);
    });
  });
}

MatchRecord _vocabularyRecord(
  V1SemanticTypeCode code, {
  int originSequence = 1,
}) {
  final contract = V1SemanticContract.byCode[code]!;
  return _record(
    recordId: code.wireValue,
    originSequence: originSequence,
    recordKind: contract.requiredRecordKind,
    payload: _payloadFor(code),
  );
}

MatchRecordPayload _payloadFor(V1SemanticTypeCode code) {
  return switch (code) {
    V1SemanticTypeCode.temporalCorrection => const TemporalCorrectionPayload(),
    V1SemanticTypeCode.correction => const CorrectionPayload(),
    V1SemanticTypeCode.legalSupersession => const LegalSupersessionPayload(),
    V1SemanticTypeCode.matchStarted ||
    V1SemanticTypeCode.matchAbandoned ||
    V1SemanticTypeCode.matchEnded =>
      TemporalTransitionPayload(semanticType: code),
    V1SemanticTypeCode.periodStarted ||
    V1SemanticTypeCode.periodEnded ||
    V1SemanticTypeCode.temporarySuspensionStarted ||
    V1SemanticTypeCode.temporarySuspensionEnded =>
      TemporalTransitionPayload(
        semanticType: code,
        period: const PeriodIdentity(index: 1),
      ),
    V1SemanticTypeCode.goal => GoalPayload(
      scoringTeamId: MatchTeamId('team-alpha'),
      captureIntentId: 'intent-1',
    ),
    V1SemanticTypeCode.yellowCard => YellowCardPayload(
      participantId: MatchParticipantId('person-a'),
      accountingScope: DisciplinaryAccountingScope.match,
      captureIntentId: 'intent-yellow',
    ),
    V1SemanticTypeCode.refereeEnteredFieldForMatchStart =>
      RefereeEnteredFieldPayload(captureIntentId: 'intent-field'),
  };
}

MatchRecord _transition({
  required String recordId,
  required V1SemanticTypeCode code,
  int originSequence = 1,
  int schemaVersion = 1,
  RecordKind recordKind = RecordKind.temporalFact,
  DateTime? recordedAt,
  DomainContractVersion? domainContractVersion,
  CompetitionRulesContext? competitionRulesContext,
}) {
  return _record(
    recordId: recordId,
    originSequence: originSequence,
    schemaVersion: schemaVersion,
    recordKind: recordKind,
    recordedAt: recordedAt,
    payload: TemporalTransitionPayload(
      semanticType: code,
      period: code == V1SemanticTypeCode.periodStarted ||
              code == V1SemanticTypeCode.periodEnded ||
              code == V1SemanticTypeCode.temporarySuspensionStarted ||
              code == V1SemanticTypeCode.temporarySuspensionEnded
          ? const PeriodIdentity(index: 1)
          : null,
      domainContractVersion: domainContractVersion,
      competitionRulesContext: competitionRulesContext,
    ),
  );
}

MatchRecord _wireRecord({
  required String recordId,
  required RecordKind recordKind,
  required String wire,
  int originSequence = 1,
}) {
  return _record(
    recordId: recordId,
    originSequence: originSequence,
    recordKind: recordKind,
    payload: StructuredPayload({
      ProductionPayloadContract.semanticType: wire,
    }),
  );
}

MatchRecord _record({
  required String recordId,
  required MatchRecordPayload payload,
  String matchId = 'match-1',
  RecordKind recordKind = RecordKind.temporalFact,
  int schemaVersion = 1,
  int originSequence = 1,
  DateTime? recordedAt,
  List<RecordRelationship> relationships = const [],
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: matchId,
    recordKind: recordKind,
    schemaVersion: schemaVersion,
    recordedAt: recordedAt ?? DateTime.utc(2026, 10, 2, 12, originSequence),
    originDeviceId: 'dev-a',
    originSequence: originSequence,
    payload: payload,
    integrity: const IntegrityMetadata(),
    relationships: relationships,
  );
}
