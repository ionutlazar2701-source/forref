import 'mobile_command.dart';
import 'mobile_command_availability.dart';

/// Decides whether this device may dispatch an authoritative command.
///
/// It does not decide sporting truth, mutate authority, or treat a peer
/// connection as permission to append Match Records.
final class CommandAuthorityGate {
  const CommandAuthorityGate();

  MobileCommandAvailability evaluate({
    required MobileCommandType commandType,
    required MobileAuthoritySnapshot authority,
  }) {
    if (!ProductionCommandCatalog.isCutOver(commandType)) {
      return MobileCommandAvailability(
        commandType: commandType,
        kind: MobileCommandAvailabilityKind.notYetCutOver,
        reasonCode: MobileCommandReason.notYetCutOver,
      );
    }
    if (authority.mode == MobileOperatingMode.watchPrimaryFuture) {
      return MobileCommandAvailability(
        commandType: commandType,
        kind: MobileCommandAvailabilityKind.authorityRequired,
        reasonCode: MobileCommandReason.watchPrimaryNotAuthorized,
      );
    }
    if (authority.companionHoldsCaptureAuthority) {
      return MobileCommandAvailability(
        commandType: commandType,
        kind: MobileCommandAvailabilityKind.authorityRequired,
        reasonCode: MobileCommandReason.singleWriter,
      );
    }
    if (!authority.localCaptureAuthorized) {
      return MobileCommandAvailability(
        commandType: commandType,
        kind: MobileCommandAvailabilityKind.authorityRequired,
        reasonCode: MobileCommandReason.authorityUnavailable,
      );
    }
    return MobileCommandAvailability(
      commandType: commandType,
      kind: MobileCommandAvailabilityKind.available,
      reasonCode: MobileCommandReason.productionCutOver,
    );
  }

  /// Catalog view. Phase can hide a command the gate would still admit.
  MobileCommandAvailability catalog({
    required MobileCommandType commandType,
    required MobileAuthoritySnapshot authority,
    MobilePhaseHint phase = MobilePhaseHint.open,
  }) {
    final gated = evaluate(commandType: commandType, authority: authority);
    if (gated.kind != MobileCommandAvailabilityKind.available) return gated;
    if (commandType == MobileCommandType.kickOff && phase.kickOffCommitted) {
      return const MobileCommandAvailability(
        commandType: MobileCommandType.kickOff,
        kind: MobileCommandAvailabilityKind.unavailable,
        reasonCode: MobileCommandReason.alreadyCommitted,
      );
    }
    return gated;
  }

  List<MobileCommandAvailability> catalogFor({
    required MobileAuthoritySnapshot authority,
    MobilePhaseHint phase = MobilePhaseHint.open,
  }) {
    return [
      for (final type in MobileCommandType.values)
        catalog(commandType: type, authority: authority, phase: phase),
    ];
  }
}

/// Transport loss must not move capture authority onto the phone.
abstract final class AuthorityContinuity {
  static MobileAuthoritySnapshot afterPeerDisconnect(
    MobileAuthoritySnapshot current,
  ) {
    return current;
  }
}
