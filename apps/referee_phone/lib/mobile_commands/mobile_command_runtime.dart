import 'package:forref_match_core/forref_match_core.dart';

import '../companion/companion_device.dart';
import '../companion/no_peer_transport.dart';
import '../companion/peer_transport.dart';
import '../companion/companion_registry.dart';
import '../match_application/match_application_boundary.dart';
import '../presentation/mobile_read_models.dart';
import 'command_authority_gate.dart';
import 'match_application_command_writer.dart';
import 'mobile_command.dart';
import 'mobile_command_availability.dart';
import 'mobile_command_dispatcher.dart';
import 'mobile_command_preparation.dart';

/// Phone-only command composition. Peer transport is a no-op.
final class MobileCommandRuntime {
  MobileCommandRuntime({
    required this.preparation,
    required this.dispatcher,
    required this.gate,
    required this.companions,
    required this.peerTransport,
    required this.outbox,
    required this.originDeviceId,
    required this.localStorageReady,
    required this.temporalEvidenceReady,
    required this.authorityKnown,
  });

  final MobileCommandPreparation preparation;
  final MobileCommandDispatcher dispatcher;
  final CommandAuthorityGate gate;
  final CompanionRegistry companions;
  final PeerCommandTransport peerTransport;
  final MobileCommandOutbox outbox;
  final String originDeviceId;
  final bool localStorageReady;
  final bool temporalEvidenceReady;
  final bool authorityKnown;

  MobileAuthoritySnapshot get authority => dispatcher.authority;

  factory MobileCommandRuntime.phoneOnly({
    required MatchApplicationBoundary? boundary,
    required String originDeviceId,
    required Future<CaptureContext?> Function(String matchId) captureContext,
    Future<TemporalContext> Function()? periodAnchor,
    bool temporalEvidenceReady = false,
    MobileCommandPreparation? preparation,
    CompanionRegistry? companions,
    PeerCommandTransport? peerTransport,
  }) {
    final writer = boundary == null
        ? const _BoundaryMissingWriter()
        : MatchApplicationCommandWriter(
            boundary: boundary,
            captureContext: captureContext,
            periodAnchor: periodAnchor,
          );
    final registry = companions ?? CompanionRegistry();
    return MobileCommandRuntime(
      preparation: preparation ?? MobileCommandPreparation(),
      dispatcher: MobileCommandDispatcher(
        writer: writer,
        authority: MobileAuthoritySnapshot.phoneOnly,
      ),
      gate: const CommandAuthorityGate(),
      companions: registry,
      peerTransport: peerTransport ?? NoPeerTransport(),
      outbox: MobileCommandOutbox(),
      originDeviceId: originDeviceId,
      localStorageReady: boundary != null,
      temporalEvidenceReady: temporalEvidenceReady,
      authorityKnown: originDeviceId.isNotEmpty,
    );
  }

  List<MobileCommandAvailability> catalog(MobilePhaseHint phase) {
    return gate.catalogFor(authority: authority, phase: phase);
  }

  MobileMatchReadiness readiness({required bool matchConfigured}) {
    final device = companions.device;
    return MobileMatchReadiness(
      matchConfigured: matchConfigured,
      localStorageReady: localStorageReady,
      temporalEvidenceReady: temporalEvidenceReady,
      authorityKnown: authorityKnown,
      companionPresent: device != null,
      companionCertified:
          device?.certificationState == CompanionCertificationState.certified,
      companionProvisioned:
          device?.pairingReadiness == PairingReadiness.readyForProvisioning,
      mode: deriveOperatingMode(device: device, authority: authority),
    );
  }

  MobileDeviceReadModel deviceState() {
    return MobileDeviceReadModel(
      pairingReadiness: companions.pairingReadiness,
      device: companions.device,
      mode: deriveOperatingMode(
        device: companions.device,
        authority: authority,
      ),
    );
  }
}

final class _BoundaryMissingWriter implements MobileAuthoritativeWriter {
  const _BoundaryMissingWriter();

  @override
  Future<MobileWriterAdmission> commit(MobileCommandEnvelope envelope) async {
    return const MobileWriterFailed('match application boundary missing');
  }
}
