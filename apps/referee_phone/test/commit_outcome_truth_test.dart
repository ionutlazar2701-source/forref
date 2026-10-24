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
  late Match match;
  late MobileCommandPreparation preparation;
  var storeClosed = false;

  setUp(() async {
    storeClosed = false;
    temp = await Directory.systemTemp.createTemp('commit_outcome_');
    database = LocalMatchDatabase.memory();
    composition = await MatchApplicationComposition.open(storageRoot: temp);
    identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    match = newLocalMatch(DateTime.utc(2026, 10, 24, 18));
    await database.upsertMatch(match);
    preparation = MobileCommandPreparation(
      commandIds: SequenceCommandIdSource(prefix: 'cmd'),
      captureIntentIds: SequenceCommandIdSource(prefix: 'intent'),
      clock: () => DateTime.utc(2026, 10, 24, 18),
    );
  });

  tearDown(() async {
    try {
      await composition.close();
    } catch (_) {
      if (!storeClosed) rethrow;
    }
    await database.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  MatchApplicationCommandWriter writerFor(MatchApplicationComposition open) {
    return MatchApplicationCommandWriter(
      boundary: open.boundary,
      captureContext: (matchId) async => identity.contextFor(matchId),
    );
  }

  MobileCommandRuntime runtimeFor() {
    return MobileCommandRuntime.phoneOnly(
      boundary: composition.boundary,
      originDeviceId: identity.originDeviceId,
      captureContext: (matchId) async => identity.contextFor(matchId),
      preparation: preparation,
    );
  }

  MobileCommandEnvelope goalEnvelope(String teamId) {
    return preparation
        .freezeGoal(
          activation: preparation.beginActivation(),
          matchId: match.matchId,
          originDeviceId: identity.originDeviceId,
          draft: GoalCaptureDraft()..scoringTeamId = teamId,
        )
        .envelope;
  }

  Future<List<MatchRecord>> records() {
    return composition.boundary.durableStore.readCommittedForMatch(
      match.matchId,
    );
  }

  List<MatchRecord> goalsOf(List<MatchRecord> committed) {
    return committed.where((record) => record.payload is GoalPayload).toList();
  }

  test('committed goal is Saved and the same intent does not append', () async {
    final writer = writerFor(composition);
    final envelope = goalEnvelope(match.teams.home.teamId);
    final first = await writer.commit(envelope);
    final second = await writer.commit(envelope);

    expect(first, isA<MobileWriterSaved>());
    expect(second, isA<MobileWriterSaved>());
    final committed = await records();
    final goals = goalsOf(committed);
    expect(goals, hasLength(1));
    expect(
      (first as MobileWriterSaved).committedRecordId,
      goals.single.recordId,
    );
    expect(
        (second as MobileWriterSaved).committedRecordId, goals.single.recordId);
    expect(
      (goals.single.payload as GoalPayload).scoringTeamId.value,
      match.teams.home.teamId,
    );
  });

  test('abort before commit is Not saved and the goal row is absent', () async {
    // In-process hook. This is not power loss and not an operating-system kill.
    composition.boundary.durableStore.abortBeforeCommitForTest = () {
      throw StateError('abort before commit');
    };
    final writer = writerFor(composition);
    final admission = await writer.commit(
      goalEnvelope(match.teams.home.teamId),
    );

    expect(admission, isA<MobileWriterFailed>());
    expect(admission, isNot(isA<MobileWriterOutcomeUnknown>()));
    expect(
        (admission as MobileWriterFailed).reason, contains('commit aborted'));
    expect(goalsOf(await records()), isEmpty);
    expect(
      composition.boundary.durableStore.captureIntentAdmissionCount(
        matchId: match.matchId,
      ),
      0,
    );
  });

  test('a reopened file returns the original goal as Saved', () async {
    final envelope = goalEnvelope(match.teams.home.teamId);
    final first = await writerFor(composition).commit(envelope);
    final recordId = (first as MobileWriterSaved).committedRecordId;
    await composition.close();

    final reopened = await MatchApplicationComposition.open(storageRoot: temp);
    composition = reopened;
    final again = await writerFor(reopened).commit(envelope);
    final committed =
        await reopened.boundary.durableStore.readCommittedForMatch(
      match.matchId,
    );

    expect(again, isA<MobileWriterSaved>());
    expect((again as MobileWriterSaved).committedRecordId, recordId);
    expect(goalsOf(committed), hasLength(1));
  });

  test('same capture intent with a different team does not overwrite',
      () async {
    final home = goalEnvelope(match.teams.home.teamId);
    final homePayload = home.payload as GoalCommandPayload;
    final away = MobileCommandEnvelope(
      commandId: 'cmd-away',
      matchId: match.matchId,
      commandType: MobileCommandType.goal,
      origin: MobileCommandOrigin.mobileUi,
      originDeviceId: identity.originDeviceId,
      createdAtLocal: DateTime.utc(2026, 10, 24, 18),
      schemaVersion: MobileCommandSchema.version,
      payload: GoalCommandPayload(
        scoringTeamId: match.teams.away.teamId,
        captureIntentId: homePayload.captureIntentId,
      ),
    );
    final writer = writerFor(composition);
    expect(await writer.commit(home), isA<MobileWriterSaved>());
    final conflict = await writer.commit(away);

    expect(conflict, isA<MobileWriterFailed>());
    expect((conflict as MobileWriterFailed).reason,
        contains('idempotency conflict'));
    final goals = goalsOf(await records());
    expect(goals, hasLength(1));
    expect(
      (goals.single.payload as GoalPayload).scoringTeamId.value,
      match.teams.home.teamId,
    );
  });

  test('generation mismatch is a known failure and writes no goal', () async {
    final current = identity.contextFor(match.matchId);
    final writer = MatchApplicationCommandWriter(
      boundary: composition.boundary,
      captureContext: (_) async => CaptureContext(
        matchId: current.matchId,
        originDeviceId: current.originDeviceId,
        authorityScope: current.authorityScope,
        authorityPrincipalId: current.authorityPrincipalId,
        authorityGeneration: 2,
        projectionAuthorityGeneration: current.projectionAuthorityGeneration,
        activeCaptureDeviceId: current.activeCaptureDeviceId,
        domainContractVersion: current.domainContractVersion,
      ),
    );
    final admission =
        await writer.commit(goalEnvelope(match.teams.home.teamId));

    expect(admission, isA<MobileWriterFailed>());
    expect(
      (admission as MobileWriterFailed).reason,
      contains('generation-1'),
    );
    expect(goalsOf(await records()), isEmpty);
  });

  test('kick-off abort is Not saved and an unreadable store stays unknown',
      () async {
    composition.boundary.durableStore.abortBeforeCommitForTest = () {
      throw StateError('abort before commit');
    };
    final writer = writerFor(composition);
    final kickOff = preparation
        .freezeKickOff(
          activation: preparation.beginActivation(),
          matchId: match.matchId,
          originDeviceId: identity.originDeviceId,
          periodIndex: 1,
        )
        .envelope;
    final aborted = await writer.commit(kickOff);
    expect(aborted, isA<MobileWriterFailed>());
    expect(aborted, isNot(isA<MobileWriterOutcomeUnknown>()));
    expect(await records(), isEmpty);

    composition.boundary.durableStore.abortBeforeCommitForTest = null;
    await composition.boundary.durableStore.close();
    storeClosed = true;
    final closed = await writer.commit(kickOff);
    expect(closed, isA<MobileWriterOutcomeUnknown>());
    expect(closed, isNot(isA<MobileWriterFailed>()));
    expect(closed, isNot(isA<MobileWriterSaved>()));
  });

  test(
      'quarantine stays unknown, is not retried, and reconciles the same intent',
      () async {
    final runtime = runtimeFor();
    final original = goalEnvelope(match.teams.home.teamId);
    final saved = await runtime.submit(original);
    expect(saved.status, MobileCommandStatus.saved);
    final recordId = saved.committedRecordId;
    await composition.close();
    final raw = _corruptOneRow(composition.databaseFile);
    composition = await MatchApplicationComposition.open(storageRoot: temp);

    final lost = MobileCommandRuntime.phoneOnly(
      boundary: composition.boundary,
      originDeviceId: identity.originDeviceId,
      captureContext: (matchId) async => identity.contextFor(matchId),
      preparation: preparation,
    );
    final unknown = await lost.submit(original);
    expect(unknown.status, MobileCommandStatus.outcomeUnknown);
    expect(unknown.writerInvoked, isTrue);

    final other = goalEnvelope(match.teams.away.teamId);
    final blocked = await lost.submit(other);
    expect(blocked.commandId, original.commandId);
    expect(blocked.status, MobileCommandStatus.outcomeUnknown);
    expect(
      lost.unresolved(MobileCommandType.goal, match.matchId)?.commandId,
      original.commandId,
    );

    _restoreRow(composition.databaseFile, raw);
    final silent = await lost.dispatcher.dispatch(original);
    expect(silent.status, MobileCommandStatus.outcomeUnknown);
    expect(silent.writerInvoked, isFalse);

    final reconciled = await lost.submit(other);
    expect(reconciled.status, MobileCommandStatus.saved);
    expect(reconciled.commandId, original.commandId);
    expect(reconciled.committedRecordId, recordId);
    expect(lost.unresolved(MobileCommandType.goal, match.matchId), isNull);

    final committed = await records();
    final goals = goalsOf(committed);
    expect(goals, hasLength(1));
    expect(
      (goals.single.payload as GoalPayload).captureIntentId,
      (original.payload as GoalCommandPayload).captureIntentId,
    );
    expect(
      (goals.single.payload as GoalPayload).scoringTeamId.value,
      match.teams.home.teamId,
    );
  });
}

({String recordId, String recordJson}) _corruptOneRow(File databaseFile) {
  final db = sqlite3.open(databaseFile.path);
  final row = db.select(
    '''
    SELECT record_id, record_json
    FROM committed_match_records
    ORDER BY origin_sequence
    LIMIT 1
    ''',
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
  return (recordId: recordId, recordJson: recordJson);
}

void _restoreRow(
  File databaseFile,
  ({String recordId, String recordJson}) raw,
) {
  final db = sqlite3.open(databaseFile.path);
  db.execute(
    'UPDATE committed_match_records SET record_json = ? WHERE record_id = ?',
    [raw.recordJson, raw.recordId],
  );
  db.close();
}
