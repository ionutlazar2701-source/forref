import '../mobile_commands/mobile_command.dart';
import 'companion_device.dart';
import 'peer_transport.dart';

/// Production peer transport for this wave. It moves nothing.
final class NoPeerTransport
    implements
        PeerCommandTransport,
        PeerRecordTransport,
        PeerConnectionStatePort,
        PeerCapabilitiesPort {
  int sendAttempts = 0;

  @override
  Future<PeerTransportReceipt> sendCommand(
      MobileCommandEnvelope envelope) async {
    sendAttempts += 1;
    return const PeerTransportReceipt.notSent();
  }

  @override
  Future<List<PeerRecordNotice>> pullRecords({required String matchId}) async {
    return const [];
  }

  @override
  PeerConnectionState get connectionState => PeerConnectionState.absent;

  @override
  Set<CompanionCapability> capabilitiesFor(String deviceId) => const {};
}
