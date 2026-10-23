import '../mobile_commands/mobile_command.dart';
import 'companion_device.dart';

enum PeerTransportReceiptKind { notSent, outcomeUnknown }

/// Transport receipt. There is no Saved variant: transport is not D1.
final class PeerTransportReceipt {
  const PeerTransportReceipt.notSent()
      : kind = PeerTransportReceiptKind.notSent;

  const PeerTransportReceipt.outcomeUnknown()
      : kind = PeerTransportReceiptKind.outcomeUnknown;

  final PeerTransportReceiptKind kind;
}

enum PeerConnectionState { absent, unavailable, connected, lost }

abstract interface class PeerCommandTransport {
  Future<PeerTransportReceipt> sendCommand(MobileCommandEnvelope envelope);
}

abstract interface class PeerRecordTransport {
  Future<List<PeerRecordNotice>> pullRecords({required String matchId});
}

abstract interface class PeerConnectionStatePort {
  PeerConnectionState get connectionState;
}

abstract interface class PeerCapabilitiesPort {
  Set<CompanionCapability> capabilitiesFor(String deviceId);
}

/// A future record notice. Arrival is not admission into Match Memory.
final class PeerRecordNotice {
  const PeerRecordNotice({
    required this.messageId,
    required this.matchId,
    this.transportOrder,
  });

  final String messageId;
  final String matchId;
  final int? transportOrder;
}

final class PeerMessage {
  const PeerMessage({
    required this.messageId,
    required this.matchId,
    this.transportOrder,
  });

  final String messageId;
  final String matchId;
  final int? transportOrder;
}

/// In-memory future outbox. Enqueue is not Saved.
final class MobileCommandOutbox {
  final List<MobileCommandEnvelope> pending = [];

  void enqueue(MobileCommandEnvelope envelope) {
    if (pending.any((item) => item.commandId == envelope.commandId)) return;
    pending.add(envelope);
  }
}
