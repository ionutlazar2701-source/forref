import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

void main() {
  final resolver = ProductionSemanticsResolver();
  const context = ProjectionContext(evaluatedAuthorityGeneration: 1);

  group('Frozen v1 semantic vocabulary', () {
    test('adding a semantic type does not require schema v2', () {
      expect(V1SemanticContract.schemaContractVersion, 1);
      expect(ProductionPayloadContract.registeredSchemaVersions, {1});
      expect(File('lib/semantics/v2_schema_semantic_interpreter.dart').existsSync(), isFalse);

      for (final contract in V1SemanticContract.byCode.values) {
        expect(contract.schemaVersion, 1);
      }

      final started = resolver.resolve(
        _transition(recordId: 'start-1', code: V1SemanticTypeCode.matchStarted),
      );
      expect(started.status, SemanticSupportStatus.supported);
    });

    test('known temporal semantic resolves deterministically', () {
      final first = resolver.resolve(
        _transition(recordId: 'period-1', code: V1SemanticTypeCode.periodStarted),
      );
      final second = resolver.resolve(
        _transition(
          recordId: 'period-2',
          originSequence: 2,
          code: V1SemanticTypeCode.periodStarted,
        ),
      );

      expect(first, equals(second));
      expect(first.supportedFacets, [ProjectionFacet.temporal]);
      expect(
        V1SemanticContract.byCode[V1SemanticTypeCode.periodStarted]!.effect,
        SemanticEffect.temporalTransitionAuthority,
      );
    });

    test('incompatible RecordKind is unsupported', () {
      final contribution = resolver.resolve(
        _transition(
          recordId: 'bad-kind',
          code: V1SemanticTypeCode.matchStarted,
          recordKind: RecordKind.action,
        ),
      );

      expect(contribution.status, SemanticSupportStatus.unsupported);
    });

    test('ordinary stoppage cannot resolve as formal suspension', () {
      for (final wire in ['ORDINARY_STOPPAGE', 'STOPPAGE', 'PAUSE']) {
        expect(V1SemanticTypeCodeWire.parseWire(wire), isNull);
        final contribution = resolver.resolve(
          _wireRecord(
            recordId: wire,
            recordKind: RecordKind.temporalFact,
            wire: wire,
          ),
        );
        expect(contribution.status, SemanticSupportStatus.unsupported);
      }

      final suspension = resolver.resolve(
        _transition(
          recordId: 'susp-1',
          code: V1SemanticTypeCode.temporarySuspensionStarted,
        ),
      );
      expect(suspension.status, SemanticSupportStatus.supported);
      expect(suspension.supportedFacets, [ProjectionFacet.temporal]);
    });

    test('resumption is a transition and not a durable match state', () {
      final contract =
          V1SemanticContract.byCode[V1SemanticTypeCode.temporarySuspensionEnded]!;
      expect(contract.isDurableMatchState, isFalse);
      expect(contract.effect, SemanticEffect.temporalTransitionAuthority);
      expect(contract.category, SemanticTypeCategory.temporal);

      final contribution = resolver.resolve(
        _transition(
          recordId: 'resume-1',
          code: V1SemanticTypeCode.temporarySuspensionEnded,
        ),
      );
      expect(contribution.status, SemanticSupportStatus.supported);
      expect(contribution.supportedFacets, [ProjectionFacet.temporal]);
    });

    test('unknown semantic and schema version stay unsupported', () {
      expect(
        resolver.resolve(
          _wireRecord(
            recordId: 'terminated',
            recordKind: RecordKind.temporalFact,
            wire: 'MATCH_TERMINATED',
          ),
        ).status,
        SemanticSupportStatus.unsupported,
      );
      expect(
        resolver.resolve(
          _transition(
            recordId: 'future',
            code: V1SemanticTypeCode.matchAbandoned,
            schemaVersion: 2,
          ),
        ).status,
        SemanticSupportStatus.unsupported,
      );
    });

    test('recordedAt does not determine semantic meaning', () {
      final early = resolver.resolve(
        _transition(
          recordId: 'early',
          code: V1SemanticTypeCode.periodEnded,
          recordedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      final late = resolver.resolve(
        _transition(
          recordId: 'late',
          code: V1SemanticTypeCode.periodEnded,
          recordedAt: DateTime.utc(2026, 12, 31),
        ),
      );

      expect(early, equals(late));
    });

    test('correction and legal supersession keep historical record identity', () {
      final projector = DeterministicMatchProjector(resolver);
      final original = _transition(
        recordId: 'fact-1',
        code: V1SemanticTypeCode.matchStarted,
      );
      final correction = _record(
        recordId: 'corr-1',
        originSequence: 2,
        recordKind: RecordKind.correction,
        payload: const CorrectionPayload(),
        relationships: [CorrectionTarget(targetRecordId: 'fact-1')],
      );
      final supersession = _record(
        recordId: 'super-1',
        originSequence: 3,
        recordKind: RecordKind.legalSupersession,
        payload: const LegalSupersessionPayload(),
        relationships: [LegalSupersessionTarget(targetRecordId: 'fact-1')],
      );

      final projection = projector.projectRecords(
        matchId: 'match-1',
        records: [original, correction, supersession],
        context: context,
      );

      expect(
        projection.committedRecordIds,
        ['fact-1', 'corr-1', 'super-1'],
      );
      expect(projection.unsupportedSemanticRecordIds, isEmpty);
      expect(projection.trustFor(ProjectionFacet.coverage), ProjectionTrust.trusted);
      expect(projection.trustFor(ProjectionFacet.score), ProjectionTrust.untrusted);
    });

    test('missing correction target makes temporal correction incomplete', () {
      final projector = DeterministicMatchProjector(resolver);
      final correction = _record(
        recordId: 'tcorr-1',
        recordKind: RecordKind.correction,
        payload: const TemporalCorrectionPayload(),
      );

      final projection = projector.projectRecords(
        matchId: 'match-1',
        records: [correction],
        context: context,
      );

      expect(projection.unsupportedSemanticRecordIds, isEmpty);
      expect(projection.trustFor(ProjectionFacet.temporal), ProjectionTrust.incomplete);
    });

    test('projector consumes production vocabulary without foundation payload keys', () {
      final projectorSource = File(
        'lib/projection/deterministic_match_projector.dart',
      ).readAsStringSync();
      expect(projectorSource, isNot(contains('projectionFacets')));
      expect(projectorSource, isNot(contains("'facet'")));
      expect(projectorSource, isNot(contains("'facets'")));

      final projector = DeterministicMatchProjector(resolver);
      final projection = projector.projectRecords(
        matchId: 'match-1',
        records: [
          _transition(recordId: 'start-1', code: V1SemanticTypeCode.matchStarted),
        ],
        context: context,
      );

      expect(projection.trustFor(ProjectionFacet.temporal), ProjectionTrust.trusted);
      expect(projection.trustFor(ProjectionFacet.disciplinary), ProjectionTrust.untrusted);
    });

    test('domain contract and competition rules stay distinct from schema and type', () {
      final withContext = resolver.resolve(
        _transition(
          recordId: 'ctx',
          code: V1SemanticTypeCode.periodStarted,
          domainContractVersion: const DomainContractVersion('domain-clock-v1'),
          competitionRulesContext: const CompetitionRulesContext(rulesetId: 'ifab'),
        ),
      );
      final withoutContext = resolver.resolve(
        _transition(recordId: 'plain', code: V1SemanticTypeCode.periodStarted),
      );

      expect(withContext, equals(withoutContext));
      expect(V1SemanticContract.schemaContractVersion, isNot('domain-clock-v1'));
    });
  });
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
}) {
  return _record(
    recordId: recordId,
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
