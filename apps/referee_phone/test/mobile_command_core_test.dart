import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/companion/no_peer_transport.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/match/new_match.dart';
import 'package:referee_phone/mobile_commands/command_authority_gate.dart';
import 'package:referee_phone/mobile_commands/mobile_command.dart';
import 'package:referee_phone/mobile_commands/mobile_command_availability.dart';
import 'package:referee_phone/mobile_commands/mobile_command_dispatcher.dart';
import 'package:referee_phone/mobile_commands/mobile_command_identity.dart';
import 'package:referee_phone/mobile_commands/mobile_command_preparation.dart';
import 'package:referee_phone/mobile_commands/mobile_command_runtime.dart';
import 'package:referee_phone/mobile_commands/match_application_command_writer.dart';
import 'package:referee_phone/presentation/mobile_read_models.dart';

void main() {
  late MobileCommandPreparation preparation;

  setUp(() {
    preparation = MobileCommandPreparation(
      commandIds: SequenceCommandIdSource(prefix: 'cmd'),
      captureIntentIds: SequenceCommandIdSource(prefix: 'intent'),
      clock: () => DateTime.utc(2026, 10, 23, 12),
    );
  });

  MobileCommandEnvelope goalEnvelope({
    required MobileCaptureActivation activation,
    String team = 'home-team',
  }) {
    final draft = GoalCaptureDraft()
      ..scoringTeamId = team
      ..scorerLabel = 'SCORER-NINE'
      ..displayMatchTime = 'CLOCK-0037';
    return preparation
        .freezeGoal(
          activation: activation,
          matchId: 'match-1',
          originDeviceId: 'phone-1',
          draft: draft,
        )
        .envelope;
  }

  test('M1 new semantic command receives a stable command id', () {
    final activation = preparation.beginActivation();
    final envelope = goalEnvelope(activation: activation);
    expect(envelope.commandId, activation.commandId);
    expect(envelope.commandId, 'cmd-1');
    expect(envelope.commandId, isNot(envelope.createdAtLocal.toString()));
    expect(envelope.origin, MobileCommandOrigin.mobileUi);
    expect(envelope.schemaVersion, MobileCommandSchema.version);
    expect(preparation.intentDraft.status, MobileCommandStatus.draft);
    expect(
      preparation
          .freezeGoal(
            activation: activation,
            matchId: 'match-1',
            originDeviceId: 'phone-1',
            draft: GoalCaptureDraft()..scoringTeamId = 'home-team',
          )
          .status,
      MobileCommandStatus.ready,
    );
  });

  test('M2 same activation retry preserves command id and capture intent',
      () async {
    final activation = preparation.beginActivation();
    final first = goalEnvelope(activation: activation);
    final writer =
        _RecordingWriter(const MobileWriterSaved(committedRecordId: 'rec'));
    final dispatcher = MobileCommandDispatcher(
      writer: writer,
      authority: MobileAuthoritySnapshot.phoneOnly,
    );
    final again = preparation.freezeGoal(
      activation: activation,
      matchId: 'match-1',
      originDeviceId: 'phone-1',
      draft: GoalCaptureDraft()..scoringTeamId = 'home-team',
    );
    expect(again.envelope.commandId, first.commandId);
    expect(again.envelope.payload, first.payload);
    final saved = await dispatcher.dispatch(first);
    final retried = await dispatcher.dispatch(again.envelope);
    expect(saved.status, MobileCommandStatus.saved);
    expect(retried.status, MobileCommandStatus.saved);
    expect(retried.commandId, saved.commandId);
    expect(retried.writerInvoked, isFalse);
    expect(writer.calls, 1);
    final payload = first.payload as GoalCommandPayload;
    expect(payload.captureIntentId, activation.captureIntentId);
  });

  test('M3 a new activation gets a new command id', () {
    final first = preparation.beginActivation();
    final second = preparation.beginActivation();
    expect(first.commandId, isNot(second.commandId));
    expect(first.captureIntentId, isNot(second.captureIntentId));
    expect(
      goalEnvelope(activation: first).commandId,
      isNot(goalEnvelope(activation: second).commandId),
    );
  });

  test('M4 frozen payload cannot retarget after the UI selection changes', () {
    final activation = preparation.beginActivation();
    final draft = GoalCaptureDraft()
      ..scoringTeamId = 'home-team'
      ..scorerLabel = 'SCORER-NINE'
      ..displayMatchTime = 'CLOCK-0037';
    final frozen = preparation.freezeGoal(
      activation: activation,
      matchId: 'match-1',
      originDeviceId: 'phone-1',
      draft: draft,
    );
    draft.scoringTeamId = 'away-team';
    draft.scorerLabel = 'OTHER';
    final again = preparation.freezeGoal(
      activation: activation,
      matchId: 'match-1',
      originDeviceId: 'phone-1',
      draft: draft,
    );
    final payload = again.envelope.payload as GoalCommandPayload;
    expect(identical(frozen.envelope, again.envelope), isTrue);
    expect(payload.scoringTeamId, 'home-team');
    expect(payload.captureIntentId, activation.captureIntentId);
    expect(payload.toString(), isNot(contains('SCORER-NINE')));
    expect(payload.toString(), isNot(contains('CLOCK-0037')));
    expect(payload.toString(), isNot(contains('away-team')));
  });

  test('M5 unsupported command cannot reach the authoritative writer',
      () async {
    final writer = _RecordingWriter(const MobileWriterSaved());
    final dispatcher = MobileCommandDispatcher(
      writer: writer,
      authority: MobileAuthoritySnapshot.phoneOnly,
    );
    final envelope = preparation
        .freezeUnsupported(
          activation: preparation.beginActivation(),
          matchId: 'match-1',
          originDeviceId: 'phone-1',
          commandType: MobileCommandType.yellow,
        )
        .envelope;
    final outcome = await dispatcher.dispatch(envelope);
    expect(outcome.status, MobileCommandStatus.unsupported);
    expect(outcome.availability, MobileCommandAvailabilityKind.notYetCutOver);
    expect(outcome.writerInvoked, isFalse);
    expect(writer.calls, 0);
  });

  test('M6 authority unavailable cannot reach the writer', () async {
    final writer = _RecordingWriter(const MobileWriterSaved());
    final blocked = MobileCommandDispatcher(
      writer: writer,
      authority: const MobileAuthoritySnapshot(
        localCaptureAuthorized: false,
        companionHoldsCaptureAuthority: false,
        mode: MobileOperatingMode.phoneOnly,
      ),
    );
    final outcome = await blocked.dispatch(
      goalEnvelope(activation: preparation.beginActivation()),
    );
    expect(outcome.status, MobileCommandStatus.authorityUnavailable);
    expect(writer.calls, 0);

    final watchPrimary = MobileCommandDispatcher(
      writer: writer,
      authority: const MobileAuthoritySnapshot(
        localCaptureAuthorized: true,
        companionHoldsCaptureAuthority: false,
        mode: MobileOperatingMode.watchPrimaryFuture,
      ),
    );
    final denied = await watchPrimary.dispatch(
      goalEnvelope(activation: preparation.beginActivation()),
    );
    expect(denied.status, MobileCommandStatus.authorityUnavailable);
    expect(denied.detail, MobileCommandReason.watchPrimaryNotAuthorized);
    expect(writer.calls, 0);
  });

  test(
      'M7 M8 M12 supported phone goal commits through the application boundary',
      () async {
    final harness = await _PhoneHarness.open();
    addTearDown(harness.close);
    final match = harness.seeded;
    final transport = NoPeerTransport();
    final runtime = harness.runtime(transport: transport);
    final kickOff = await runtime.dispatcher.dispatch(
      runtime.preparation
          .freezeKickOff(
            activation: runtime.preparation.beginActivation(),
            matchId: match.matchId,
            originDeviceId: harness.identity.originDeviceId,
            periodIndex: 1,
          )
          .envelope,
    );
    expect(kickOff.status, MobileCommandStatus.saved);

    final goal = await runtime.dispatcher.dispatch(
      runtime.preparation
          .freezeGoal(
            activation: runtime.preparation.beginActivation(),
            matchId: match.matchId,
            originDeviceId: harness.identity.originDeviceId,
            draft: GoalCaptureDraft()
              ..scoringTeamId = match.teams.home.teamId
              ..scorerLabel = 'SCORER-NINE'
              ..displayMatchTime = 'CLOCK-0037',
          )
          .envelope,
    );
    expect(goal.status, MobileCommandStatus.saved);
    expect(goal.writerInvoked, isTrue);
    expect(transport.sendAttempts, 0);
    expect(runtime.outbox.pending, isEmpty);

    final stored = await harness.database.getMatch(match.matchId);
    expect(stored!.events, isEmpty);
    expect(stored.score.home, 0);

    final records = await harness.composition.boundary.durableStore
        .readCommittedForMatch(match.matchId);
    final goals = records.where((record) => record.payload is GoalPayload);
    expect(goals, hasLength(1));
    final payload = goals.single.payload as GoalPayload;
    expect(payload.scoringTeamId, MatchTeamId(match.teams.home.teamId));
    expect(payload.captureIntentId, isNot(contains('SCORER-NINE')));

    final report = MobileMatchReportState(
      matchId: match.matchId,
      score: await harness.composition.boundary.readScoreProjection(
        matchId: match.matchId,
        evaluatedAuthorityGeneration:
            PhoneCaptureIdentity.initialAuthorityGeneration,
        homeTeamId: MatchTeamId(match.teams.home.teamId),
        awayTeamId: MatchTeamId(match.teams.away.teamId),
      ),
    );
    expect(report.score, isA<KnownScore>());
    expect(
      (report.score! as KnownScore)
          .goalsByTeam[MatchTeamId(match.teams.home.teamId)],
      1,
    );
    expect(report.includesDisciplinaryRows, isFalse);
    expect(report.includesSubstitutionRows, isFalse);
  });

  test('M9 a known durable failure becomes failed', () async {
    final harness = await _PhoneHarness.open();
    addTearDown(harness.close);
    final match = harness.seeded;
    final current = harness.identity.contextFor(match.matchId);
    final writer = MatchApplicationCommandWriter(
      boundary: harness.composition.boundary,
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
    final dispatcher = MobileCommandDispatcher(
      writer: writer,
      authority: MobileAuthoritySnapshot.phoneOnly,
    );
    final outcome = await dispatcher.dispatch(
      MobileCommandEnvelope(
        commandId: 'cmd-fail',
        matchId: match.matchId,
        commandType: MobileCommandType.goal,
        origin: MobileCommandOrigin.mobileUi,
        originDeviceId: current.originDeviceId,
        createdAtLocal: DateTime.utc(2026, 10, 23),
        schemaVersion: MobileCommandSchema.version,
        payload: const GoalCommandPayload(
          scoringTeamId: 'team',
          captureIntentId: 'intent-fail',
        ),
      ),
    );
    expect(outcome.status, MobileCommandStatus.failed);
    expect(outcome.writerInvoked, isTrue);
    expect(
      await harness.composition.boundary.durableStore.readCommittedForMatch(
        match.matchId,
      ),
      isEmpty,
    );
  });

  test('M10 unknown remains outcome unknown and is not retried', () async {
    final writer = _RecordingWriter(const MobileWriterOutcomeUnknown());
    final dispatcher = MobileCommandDispatcher(
      writer: writer,
      authority: MobileAuthoritySnapshot.phoneOnly,
    );
    final envelope = goalEnvelope(activation: preparation.beginActivation());
    final first = await dispatcher.dispatch(envelope);
    final second = await dispatcher.dispatch(envelope);
    expect(first.status, MobileCommandStatus.outcomeUnknown);
    expect(second.status, MobileCommandStatus.outcomeUnknown);
    expect(second.writerInvoked, isFalse);
    expect(writer.calls, 1);
    expect(first.status, isNot(MobileCommandStatus.failed));
    expect(first.status, isNot(MobileCommandStatus.saved));
  });

  test('M11 a disabled peer transport does not block the phone command',
      () async {
    final harness = await _PhoneHarness.open();
    addTearDown(harness.close);
    final transport = NoPeerTransport();
    final runtime = harness.runtime(transport: transport);
    final outcome = await runtime.dispatcher.dispatch(
      runtime.preparation
          .freezeKickOff(
            activation: runtime.preparation.beginActivation(),
            matchId: harness.seeded.matchId,
            originDeviceId: harness.identity.originDeviceId,
            periodIndex: 1,
          )
          .envelope,
    );
    expect(outcome.status, MobileCommandStatus.saved);
    expect(transport.sendAttempts, 0);
    expect(transport.connectionState.name, 'absent');
  });

  test('dispatching is visible before the writer returns', () async {
    late MobileCommandDispatcher dispatcher;
    final writer = _HookWriter((envelope) async {
      expect(
        dispatcher.progressOf(envelope.commandId),
        MobileCommandStatus.dispatching,
      );
      return const MobileWriterSaved(committedRecordId: 'rec');
    });
    dispatcher = MobileCommandDispatcher(
      writer: writer,
      authority: MobileAuthoritySnapshot.phoneOnly,
    );
    final outcome = await dispatcher.dispatch(
      goalEnvelope(activation: preparation.beginActivation()),
    );
    expect(outcome.status, MobileCommandStatus.saved);
  });

  test('same command id with a different payload does not write again',
      () async {
    final writer =
        _RecordingWriter(const MobileWriterSaved(committedRecordId: 'rec'));
    final dispatcher = MobileCommandDispatcher(
      writer: writer,
      authority: MobileAuthoritySnapshot.phoneOnly,
    );
    final activation = preparation.beginActivation();
    final original = goalEnvelope(activation: activation);
    await dispatcher.dispatch(original);
    final hostile = MobileCommandEnvelope(
      commandId: original.commandId,
      matchId: original.matchId,
      commandType: original.commandType,
      origin: original.origin,
      originDeviceId: original.originDeviceId,
      createdAtLocal: original.createdAtLocal,
      schemaVersion: original.schemaVersion,
      payload: GoalCommandPayload(
        scoringTeamId: 'away-team',
        captureIntentId: activation.captureIntentId,
      ),
    );
    final outcome = await dispatcher.dispatch(hostile);
    expect(outcome.status, MobileCommandStatus.failed);
    expect(outcome.detail, MobileCommandReason.commandIdentityConflict);
    expect(outcome.writerInvoked, isFalse);
    expect(writer.calls, 1);
  });

  test('catalog hides cut-over commands that are not yet production writers',
      () {
    const gate = CommandAuthorityGate();
    final catalog =
        gate.catalogFor(authority: MobileAuthoritySnapshot.phoneOnly);
    expect(
      catalog
          .firstWhere((entry) => entry.commandType == MobileCommandType.goal)
          .kind,
      MobileCommandAvailabilityKind.available,
    );
    for (final type in const [
      MobileCommandType.yellow,
      MobileCommandType.directSendOff,
      MobileCommandType.secondCautionSendOff,
      MobileCommandType.substitution,
      MobileCommandType.fullTime,
      MobileCommandType.finishMatch,
    ]) {
      expect(
        catalog.firstWhere((entry) => entry.commandType == type).kind,
        MobileCommandAvailabilityKind.notYetCutOver,
        reason: type.name,
      );
    }
  });

  test('command and companion sources do not touch legacy or research writers',
      () {
    final roots = [
      Directory('lib/mobile_commands'),
      Directory('lib/companion'),
      Directory('lib/presentation'),
    ];
    final forbidden = [
      'MatchSession',
      'match_session',
      'package:firebase',
      'google_sign_in',
      'play_services',
      'research/',
      'SavedGoal',
      'SavedCaution',
      'SavedSendOff',
      'SavedSubstitution',
      'WatchConnectivity',
      'wear_os',
    ];
    for (final root in roots) {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final text = entity.readAsStringSync();
        for (final token in forbidden) {
          expect(text, isNot(contains(token)), reason: '${entity.path} $token');
        }
      }
    }
  });
}

