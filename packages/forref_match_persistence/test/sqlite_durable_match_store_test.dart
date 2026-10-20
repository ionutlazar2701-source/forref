import 'dart:io';

import 'package:forref_match_core/canonical_record_form.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('forref_match_memory_');
  });

  tearDown(() async {
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  test('successful append survives close and reopen', () async {
    final file = File('${temp.path}/memory.sqlite');
    final record = _record(
      recordId: 'rec-1',
      payload: {
        'meta': {'half': 1, 'tags': ['a', 'b']},
      },
      relationships: [CausalDependency(targetRecordId: 'cause-1')],
    );

    final store = SqliteDurableMatchStore.open(file);
    final outcome = await store.commit(record);
    expect(outcome, isA<DurableCommitSuccess>());
    expect(
      (outcome as DurableCommitSuccess).diagnostics,
      contains('commit-returned'),
    );
    await store.close();

    final reopened = SqliteDurableMatchStore.open(file);
    final loaded = await reopened.getById('rec-1');
    expect(loaded, isNotNull);
    expect(identicalCanonicalRecordContent(loaded!, record), isTrue);
    await reopened.close();
  });

  test('duplicate replay remains idempotent', () async {
    final store = SqliteDurableMatchStore.open(File('${temp.path}/memory.sqlite'));
    final record = _record(recordId: 'rec-1');

    final first = await store.commit(record);
    final second = await store.commit(record);

    expect(first, isA<DurableCommitSuccess>());
    expect(second, isA<DurableCommitSuccess>());
    expect((second as DurableCommitSuccess).diagnostics, contains('idempotent-no-op'));
    expect(await store.readCommittedForMatch('match-1'), hasLength(1));
    await store.close();
  });

  test('same recordId with different content fails closed', () async {
    final store = SqliteDurableMatchStore.open(File('${temp.path}/memory.sqlite'));
    await store.commit(_record(recordId: 'rec-1', payload: {'a': 1}));

    final outcome = await store.commit(
      _record(recordId: 'rec-1', payload: {'a': 2}),
    );

    expect(outcome, isA<DurableCommitFailure>());
    final stored = await store.getById('rec-1');
    expect((stored!.payload as StructuredPayload).fields['a'], 1);
    await store.close();
  });

  test('origin-sequence conflict fails closed', () async {
    final store = SqliteDurableMatchStore.open(File('${temp.path}/memory.sqlite'));
    await store.commit(_record(recordId: 'rec-a', originSequence: 1));

    final outcome = await store.commit(
      _record(recordId: 'rec-b', originSequence: 1),
    );

    expect(outcome, isA<DurableCommitFailure>());
    expect((outcome as DurableCommitFailure).reason, contains('origin-sequence'));
    expect(await store.getById('rec-b'), isNull);
    expect((await store.readCommittedForMatch('match-1')).single.recordId, 'rec-a');
    await store.close();
  });

  test('failed transaction creates no committed record', () async {
    final file = File('${temp.path}/memory.sqlite');
    final store = SqliteDurableMatchStore.open(file);
    store.abortBeforeCommitForTest = () {
      throw StateError('injected abort before commit');
    };

    final outcome = await store.commit(_record(recordId: 'rec-abort'));

    expect(outcome, isA<DurableCommitFailure>());
    expect(outcome, isNot(isA<DurableCommitSuccess>()));
    expect(await store.getById('rec-abort'), isNull);
    await store.close();

    final reopened = SqliteDurableMatchStore.open(file);
    expect(await reopened.getById('rec-abort'), isNull);
    await reopened.close();
  });

  test('adapter commit cannot update or delete a committed record', () async {
    final store = SqliteDurableMatchStore.open(File('${temp.path}/memory.sqlite'));
    await store.commit(_record(recordId: 'rec-1', payload: {'v': 1}));

    final updateAttempt = await store.commit(
      _record(recordId: 'rec-1', payload: {'v': 2}),
    );

    expect(updateAttempt, isA<DurableCommitFailure>());
    expect(
      ((await store.getById('rec-1'))!.payload as StructuredPayload).fields['v'],
      1,
    );
    expect(
      store.tableNames(),
      containsAll([
        'capture_intent_admissions',
        'committed_match_records',
        'generation_one_authority_roots',
      ]),
    );
    await store.close();
  });

  test('recovery does not depend on projection or current-state tables', () async {
    final file = File('${temp.path}/memory.sqlite');
    final store = SqliteDurableMatchStore.open(file);
    await store.commit(_record(recordId: 'rec-1', originSequence: 1));
    expect(
      store.tableNames(),
      containsAll([
        'capture_intent_admissions',
        'committed_match_records',
        'generation_one_authority_roots',
      ]),
    );
    await store.close();

    final reopened = SqliteDurableMatchStore.open(file);
    expect(
      reopened.tableNames(),
      containsAll([
        'capture_intent_admissions',
        'committed_match_records',
        'generation_one_authority_roots',
      ]),
    );
    expect(await reopened.readCommittedForMatch('match-1'), hasLength(1));
    await reopened.close();
  });

  test('sequence frontier reconstructs from committed records', () async {
    final file = File('${temp.path}/memory.sqlite');
    final store = SqliteDurableMatchStore.open(file);
    await store.commit(_record(recordId: 'r1', originSequence: 1));
    await store.commit(_record(recordId: 'r3', originSequence: 3));
    await store.close();

    final reopened = SqliteDurableMatchStore.open(file);
    final frontier = await reopened.originSequenceFrontier(
      matchId: 'match-1',
      originDeviceId: 'dev-a',
    );
    expect(frontier.committedSequences, [1, 3]);
    expect(frontier.highestContiguousCommitted, 1);
    expect(frontier.missingSequences, [2]);
    await reopened.close();
  });

  test('multiple matches remain isolated', () async {
    final store = SqliteDurableMatchStore.open(File('${temp.path}/memory.sqlite'));
    await store.commit(_record(recordId: 'm1-r1', matchId: 'match-1', originSequence: 1));
    await store.commit(_record(recordId: 'm2-r1', matchId: 'match-2', originSequence: 1));

    final match1 = await store.readCommittedForMatch('match-1');
    final match2 = await store.readCommittedForMatch('match-2');
    expect(match1.map((record) => record.recordId), ['m1-r1']);
    expect(match2.map((record) => record.recordId), ['m2-r1']);
    await store.close();
  });

  test('legacy Drift tables are untouched', () async {
    final legacyFile = File('${temp.path}/legacy.sqlite');
    final legacy = sqlite3.open(legacyFile.path);
    legacy.execute('CREATE TABLE matches (match_id TEXT)');
    legacy.execute('CREATE TABLE match_events (event_id TEXT)');
    legacy.execute("INSERT INTO matches (match_id) VALUES ('legacy-match')");
    legacy.close();

    final store = SqliteDurableMatchStore.open(File('${temp.path}/new_memory.sqlite'));
    await store.commit(_record(recordId: 'rec-1'));
    expect(store.tableNames(), isNot(contains('matches')));
    expect(store.tableNames(), isNot(contains('match_events')));
    await store.close();

    final reopenedLegacy = sqlite3.open(legacyFile.path);
    final rows = reopenedLegacy.select('SELECT match_id FROM matches');
    expect(rows.first.columnAt(0), 'legacy-match');
    final tables = reopenedLegacy.select(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    expect(
      [for (final row in tables) row.columnAt(0)],
      containsAll(['matches', 'match_events']),
    );
    reopenedLegacy.close();

    final sources = Directory('lib')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final source in sources) {
      final text = source.readAsStringSync();
      expect(text, isNot(contains('LocalMatchDatabase')));
      expect(text, isNot(contains('MatchSession')));
      expect(text, isNot(contains('package:match_core')));
    }
  });

  test('originSequence below 1 is rejected and stores nothing', () async {
    final store = SqliteDurableMatchStore.open(File('${temp.path}/memory.sqlite'));
    final outcome = await store.commit(_record(recordId: 'rec-0', originSequence: 0));
    expect(outcome, isA<DurableCommitFailure>());
    expect(await store.readCommittedForMatch('match-1'), isEmpty);
    await store.close();
  });
}

MatchRecord _record({
  required String recordId,
  String matchId = 'match-1',
  String originDeviceId = 'dev-a',
  int originSequence = 1,
  Map<String, Object?> payload = const {'kind': 'sample'},
  List<RecordRelationship> relationships = const [],
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
    integrity: const IntegrityMetadata(evidenceRefs: ['evidence-1']),
    temporalContext: const TemporalContext(evidenceIds: ['clock-1']),
    authorityContext: const AuthorityContext(
      scope: v1AuthorityScope,
      principal: AuthorityPrincipal(principalId: 'ref-1'),
      activeCaptureDevice: ActiveCaptureDevice(deviceId: 'phone-a'),
      generation: AuthorityGeneration(value: 1),
    ),
    relationships: relationships,
  );
}
