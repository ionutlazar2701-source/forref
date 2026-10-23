import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('forref_night_yellow_');
  });

  tearDown(() async {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<SqliteDurableMatchStore> open() async {
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

  test('failed D1 stores no yellow and no admission', () async {
    final store = await open();
    store.abortBeforeCommitForTest = () => throw StateError('abort');
    final outcome = await store.commit(_yellow(recordId: 'y-1'));
    expect(outcome, isA<DurableCommitFailure>());
    expect(await store.getById('y-1'), isNull);
    expect(store.captureIntentAdmissionCount(matchId: 'match-1'), 0);
    await store.close();
  });

  test('same yellow intent retries as one row', () async {
    final store = await open();
    expect(await store.commit(_yellow(recordId: 'y-1')), isA<DurableCommitSuccess>());
    final retry = await store.commit(_yellow(recordId: 'y-2', originSequence: 2));
    expect(retry, isA<DurableCommitSuccess>());
    expect((retry as DurableCommitSuccess).committedRecordId, 'y-1');
    expect(await store.readCommittedForMatch('match-1'), hasLength(1));
    expect(store.captureIntentAdmissionCount(matchId: 'match-1'), 1);
    await store.close();
  });

  test('same intent rebound to another participant conflicts', () async {
    final store = await open();
    expect(await store.commit(_yellow(recordId: 'y-1')), isA<DurableCommitSuccess>());
    final conflict = await store.commit(
      _yellow(
        recordId: 'y-2',
        originSequence: 2,
        participantId: 'person-b',
      ),
    );
    expect(conflict, isA<DurableCommitFailure>());
    expect(await store.readCommittedForMatch('match-1'), hasLength(1));
    await store.close();
  });

  test('generation 2 yellow is not admitted', () async {
    final store = await open();
    final outcome = await store.commit(_yellow(recordId: 'y-gen2', generation: 2));
    expect(outcome, isA<DurableCommitFailure>());
    expect(await store.getById('y-gen2'), isNull);
    expect(store.captureIntentAdmissionCount(matchId: 'match-1'), 0);
    await store.close();
  });

  test('field entry round-trips and is not MATCH_STARTED', () async {
    final store = await open();
    final record = _field(recordId: 'entered-1');
    expect(await store.commit(record), isA<DurableCommitSuccess>());
    final stored = await store.getById('entered-1');
    expect(stored!.payload, isA<RefereeEnteredFieldPayload>());
    expect(stored.payload, isNot(isA<TemporalTransitionPayload>()));
    await store.close();
  });

  test('reopen keeps the yellow row', () async {
    final file = File('${temp.path}/memory.sqlite');
    final store = SqliteDurableMatchStore.open(file);
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
    expect(await store.commit(_yellow(recordId: 'y-1')), isA<DurableCommitSuccess>());
    await store.close();
    final reopened = SqliteDurableMatchStore.open(file);
    final stored = await reopened.getById('y-1');
    final payload = stored!.payload as YellowCardPayload;
    expect(payload.participantId, MatchParticipantId('person-a'));
    expect(payload.accountingScope, DisciplinaryAccountingScope.match);
    expect(reopened.captureIntentAdmissionCount(matchId: 'match-1'), 1);
    await reopened.close();
  });
}

MatchRecord _yellow({
  required String recordId,
  int originSequence = 1,
  String participantId = 'person-a',
  int generation = 1,
  DisciplinaryAccountingScope scope = DisciplinaryAccountingScope.match,
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
      participantId: MatchParticipantId(participantId),
      accountingScope: scope,
      captureIntentId: 'intent-y',
      situationAtDetermination: ParticipantSituation.substitute,
    ),
    integrity: const IntegrityMetadata(evidenceRefs: ['evidence-1']),
    authorityContext: AuthorityContext(
      scope: v1AuthorityScope,
      principal: const AuthorityPrincipal(principalId: 'ref-1'),
      generation: AuthorityGeneration(value: generation),
    ),
  );
}

MatchRecord _field({required String recordId}) {
  return MatchRecord(
    recordId: recordId,
    matchId: 'match-1',
    recordKind: RecordKind.temporalFact,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 2, 12),
    originDeviceId: 'dev-a',
    originSequence: 1,
    payload: RefereeEnteredFieldPayload(captureIntentId: 'intent-field'),
    integrity: const IntegrityMetadata(evidenceRefs: ['evidence-1']),
    authorityContext: const AuthorityContext(
      scope: v1AuthorityScope,
      principal: AuthorityPrincipal(principalId: 'ref-1'),
      generation: AuthorityGeneration(value: 1),
    ),
  );
}
