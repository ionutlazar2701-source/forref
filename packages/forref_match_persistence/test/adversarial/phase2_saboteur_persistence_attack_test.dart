import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('forref_phase2_saboteur_');
  });

  tearDown(() async {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<SqliteDurableMatchStore> open() async {
    final store =
        SqliteDurableMatchStore.open(File('${temp.path}/memory.sqlite'));
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

  group('BANK B2 persistence', () {
    test('stored v1 yellow json does not contain subjectKind', () async {
      final store = await open();
      final record =
          _yellow(recordId: 'y-v1', sequence: 1, intent: 'intent-v1');
      expect(await store.commit(record), isA<DurableCommitSuccess>());
      await store.close();

      final db = sqlite3.open('${temp.path}/memory.sqlite');
      final rows = db.select(
        'SELECT record_json FROM committed_match_records WHERE record_id = ?',
        ['y-v1'],
      );
      final storedJson = rows.single.columnAt(0) as String;
      expect(storedJson, isNot(contains('subjectKind')));
      expect(storedJson, isNot(contains('TEAM_OFFICIAL')));
      expect(storedJson, contains('"schemaVersion":1'));
      final decoded = decodeMatchRecordFromStorage(storedJson);
      expect(decoded.schemaVersion, 1);
      expect(decoded.payload, isA<YellowCardPayload>());
      final payload = decoded.payload as YellowCardPayload;
      expect(payload.yellowSchemaVersion, 1);
      expect(payload.participantId, MatchParticipantId('123'));
      expect(
          subjectOfYellowCard(payload), isA<ParticipantDisciplinarySubject>());
      expect(subjectOfYellowCard(payload),
          isNot(isA<TeamOfficialDisciplinarySubject>()));
      expect(
        subjectOfYellowCard(payload),
        ParticipantDisciplinarySubject(MatchParticipantId('123')),
      );
      db.close();
    });

    test('participant yellow and official yellow share no capture intent',
        () async {
      final store = await open();
      expect(
        await store.commit(
          _yellow(recordId: 'y-v1', sequence: 1, intent: 'intent-shared'),
        ),
        isA<DurableCommitSuccess>(),
      );
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
        _officialYellow(
            recordId: 'y-off', sequence: 2, intent: 'intent-shared'),
      );
      expect(conflict, isA<DurableCommitFailure>());
      expect((conflict as DurableCommitFailure).reason,
          contains('idempotency conflict'));
      final rows = await store.readCommittedForMatch('match-1');
      expect(rows, hasLength(1));
      expect(rows.single.payload, isA<YellowCardPayload>());
      expect(
          rows.where((item) => item.payload is YellowCardPayloadV2), isEmpty);
      expect(store.captureIntentAdmissionCount(matchId: 'match-1'), 1);
      await store.close();
    });
  });

  group('BANK D persistence', () {
    test('yellow then send-off with the same intent conflicts', () async {
      final store = await open();
      expect(
        await store.commit(
          _yellow(recordId: 'y-v1', sequence: 1, intent: 'intent-shared'),
        ),
        isA<DurableCommitSuccess>(),
      );
      final conflict = await store.commit(
        _directSendOff(recordId: 'so-1', sequence: 2, intent: 'intent-shared'),
      );
      expect(conflict, isA<DurableCommitFailure>());
      expect((conflict as DurableCommitFailure).reason,
          contains('idempotency conflict'));
      final rows = await store.readCommittedForMatch('match-1');
      expect(rows, hasLength(1));
      expect(rows.single.recordId, 'y-v1');
      expect(rows.single.payload, isA<YellowCardPayload>());
      expect(rows.where((item) => item.payload is SendOffPayload), isEmpty);
      expect(store.captureIntentAdmissionCount(matchId: 'match-1'), 1);
      await store.close();
    });

    test('send-off then yellow with the same intent conflicts', () async {
      final store = await open();
      expect(
        await store.commit(
          _directSendOff(
              recordId: 'so-1', sequence: 1, intent: 'intent-shared'),
        ),
        isA<DurableCommitSuccess>(),
      );
      final conflict = await store.commit(
        _yellow(recordId: 'y-v1', sequence: 2, intent: 'intent-shared'),
      );
      expect(conflict, isA<DurableCommitFailure>());
      expect((conflict as DurableCommitFailure).reason,
          contains('idempotency conflict'));
      final rows = await store.readCommittedForMatch('match-1');
      expect(rows, hasLength(1));
      expect(rows.single.payload, isA<SendOffPayload>());
      expect(rows.where((item) => item.payload is YellowCardPayload), isEmpty);
      expect(store.captureIntentAdmissionCount(matchId: 'match-1'), 1);
      await store.close();
    });

    test('official send-off does not reuse a participant yellow intent',
        () async {
      final store = await open();
      expect(
        await store.commit(
          _yellow(recordId: 'y-v1', sequence: 1, intent: 'intent-shared'),
        ),
        isA<DurableCommitSuccess>(),
      );
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
        _officialSendOff(
            recordId: 'so-off', sequence: 2, intent: 'intent-shared'),
      );
      expect(conflict, isA<DurableCommitFailure>());
      expect((conflict as DurableCommitFailure).reason,
          contains('idempotency conflict'));
      final rows = await store.readCommittedForMatch('match-1');
      expect(rows, hasLength(1));
      expect(rows.single.payload, isA<YellowCardPayload>());
      expect(await store.getById('so-off'), isNull);
      await store.close();
    });
  });

  group('CROSS-DOMAIN persistence', () {
    test('D1 abort stores no yellow row and no capture intent', () async {
      final store = await open();
      store.abortBeforeCommitForTest = () => throw StateError('abort');
      final outcome = await store.commit(
        _yellow(recordId: 'y-v1', sequence: 1, intent: 'intent-v1'),
      );
      expect(outcome, isA<DurableCommitFailure>());
      expect(await store.getById('y-v1'), isNull);
      expect(await store.readCommittedForMatch('match-1'), isEmpty);
      expect(store.captureIntentAdmissionCount(matchId: 'match-1'), 0);
      await store.close();

      final db = sqlite3.open('${temp.path}/memory.sqlite');
      final records = db.select('SELECT COUNT(*) FROM committed_match_records');
      final intents =
          db.select('SELECT COUNT(*) FROM capture_intent_admissions');
      expect(records.single.columnAt(0), 0);
      expect(intents.single.columnAt(0), 0);
      db.close();
    });

    test('D1 abort of a later send-off keeps the committed yellow only',
        () async {
      final store = await open();
      expect(
        await store.commit(
          _yellow(recordId: 'y-v1', sequence: 1, intent: 'intent-v1'),
        ),
        isA<DurableCommitSuccess>(),
      );
      store.abortBeforeCommitForTest = () => throw StateError('abort');
      final outcome = await store.commit(
        _directSendOff(recordId: 'so-1', sequence: 2, intent: 'intent-send'),
      );
      expect(outcome, isA<DurableCommitFailure>());
      expect(await store.getById('so-1'), isNull);
      final rows = await store.readCommittedForMatch('match-1');
      expect(rows, hasLength(1));
      expect(rows.single.payload, isA<YellowCardPayload>());
      expect(store.captureIntentAdmissionCount(matchId: 'match-1'), 1);
      await store.close();
    });
  });
}

