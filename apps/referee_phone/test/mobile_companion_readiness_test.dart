import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:referee_phone/companion/companion_capabilities.dart';
import 'package:referee_phone/companion/companion_device.dart';
import 'package:referee_phone/companion/companion_registry.dart';
import 'package:referee_phone/companion/no_peer_transport.dart';
import 'package:referee_phone/companion/peer_protocol.dart';
import 'package:referee_phone/companion/peer_transport.dart';
import 'package:referee_phone/companion/simulated_peer.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/mobile_commands/command_authority_gate.dart';
import 'package:referee_phone/mobile_commands/mobile_command.dart';
import 'package:referee_phone/mobile_commands/mobile_command_availability.dart';
import 'package:referee_phone/mobile_commands/mobile_command_dispatcher.dart';
import 'package:referee_phone/mobile_commands/mobile_command_runtime.dart';
import 'package:referee_phone/presentation/mobile_read_models.dart';

void main() {
  CompanionDevice knownDevice({
    CompanionCertificationState certification =
        CompanionCertificationState.known,
    PairingReadiness pairing = PairingReadiness.paired,
    Set<CompanionCapability> capabilities = const {},
    bool holdsCaptureAuthority = false,
  }) {
    return CompanionDevice(
      deviceId: 'watch-1',
      displayName: 'Lab Watch',
      platformFamily: PlatformFamily.wearOs,
      capabilities: capabilities,
      connectionState: CompanionConnectionState.connected,
      certificationState: certification,
      pairingReadiness: pairing,
      holdsCaptureAuthority: holdsCaptureAuthority,
    );
  }

  test('P1 no device is unpaired', () {
    final registry = CompanionRegistry();
    final runtime = MobileCommandRuntime.phoneOnly(
      boundary: null,
      originDeviceId: 'phone-1',
      captureContext: (_) async => null,
      companions: registry,
    );
    expect(registry.pairingReadiness, PairingReadiness.unpaired);
    expect(runtime.deviceState().companionPresent, isFalse);
    expect(runtime.readiness(matchConfigured: false).companionPresent, isFalse);
    expect(runtime.authority.mode, MobileOperatingMode.phoneOnly);
  });

  test('P2 a simulated known device is readable and paired', () {
    final registry = CompanionRegistry()..present(knownDevice());
    expect(registry.device!.displayName, 'Lab Watch');
    expect(registry.pairingReadiness, PairingReadiness.paired);
    expect(registry.device!.platformFamily, PlatformFamily.wearOs);
  });

  test('P3 paired is not certified', () {
    final device = knownDevice();
    expect(device.pairingReadiness, PairingReadiness.paired);
    expect(
      device.certificationState,
      isNot(CompanionCertificationState.certified),
    );
  });

  test('P4 certified is not authoritative', () {
    final registry = CompanionRegistry()
      ..present(
        knownDevice(certification: CompanionCertificationState.certified),
      );
    expect(registry.device!.holdsCaptureAuthority, isFalse);
    expect(
      () => registry.present(knownDevice(holdsCaptureAuthority: true)),
      throwsStateError,
    );
    const gate = CommandAuthorityGate();
    final decision = gate.evaluate(
      commandType: MobileCommandType.goal,
      authority: MobileAuthoritySnapshot.phoneOnly,
    );
    expect(decision.kind, MobileCommandAvailabilityKind.available);
    expect(
      deriveOperatingMode(
        device: registry.device,
        authority: MobileAuthoritySnapshot.phoneOnly,
      ),
      MobileOperatingMode.companionPrepared,
    );
  });

  test('P5 protocol mismatch is rejected', () {
    const handshake = PeerHandshake();
    final rejected = handshake.respond(
      const PeerHello(
        deviceId: 'watch-1',
        appVersion: 'lab',
        protocolVersion: 99,
        platformFamily: PlatformFamily.huawei,
        capabilities: {},
      ),
    );
    expect(rejected, isA<PeerHelloRejected>());
    final accepted = handshake.respond(
      const PeerHello(
        deviceId: 'watch-1',
        appVersion: PeerProtocol.appVersion,
        protocolVersion: PeerProtocol.version,
        platformFamily: PlatformFamily.watchOs,
        capabilities: {CompanionCapability.supportsPeerTransport},
      ),
    );
    expect(accepted, isA<PeerHelloAccepted>());
  });

  test('P6 an unknown capability does not default to supported', () {
    final parsed = capabilitiesFromNames([
      'canCaptureGoal',
      'canTeleport',
      'huaweiWatchCertified',
    ]);
    expect(parsed, {CompanionCapability.canCaptureGoal});
    expect(capabilitySupported(parsed, 'canTeleport'), isFalse);
    expect(
      capabilitySupported(parsed, CompanionCapability.canCaptureYellow.name),
      isFalse,
    );
  });

  test('P7 command and device core do not require GMS', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, isNot(contains('play-services')));
    expect(gradle, isNot(contains('com.google.gms')));
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('firebase')));
    expect(pubspec, isNot(contains('google_sign_in')));
    for (final directory in [
      Directory('lib/mobile_commands'),
      Directory('lib/companion'),
      Directory('lib/presentation'),
    ]) {
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final text = entity.readAsStringSync();
        expect(text, isNot(contains('package:flutter/')));
        expect(text, isNot(contains('dart:io')));
        expect(text, isNot(contains('firebase')));
      }
    }
  });

  test('P8 connection loss does not mutate sporting truth or authority',
      () async {
    final temp = await Directory.systemTemp.createTemp('mobile_peer_');
    final composition =
        await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(() async {
      await composition.close();
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    const matchId = 'match-p8';
    final registry = CompanionRegistry()..present(knownDevice());
    final beforeAuthority = const MobileAuthoritySnapshot(
      localCaptureAuthorized: false,
      companionHoldsCaptureAuthority: true,
      mode: MobileOperatingMode.phonePrimary,
    );
    final runtime = MobileCommandRuntime.phoneOnly(
      boundary: composition.boundary,
      originDeviceId: identity.originDeviceId,
      captureContext: (id) async => identity.contextFor(id),
      companions: registry,
    );
    final kickOff = await runtime.dispatcher.dispatch(
      runtime.preparation
          .freezeKickOff(
            activation: runtime.preparation.beginActivation(),
            matchId: matchId,
            originDeviceId: identity.originDeviceId,
            periodIndex: 1,
          )
          .envelope,
    );
    expect(kickOff.status, MobileCommandStatus.saved);
    final before =
        await composition.boundary.durableStore.readCommittedForMatch(
      matchId,
    );
    registry.loseConnection();
    final afterDisconnect = AuthorityContinuity.afterPeerDisconnect(
      beforeAuthority,
    );
    expect(afterDisconnect.localCaptureAuthorized, isFalse);
    expect(afterDisconnect.companionHoldsCaptureAuthority, isTrue);
    expect(
      registry.device!.connectionState,
      CompanionConnectionState.connectionLost,
    );
    expect(registry.device!.holdsCaptureAuthority, isFalse);
    final after = await composition.boundary.durableStore.readCommittedForMatch(
      matchId,
    );
    expect(after.map((record) => record.recordId), [
      for (final record in before) record.recordId,
    ]);
  });

  test('P9 a repeated peer message id is rejected', () {
    final adapter = SimulatedPeerAdapter();
    const message = PeerMessage(messageId: 'msg-1', matchId: 'match-1');
    expect(adapter.acceptInbound(message), isTrue);
    expect(adapter.acceptInbound(message), isFalse);
    expect(adapter.arrivals, hasLength(2));
  });

  test('P10 transport order does not rewrite established match state',
      () async {
    const committed = ['record-a', 'record-b'];
    final arrivals = [
      const PeerMessage(
        messageId: 'late',
        matchId: 'match-1',
        transportOrder: 2,
      ),
      const PeerMessage(
        messageId: 'early',
        matchId: 'match-1',
        transportOrder: 1,
      ),
    ];
    expect(
      authoritativeRecordOrder(
        committedRecordIds: committed,
        transportArrivals: arrivals,
      ),
      committed,
    );
    final receipt = await NoPeerTransport().sendCommand(
      MobileCommandEnvelope(
        commandId: 'cmd',
        matchId: 'match-1',
        commandType: MobileCommandType.goal,
        origin: MobileCommandOrigin.mobileUi,
        originDeviceId: 'phone-1',
        createdAtLocal: DateTime.utc(2026, 10, 23),
        schemaVersion: 1,
        payload: const GoalCommandPayload(
          scoringTeamId: 'home',
          captureIntentId: 'intent',
        ),
      ),
    );
    expect(receipt.kind, PeerTransportReceiptKind.notSent);
  });

  test('transport receipt cannot be expressed as Saved', () async {
    final receipt = await NoPeerTransport().sendCommand(
      MobileCommandEnvelope(
        commandId: 'cmd',
        matchId: 'match-1',
        commandType: MobileCommandType.kickOff,
        origin: MobileCommandOrigin.mobileUi,
        originDeviceId: 'phone-1',
        createdAtLocal: DateTime.utc(2026, 10, 23),
        schemaVersion: MobileCommandSchema.version,
        payload: const KickOffCommandPayload(periodIndex: 1),
      ),
    );
    expect(receipt.kind, PeerTransportReceiptKind.notSent);
    expect(receipt.kind.name, isNot('saved'));
  });

  test('a companion that holds authority blocks a second phone writer',
      () async {
    final writer = _CountingWriter();
    final dispatcher = MobileCommandDispatcher(
      writer: writer,
      authority: const MobileAuthoritySnapshot(
        localCaptureAuthorized: true,
        companionHoldsCaptureAuthority: true,
        mode: MobileOperatingMode.phonePrimary,
      ),
    );
    final outcome = await dispatcher.dispatch(
      MobileCommandEnvelope(
        commandId: 'cmd',
        matchId: 'match-1',
        commandType: MobileCommandType.goal,
        origin: MobileCommandOrigin.mobileUi,
        originDeviceId: 'phone-1',
        createdAtLocal: DateTime.utc(2026, 10, 23),
        schemaVersion: MobileCommandSchema.version,
        payload: const GoalCommandPayload(
          scoringTeamId: 'home',
          captureIntentId: 'intent',
        ),
      ),
    );
    expect(outcome.status, MobileCommandStatus.authorityUnavailable);
    expect(outcome.detail, MobileCommandReason.singleWriter);
    expect(writer.calls, 0);
  });

  test('outbox enqueue is not a saved acknowledgement', () {
    final outbox = MobileCommandOutbox();
    final envelope = MobileCommandEnvelope(
      commandId: 'cmd',
      matchId: 'match-1',
      commandType: MobileCommandType.goal,
      origin: MobileCommandOrigin.mobileUi,
      originDeviceId: 'phone-1',
      createdAtLocal: DateTime.utc(2026, 10, 23),
      schemaVersion: MobileCommandSchema.version,
      payload: const GoalCommandPayload(
        scoringTeamId: 'home',
        captureIntentId: 'intent',
      ),
    );
    outbox.enqueue(envelope);
    outbox.enqueue(envelope);
    expect(outbox.pending, hasLength(1));
  });
}

final class _CountingWriter implements MobileAuthoritativeWriter {
  int calls = 0;

  @override
  Future<MobileWriterAdmission> commit(MobileCommandEnvelope envelope) async {
    calls += 1;
    return const MobileWriterSaved();
  }
}
