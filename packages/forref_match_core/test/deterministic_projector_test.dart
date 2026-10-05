import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

void main() {
  const foundationResolver = FoundationPayloadSemanticsResolver();
  const projector = DeterministicMatchProjector(foundationResolver);
  const context = ProjectionContext(evaluatedAuthorityGeneration: 1);

  group('DeterministicMatchProjector', () {
    test('identical Match Memory produces identical projection', () async {
      final memory = _Memory([
        _record(recordId: 'a', originDeviceId: 'dev-a', originSequence: 1),
        _record(recordId: 'b', originDeviceId: 'dev-a', originSequence: 2),
      ]);

      final first = await projector.project(memory, 'match-1', context);
      final second = await projector.project(memory, 'match-1', context);

      expect(first, equals(second));
    });

    test('read order does not alter projection for equivalent records', () async {
      final records = [
        _record(
          recordId: 'z',
          originDeviceId: 'dev-b',
          originSequence: 1,
          facet: ProjectionFacet.disciplinary,
        ),
        _record(
          recordId: 'a',
          originDeviceId: 'dev-a',
          originSequence: 1,
          facet: ProjectionFacet.score,
        ),
        _record(
          recordId: 'm',
          originDeviceId: 'dev-a',
          originSequence: 2,
          facet: ProjectionFacet.temporal,
        ),
      ];

      final forward = await projector.project(
        _Memory(records),
        'match-1',
        context,
      );
      final reversed = await projector.project(
        _Memory(records.reversed.toList()),
        'match-1',
        context,
      );

      expect(forward, equals(reversed));
      expect(forward.committedRecordIds, ['a', 'm', 'z']);
    });

    test('missing dependency degrades only affected facet', () async {
      final memory = _Memory([
        _record(
          recordId: 'score-1',
          facet: ProjectionFacet.score,
          relationships: [CausalDependency(targetRecordId: 'missing-1')],
        ),
        _record(
          recordId: 'card-1',
          originSequence: 2,
          facet: ProjectionFacet.disciplinary,
        ),
      ]);

      final projection = await projector.project(memory, 'match-1', context);

      expect(projection.trustFor(ProjectionFacet.score), ProjectionTrust.incomplete);
      expect(projection.trustFor(ProjectionFacet.disciplinary), ProjectionTrust.trusted);
      expect(projection.trustFor(ProjectionFacet.temporal), ProjectionTrust.untrusted);
      expect(projection.missingDependencyTargets, ['missing-1']);
    });

    test('same-scope authority conflict conflicts affected facet', () async {
      final memory = _Memory([
        _record(
          recordId: 'score-a',
          facet: ProjectionFacet.score,
          principalId: 'ref-a',
          generation: 1,
        ),
        _record(
          recordId: 'score-b',
          originSequence: 2,
          facet: ProjectionFacet.score,
          principalId: 'ref-b',
          generation: 1,
        ),
      ]);

      final projection = await projector.project(memory, 'match-1', context);

      expect(projection.trustFor(ProjectionFacet.authority), ProjectionTrust.conflicted);
      expect(projection.trustFor(ProjectionFacet.score), ProjectionTrust.conflicted);
      expect(projection.conflictNotes, isNotEmpty);
    });

    test('later arrival of missing dependency restores deterministic projection', () async {
      final partial = _Memory([
        _record(
          recordId: 'score-1',
          facet: ProjectionFacet.score,
          relationships: [CausalDependency(targetRecordId: 'dep-1')],
        ),
      ]);
      final complete = _Memory([
        _record(
          recordId: 'dep-1',
          facet: ProjectionFacet.temporal,
        ),
        _record(
          recordId: 'score-1',
          originSequence: 2,
          facet: ProjectionFacet.score,
          relationships: [CausalDependency(targetRecordId: 'dep-1')],
        ),
      ]);

      final before = await projector.project(partial, 'match-1', context);
      final after = await projector.project(complete, 'match-1', context);

      expect(before.trustFor(ProjectionFacet.score), ProjectionTrust.incomplete);
      expect(after.trustFor(ProjectionFacet.score), ProjectionTrust.trusted);
      expect(after.trustFor(ProjectionFacet.temporal), ProjectionTrust.trusted);
      expect(after.missingDependencyTargets, isEmpty);
    });

    test('projection can be discarded and rebuilt from Match Memory', () async {
      final memory = _Memory([
        _record(recordId: 'a', facet: ProjectionFacet.score),
        _record(recordId: 'b', originSequence: 2, facet: ProjectionFacet.disciplinary),
      ]);

      final first = await projector.project(memory, 'match-1', context);
      final rebuilt = await projector.project(memory, 'match-1', context);

      expect(rebuilt, equals(first));
    });

    test('projector never mutates Match Records', () async {
      final record = _record(recordId: 'a', facet: ProjectionFacet.score);
      final snapshot = _recordSnapshot(record);
      final memory = _Memory([record]);

      await projector.project(memory, 'match-1', context);

      expect(_recordSnapshot(record), equals(snapshot));
    });

    test('recordedAt cannot act as Last Write Wins', () async {
      final early = _record(
        recordId: 'early',
        originDeviceId: 'dev-a',
        originSequence: 1,
        facet: ProjectionFacet.score,
        payload: {'value': 1},
        recordedAt: DateTime.utc(2026, 1, 1),
      );
      final late = _record(
        recordId: 'late',
        originDeviceId: 'dev-a',
        originSequence: 2,
        facet: ProjectionFacet.score,
        payload: {'value': 2},
        recordedAt: DateTime.utc(2026, 12, 31),
      );

      final ordered = await projector.project(
        _Memory([early, late]),
        'match-1',
        context,
      );
      final reversedFetch = await projector.project(
        _Memory([late, early]),
        'match-1',
        context,
      );

      expect(ordered.committedRecordIds, ['early', 'late']);
      expect(reversedFetch.committedRecordIds, ['early', 'late']);
      expect(ordered, equals(reversedFetch));
    });

    test('does not depend on legacy Match or currentState types', () {
      final lib = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      for (final file in lib) {
        final text = file.readAsStringSync();
        expect(text, isNot(contains('package:match_core/')));
        expect(text, isNot(contains('MatchSession')));
        expect(text, isNot(contains('currentState')));
        expect(text, isNot(contains('LocalMatchDatabase')));
      }
    });

    test('projector has no direct knowledge of foundation payload keys', () {
      final projectorSource = File(
        'lib/projection/deterministic_match_projector.dart',
      ).readAsStringSync();

      expect(projectorSource, isNot(contains('projectionFacets')));
      expect(projectorSource, isNot(contains("'facet'")));
      expect(projectorSource, isNot(contains("'facets'")));
      expect(projectorSource, isNot(contains('StructuredPayload')));
    });

    test('alternative resolver maps same record differently without projector change', () async {
      final record = _record(
        recordId: 'score-alt',
        facet: ProjectionFacet.disciplinary,
      );
      const foundationProjector = DeterministicMatchProjector(foundationResolver);
      const prefixProjector = DeterministicMatchProjector(_PrefixSemanticsResolver());
      final memory = _Memory([record]);

      final foundationProjection = await foundationProjector.project(
        memory,
        'match-1',
        context,
      );
      final prefixProjection = await prefixProjector.project(
        memory,
        'match-1',
        context,
      );

      expect(
        foundationProjection.trustFor(ProjectionFacet.disciplinary),
        ProjectionTrust.trusted,
      );
      expect(
        foundationProjection.trustFor(ProjectionFacet.score),
        ProjectionTrust.untrusted,
      );
      expect(prefixProjection.trustFor(ProjectionFacet.score), ProjectionTrust.trusted);
      expect(
        prefixProjection.trustFor(ProjectionFacet.disciplinary),
        ProjectionTrust.untrusted,
      );
    });

    test('nested payload facet assignment remains independent across facets', () async {
      final memory = _Memory([
        _record(
          recordId: 'temporal-1',
          facet: ProjectionFacet.temporal,
          relationships: [CausalDependency(targetRecordId: 'missing-t')],
        ),
        _record(
          recordId: 'score-1',
          originSequence: 2,
          facet: ProjectionFacet.score,
        ),
        _record(
          recordId: 'card-1',
          originSequence: 3,
          facet: ProjectionFacet.disciplinary,
        ),
      ]);

      final projection = await projector.project(memory, 'match-1', context);

      expect(projection.trustFor(ProjectionFacet.temporal), ProjectionTrust.incomplete);
      expect(projection.trustFor(ProjectionFacet.score), ProjectionTrust.trusted);
      expect(projection.trustFor(ProjectionFacet.disciplinary), ProjectionTrust.trusted);
    });

    test('ACTION does not automatically affect score', () async {
      final memory = _Memory([
        _record(recordId: 'action-1', recordKind: RecordKind.action),
      ]);

      final projection = await projector.project(memory, 'match-1', context);

      expect(projection.trustFor(ProjectionFacet.score), ProjectionTrust.untrusted);
      expect(projection.trustFor(ProjectionFacet.coverage), ProjectionTrust.trusted);
      expect(projection.unsupportedSemanticRecordIds, ['action-1']);
    });

    test('HUMAN_DETERMINATION does not automatically affect disciplinary', () async {
      final memory = _Memory([
        _record(
          recordId: 'determination-1',
          recordKind: RecordKind.humanDetermination,
        ),
      ]);

      final projection = await projector.project(memory, 'match-1', context);

      expect(
        projection.trustFor(ProjectionFacet.disciplinary),
        ProjectionTrust.untrusted,
      );
      expect(projection.unsupportedSemanticRecordIds, ['determination-1']);
    });

    test('TEMPORAL_FACT affects temporal only with explicit semantics', () async {
      final withoutSemantics = await projector.project(
        _Memory([
          _record(recordId: 'temporal-a', recordKind: RecordKind.temporalFact),
        ]),
        'match-1',
        context,
      );
      final withSemantics = await projector.project(
        _Memory([
          _record(
            recordId: 'temporal-b',
            recordKind: RecordKind.temporalFact,
            facet: ProjectionFacet.temporal,
          ),
        ]),
        'match-1',
        context,
      );

      expect(
        withoutSemantics.trustFor(ProjectionFacet.temporal),
        ProjectionTrust.untrusted,
      );
      expect(withSemantics.trustFor(ProjectionFacet.temporal), ProjectionTrust.trusted);
    });

    test('unknown semantic record is preserved but not guessed into sporting facet', () async {
      final memory = _Memory([
        _record(recordId: 'unknown-1', recordKind: RecordKind.occurrence),
      ]);

      final projection = await projector.project(memory, 'match-1', context);

      expect(projection.committedRecordIds, ['unknown-1']);
      expect(projection.unsupportedSemanticRecordIds, ['unknown-1']);
      expect(projection.trustFor(ProjectionFacet.score), ProjectionTrust.untrusted);
      expect(projection.trustFor(ProjectionFacet.disciplinary), ProjectionTrust.untrusted);
      expect(projection.trustFor(ProjectionFacet.temporal), ProjectionTrust.untrusted);
    });

    test('CONFLICTED wins over INCOMPLETE by explicit cause resolution', () async {
      final memory = _Memory([
        _record(
          recordId: 'score-a',
          facet: ProjectionFacet.score,
          principalId: 'ref-a',
          generation: 1,
          relationships: [CausalDependency(targetRecordId: 'missing-1')],
        ),
        _record(
          recordId: 'score-b',
          originSequence: 2,
          facet: ProjectionFacet.score,
          principalId: 'ref-b',
          generation: 1,
        ),
      ]);

      final projection = await projector.project(memory, 'match-1', context);

      expect(projection.trustFor(ProjectionFacet.score), ProjectionTrust.conflicted);
      expect(
        projection.facetTrust[ProjectionFacet.score]!.reason,
        'contradictory valid authority',
      );
    });
  });
}