MatchRecord _record({
  required String recordId,
  required int sequence,
  required MatchRecordPayload payload,
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: 'match-1',
    recordKind: RecordKind.humanDetermination,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 2, 12, sequence),
    originDeviceId: 'dev-a',
    originSequence: sequence,
    payload: payload,
    integrity: const IntegrityMetadata(evidenceRefs: ['evidence-1']),
    authorityContext: AuthorityContext(
      scope: v1AuthorityScope,
      principal: const AuthorityPrincipal(principalId: 'ref-1'),
      generation: AuthorityGeneration(value: 1),
    ),
  );
}

MatchRecord _yellow({
  required String recordId,
  required int sequence,
  required String intent,
}) {
  return _record(
    recordId: recordId,
    sequence: sequence,
    payload: YellowCardPayload(
      participantId: MatchParticipantId('123'),
      accountingScope: DisciplinaryAccountingScope.match,
      captureIntentId: intent,
    ),
  );
}

MatchRecord _officialYellow({
  required String recordId,
  required int sequence,
  required String intent,
}) {
  return _record(
    recordId: recordId,
    sequence: sequence,
    payload: YellowCardPayloadV2(
      disciplinarySubject: TeamOfficialDisciplinarySubject(
        MatchTeamOfficialId('123'),
      ),
      accountingScope: DisciplinaryAccountingScope.match,
      captureIntentId: intent,
    ),
  );
}

MatchRecord _directSendOff({
  required String recordId,
  required int sequence,
  required String intent,
}) {
  return _record(
    recordId: recordId,
    sequence: sequence,
    payload: SendOffPayload(
      disciplinarySubject: ParticipantDisciplinarySubject(
        MatchParticipantId('123'),
      ),
      disciplinaryScope: DisciplinaryAccountingScope.match,
      pathway: SendOffPathway.direct,
      captureIntentId: intent,
    ),
  );
}

MatchRecord _officialSendOff({
  required String recordId,
  required int sequence,
  required String intent,
}) {
  return _record(
    recordId: recordId,
    sequence: sequence,
    payload: SendOffPayload(
      disciplinarySubject: TeamOfficialDisciplinarySubject(
        MatchTeamOfficialId('123'),
      ),
      disciplinaryScope: DisciplinaryAccountingScope.match,
      pathway: SendOffPathway.direct,
      captureIntentId: intent,
    ),
  );
}
