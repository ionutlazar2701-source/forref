import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/match/new_match.dart';
import 'package:referee_phone/mobile_commands/match_application_command_writer.dart';
import 'package:referee_phone/mobile_commands/mobile_command.dart';
import 'package:referee_phone/mobile_commands/mobile_command_availability.dart';
import 'package:referee_phone/mobile_commands/mobile_command_dispatcher.dart';
import 'package:referee_phone/mobile_commands/mobile_command_identity.dart';
import 'package:referee_phone/mobile_commands/mobile_command_preparation.dart';
import 'package:referee_phone/mobile_commands/mobile_command_runtime.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory temp;
  late LocalMatchDatabase database;
  late MatchApplicationComposition composition;
  late PhoneCaptureIdentity identity;
  late MobileCommandPreparation preparation;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('reconcile_safety_');
    database = LocalMatchDatabase.memory();
    composition = await MatchApplicationComposition.open(storageRoot: temp);
    identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    preparation = MobileCommandPreparation(
      commandIds: SequenceCommandIdSource(prefix: 'cmd'),
      captureIntentIds: SequenceCommandIdSource(prefix: 'intent'),
      clock: () => DateTime.utc(2026, 10, 24, 19),
    );
  });

  tearDown(() async {
    try {
      await composition.close();
    } catch (_) {}
    await database.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  MatchApplicationCommandWriter productionWriter() {
    return MatchApplicationCommandWriter(
      boundary: composition.boundary,
      captureContext: (matchId) async => identity.contextFor(matchId),
    );
  }

  MobileCommandEnvelope goalFor(Match match, String teamId) {
    return preparation
        .freezeGoal(
          activation: preparation.beginActivation(),
          matchId: match.matchId,
          originDeviceId: identity.originDeviceId,
          draft: GoalCaptureDraft()..scoringTeamId = teamId,
        )
        .envelope;
  }

  Future<int> goalCount(String matchId) async {
    final records =
        await composition.boundary.durableStore.readCommittedForMatch(matchId);
    return records.where((record) => record.payload is GoalPayload).length;
  }

  test('UNKNOWN reconcile invokes zero extra sporting commits', () async {
    final match = newLocalMatch(DateTime.utc(2026, 10, 24, 19));
    await database.upsertMatch(match);
    final envelope = goalFor(match, match.teams.home.teamId);
    final counter = _CommitCounter(productionWriter());
    final dispatcher = MobileCommandDispatcher(
      writer: counter,
      authority: MobileAuthoritySnapshot.phoneOnly,
    );
    final saved = await dispatcher.dispatch(envelope);
    expect(saved.status, MobileCommandStatus.saved);
    expect(counter.commits, 1);
    final before = await goalCount(match.matchId);

    await composition.close();
    _corruptMatch(composition.databaseFile, match.matchId);
    composition = await MatchApplicationComposition.open(storageRoot: temp);
    final lostCounter = _CommitCounter(productionWriter());
    final lost = MobileCommandDispatcher(
      writer: lostCounter,
      authority: MobileAuthoritySnapshot.phoneOnly,
    );
    final unknown = await lost.dispatch(envelope);
    expect(unknown.status, MobileCommandStatus.outcomeUnknown);
    expect(lostCounter.commits, 1);

    final again = await lost.reconcile(envelope);
    expect(again.status, MobileCommandStatus.outcomeUnknown);
    expect(again.writerInvoked, isFalse);
    expect(lostCounter.commits, 1);
    expect(lostCounter.inspections, 1);

    _restoreMatch(composition.databaseFile);
    final proved = await lost.reconcile(envelope);
    expect(proved.status, MobileCommandStatus.saved);
    expect(proved.writerInvoked, isFalse);
    expect(proved.committedRecordId, saved.committedRecordId);
    expect(lostCounter.commits, 1);
    expect(lostCounter.inspections, 2);
    expect(await goalCount(match.matchId), before);
  });

  test('repeated UNKNOWN attempt does not allocate another capture identity',
      () async {
    final match = newLocalMatch(DateTime.utc(2026, 10, 24, 19, 1));
    await database.upsertMatch(match);
    final original = goalFor(match, match.teams.home.teamId);
    await composition.close();
    composition = await MatchApplicationComposition.open(storageRoot: temp);
    final closedRuntime = MobileCommandRuntime.phoneOnly(
      boundary: composition.boundary,
      originDeviceId: identity.originDeviceId,
      captureContext: (matchId) async => identity.contextFor(matchId),
      preparation: preparation,
    );
    await composition.boundary.durableStore.close();
    final unknown = await closedRuntime.submit(original);
    expect(unknown.status, MobileCommandStatus.outcomeUnknown);

    final other = goalFor(match, match.teams.away.teamId);
    final repeated = await closedRuntime.submit(other);
    expect(repeated.commandId, original.commandId);
    expect(repeated.status, MobileCommandStatus.outcomeUnknown);
    final held = closedRuntime.unresolved(
      MobileCommandType.goal,
      match.matchId,
    );
    expect(held?.commandId, original.commandId);
    final payload = held?.payload as GoalCommandPayload?;
    final originalPayload = original.payload as GoalCommandPayload;
    expect(payload?.captureIntentId, originalPayload.captureIntentId);
    expect(other.commandId, isNot(original.commandId));
  });

  test('goal UNKNOWN on match A is not acknowledged for match B', () async {
    final matchA = newLocalMatch(DateTime.utc(2026, 10, 24, 19, 2));
    final matchB = newLocalMatch(DateTime.utc(2026, 10, 24, 19, 3));
    await database.upsertMatch(matchA);
    await database.upsertMatch(matchB);
    final runtime = MobileCommandRuntime.phoneOnly(
      boundary: composition.boundary,
      originDeviceId: identity.originDeviceId,
      captureContext: (matchId) async => identity.contextFor(matchId),
      preparation: preparation,
    );
    final goalA = goalFor(matchA, matchA.teams.home.teamId);
    expect(
      (await runtime.submit(goalA)).status,
      MobileCommandStatus.saved,
    );
    await composition.close();
    _corruptMatch(composition.databaseFile, matchA.matchId);
    composition = await MatchApplicationComposition.open(storageRoot: temp);
    final lost = MobileCommandRuntime.phoneOnly(
      boundary: composition.boundary,
      originDeviceId: identity.originDeviceId,
      captureContext: (matchId) async => identity.contextFor(matchId),
      preparation: preparation,
    );
    final unknownA = await lost.submit(goalA);
    expect(unknownA.status, MobileCommandStatus.outcomeUnknown);
    expect(unknownA.commandId, goalA.commandId);

    final goalB = goalFor(matchB, matchB.teams.home.teamId);
    final outcomeB = await lost.submit(goalB);
    expect(outcomeB.commandId, goalB.commandId);
    expect(outcomeB.commandId, isNot(goalA.commandId));
    expect(outcomeB.status, MobileCommandStatus.saved);
    expect(
      lost.unresolved(MobileCommandType.goal, matchA.matchId)?.commandId,
      goalA.commandId,
    );
    expect(lost.unresolved(MobileCommandType.goal, matchB.matchId), isNull);
    expect(await goalCount(matchB.matchId), 1);
    final goalsB = await composition.boundary.durableStore
        .readCommittedForMatch(matchB.matchId);
    expect(
      (goalsB.singleWhere((record) => record.payload is GoalPayload).payload
              as GoalPayload)
          .captureIntentId,
      (goalB.payload as GoalCommandPayload).captureIntentId,
    );
  });

  test('two unresolved goals on different matches do not overwrite', () async {
    final matchA = newLocalMatch(DateTime.utc(2026, 10, 24, 19, 4));
    final matchB = newLocalMatch(DateTime.utc(2026, 10, 24, 19, 5));
    await database.upsertMatch(matchA);
    await database.upsertMatch(matchB);
    final goalA = goalFor(matchA, matchA.teams.home.teamId);
    final goalB = goalFor(matchB, matchB.teams.home.teamId);
    await composition.boundary.durableStore.close();
    final runtime = MobileCommandRuntime.phoneOnly(
      boundary: composition.boundary,
      originDeviceId: identity.originDeviceId,
      captureContext: (matchId) async => identity.contextFor(matchId),
      preparation: preparation,
    );
    expect(
      (await runtime.submit(goalA)).status,
      MobileCommandStatus.outcomeUnknown,
    );
    expect(
      (await runtime.submit(goalB)).status,
      MobileCommandStatus.outcomeUnknown,
    );
    expect(
      runtime.unresolved(MobileCommandType.goal, matchA.matchId)?.commandId,
      goalA.commandId,
    );
    expect(
      runtime.unresolved(MobileCommandType.goal, matchB.matchId)?.commandId,
      goalB.commandId,
    );
    expect(goalA.commandId, isNot(goalB.commandId));
  });

  test('same capture intent with a different team is a conflict without append',
      () async {
    final match = newLocalMatch(DateTime.utc(2026, 10, 24, 19, 6));
    await database.upsertMatch(match);
    final home = goalFor(match, match.teams.home.teamId);
    final writer = productionWriter();
    final counter = _CommitCounter(writer);
    expect(await counter.commit(home), isA<MobileWriterSaved>());
    final homePayload = home.payload as GoalCommandPayload;
    final away = MobileCommandEnvelope(
      commandId: 'cmd-conflict',
      matchId: match.matchId,
      commandType: MobileCommandType.goal,
      origin: MobileCommandOrigin.mobileUi,
      originDeviceId: identity.originDeviceId,
      createdAtLocal: DateTime.utc(2026, 10, 24, 19, 6),
      schemaVersion: MobileCommandSchema.version,
      payload: GoalCommandPayload(
        scoringTeamId: match.teams.away.teamId,
        captureIntentId: homePayload.captureIntentId,
      ),
    );
    final inspected = await counter.inspectOutcome(away);
    expect(inspected, isA<MobileWriterFailed>());
    expect(inspected, isNot(isA<MobileWriterSaved>()));
    expect(
      (inspected as MobileWriterFailed).reason,
      contains('idempotency conflict'),
    );
    expect(counter.commits, 1);
    expect(counter.inspections, 1);
    expect(await goalCount(match.matchId), 1);
  });

  test(
      'kick-off with only MATCH_STARTED is not full Saved and is not rewritten',
      () async {
    final match = newLocalMatch(DateTime.utc(2026, 10, 24, 19, 7));
    await database.upsertMatch(match);
    final kickOff = preparation
        .freezeKickOff(
          activation: preparation.beginActivation(),
          matchId: match.matchId,
          originDeviceId: identity.originDeviceId,
          periodIndex: 1,
        )
        .envelope;
    var aborts = 0;
    composition.boundary.durableStore.abortBeforeCommitForTest = () {
      aborts += 1;
      if (aborts > 1) throw StateError('abort period start');
    };
    final writer = productionWriter();
    final partial = await writer.commit(kickOff);
    expect(partial, isA<MobileWriterFailed>());
    expect((partial as MobileWriterFailed).partial, isTrue);
    composition.boundary.durableStore.abortBeforeCommitForTest = null;
    final before = await composition.boundary.durableStore
        .readCommittedForMatch(match.matchId);
    expect(before, hasLength(1));

    final counter = _CommitCounter(writer);
    final inspected = await counter.inspectOutcome(kickOff);
    expect(inspected, isA<MobileWriterFailed>());
    expect((inspected as MobileWriterFailed).partial, isTrue);
    expect(inspected, isNot(isA<MobileWriterSaved>()));
    expect(counter.commits, 0);
    expect(counter.inspections, 1);
    final after = await composition.boundary.durableStore.readCommittedForMatch(
      match.matchId,
    );
    expect(after, hasLength(1));
    expect(after.single.recordId, before.single.recordId);
  });
}

final class _CommitCounter implements MobileAuthoritativeWriter {
  _CommitCounter(this.inner);

  final MobileAuthoritativeWriter inner;
  int commits = 0;

  int inspections = 0;

  @override
  Future<MobileWriterAdmission> commit(MobileCommandEnvelope envelope) async {
    commits += 1;
    return inner.commit(envelope);
  }

  @override
  Future<MobileWriterAdmission> inspectOutcome(
    MobileCommandEnvelope envelope,
  ) async {
    inspections += 1;
    return inner.inspectOutcome(envelope);
  }
}

({String recordId, String recordJson})? _damaged;

void _corruptMatch(File databaseFile, String matchId) {
  final db = sqlite3.open(databaseFile.path);
  final row = db.select(
    '''
    SELECT record_id, record_json
    FROM committed_match_records
    WHERE match_id = ?
    ORDER BY origin_sequence
    LIMIT 1
    ''',
    [matchId],
  ).single;
  final recordId = row.columnAt(0) as String;
  final recordJson = row.columnAt(1) as String;
  final json = jsonDecode(recordJson) as Map<String, Object?>;
  json['payload'] = 'not-an-object';
  db.execute(
    'UPDATE committed_match_records SET record_json = ? WHERE record_id = ?',
    [jsonEncode(json), recordId],
  );
  db.close();
  _damaged = (recordId: recordId, recordJson: recordJson);
}

void _restoreMatch(File databaseFile) {
  final raw = _damaged;
  if (raw == null) return;
  final db = sqlite3.open(databaseFile.path);
  db.execute(
    'UPDATE committed_match_records SET record_json = ? WHERE record_id = ?',
    [raw.recordJson, raw.recordId],
  );
  db.close();
}
