import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

/// Locks existing fail-closed score behavior.
///
/// This file does not define a numeric score, a Goal capture flow, or a
/// Score Projection Trust contract. Helpers at the bottom are copied locally
/// from the production resolver and frozen-vocabulary tests.
void main() {
  final resolver = ProductionSemanticsResolver();
  final projector = DeterministicMatchProjector(resolver);
  const context = ProjectionContext(evaluatedAuthorityGeneration: 1);

  group('fail-closed score projection trust', () {
    test('production vocabulary includes GOAL and the night-program codes', () {
      expect(
        V1SemanticTypeCode.values.map((code) => code.wireValue).toSet(),
        {
          'MATCH_STARTED',
          'PERIOD_STARTED',
          'PERIOD_ENDED',
          'TEMPORARY_SUSPENSION_STARTED',
          'TEMPORARY_SUSPENSION_ENDED',
          'MATCH_ABANDONED',
          'MATCH_ENDED',
          'TEMPORAL_CORRECTION',
          'CORRECTION',
          'LEGAL_SUPERSESSION',
          'GOAL',
          'YELLOW_CARD',
          'REFEREE_ENTERED_FIELD_FOR_MATCH_START',
        },
      );
      expect(V1SemanticTypeCodeWire.parseWire('GOAL'), V1SemanticTypeCode.goal);
      expect(V1SemanticTypeCodeWire.parseWire('YELLOW'), isNull);
    });

    test('non-goal v1 semantics leave score untrusted and expose no numeral',
        () {
      for (final code in V1SemanticTypeCode.values) {
        if (code == V1SemanticTypeCode.goal) continue;
        final contract = V1SemanticContract.byCode[code]!;
        if (code == V1SemanticTypeCode.yellowCard) {
          expect(contract.createsSportingState, isTrue, reason: code.wireValue);
        } else {
          expect(contract.createsSportingState, isFalse, reason: code.wireValue);
        }
        expect(
          contract.projectionFacets,
          isNot(contains(ProjectionFacet.score)),
          reason: code.wireValue,
        );

        final subject = _subjectRecord(code);
        final contribution = resolver.resolve(subject);
        expect(contribution.isSupported, isTrue, reason: code.wireValue);
        expect(
          contribution.supportedFacets,
          isNot(contains(ProjectionFacet.score)),
          reason: code.wireValue,
        );

        final projection = projector.projectRecords(
          matchId: 'match-1',
          records: _historyFor(code),
          context: context,
        );

        expect(
          projection.unsupportedSemanticRecordIds,
          isEmpty,
          reason: code.wireValue,
        );
        if (code.category == SemanticTypeCategory.temporal) {
          expect(
            projection.trustFor(ProjectionFacet.temporal),
            ProjectionTrust.trusted,
            reason: code.wireValue,
          );
        } else {
          expect(
            projection.trustFor(ProjectionFacet.coverage),
            ProjectionTrust.trusted,
            reason: code.wireValue,
          );
        }
        expectScoreUntrusted(projection, reason: code.wireValue);
        expectNoNumericScoreSurface(projection, reason: code.wireValue);
      }
    });

    test('GOAL without completeness proof stays unavailable', () {
      final projection = projector.projectRecords(
        matchId: 'match-1',
        records: _historyFor(V1SemanticTypeCode.goal),
        context: context,
      );
      expect(projection.scoreProjection, isA<ScoreUnavailable>());
      expectScoreUntrusted(projection, reason: 'GOAL without proof');
    });

    test('empty production projection does not invent a numeric score', () {
      final projection = projector.projectRecords(
        matchId: 'match-1',
        records: const [],
        context: context,
      );

      expectScoreUntrusted(projection);
      expectNoNumericScoreSurface(projection);
    });

    test(
      'score-like fields stay unsupported and do not trust the score facet',
      () {
        for (final kind in RecordKind.values) {
          final record = _mapRecord(
            recordId: 'score-fields-${kind.name}',
            recordKind: kind,
            payload: const {
              'scoreHome': 2,
              'scoreAway': 1,
              'home': 2,
              'away': 1,
            },
          );

          expectUnsupportedScore(resolver, projector, context, record);
        }
      },
    );

    test('GOAL and YELLOW payloads stay unsupported on every record kind', () {
      for (final wire in ['GOAL', 'YELLOW']) {
        for (final kind in RecordKind.values) {
          final record = _mapRecord(
            recordId: '$wire-${kind.name}',
            recordKind: kind,
            payload: {
              ProductionPayloadContract.semanticType: wire,
              'scoreHome': 1,
              'scoreAway': 0,
              'home': 1,
              'away': 0,
            },
          );

          expectUnsupportedScore(resolver, projector, context, record);
          expectUnsupportedScore(
            resolver,
            projector,
            context,
            _wireRecord(
              recordId: 'wired-$wire-${kind.name}',
              recordKind: kind,
              wire: wire,
            ),
          );
        }
      }
    });

    test('GOAL-like payload beside a temporal record does not trust score', () {
      final started = _transition(
        recordId: 'fact-1',
        code: V1SemanticTypeCode.matchStarted,
      );
      final goal = _mapRecord(
        recordId: 'goal-1',
        originSequence: 2,
        recordKind: RecordKind.action,
        payload: {
          ProductionPayloadContract.semanticType: 'GOAL',
          'scoreHome': 1,
          'scoreAway': 0,
          'home': '1',
          'away': '0',
        },
      );

      final contribution = resolver.resolve(goal);
      expect(contribution.status, SemanticSupportStatus.unsupported);
      expect(contribution.isSupported, isFalse);
      expect(
          contribution.supportedFacets, isNot(contains(ProjectionFacet.score)));

      final projection = projector.projectRecords(
        matchId: 'match-1',
        records: [started, goal],
        context: context,
      );

      expect(projection.committedRecordIds, contains('goal-1'));
      expect(projection.unsupportedSemanticRecordIds, contains('goal-1'));
      expect(
        projection.trustFor(ProjectionFacet.temporal),
        ProjectionTrust.trusted,
      );
      expectScoreUntrusted(projection, reason: 'GOAL');
      expect(
        projection.facetTrust[ProjectionFacet.score]!.trust,
        ProjectionTrust.untrusted,
      );
      expect(
        projection.facetTrust[ProjectionFacet.score]!.reason,
        'no explicit projection semantics declared',
      );
      expectNoNumericScoreSurface(projection, reason: 'GOAL');
    });

    test('score numerals smuggled onto MATCH_STARTED do not trust score', () {
      final record = _transition(
        recordId: 'started-with-score-fields',
        code: V1SemanticTypeCode.matchStarted,
      );

      final contribution = resolver.resolve(record);
      expect(contribution.status, SemanticSupportStatus.supported);
      expect(contribution.supportedFacets, [ProjectionFacet.temporal]);
      expect(
        contribution.supportedFacets,
        isNot(contains(ProjectionFacet.score)),
      );

      final projection = projector.projectRecords(
        matchId: 'match-1',
        records: [record],
        context: context,
      );

      expect(projection.unsupportedSemanticRecordIds, isEmpty);
      expect(
        projection.trustFor(ProjectionFacet.temporal),
        ProjectionTrust.trusted,
      );
      expectScoreUntrusted(projection, reason: 'smuggled score fields');
      expectNoNumericScoreSurface(projection, reason: 'smuggled score fields');
    });

    test('foundation score facet key is not production score trust', () {
      final record = _mapRecord(
        recordId: 'foundation-score',
        recordKind: RecordKind.action,
        payload: {
          FoundationPayloadSemanticsResolver.legacyFacet: ProjectionFacet.score,
          'scoreHome': 3,
          'scoreAway': 1,
          'home': 3,
          'away': 1,
        },
      );

      expect(
        const FoundationPayloadSemanticsResolver()
            .resolve(record)
            .supportedFacets,
        [ProjectionFacet.score],
      );

      final contribution = resolver.resolve(record);
      expect(contribution.status, SemanticSupportStatus.unsupported);
      expect(contribution.supportedFacets, isEmpty);

      final projection = projector.projectRecords(
        matchId: 'match-1',
        records: [record],
        context: context,
      );

      expect(projection.unsupportedSemanticRecordIds, ['foundation-score']);
      expectScoreUntrusted(projection, reason: 'foundation facet key');
      expectNoNumericScoreSurface(projection, reason: 'foundation facet key');
    });

    test('MatchProjectionState declares no home or away integer score', () {
      final classSource = _matchProjectionStateClassSource();
      for (final name in _forbiddenScoreNames) {
        expect(classSource, isNot(contains(name)), reason: name);
      }
      expect(
        RegExp(
          r'\b(?:final\s+)?int\??\s+(?:home|away|scoreHome|scoreAway|homeScore|awayScore|goalsHome|goalsAway)\b',
        ).hasMatch(classSource),
        isFalse,
      );

      final declaredFields = RegExp(
        r'^\s+final\s+([A-Za-z0-9_<>,? ]+?)\s+(\w+);',
        multiLine: true,
      ).allMatches(classSource).toList();
      final names = declaredFields.map((field) => field.group(2)!).toSet();
      expect(
        names.intersection({..._forbiddenScoreNames, 'home', 'away'}),
        isEmpty,
      );
      final intFields = declaredFields
          .where(
              (field) => RegExp(r'^int\??$').hasMatch(field.group(1)!.trim()))
          .map((field) => field.group(2)!)
          .toSet();
      expect(intFields, {'evaluatedAuthorityGeneration'});
      expect(names, contains('facetTrust'));

      final projection = projector.projectRecords(
        matchId: 'match-1',
        records: [
          _transition(
            recordId: 'fact-1',
            code: V1SemanticTypeCode.matchStarted,
          ),
        ],
        context: context,
      );
      expect(projection.trustFor('scoreHome'), ProjectionTrust.untrusted);
      expect(projection.trustFor('scoreAway'), ProjectionTrust.untrusted);
      expect(projection.trustFor('home'), ProjectionTrust.untrusted);
      expect(projection.trustFor('away'), ProjectionTrust.untrusted);
      expect(projection.trustFor('homeScore'), ProjectionTrust.untrusted);
      expect(projection.trustFor('awayScore'), ProjectionTrust.untrusted);
      expectScoreUntrusted(projection);
      expectNoNumericScoreSurface(projection);
    });
  });
}