final class _RecordingWriter implements MobileAuthoritativeWriter {
  _RecordingWriter(this.admission);

  final MobileWriterAdmission admission;
  int calls = 0;

  @override
  Future<MobileWriterAdmission> commit(MobileCommandEnvelope envelope) async {
    calls += 1;
    return admission;
  }
}

final class _HookWriter implements MobileAuthoritativeWriter {
  _HookWriter(this._commit);

  final Future<MobileWriterAdmission> Function(MobileCommandEnvelope) _commit;

  @override
  Future<MobileWriterAdmission> commit(MobileCommandEnvelope envelope) {
    return _commit(envelope);
  }
}

final class _PhoneHarness {
  _PhoneHarness({
    required this.temp,
    required this.database,
    required this.composition,
    required this.identity,
    required this.seeded,
  });

  final Directory temp;
  final LocalMatchDatabase database;
  final MatchApplicationComposition composition;
  final PhoneCaptureIdentity identity;
  final Match seeded;

  static Future<_PhoneHarness> open() async {
    final temp = await Directory.systemTemp.createTemp('mobile_cmd_');
    final database = LocalMatchDatabase.memory();
    final composition =
        await MatchApplicationComposition.open(storageRoot: temp);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final seeded = newLocalMatch(DateTime.utc(2026, 10, 23, 18));
    await database.upsertMatch(seeded);
    return _PhoneHarness(
      temp: temp,
      database: database,
      composition: composition,
      identity: identity,
      seeded: seeded,
    );
  }

  MobileCommandRuntime runtime({NoPeerTransport? transport}) {
    return MobileCommandRuntime.phoneOnly(
      boundary: composition.boundary,
      originDeviceId: identity.originDeviceId,
      captureContext: (matchId) async => identity.contextFor(matchId),
      peerTransport: transport,
    );
  }

  Future<void> close() async {
    await composition.close();
    await database.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  }
}
