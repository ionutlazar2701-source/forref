import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('forref_origin_seq_');
  });

  tearDown(() async {
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  test('first committed record for an origin gets sequence 1', () async {
    final store = SqliteDurableMatchStore.open(File('${temp.path}/memory.sqlite'));
    addTearDown(store.close);

    final outcome = await store.commitAtNextOriginSequence(
      _request(recordId: 'rec-1'),
    );

    expect(outcome, isA<DurableCommitSuccess>());
    final stored = await store.getById('rec-1');
    expect(stored!.originSequence, 1);
  });

  test('next successful record gets sequence 2', () async {
    final store = SqliteDurableMatchStore.open(File('${temp.path}/memory.sqlite'));
    addTearDown(store.close);

    expect(
      await store.commitAtNextOriginSequence(_request(recordId: 'rec-1')),
      isA<DurableCommitSuccess>(),
    );
    expect(
      await store.commitAtNextOriginSequence(_request(recordId: 'rec-2')),
      isA<DurableCommitSuccess>(),
    );

    final records = await store.readCommittedForMatch('match-1');
    expect(records.map((record) => record.originSequence).toList(), [1, 2]);
  });

  test('failed commit does not create a committed sequence gap', () async {
    final store = SqliteDurableMatchStore.open(File('${temp.path}/memory.sqlite'));
    addTearDown(store.close);

    store.abortBeforeCommitForTest = () {
      throw StateError('abort before commit');
    };
    expect(
      await store.commitAtNextOriginSequence(_request(recordId: 'rec-fail')),
      isA<DurableCommitFailure>(),
    );
    store.abortBeforeCommitForTest = null;

    expect(
      await store.commitAtNextOriginSequence(_request(recordId: 'rec-1')),
      isA<DurableCommitSuccess>(),
    );
    final frontier = await store.originSequenceFrontier(
      matchId: 'match-1',
      originDeviceId: 'dev-a',
    );
    expect(frontier.committedSequences, [1]);
    expect(frontier.missingSequences, isEmpty);
  });

  test('close reopen continues from committed frontier', () async {
    final file = File('${temp.path}/memory.sqlite');
    final store = SqliteDurableMatchStore.open(file);
    expect(
      await store.commitAtNextOriginSequence(_request(recordId: 'rec-1')),
      isA<DurableCommitSuccess>(),
    );
    await store.close();

    final reopened = SqliteDurableMatchStore.open(file);
    addTearDown(reopened.close);
    expect(
      await reopened.commitAtNextOriginSequence(_request(recordId: 'rec-2')),
      isA<DurableCommitSuccess>(),
    );
    final stored = await reopened.getById('rec-2');
    expect(stored!.originSequence, 2);
  });

  test('concurrent commit attempts cannot commit the same origin sequence', () async {
    final store = SqliteDurableMatchStore.open(File('${temp.path}/memory.sqlite'));
    addTearDown(store.close);

    final results = await Future.wait([
      store.commitAtNextOriginSequence(_request(recordId: 'rec-a')),
      store.commitAtNextOriginSequence(_request(recordId: 'rec-b')),
    ]);

    expect(results.every((result) => result is DurableCommitSuccess), isTrue);
    final sequences = [
      for (final record in await store.readCommittedForMatch('match-1'))
        record.originSequence,
    ]..sort();
    expect(sequences, [1, 2]);
  });

  test('two origins maintain independent sequence spaces', () async {
    final store = SqliteDurableMatchStore.open(File('${temp.path}/memory.sqlite'));
    addTearDown(store.close);

    expect(
      await store.commitAtNextOriginSequence(
        _request(recordId: 'a-1', originDeviceId: 'dev-a'),
      ),
      isA<DurableCommitSuccess>(),
    );
    expect(
      await store.commitAtNextOriginSequence(
        _request(recordId: 'b-1', originDeviceId: 'dev-b'),
      ),
      isA<DurableCommitSuccess>(),
    );

    final frontierA = await store.originSequenceFrontier(
      matchId: 'match-1',
      originDeviceId: 'dev-a',
    );
    final frontierB = await store.originSequenceFrontier(
      matchId: 'match-1',
      originDeviceId: 'dev-b',
    );
    expect(frontierA.committedSequences, [1]);
    expect(frontierB.committedSequences, [1]);
  });

  test('two matches maintain independent sequence spaces', () async {
    final store = SqliteDurableMatchStore.open(File('${temp.path}/memory.sqlite'));
    addTearDown(store.close);

    expect(
      await store.commitAtNextOriginSequence(
        _request(recordId: 'm1-1', matchId: 'match-1'),
      ),
      isA<DurableCommitSuccess>(),
    );
    expect(
      await store.commitAtNextOriginSequence(
        _request(recordId: 'm2-1', matchId: 'match-2'),
      ),
      isA<DurableCommitSuccess>(),
    );

    final match1 = await store.readCommittedForMatch('match-1');
    final match2 = await store.readCommittedForMatch('match-2');
    expect(match1.single.originSequence, 1);
    expect(match2.single.originSequence, 1);
  });

  test('no separate sequence counter table exists', () {
    final source = File('lib/sqlite_durable_match_store.dart').readAsStringSync();
    expect(source, isNot(contains('origin_sequence_counter')));
    expect(source, isNot(contains('CREATE TABLE IF NOT EXISTS origin_sequence')));
    expect(source, contains('COALESCE(MAX(origin_sequence), 0) + 1'));
  });
}

AuthoritativeRecordCommitRequest _request({
  required String recordId,
  String matchId = 'match-1',
  String originDeviceId = 'dev-a',
}) {
  return AuthoritativeRecordCommitRequest(
    recordId: recordId,
    matchId: matchId,
    originDeviceId: originDeviceId,
    recordKind: RecordKind.temporalFact,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 2, 12),
    payload: TemporalTransitionPayload(
      semanticType: V1SemanticTypeCode.matchStarted,
    ),
    integrity: const IntegrityMetadata(),
    authorityContext: const AuthorityContext(
      scope: v1AuthorityScope,
      principal: AuthorityPrincipal(principalId: 'ref-1'),
      generation: AuthorityGeneration(value: 1),
    ),
  );
}