final class _PrefixSemanticsResolver implements ProjectionSemanticsResolver {
  const _PrefixSemanticsResolver();

  @override
  SemanticProjectionContribution resolve(MatchRecord record) {
    if (record.recordId.startsWith('score-')) {
      return const SemanticProjectionContribution(
        status: SemanticSupportStatus.supported,
        supportedFacets: [ProjectionFacet.score],
      );
    }
    return const SemanticProjectionContribution(
      status: SemanticSupportStatus.unsupported,
    );
  }
}

final class _Memory implements MatchMemory {
  _Memory(this._records);

  final List<MatchRecord> _records;

  @override
  Future<MatchRecord?> getById(String recordId) async {
    for (final record in _records) {
      if (record.recordId == recordId) return record;
    }
    return null;
  }

  @override
  Future<List<MatchRecord>> readCommittedForMatch(String matchId) async {
    return [
      for (final record in _records)
        if (record.matchId == matchId) record,
    ];
  }
}

MatchRecord _record({
  required String recordId,
  String matchId = 'match-1',
  String originDeviceId = 'dev-a',
  int originSequence = 1,
  String? facet,
  RecordKind recordKind = RecordKind.action,
  Map<String, Object?> payload = const {},
  List<RecordRelationship> relationships = const [],
  String principalId = 'ref-1',
  int generation = 1,
  DateTime? recordedAt,
}) {
  final fields = <String, Object?>{...payload};
  if (facet != null) {
    fields[FoundationPayloadSemanticsResolver.legacyFacet] = facet;
  }

  return MatchRecord(
    recordId: recordId,
    matchId: matchId,
    recordKind: recordKind,
    schemaVersion: 1,
    recordedAt: recordedAt ?? DateTime.utc(2026, 10, 2, 12, originSequence),
    originDeviceId: originDeviceId,
    originSequence: originSequence,
    payload: StructuredPayload(fields),
    integrity: const IntegrityMetadata(),
    authorityContext: AuthorityContext(
      scope: v1AuthorityScope,
      principal: AuthorityPrincipal(principalId: principalId),
      generation: AuthorityGeneration(value: generation),
    ),
    relationships: relationships,
  );
}

Map<String, Object?> _recordSnapshot(MatchRecord record) {
  return {
    'recordId': record.recordId,
    'originSequence': record.originSequence,
    'relationships': record.relationships.length,
    'payload': record.payload is StructuredPayload
        ? (record.payload as StructuredPayload).fields
        : null,
  };
}