const _forbiddenScoreNames = [
  'scoreHome',
  'scoreAway',
  'homeScore',
  'awayScore',
  'goalsHome',
  'goalsAway',
];

void expectScoreUntrusted(MatchProjectionState projection, {String? reason}) {
  final score = projection.facetTrust[ProjectionFacet.score];
  expect(score, isNotNull, reason: reason);
  expect(score!.facetId, ProjectionFacet.score, reason: reason);
  expect(score.trust, ProjectionTrust.untrusted, reason: reason);
  expect(
    projection.trustFor(ProjectionFacet.score),
    ProjectionTrust.untrusted,
    reason: reason,
  );
  expect(score.reason, isNot(contains(RegExp(r'\d'))), reason: reason);
}

void expectNoNumericScoreSurface(
  MatchProjectionState projection, {
  String? reason,
}) {
  expectScoreUntrusted(projection, reason: reason);
  final observed = [
    projection.matchId,
    '${projection.evaluatedAuthorityGeneration}',
    ...projection.facetTrust.keys,
    ...projection.facetTrust.values.map(
      (facet) => '${facet.facetId}:${facet.trust.name}:${facet.reason}',
    ),
    ...projection.committedRecordIds,
    ...projection.missingDependencyTargets,
    ...projection.conflictNotes,
    ...projection.unsupportedSemanticRecordIds,
  ].join('\n');
  for (final name in _forbiddenScoreNames) {
    expect(observed, isNot(contains(name)), reason: reason ?? name);
  }
  expect(projection.evaluatedAuthorityGeneration, isA<int>(), reason: reason);
}

