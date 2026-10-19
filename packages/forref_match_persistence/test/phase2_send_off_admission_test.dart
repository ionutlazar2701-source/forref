import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('forref_phase2_send_off_');
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

  test('direct SEND_OFF retries as one row', () async {
    final store = await open();
    expect(await store.commit(_direct()), isA<DurableCommitSuccess>());
    final retry = await store.commit(_direct(recordId: 'so-2', sequence: 2));
    expect((retry as DurableCommitSuccess).committedRecordId, 'so-1');
    expect(await store.readCommittedForMatch('match-1'), hasLength(1));
    await store.close();
  });

  test('same intent with a different pathway conflicts', () async {
    final store = await open();
    expect(await store.commit(_direct(intent: 'shared')), isA<DurableCommitSuccess>());
    final conflict = await store.commit(
      _second(recordId: 'so-2', sequence: 2, intent: 'shared'),
    );
    expect(conflict, isA<DurableCommitFailure>());
    expect(await store.readCommittedForMatch('match-1'), hasLength(1));
    await store.close();
  });

  test('same intent with a changed Y2 conflicts', () async {
    final store = await open();
    expect(await store.commit(_second()), isA<DurableCommitSuccess>());
    final conflict = await store.commit(
      _second(recordId: 'so-2', sequence: 2, second: 'y3'),
    );
    expect(conflict, isA<DurableCommitFailure>());
    expect((conflict as DurableCommitFailure).reason, contains('idempotency conflict'));
    await store.close();
  });

  test('generation other than 1 is not saved', () async {
    final store = await open();
    expect(await store.commit(_direct(generation: 2)), isA<DurableCommitFailure>());
    expect(await store.getById('so-1'), isNull);
    expect(store.captureIntentAdmissionCount(matchId: 'match-1'), 0);
    await store.close();
  });

  test('foreign origin is not saved', () async {
    final store = await open();
    expect(
      await store.commit(_direct(originDeviceId: 'dev-b')),
      isA<DurableCommitFailure>(),
    );
    expect(await store.getById('so-1'), isNull);
    await store.close();
  });

  test('failed D1 stores no SEND_OFF', () async {
    final store = await open();
    store.abortBeforeCommitForTest = () => throw StateError('abort');
    expect(await store.commit(_direct()), isA<DurableCommitFailure>());
    expect(await store.getById('so-1'), isNull);
    expect(store.captureIntentAdmissionCount(matchId: 'match-1'), 0);
    await store.close();
  });

  test('team-official SEND_OFF requires a binding', () async {
    final store = await open();
    expect(await store.commit(_official()), isA<DurableCommitFailure>());
    expect(
      await store.commitTeamOfficialTeamBinding(
        TeamOfficialTeamBinding(
          matchId: 'match-1',
          teamOfficialId: MatchTeamOfficialId('official-7'),
          teamId: MatchTeamId('team-alpha'),
        ),
      ),
      isA<TeamBindingCommitSuccess>(),
    );
    expect(await store.commit(_official()), isA<DurableCommitSuccess>());
    final stored = await store.getById('so-off');
    expect(
      (stored!.payload as SendOffPayload).disciplinarySubject,
      TeamOfficialDisciplinarySubject(MatchTeamOfficialId('official-7')),
    );
    await store.close();
  });

  test('two yellow commits do not synthesize SEND_OFF', () async {
    final store = await open();
    expect(await store.commit(_yellow('y1', 1, 'intent-1')), isA<DurableCommitSuccess>());
    expect(await store.commit(_yellow('y2', 2, 'intent-2')), isA<DurableCommitSuccess>());
    final rows = await store.readCommittedForMatch('match-1');
    expect(rows.where((item) => item.payload is SendOffPayload), isEmpty);
    expect(rows, hasLength(2));
    await store.close();
  });
}

MatchRecord _base({
  required String recordId,
  required int sequence,
  required MatchRecordPayload payload,
  int generation = 1,
  String originDeviceId = 'dev-a',
  List<RecordRelationship> relationships = const [],
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: 'match-1',
    recordKind: RecordKind.humanDetermination,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 2, 12, sequence),
    originDeviceId: originDeviceId,
    originSequence: sequence,
    payload: payload,
    relationships: relationships,
    integrity: const IntegrityMetadata(evidenceRefs: ['evidence-1']),
    authorityContext: AuthorityContext(
      scope: v1AuthorityScope,
      principal: const AuthorityPrincipal(principalId: 'ref-1'),
      generation: AuthorityGeneration(value: generation),
    ),
  );
}

MatchRecord _direct({
  String recordId = 'so-1',
  int sequence = 1,
  String intent = 'intent-send',
  int generation = 1,
  String originDeviceId = 'dev-a',
}) {
  return _base(
    recordId: recordId,
    sequence: sequence,
    generation: generation,
    originDeviceId: originDeviceId,
    payload: SendOffPayload(
      disciplinarySubject: ParticipantDisciplinarySubject(
        MatchParticipantId('person-a'),
      ),
      disciplinaryScope: DisciplinaryAccountingScope.match,
      pathway: SendOffPathway.direct,
      captureIntentId: intent,
    ),
  );
}

MatchRecord _second({
  String recordId = 'so-1',
  int sequence = 1,
  String intent = 'intent-send',
  String second = 'y2',
}) {
  return _base(
    recordId: recordId,
    sequence: sequence,
    relationships: [
      const CausalDependency(targetRecordId: 'y1'),
      CausalDependency(targetRecordId: second),
    ],
    payload: SendOffPayload(
      disciplinarySubject: ParticipantDisciplinarySubject(
        MatchParticipantId('person-a'),
      ),
      disciplinaryScope: DisciplinaryAccountingScope.match,
      pathway: SendOffPathway.secondCaution,
      captureIntentId: intent,
      firstStandingCautionRecordId: 'y1',
      secondCautionRecordId: second,
    ),
  );
}

MatchRecord _official() {
  return _base(
    recordId: 'so-off',
    sequence: 1,
    payload: SendOffPayload(
      disciplinarySubject: TeamOfficialDisciplinarySubject(
        MatchTeamOfficialId('official-7'),
      ),
      disciplinaryScope: DisciplinaryAccountingScope.match,
      pathway: SendOffPathway.direct,
      captureIntentId: 'intent-official-send',
    ),
  );
}

MatchRecord _yellow(String recordId, int sequence, String intent) {
  return _base(
    recordId: recordId,
    sequence: sequence,
    payload: YellowCardPayload(
      participantId: MatchParticipantId('person-a'),
      accountingScope: DisciplinaryAccountingScope.match,
      captureIntentId: intent,
    ),
  );
}
