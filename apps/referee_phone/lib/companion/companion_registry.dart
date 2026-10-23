import 'companion_device.dart';

/// Application-level companion book. No discovery and no radio.
final class CompanionRegistry {
  CompanionDevice? _device;

  CompanionDevice? get device => _device;

  PairingReadiness get pairingReadiness =>
      _device?.pairingReadiness ?? PairingReadiness.unpaired;

  void clear() => _device = null;

  /// Presents a fixture or a future pairing result.
  ///
  /// Refuses a device that already claims capture authority. Pairing does
  /// not answer who may append Match Records.
  void present(CompanionDevice device) {
    if (device.holdsCaptureAuthority) {
      throw StateError('pairing cannot assign capture authority');
    }
    _device = device;
  }

  void loseConnection() {
    final current = _device;
    if (current == null) return;
    _device = CompanionDevice(
      deviceId: current.deviceId,
      displayName: current.displayName,
      platformFamily: current.platformFamily,
      capabilities: current.capabilities,
      connectionState: CompanionConnectionState.connectionLost,
      certificationState: current.certificationState,
      pairingReadiness: current.pairingReadiness,
      holdsCaptureAuthority: current.holdsCaptureAuthority,
    );
  }
}
