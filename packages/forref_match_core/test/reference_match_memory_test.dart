import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

void main() {
  group('ReferenceOnlyMatchMemory', () {
    late ReferenceOnlyMatchMemory memory;

    setUp(() => memory = ReferenceOnlyMatchMemory());

    test('append preserves immutable record', () {
      final record = _record(
        recordId: 'rec-1',
        originSequence: 1,
        payload: {'event': 'goal'},
      );

      final outcome = memory.appendRecord(record);

      expect(outcome, isA<ReferenceAppendSuccess>());
      final stored = (outcome as ReferenceAppendSuccess).record;
      expect(stored.recordId, 'rec-1');
      expect(stored.payload, isA<StructuredPayload>());
      expect(
        (stored.payload as StructuredPayload).fields['event'],
        'goal',
      );
    });

    test('identical duplicate is idempotent no-op', () async {
      final record = _record(recordId: 'rec-1', originSequence: 1);
      memory.appendRecord(record);

      final second = memory.appendRecord(record);

      expect(second, isA<ReferenceAppendIdempotentNoOp>());
      expect(await memory.readCommittedForMatch('match-1'), hasLength(1));
    });

    test('same recordId with different content fails closed', () async {
      memory.appendRecord(
        _record(recordId: 'rec-1', originSequence: 1, payload: {'a': 1}),
      );

      final outcome = memory.appendRecord(
        _record(recordId: 'rec-1', originSequence: 1, payload: {'a': 2}),
      );

      expect(outcome, isA<ReferenceAppendIdentityConflict>());
      expect(await memory.readCommittedForMatch('match-1'), hasLength(1));
      expect(
        ((await memory.readCommittedForMatch('match-1')).single.payload
                as StructuredPayload)
            .fields['a'],
        1,
      );
    });

    test('records are never overwritten', () async {
      memory.appendRecord(
        _record(recordId: 'rec-1', originSequence: 1, payload: {'v': 1}),
      );
      memory.appendRecord(
        _record(recordId: 'rec-1', originSequence: 1, payload: {'v': 2}),
      );
      memory.appendRecord(
        _record(recordId: 'rec-2', originSequence: 2, payload: {'v': 9}),
      );

      final records = await memory.readCommittedForMatch('match-1');
      expect(records, hasLength(2));
      expect(records.map((r) => r.recordId).toList(), ['rec-1', 'rec-2']);
    });

    test('origin sequence frontier advances only from committed records', () {
      memory.appendRecord(_record(recordId: 'r1', originSequence: 1));
      memory.appendRecord(_record(recordId: 'r2', originSequence: 3));

      final frontier = memory.originSequenceFrontier(
        matchId: 'match-1',
        originDeviceId: 'dev-a',
      );

      expect(frontier.committedSequences, [1, 3]);
      expect(frontier.highestObserved, 3);
      expect(frontier.highestContiguousCommitted, 1);
      expect(frontier.missingSequences, [2]);
    });

    test('rejected conflict does not consume sequence frontier slot', () {
      memory.appendRecord(
        _record(recordId: 'r1', originSequence: 1, payload: {'x': 1}),
      );
      memory.appendRecord(
        _record(recordId: 'r1', originSequence: 99, payload: {'x': 2}),
      );

      final frontier = memory.originSequenceFrontier(
        matchId: 'match-1',
        originDeviceId: 'dev-a',
      );

      expect(frontier.committedSequences, [1]);
      expect(frontier.missingSequences, isEmpty);
      expect(frontier.highestContiguousCommitted, 1);
    });

    test('sequence gaps remain observable', () {
      memory.appendRecord(_record(recordId: 'r1', originSequence: 1));
      memory.appendRecord(_record(recordId: 'r2', originSequence: 2));
      memory.appendRecord(_record(recordId: 'r4', originSequence: 4));

      final frontier = memory.originSequenceFrontier(
        matchId: 'match-1',
        originDeviceId: 'dev-a',
      );

      expect(frontier.committedSequences, [1, 2, 4]);
      expect(frontier.highestContiguousCommitted, 2);
      expect(frontier.missingSequences, [3]);
    });

    test('records from multiple origins coexist without global ordering', () async {
      memory.appendRecord(_record(
        recordId: 'a-2',
        originDeviceId: 'dev-a',
        originSequence: 2,
      ));
      memory.appendRecord(_record(
        recordId: 'b-1',
        originDeviceId: 'dev-b',
        originSequence: 1,
      ));
      memory.appendRecord(_record(
        recordId: 'a-1',
        originDeviceId: 'dev-a',
        originSequence: 1,
      ));

      final records = await memory.readCommittedForMatch('match-1');
      expect(records.map((r) => r.recordId).toList(), ['a-2', 'b-1', 'a-1']);

      final frontierA = memory.originSequenceFrontier(
        matchId: 'match-1',
        originDeviceId: 'dev-a',
      );
      final frontierB = memory.originSequenceFrontier(
        matchId: 'match-1',
        originDeviceId: 'dev-b',
      );

      expect(frontierA.committedSequences, [1, 2]);
      expect(frontierB.committedSequences, [1]);
      expect(frontierA.highestContiguousCommitted, 2);
    });

    test('older authority generation records remain historical data', () async {
      memory.appendRecord(_record(
        recordId: 'gen-1',
        originSequence: 1,
        generation: 1,
      ));
      memory.appendRecord(_record(
        recordId: 'gen-2',
        originSequence: 2,
        generation: 2,
      ));

      final records = await memory.readCommittedForMatch('match-1');
      expect(records, hasLength(2));
      expect(records.first.authorityContext!.generation!.value, 1);
      expect(records.last.authorityContext!.generation!.value, 2);
    });

    test('reference Match Memory cannot claim D1 durability', () {
      expect(memory.claimsD1Durability, isFalse);
      expect(memory, isA<ReferenceDurabilityMarker>());
      expect(memory, isNot(isA<DurableCommitPort>()));
    });

    test('structurally identical nested payloads are idempotent', () async {
      final nested = {
        'meta': {'half': 1, 'tags': ['a', 'b']},
        'count': 2,
      };
      memory.appendRecord(
        _record(recordId: 'rec-1', originSequence: 1, payload: nested),
      );

      final resubmit = _record(
        recordId: 'rec-1',
        originSequence: 1,
        payload: {
          'meta': {'half': 1, 'tags': ['a', 'b']},
          'count': 2,
        },
      );
      final outcome = memory.appendRecord(resubmit);

      expect(outcome, isA<ReferenceAppendIdempotentNoOp>());
      expect(await memory.readCommittedForMatch('match-1'), hasLength(1));
    });

    test('nested semantic payload difference causes identity conflict', () async {
      memory.appendRecord(
        _record(
          recordId: 'rec-1',
          originSequence: 1,
          payload: {'meta': {'tags': ['a', 'b']}},
        ),
      );

      final outcome = memory.appendRecord(
        _record(
          recordId: 'rec-1',
          originSequence: 1,
          payload: {'meta': {'tags': ['a', 'c']}},
        ),
      );

      expect(outcome, isA<ReferenceAppendIdentityConflict>());
      expect(await memory.readCommittedForMatch('match-1'), hasLength(1));
    });

    test('originSequence zero is rejected', () async {
      final outcome = memory.appendRecord(
        _record(recordId: 'rec-0', originSequence: 0),
      );

      expect(outcome, isA<ReferenceAppendInvalidOriginSequence>());
      expect(await memory.readCommittedForMatch('match-1'), isEmpty);
    });

    test('originSequence negative is rejected', () async {
      final outcome = memory.appendRecord(
        _record(recordId: 'rec-neg', originSequence: -1),
      );

      expect(outcome, isA<ReferenceAppendInvalidOriginSequence>());
      expect(await memory.readCommittedForMatch('match-1'), isEmpty);
    });

    test('same origin slot cannot commit two distinct records', () async {
      memory.appendRecord(_record(recordId: 'rec-a', originSequence: 1));

      final outcome = memory.appendRecord(
        _record(recordId: 'rec-b', originSequence: 1),
      );

      expect(outcome, isA<ReferenceAppendOriginSequenceConflict>());
      expect(await memory.readCommittedForMatch('match-1'), hasLength(1));
      expect(
        (await memory.readCommittedForMatch('match-1')).single.recordId,
        'rec-a',
      );
    });

    test('rejected origin sequence conflict does not alter Match Memory', () async {
      memory.appendRecord(
        _record(recordId: 'rec-a', originSequence: 1, payload: {'v': 1}),
      );
      memory.appendRecord(
        _record(recordId: 'rec-b', originSequence: 1, payload: {'v': 2}),
      );

      final frontier = memory.originSequenceFrontier(
        matchId: 'match-1',
        originDeviceId: 'dev-a',
      );

      expect(frontier.committedSequences, [1]);
      expect(await memory.getById('rec-b'), isNull);
    });
  });
}

MatchRecord _record({
  required String recordId,
  String matchId = 'match-1',
  String originDeviceId = 'dev-a',
  int originSequence = 1,
  Map<String, Object?> payload = const {'kind': 'sample'},
  int? generation,
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: matchId,
    recordKind: RecordKind.action,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 2, 12, originSequence),
    originDeviceId: originDeviceId,
    originSequence: originSequence,
    payload: StructuredPayload(payload),
    integrity: const IntegrityMetadata(),
    authorityContext: AuthorityContext(
      scope: v1AuthorityScope,
      generation: generation == null
          ? null
          : AuthorityGeneration(value: generation),
    ),
  );
}
