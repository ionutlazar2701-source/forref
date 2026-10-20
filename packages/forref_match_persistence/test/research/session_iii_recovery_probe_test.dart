import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('forref_session_iii_recovery_');
  });

  tearDown(() async {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('a committed yellow survives closing and reopening the same file', () async {
    final store = await _open(temp);
    expect(await store.commit(_yellow(recordId: 'y1', intent: 'intent-y1')),
        isA<DurableCommitSuccess>());
    await store.close();

    final reopened = SqliteDurableMatchStore.open(File('${temp.path}/memory.sqlite'));
    final records = await reopened.readCommittedForMatch('match-1');
    expect(records.map((record) => record.recordId), contains('y1'));
    expect(records.where((record) => record.payload is SendOffPayload), isEmpty);
    await reopened.close();
  });

  test('the same capture intent retries as the existing yellow', () async {
    final store = await _open(temp);
    expect(await store.commit(_yellow(recordId: 'y1', intent: 'intent-y1')),
        isA<DurableCommitSuccess>());
    final retry = await store.commit(
      _yellow(recordId: 'y1-retry', intent: 'intent-y1', originSequence: 2),
    );
    expect(retry, isA<DurableCommitSuccess>());
    expect((retry as DurableCommitSuccess).committedRecordId, 'y1');
    final records = await store.readCommittedForMatch('match-1');
    expect(records.where((record) => record.payload is YellowCardPayload), hasLength(1));
    expect(records.where((record) => record.payload is SendOffPayload), isEmpty);
    await store.close();
  });

  test('a known D1 failure leaves no yellow and is not an unknown outcome', () async {
    final store = await _open(temp);
    store.abortBeforeCommitForTest = () => throw StateError('abort');
    final outcome = await store.commit(_yellow(recordId: 'y-fail', intent: 'intent-fail'));
    expect(outcome, isA<DurableCommitFailure>());
    expect(await store.getById('y-fail'), isNull);
    expect(store.captureIntentAdmissionCount(matchId: 'match-1'), 0);
    await store.close();
  });

  test('a missing row without a failure result is not a known failure', () async {
    final store = await _open(temp);
    expect(await store.getById('never-submitted'), isNull);
    await store.close();
  });
}

Future<SqliteDurableMatchStore> _open(Directory temp) async {
  final store = SqliteDurableMatchStore.open(File('${temp.path}/memory.sqlite'));
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
  return store;
}

MatchRecord _yellow({
  required String recordId,
  required String intent,
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
    payload: YellowCardPayload(
      participantId: MatchParticipantId('p-1'),
      accountingScope: DisciplinaryAccountingScope.match,
      captureIntentId: intent,
    ),
    integrity: IntegrityMetadata(evidenceRefs: [recordId]),
    authorityContext: AuthorityContext(
      scope: v1AuthorityScope,
      principal: const AuthorityPrincipal(principalId: 'ref-1'),
      generation: const AuthorityGeneration(value: 1),
    ),
  );
}