void expectUnsupportedScore(
  ProductionSemanticsResolver resolver,
  DeterministicMatchProjector projector,
  ProjectionContext context,
  MatchRecord record,
) {
  final contribution = resolver.resolve(record);
  expect(
    contribution.status,
    SemanticSupportStatus.unsupported,
    reason: record.recordId,
  );
  expect(contribution.isSupported, isFalse, reason: record.recordId);
  expect(contribution.supportedFacets, isEmpty, reason: record.recordId);

  final projection = projector.projectRecords(
    matchId: 'match-1',
    records: [record],
    context: context,
  );
  expect(
    projection.committedRecordIds,
    contains(record.recordId),
    reason: record.recordId,
  );
  expect(
    projection.unsupportedSemanticRecordIds,
    contains(record.recordId),
    reason: record.recordId,
  );
  expectScoreUntrusted(projection, reason: record.recordId);
  expectNoNumericScoreSurface(projection, reason: record.recordId);
}

String _matchProjectionStateClassSource() {
  final source = File(
    'lib/projection/match_projection_state.dart',
  ).readAsStringSync();
  const marker = 'final class MatchProjectionState';
  final start = source.indexOf(marker);
  expect(start, greaterThanOrEqualTo(0));
  final nextTopLevel = source.indexOf('\nbool _listEquals', start);
  expect(nextTopLevel, greaterThan(start));
  return source.substring(start, nextTopLevel);
}

