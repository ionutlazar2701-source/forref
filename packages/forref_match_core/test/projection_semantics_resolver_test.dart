import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

void main() {
  group('ProjectionSemanticsResolver boundary', () {
    test('foundation resolver preserves legacy payload facet semantics', () {
      const resolver = FoundationPayloadSemanticsResolver();
      final record = MatchRecord(
        recordId: 'score-1',
        matchId: 'match-1',
        recordKind: RecordKind.action,
        schemaVersion: 1,
        recordedAt: DateTime.utc(2026, 10, 2),
        originDeviceId: 'dev-a',
        originSequence: 1,
        payload: StructuredPayload({
          FoundationPayloadSemanticsResolver.legacyFacet: ProjectionFacet.score,
        }),
        integrity: const IntegrityMetadata(),
      );

      final contribution = resolver.resolve(record);

      expect(contribution.status, SemanticSupportStatus.supported);
      expect(contribution.supportedFacets, [ProjectionFacet.score]);
    });

    test('foundation resolver marks unknown payload as unsupported', () {
      const resolver = FoundationPayloadSemanticsResolver();
      final record = MatchRecord(
        recordId: 'unknown-1',
        matchId: 'match-1',
        recordKind: RecordKind.occurrence,
        schemaVersion: 1,
        recordedAt: DateTime.utc(2026, 10, 2),
        originDeviceId: 'dev-a',
        originSequence: 1,
        payload: StructuredPayload(const {'note': 'no facet keys'}),
        integrity: const IntegrityMetadata(),
      );

      final contribution = resolver.resolve(record);

      expect(contribution.status, SemanticSupportStatus.unsupported);
      expect(contribution.isSupported, isFalse);
    });

    test('unsupported record remains authority without invented sporting effect', () async {
      const projector = DeterministicMatchProjector(
        FoundationPayloadSemanticsResolver(),
      );
      const context = ProjectionContext(evaluatedAuthorityGeneration: 1);
      final record = MatchRecord(
        recordId: 'unknown-1',
        matchId: 'match-1',
        recordKind: RecordKind.occurrence,
        schemaVersion: 1,
        recordedAt: DateTime.utc(2026, 10, 2),
        originDeviceId: 'dev-a',
        originSequence: 1,
        payload: StructuredPayload(const {'note': 'no facet keys'}),
        integrity: const IntegrityMetadata(),
      );

      final projection = projector.projectRecords(
        matchId: 'match-1',
        records: [record],
        context: context,
      );

      expect(projection.committedRecordIds, ['unknown-1']);
      expect(projection.unsupportedSemanticRecordIds, ['unknown-1']);
      expect(projection.trustFor(ProjectionFacet.score), ProjectionTrust.untrusted);
    });
  });
}
