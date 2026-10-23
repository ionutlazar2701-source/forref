/// Conceptual family only. A value is not device certification and is not
/// a Huawei Watch support claim.
enum PlatformFamily { wearOs, watchOs, garmin, zepp, huawei, unknown }

enum CompanionConnectionState { disconnected, connected, connectionLost }

enum CompanionCertificationState { unknown, known, compatible, certified }

enum PairingReadiness {
  unpaired,
  discoverable,
  pairing,
  paired,
  readyForProvisioning,
  incompatible,
}

/// A known companion. Connection and certification are not capture authority.
final class CompanionDevice {
  const CompanionDevice({
    required this.deviceId,
    required this.displayName,
    required this.platformFamily,
    required this.capabilities,
    required this.connectionState,
    required this.certificationState,
    required this.pairingReadiness,
    this.holdsCaptureAuthority = false,
  });

  final String deviceId;
  final String displayName;
  final PlatformFamily platformFamily;
  final Set<CompanionCapability> capabilities;
  final CompanionConnectionState connectionState;
  final CompanionCertificationState certificationState;
  final PairingReadiness pairingReadiness;

  /// Display of an explicit authority assignment. Pairing must leave this false.
  final bool holdsCaptureAuthority;
}

enum CompanionCapability {
  canCaptureGoal,
  canCaptureYellow,
  canCaptureSendOff,
  canCaptureSubstitution,
  canStoreMatchMemoryLocally,
  supportsIndependentMatchTiming,
  supportsLocalHaptics,
  supportsPeerTransport,
}