List<MatchRecord> _historyFor(V1SemanticTypeCode code) {
  final subject = _subjectRecord(code);
  return switch (code) {
    V1SemanticTypeCode.temporalCorrection ||
    V1SemanticTypeCode.correction ||
    V1SemanticTypeCode.legalSupersession ||
    V1SemanticTypeCode.goal ||
    V1SemanticTypeCode.yellowCard ||
    V1SemanticTypeCode.refereeEnteredFieldForMatchStart =>
      [
        _transition(recordId: 'fact-1', code: V1SemanticTypeCode.matchStarted),
        subject,
      ],
    _ => [subject],
  };
}

MatchRecord _subjectRecord(V1SemanticTypeCode code) {
  return switch (code) {
    V1SemanticTypeCode.matchStarted ||
    V1SemanticTypeCode.periodStarted ||
    V1SemanticTypeCode.periodEnded ||
    V1SemanticTypeCode.temporarySuspensionStarted ||
    V1SemanticTypeCode.temporarySuspensionEnded ||
    V1SemanticTypeCode.matchAbandoned ||
    V1SemanticTypeCode.matchEnded =>
      _transition(recordId: 'subject', code: code),
    V1SemanticTypeCode.temporalCorrection => _record(
        recordId: 'subject',
        originSequence: 2,
        recordKind: RecordKind.correction,
        payload: const TemporalCorrectionPayload(),
        relationships: [CorrectionTarget(targetRecordId: 'fact-1')],
      ),
    V1SemanticTypeCode.correction => _record(
        recordId: 'subject',
        originSequence: 2,
        recordKind: RecordKind.correction,
        payload: const CorrectionPayload(),
        relationships: [CorrectionTarget(targetRecordId: 'fact-1')],
      ),
    V1SemanticTypeCode.legalSupersession => _record(
        recordId: 'subject',
        originSequence: 2,
        recordKind: RecordKind.legalSupersession,
        payload: const LegalSupersessionPayload(),
        relationships: [LegalSupersessionTarget(targetRecordId: 'fact-1')],
      ),
    V1SemanticTypeCode.goal => _record(
        recordId: 'subject',
        originSequence: 2,
        recordKind: RecordKind.humanDetermination,
        payload: GoalPayload(
          scoringTeamId: MatchTeamId('team-alpha'),
          captureIntentId: 'intent-1',
        ),
      ),
    V1SemanticTypeCode.yellowCard => _record(
        recordId: 'subject',
        originSequence: 2,
        recordKind: RecordKind.humanDetermination,
        payload: YellowCardPayload(
          participantId: MatchParticipantId('person-a'),
          accountingScope: DisciplinaryAccountingScope.match,
          captureIntentId: 'intent-yellow',
        ),
      ),
    V1SemanticTypeCode.refereeEnteredFieldForMatchStart => _record(
        recordId: 'subject',
        originSequence: 2,
        recordKind: RecordKind.temporalFact,
        payload: RefereeEnteredFieldPayload(captureIntentId: 'intent-field'),
      ),
  };
}

// Copied locally from test/frozen_semantic_vocabulary_test.dart.
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

// Copied locally from test/frozen_semantic_vocabulary_test.dart.
MatchRecord _wireRecord({
  required String recordId,
  required RecordKind recordKind,
  required String wire,
}) {
  return _record(
    recordId: recordId,
    recordKind: recordKind,
    payload: StructuredPayload({
      ProductionPayloadContract.semanticType: wire,
    }),
  );
}

// Copied locally from test/frozen_semantic_vocabulary_test.dart.
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

/// Copied from test/production_semantics_resolver_test.dart `_record`.
/// Renamed so it can sit beside the payload-based helper above.
MatchRecord _mapRecord({
  required String recordId,
  String matchId = 'match-1',
  RecordKind recordKind = RecordKind.occurrence,
  int schemaVersion = 1,
  Map<String, Object?> payload = const {},
  int originSequence = 1,
  List<RecordRelationship> relationships = const [],
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: matchId,
    recordKind: recordKind,
    schemaVersion: schemaVersion,
    recordedAt: DateTime.utc(2026, 10, 2, 12, originSequence),
    originDeviceId: 'dev-a',
    originSequence: originSequence,
    payload: StructuredPayload(payload),
    integrity: const IntegrityMetadata(),
    relationships: relationships,
  );
}
