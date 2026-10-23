import 'companion_registry.dart';
import 'peer_protocol.dart';
import 'peer_transport.dart';

/// In-memory peer used by tests. Duplicate message ids are rejected.
final class SimulatedPeerAdapter {
  SimulatedPeerAdapter({PeerHandshake? handshake, CompanionRegistry? registry})
      : handshakePort = handshake ?? const PeerHandshake(),
        registry = registry ?? CompanionRegistry();

  final PeerHandshake handshakePort;
  final CompanionRegistry registry;
  final Set<String> _messageIds = {};
  final List<PeerMessage> arrivals = [];

  bool acceptInbound(PeerMessage message) {
    arrivals.add(message);
    return _messageIds.add(message.messageId);
  }

  PeerHelloResponse handshake(PeerHello hello) => handshakePort.respond(hello);
}
