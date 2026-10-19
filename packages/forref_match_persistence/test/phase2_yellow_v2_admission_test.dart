import 'dart:convert';
import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('forref_phase2_yellow_');
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

  test('v1 yellow bytes stay participant-only', () async {
    final store = await open();
    final record = _v1();
    expect(await store.commit(record), isA<DurableCommitSuccess>());
    final stored = await store.getById('y-v1');
    expect(stored!.payload, isA<YellowCardPayload>());
    expect(stored.schemaVersion, 1);
    final encoded = encodeMatchRecordJson(stored);
    expect(encoded, contains('v1-yellow-card'));
    expect(encoded, isNot(contains('subjectKind')));
    expect(encoded, isNot(contains('TEAM_OFFICIAL')));
    await store.close();
  });

  test('v1 bytes that already contain a v2 subject do not decode', () {
    final record = _v1();
    final json = encodeMatchRecordForStorage(record);
    final payload = Map<String, Object?>.from(json['payload']! as Map);
    payload['subjectKind'] = 'TEAM_OFFICIAL';
    payload['subjectId'] = '123';
    json['payload'] = payload;
    expect(
      () => decodeMatchRecordFromStorage(jsonEncode(json)),
      throwsFormatException,
    );
  });

  test('team-official v2 round-trips', () async {
    final store = await open();
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
    final stored = await store.getById('y-off');
    final payload = stored!.payload as YellowCardPayloadV2;
    expect(payload.yellowSchemaVersion, 2);
    expect(
      payload.disciplinarySubject,
      TeamOfficialDisciplinarySubject(MatchTeamOfficialId('official-7')),
    );
    expect(payload.accountingScope, DisciplinaryAccountingScope.match);
    await store.close();
  });

  test('team official without a binding is not saved', () async {
    final store = await open();
    final outcome = await store.commit(_official());
    expect(outcome, isA<DurableCommitFailure>());
    expect(await store.getById('y-off'), isNull);
    expect(store.captureIntentAdmissionCount(matchId: 'match-1'), 0);
    await store.close();
  });

  test('a second team binding conflicts and does not replace the first', () async {
    final store = await open();
    final official = MatchTeamOfficialId('official-7');
    expect(
      await store.commitTeamOfficialTeamBinding(
        TeamOfficialTeamBinding(
          matchId: 'match-1',
          teamOfficialId: official,
          teamId: MatchTeamId('team-alpha'),
        ),
      ),
      isA<TeamBindingCommitSuccess>(),
    );
    final wrong = await store.commitTeamOfficialTeamBinding(
      TeamOfficialTeamBinding(
        matchId: 'match-1',
        teamOfficialId: official,
        teamId: MatchTeamId('team-beta'),
      ),
    );
    expect(wrong, isA<TeamBindingCommitConflict>());
    expect(await store.commit(_official()), isA<DurableCommitSuccess>());
    await store.close();
  });

  test('same intent across participant and official conflicts', () async {
    final store = await open();
    expect(await store.commit(_v1(intent: 'shared')), isA<DurableCommitSuccess>());
    expect(
      await store.commitTeamOfficialTeamBinding(
        TeamOfficialTeamBinding(
          matchId: 'match-1',
          teamOfficialId: MatchTeamOfficialId('123'),
          teamId: MatchTeamId('team-alpha'),
        ),
      ),
      isA<TeamBindingCommitSuccess>(),
    );
    final conflict = await store.commit(
      _official(recordId: 'y-off-2', officialId: '123', intent: 'shared', sequence: 2),
    );
    expect(conflict, isA<DurableCommitFailure>());
    expect((conflict as DurableCommitFailure).reason, contains('idempotency conflict'));
    expect(await store.readCommittedForMatch('match-1'), hasLength(1));
    await store.close();
  });

  test('same official intent retries as one row', () async {
    final store = await open();
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
    final retry = await store.commit(_official(recordId: 'y-off-2', sequence: 2));
    expect((retry as DurableCommitSuccess).committedRecordId, 'y-off');
    expect(store.captureIntentAdmissionCount(matchId: 'match-1'), 1);
    await store.close();
  });

  test('failed D1 stores no official yellow', () async {
    final store = await open();
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
    store.abortBeforeCommitForTest = () => throw StateError('abort');
    expect(await store.commit(_official()), isA<DurableCommitFailure>());
    expect(await store.getById('y-off'), isNull);
    expect(store.captureIntentAdmissionCount(matchId: 'match-1'), 0);
    await store.close();
  });
}

MatchRecord _authorityRecord({
  required String recordId,
  required int originSequence,
  required MatchRecordPayload payload,
  int generation = 1,
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: 'match-1',
    recordKind: RecordKind.humanDetermination,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 2, 12, originSequence),
    originDeviceId: 'dev-a',
    originSequence: originSequence,
    payload: payload,
    integrity: const IntegrityMetadata(evidenceRefs: ['evidence-1']),
    authorityContext: AuthorityContext(
      scope: v1AuthorityScope,
      principal: const AuthorityPrincipal(principalId: 'ref-1'),
      generation: AuthorityGeneration(value: generation),
    ),
  );
}

MatchRecord _v1({String intent = 'intent-v1'}) {
  return _authorityRecord(
    recordId: 'y-v1',
    originSequence: 1,
    payload: YellowCardPayload(
      participantId: MatchParticipantId('123'),
      accountingScope: DisciplinaryAccountingScope.match,
      captureIntentId: intent,
    ),
  );
}

MatchRecord _official({
  String recordId = 'y-off',
  String officialId = 'official-7',
  String intent = 'intent-official',
  int sequence = 1,
}) {
  return _authorityRecord(
    recordId: recordId,
    originSequence: sequence,
    payload: YellowCardPayloadV2(
      disciplinarySubject: TeamOfficialDisciplinarySubject(
        MatchTeamOfficialId(officialId),
      ),
      accountingScope: DisciplinaryAccountingScope.match,
      captureIntentId: intent,
    ),
  );
}
