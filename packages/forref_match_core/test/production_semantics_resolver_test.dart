import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

void main() {
  group('ProductionSemanticsResolver', () {
    late ProductionSemanticsResolver resolver;

    setUp(() {
      resolver = ProductionSemanticsResolver();
    });

    test('never reads foundation payload keys', () {
      final resolverFiles = [
        'lib/semantics/production_semantics_resolver.dart',
        'lib/semantics/v1_schema_semantic_interpreter.dart',
      ];
      for (final path in resolverFiles) {
        final text = File(path).readAsStringSync();
        expect(text, isNot(contains("fields['projectionFacets']")));
        expect(text, isNot(contains('fields["projectionFacets"]')));
        expect(text, isNot(contains("fields['facet']")));
        expect(text, isNot(contains("fields['facets']")));
        expect(
          text,
          isNot(contains('FoundationPayloadSemanticsResolver')),
        );
      }
    });

    test('RecordKind alone cannot create sporting semantics', () {
      for (final kind in RecordKind.values) {
        final contribution = resolver.resolve(
          _record(
            recordId: 'kind-${kind.name}',
            recordKind: kind,
            payload: const {},
          ),
        );
        expect(contribution.isSupported, isFalse);
        expect(contribution.supportedFacets, isEmpty);
      }
    });

    test('known typed semantic and supported schema resolve deterministically', () {
      final correction = resolver.resolve(
        _record(
          recordId: 'corr-1',
          recordKind: RecordKind.correction,
          payload: const CorrectionPayload(),
        ),
      );
      final supersession = resolver.resolve(
        _record(
          recordId: 'super-1',
          recordKind: RecordKind.legalSupersession,
          payload: const LegalSupersessionPayload(),
        ),
      );

      expect(correction.status, SemanticSupportStatus.supported);
      expect(correction.supportedFacets, [ProjectionFacet.coverage]);
      expect(supersession.status, SemanticSupportStatus.supported);
      expect(supersession.supportedFacets, [ProjectionFacet.coverage]);
    });

    test('unknown semantic type returns unsupported', () {
      final contribution = resolver.resolve(
        _record(
          recordId: 'goal-1',
          recordKind: RecordKind.action,
          payload: {
            ProductionPayloadContract.semanticType: 'GOAL',
          },
        ),
      );

      expect(contribution.status, SemanticSupportStatus.unsupported);
      expect(contribution.isSupported, isFalse);
    });

    test('unknown schema version returns unsupported', () {
      final contribution = resolver.resolve(
        _record(
          recordId: 'corr-v99',
          schemaVersion: 99,
          recordKind: RecordKind.correction,
          payload: {
            ProductionPayloadContract.semanticType: 'CORRECTION',
          },
        ),
      );

      expect(contribution.status, SemanticSupportStatus.unsupported);
    });

    test('same historical schema retains same semantic meaning', () {
      final first = resolver.resolve(
        _record(
          recordId: 'corr-a',
          recordKind: RecordKind.correction,
          payload: const CorrectionPayload(),
        ),
      );
      final second = resolver.resolve(
        _record(
          recordId: 'corr-b',
          originSequence: 2,
          recordKind: RecordKind.correction,
          payload: const CorrectionPayload(),
        ),
      );

      expect(first, equals(second));
    });

    test('semantic type mismatched with RecordKind returns unsupported', () {
      final contribution = resolver.resolve(
        _record(
          recordId: 'mismatch-1',
          recordKind: RecordKind.action,
          payload: {
            ProductionPayloadContract.semanticType: 'CORRECTION',
          },
        ),
      );

      expect(contribution.status, SemanticSupportStatus.unsupported);
    });

    test('foundation resolver remains isolated from production semantics', () {
      final productionSource = File(
        'lib/semantics/production_semantics_resolver.dart',
      ).readAsStringSync();
      expect(
        productionSource,
        isNot(contains('FoundationPayloadSemanticsResolver')),
      );

      final foundationSource = File(
        'lib/projection/foundation_payload_semantics_resolver.dart',
      ).readAsStringSync();
      expect(foundationSource, isNot(contains('ProductionSemanticsResolver')));
      expect(foundationSource, isNot(contains('ProductionPayloadContract')));
    });

    test('projector accepts production resolver without code changes', () async {
      final projector = DeterministicMatchProjector(ProductionSemanticsResolver());
      const context = ProjectionContext(evaluatedAuthorityGeneration: 1);
      final original = _record(
        recordId: 'fact-1',
        recordKind: RecordKind.temporalFact,
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.matchStarted,
        ),
      );
      final correction = _record(
        recordId: 'corr-1',
        originSequence: 2,
        recordKind: RecordKind.correction,
        payload: const CorrectionPayload(),
        relationships: [CorrectionTarget(targetRecordId: 'fact-1')],
      );

      final projection = projector.projectRecords(
        matchId: 'match-1',
        records: [original, correction],
        context: context,
      );

      expect(projection.committedRecordIds, ['fact-1', 'corr-1']);
      expect(projection.unsupportedSemanticRecordIds, isEmpty);
      expect(projection.trustFor(ProjectionFacet.coverage), ProjectionTrust.trusted);
      expect(projection.trustFor(ProjectionFacet.temporal), ProjectionTrust.trusted);
      expect(projection.trustFor(ProjectionFacet.score), ProjectionTrust.untrusted);
    });
  });
}

MatchRecord _record({
  required String recordId,
  String matchId = 'match-1',
  RecordKind recordKind = RecordKind.occurrence,
  int schemaVersion = 1,
  Object payload = const <String, Object?>{},
  int originSequence = 1,
  List<RecordRelationship> relationships = const [],
}) {
  final MatchRecordPayload resolvedPayload;
  if (payload is MatchRecordPayload) {
    resolvedPayload = payload;
  } else if (payload is Map<String, Object?>) {
    resolvedPayload = StructuredPayload(payload);
  } else if (payload is Map) {
    resolvedPayload = StructuredPayload({
      for (final entry in payload.entries) entry.key as String: entry.value,
    });
  } else {
    throw ArgumentError('Unsupported test payload: $payload');
  }
  return MatchRecord(
    recordId: recordId,
    matchId: matchId,
    recordKind: recordKind,
    schemaVersion: schemaVersion,
    recordedAt: DateTime.utc(2026, 10, 2, 12, originSequence),
    originDeviceId: 'dev-a',
    originSequence: originSequence,
    payload: resolvedPayload,
    integrity: const IntegrityMetadata(),
    relationships: relationships,
  );
}
