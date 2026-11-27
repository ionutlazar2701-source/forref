import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/officiate/watch_provision_debug_bridge.dart';

void main() {
  late Directory temp;
  late MatchApplicationComposition composition;
  late PhoneCaptureIdentity identity;
  late Map<String, Object?> fixture;
  late String canonical;
  late WatchProvisionDebugBridge bridge;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('watch_provision_bridge_');
    composition = await MatchApplicationComposition.open(storageRoot: temp);
    identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    fixture = jsonDecode(
      File('../../packages/forref_match_core/test/fixtures/watch_provision_v1.json')
          .readAsStringSync(),
    ) as Map<String, Object?>;
    canonical = fixture['canonical']! as String;
    bridge = WatchProvisionDebugBridge(
      boundary: composition.boundary,
      phoneOriginDeviceId: identity.originDeviceId,
      port: 47231,
    );
  });

  tearDown(() async {
    await bridge.stop();
    await composition.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('the debug port and path are the local bridge', () {
    expect(forrefWatchProvisionPort, 47221);
    expect(forrefWatchProvisionPath, '/watch-provision/v1');
  });

  test('a pending request returns the stored canonical and not a payload', () async {
    await composition.boundary.prepareWatchOperatedMatch(
      canonicalMessage: canonical,
      phoneOriginDeviceId: identity.originDeviceId,
    );
    expect(
      await bridge.start('match-watch-001'),
      WatchProvisionBridgeDisposition.listening,
    );
    final body = await _post(bridge, {
      'operation': 'pending',
      'installationId': fixture['localInstallationId'],
      'requestId': '11111111-2222-4333-8444-555555555555',
      'generation': 1,
    });
    expect(body['disposition'], 'prepared');
    expect(body['canonical'], canonical);
    expect(body['contentHash'], fixture['contentHash']);
    expect(body.containsKey('payloadVersion'), isFalse);
    expect(body['saved'], isFalse);
    expect(body['d1Certified'], isFalse);
    expect(body['homeName'], 'North');
    expect(body['awayName'], 'South');
  });

  test('the wrong installation and a second correlation are refused', () async {
    await composition.boundary.prepareWatchOperatedMatch(
      canonicalMessage: canonical,
      phoneOriginDeviceId: identity.originDeviceId,
    );
    await bridge.start('match-watch-001');
    final first = await _post(bridge, {
      'operation': 'pending',
      'installationId': fixture['localInstallationId'],
      'requestId': '11111111-2222-4333-8444-555555555555',
      'generation': 1,
    });
    expect(first['disposition'], 'prepared');
    final wrongWatch = await _post(bridge, {
      'operation': 'pending',
      'installationId': 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
      'requestId': '11111111-2222-4333-8444-555555555555',
      'generation': 1,
    });
    expect(wrongWatch['disposition'], 'refused');
    expect(wrongWatch.containsKey('canonical'), isFalse);
    final otherRequest = await _post(bridge, {
      'operation': 'pending',
      'installationId': fixture['localInstallationId'],
      'requestId': '99999999-8888-4777-8666-555555555555',
      'generation': 1,
    });
    expect(otherRequest['reason'], 'correlation');
    expect(otherRequest.containsKey('canonical'), isFalse);
  });

  test('the lock durable flag follows the authority commit', () async {
    await composition.boundary.prepareWatchOperatedMatch(
      canonicalMessage: canonical,
      phoneOriginDeviceId: identity.originDeviceId,
    );
    await bridge.start('match-watch-001');
    await _post(bridge, {
      'operation': 'pending',
      'installationId': fixture['localInstallationId'],
      'requestId': '11111111-2222-4333-8444-555555555555',
      'generation': 1,
    });
    final substituted = await _post(bridge, {
      'operation': 'lock',
      'installationId': fixture['localInstallationId'],
      'requestId': '11111111-2222-4333-8444-555555555555',
      'generation': 1,
      'matchId': 'match-watch-001',
      'contentHash': fixture['contentHash'],
      'readBack': true,
      'canonical': '{"schema":"forref.watch-provision.v1"}',
    });
    expect(substituted['reason'], 'canonical');
    expect(substituted['durable'], isFalse);
    final blocked = await _post(bridge, {
      'operation': 'lock',
      'installationId': fixture['localInstallationId'],
      'requestId': '11111111-2222-4333-8444-555555555555',
      'generation': 1,
      'matchId': 'match-watch-001',
      'contentHash': fixture['contentHash'],
      'readBack': false,
    });
    expect(blocked['durable'], isFalse);
    expect(
      await composition.boundary.durableStore.readGenerationOneAuthorityRoot(
        'match-watch-001',
      ),
      isNull,
    );
    final locked = await _post(bridge, {
      'operation': 'lock',
      'installationId': fixture['localInstallationId'],
      'requestId': '11111111-2222-4333-8444-555555555555',
      'generation': 1,
      'matchId': 'match-watch-001',
      'contentHash': fixture['contentHash'],
      'readBack': true,
    });
    expect(locked['disposition'], 'locked');
    expect(locked['durable'], isTrue);
    expect(locked['saved'], isFalse);
    expect(locked['d1Certified'], isFalse);
    final root =
        await composition.boundary.durableStore.readGenerationOneAuthorityRoot(
      'match-watch-001',
    );
    expect(root?.deviceId, fixture['localInstallationId']);
    final stage = await composition.boundary.durableStore.readWatchProvisionStage(
      'match-watch-001',
    );
    expect(stage?.canonical, canonical);
    final recorded = await _post(bridge, {
      'operation': 'activation',
      'type': 'WATCH_ACTIVATED_V1',
      'installationId': fixture['localInstallationId'],
      'requestId': '11111111-2222-4333-8444-555555555555',
      'generation': 1,
      'matchId': 'match-watch-001',
      'contentHash': fixture['contentHash'],
      'readBack': true,
    });
    expect(recorded['disposition'], 'recorded');
    expect(bridge.lastActivation?['requestId'], '11111111-2222-4333-8444-555555555555');
  });

  test('an unprepared bridge does not invent a document', () async {
    expect(
      await bridge.start('match-watch-001'),
      WatchProvisionBridgeDisposition.missing,
    );
    expect(bridge.isListening, isFalse);
  });
}

Future<Map<String, Object?>> _post(
  WatchProvisionDebugBridge bridge,
  Map<String, Object?> body,
) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(
      Uri.parse('http://${bridge.loopbackEndpoint}$forrefWatchProvisionPath'),
    );
    request.headers.contentType = ContentType.json;
    request.add(utf8.encode(jsonEncode(body)));
    final response = await request.close();
    final text = await utf8.decodeStream(response);
    return (jsonDecode(text) as Map).cast<String, Object?>();
  } finally {
    client.close(force: true);
  }
}
