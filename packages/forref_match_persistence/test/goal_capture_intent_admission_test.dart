import 'dart:convert';
import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('forref_goal_intent_');
  });

  tearDown(() async {
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  Future<void> admitRoot(SqliteDurableMatchStore store) async {
    expect(
      await store.commitGenerationOneAuthorityRoot(
        const GenerationOneAuthorityRoot(
          matchId: 'match-1',
          principalId: 'ref-1',
          deviceId: 'dev-a',
        ),
      ),
      isA<GenerationOneRootCommitSuccess>(),
    );
  }

  test('abortBeforeCommitForTest rolls back record and capture intent',
      () async {
    final file = File('${temp.path}/memory.sqlite');
    final store = SqliteDurableMatchStore.open(file);
    await admitRoot(store);
    store.abortBeforeCommitForTest = () {
      throw StateError('abort before commit');
    };

    final record = _goal(recordId: 'goal-1', captureIntentId: 'intent-1');
    final outcome = await store.commit(record);

    expect(outcome, isA<DurableCommitFailure>());
    expect(await store.getById('goal-1'), isNull);
    expect(store.captureIntentAdmissionCount(matchId: 'match-1'), 0);
    await store.close();

    final reopened = SqliteDurableMatchStore.open(file);
    expect(await reopened.getById('goal-1'), isNull);
    expect(reopened.captureIntentAdmissionCount(matchId: 'match-1'), 0);
    await reopened.close();
  });

  test('after DurableCommitSuccess close reopen keeps record and intent',
      () async {
    final file = File('${temp.path}/memory.sqlite');
    final store = SqliteDurableMatchStore.open(file);
    await admitRoot(store);
    final record = _goal(recordId: 'goal-1', captureIntentId: 'intent-1');
    expect(await store.commit(record), isA<DurableCommitSuccess>());
    expect(store.captureIntentAdmissionCount(matchId: 'match-1'), 1);
    await store.close();

    final reopened = SqliteDurableMatchStore.open(file);
    expect(await reopened.getById('goal-1'), isNotNull);
    expect(reopened.captureIntentAdmissionCount(matchId: 'match-1'), 1);
    await reopened.close();
  });

  test(
      'same capture intent retry returns original record id without second row',
      () async {
    final file = File('${temp.path}/memory.sqlite');
    final store = SqliteDurableMatchStore.open(file);
    await admitRoot(store);
    final first = _goal(recordId: 'goal-1', captureIntentId: 'intent-1');
    final firstOutcome = await store.commit(first);
    expect(firstOutcome, isA<DurableCommitSuccess>());

    final retry = _goal(
      recordId: 'goal-2',
      captureIntentId: 'intent-1',
      originSequence: 2,
    );
    final retryOutcome = await store.commit(retry);
    expect(retryOutcome, isA<DurableCommitSuccess>());
    expect(
      (retryOutcome as DurableCommitSuccess).committedRecordId,
      'goal-1',
    );
    expect(store.captureIntentAdmissionCount(matchId: 'match-1'), 1);
    expect(await store.readCommittedForMatch('match-1'), hasLength(1));
    await store.close();
  });

  test('conflicting scoring team on same intent fails with one row', () async {
    final store =
        SqliteDurableMatchStore.open(File('${temp.path}/memory.sqlite'));
    await admitRoot(store);
    expect(
      await store.commit(
        _goal(
          recordId: 'goal-1',
          captureIntentId: 'intent-1',
          scoringTeamId: 'team-home',
        ),
      ),
      isA<DurableCommitSuccess>(),
    );

    final conflict = await store.commit(
      _goal(
        recordId: 'goal-2',
        captureIntentId: 'intent-1',
        scoringTeamId: 'team-away',
        originSequence: 2,
      ),
    );
    expect(conflict, isA<DurableCommitFailure>());
    expect(
      (conflict as DurableCommitFailure).reason,
      contains('idempotency conflict'),
    );
    expect(store.captureIntentAdmissionCount(matchId: 'match-1'), 1);
    expect(await store.readCommittedForMatch('match-1'), hasLength(1));
    await store.close();
  });

  test('concurrent duplicate intent commits end with one admission row',
      () async {
    final store =
        SqliteDurableMatchStore.open(File('${temp.path}/memory.sqlite'));
    await admitRoot(store);
    final results = await Future.wait([
      store.commit(
        _goal(
            recordId: 'goal-a', captureIntentId: 'intent-1', originSequence: 1),
      ),
      store.commit(
        _goal(
            recordId: 'goal-b', captureIntentId: 'intent-1', originSequence: 2),
      ),
    ]);

    expect(results.every((result) => result is DurableCommitSuccess), isTrue);
    final successes = results.cast<DurableCommitSuccess>();
    expect(successes.map((s) => s.committedRecordId).toSet(), hasLength(1));
    expect(store.captureIntentAdmissionCount(matchId: 'match-1'), 1);
    expect(await store.readCommittedForMatch('match-1'), hasLength(1));
    await store.close();
  });

  test('missing generation-1 root is not recreated when records exist',
      () async {
    final file = File('${temp.path}/memory.sqlite');
    final store = SqliteDurableMatchStore.open(file);
    expect(
      await store.commit(
        MatchRecord(
          recordId: 'started-1',
          matchId: 'match-1',
          recordKind: RecordKind.temporalFact,
          schemaVersion: 1,
          recordedAt: DateTime.utc(2026, 10, 2, 12),
          originDeviceId: 'dev-a',
          originSequence: 1,
          payload: TemporalTransitionPayload(
            semanticType: V1SemanticTypeCode.matchStarted,
          ),
          integrity: const IntegrityMetadata(evidenceRefs: ['evidence-1']),
          authorityContext: const AuthorityContext(
            scope: v1AuthorityScope,
            principal: AuthorityPrincipal(principalId: 'ref-1'),
            generation: AuthorityGeneration(value: 1),
          ),
        ),
      ),
      isA<DurableCommitSuccess>(),
    );
    expect(
      await store.commit(_goal(
          recordId: 'goal-1', captureIntentId: 'intent-1', originSequence: 2)),
      isA<DurableCommitFailure>(),
    );
    expect(await store.readGenerationOneAuthorityRoot('match-1'), isNull);
    expect(store.captureIntentAdmissionCount(matchId: 'match-1'), 0);
    await store.close();

    final reopened = SqliteDurableMatchStore.open(file);
    expect(await reopened.readGenerationOneAuthorityRoot('match-1'), isNull);
    expect(
      await reopened.commit(
        _goal(
            recordId: 'goal-2', captureIntentId: 'intent-2', originSequence: 2),
      ),
      isA<DurableCommitFailure>(),
    );
    expect(await reopened.readGenerationOneAuthorityRoot('match-1'), isNull);
    expect(
      (await reopened.readCommittedForMatch('match-1'))
          .where((record) => record.payload is GoalPayload),
      isEmpty,
    );
    await reopened.close();
  });

  test('generation-1 root commits before records and survives reopen',
      () async {
    final file = File('${temp.path}/memory.sqlite');
    final store = SqliteDurableMatchStore.open(file);
    const root = GenerationOneAuthorityRoot(
      matchId: 'match-1',
      principalId: 'ref-1',
      deviceId: 'phone-a',
    );
    expect(
      await store.commitGenerationOneAuthorityRoot(root),
      isA<GenerationOneRootCommitSuccess>(),
    );
    expect(await store.readGenerationOneAuthorityRoot('match-1'), root);
    await store.close();

    final reopened = SqliteDurableMatchStore.open(file);
    expect(await reopened.readGenerationOneAuthorityRoot('match-1'), root);
    await reopened.close();
  });

  test('second generation-1 root with different principal fails', () async {
    final store =
        SqliteDurableMatchStore.open(File('${temp.path}/memory.sqlite'));
    expect(
      await store.commitGenerationOneAuthorityRoot(
        const GenerationOneAuthorityRoot(
          matchId: 'match-1',
          principalId: 'ref-1',
          deviceId: 'phone-a',
        ),
      ),
      isA<GenerationOneRootCommitSuccess>(),
    );
    final conflict = await store.commitGenerationOneAuthorityRoot(
      const GenerationOneAuthorityRoot(
        matchId: 'match-1',
        principalId: 'ref-2',
        deviceId: 'phone-a',
      ),
    );
    expect(conflict, isA<GenerationOneRootCommitFailure>());
    await store.close();
  });

  test('corrupt json row remains and quarantine is reported on read', () async {
    final file = File('${temp.path}/memory.sqlite');
    final store = SqliteDurableMatchStore.open(file);
    await admitRoot(store);
    await store
        .commit(_goal(recordId: 'goal-good', captureIntentId: 'intent-1'));
    await store.commit(
      _goal(
        recordId: 'goal-bad',
        captureIntentId: 'intent-2',
        originSequence: 2,
      ),
    );
    await store.close();

    final db = sqlite3.open(file.path);
    final raw = db
        .select(
          'SELECT record_json FROM committed_match_records WHERE record_id = ?',
          ['goal-bad'],
        )
        .single
        .columnAt(0) as String;
    final json = jsonDecode(raw) as Map<String, Object?>;
    json['payload'] = 'not-an-object';
    db.execute(
      'UPDATE committed_match_records SET record_json = ? WHERE record_id = ?',
      [jsonEncode(json), 'goal-bad'],
    );
    db.close();

    final reopened = SqliteDurableMatchStore.open(file);
    final snapshot =
        await reopened.readCommittedForMatchWithQuarantine('match-1');
    expect(snapshot.records.map((r) => r.recordId), ['goal-good']);
    expect(snapshot.quarantinedRecordIds, ['goal-bad']);

    final verifyDb = sqlite3.open(file.path);
    final rows = verifyDb.select(
      'SELECT COUNT(*) FROM committed_match_records WHERE match_id = ?',
      ['match-1'],
    );
    expect(rows.single.columnAt(0), 2);
    verifyDb.close();

    expect(
      reopened.readCommittedForMatch('match-1'),
      throwsA(isA<CommittedRecordQuarantineException>()),
    );
    await reopened.close();
  });

  test(
      'commitAtNextOriginSequence idempotent intent does not allocate sequence',
      () async {
    final store =
        SqliteDurableMatchStore.open(File('${temp.path}/memory.sqlite'));
    await admitRoot(store);
    final request =
        _goalRequest(recordId: 'goal-1', captureIntentId: 'intent-1');
    expect(
      await store.commitAtNextOriginSequence(request),
      isA<DurableCommitSuccess>(),
    );
    final retry = _goalRequest(recordId: 'goal-2', captureIntentId: 'intent-1');
    final outcome = await store.commitAtNextOriginSequence(retry);
    expect(outcome, isA<DurableCommitSuccess>());
    expect((outcome as DurableCommitSuccess).committedRecordId, 'goal-1');
    expect(await store.readCommittedForMatch('match-1'), hasLength(1));
    await store.close();
  });
}

MatchRecord _goal({
  required String recordId,
  required String captureIntentId,
  String scoringTeamId = 'team-home',
  int originSequence = 1,
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: 'match-1',
    recordKind: RecordKind.humanDetermination,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 2, 12, originSequence),
    originDeviceId: 'dev-a',
    originSequence: originSequence,
    payload: GoalPayload(
      scoringTeamId: MatchTeamId(scoringTeamId),
      captureIntentId: captureIntentId,
    ),
    integrity: const IntegrityMetadata(evidenceRefs: ['evidence-1']),
    authorityContext: const AuthorityContext(
      scope: v1AuthorityScope,
      principal: AuthorityPrincipal(principalId: 'ref-1'),
      activeCaptureDevice: ActiveCaptureDevice(deviceId: 'phone-a'),
      generation: AuthorityGeneration(value: 1),
    ),
  );
}

AuthoritativeRecordCommitRequest _goalRequest({
  required String recordId,
  required String captureIntentId,
  String scoringTeamId = 'team-home',
}) {
  return AuthoritativeRecordCommitRequest(
    recordId: recordId,
    matchId: 'match-1',
    originDeviceId: 'dev-a',
    recordKind: RecordKind.humanDetermination,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 2, 12),
    payload: GoalPayload(
      scoringTeamId: MatchTeamId(scoringTeamId),
      captureIntentId: captureIntentId,
    ),
    integrity: const IntegrityMetadata(evidenceRefs: ['evidence-1']),
    authorityContext: const AuthorityContext(
      scope: v1AuthorityScope,
      principal: AuthorityPrincipal(principalId: 'ref-1'),
      activeCaptureDevice: ActiveCaptureDevice(deviceId: 'phone-a'),
      generation: AuthorityGeneration(value: 1),
    ),
  );
}
