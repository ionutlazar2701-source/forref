import 'companion_device.dart';

abstract final class PeerProtocol {
  static const version = 1;
  static const appVersion = 'mobile-001';
}

final class PeerHello {
  const PeerHello({
    required this.deviceId,
    required this.appVersion,
    required this.protocolVersion,
    required this.platformFamily,
    required this.capabilities,
  });

  final String deviceId;
  final String appVersion;
  final int protocolVersion;
  final PlatformFamily platformFamily;
  final Set<CompanionCapability> capabilities;
}

sealed class PeerHelloResponse {
  const PeerHelloResponse();
}

final class PeerHelloAccepted extends PeerHelloResponse {
  const PeerHelloAccepted({required this.protocolVersion});

  final int protocolVersion;
}

final class PeerHelloRejected extends PeerHelloResponse {
  const PeerHelloRejected({required this.reason});

  final String reason;
}

final class PeerHandshake {
  const PeerHandshake({this.supportedVersion = PeerProtocol.version});

  final int supportedVersion;

  PeerHelloResponse respond(PeerHello hello) {
    if (hello.protocolVersion != supportedVersion) {
      return PeerHelloRejected(
        reason: 'protocol mismatch: ${hello.protocolVersion}',
      );
    }
    if (hello.deviceId.isEmpty) {
      return const PeerHelloRejected(reason: 'device identity missing');
    }
    return PeerHelloAccepted(protocolVersion: supportedVersion);
  }
}
