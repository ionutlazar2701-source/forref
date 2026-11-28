import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:forref_match_persistence/watch_identity.dart';
import 'package:referee_phone/officiate/watch_provision_debug_bridge.dart';

void main() {
  test('correlation evidence names the stored identity and not the document',
      () {
    const canonical =
        '{"schema":"forref.watch-provision.v1","teams":{"home":{"name":"North"}}}';
    final line = describeDebugCorrelation(jsonEncode({
      'requestId': '11111111-2222-4333-8444-555555555555',
      'phase': 'pending',
      'matchId': 'match-watch-001',
      'contentHash': 'ab' * 32,
      'generation': 1,
      'canonical': canonical,
    }));
    expect(line, contains('request=11111111-2222-4333-8444-555555555555'));
    expect(line, contains('phase=pending'));
    expect(line, contains('generation=1'));
    expect(line.contains('North'), isFalse);
    expect(line.contains(canonical), isFalse);
    expect(describeDebugCorrelation(null), 'correlation=absent');
  });

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

  test('a pending request returns the stored canonical and not a payload',
      () async {
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
    final stage =
        await composition.boundary.durableStore.readWatchProvisionStage(
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
    expect(bridge.lastActivation?['requestId'],
        '11111111-2222-4333-8444-555555555555');
  });

  test('a lock before pending does not commit a root', () async {
    await composition.boundary.prepareWatchOperatedMatch(
      canonicalMessage: canonical,
      phoneOriginDeviceId: identity.originDeviceId,
    );
    await bridge.start('match-watch-001');
    final early = await _exchange(bridge, {
      'operation': 'lock',
      'installationId': fixture['localInstallationId'],
      'requestId': '11111111-2222-4333-8444-555555555555',
      'generation': 1,
      'matchId': 'match-watch-001',
      'contentHash': fixture['contentHash'],
      'readBack': true,
    });
    expect(early.status, 409);
    expect(early.body['reason'], 'order');
    expect(early.body['durable'], isFalse);
    expect(
      await composition.boundary.durableStore.readGenerationOneAuthorityRoot(
        'match-watch-001',
      ),
      isNull,
    );
  });

  test('a lost lock response keeps one root and the same correlation',
      () async {
    final file = File('${temp.path}/correlation.json');
    await bridge.stop();
    bridge = WatchProvisionDebugBridge(
      boundary: composition.boundary,
      phoneOriginDeviceId: identity.originDeviceId,
      port: 47232,
      correlationFile: file,
    );
    await composition.boundary.prepareWatchOperatedMatch(
      canonicalMessage: canonical,
      phoneOriginDeviceId: identity.originDeviceId,
    );
    await bridge.start('match-watch-001');
    final pending = await _exchange(bridge, {
      'operation': 'pending',
      'installationId': fixture['localInstallationId'],
      'requestId': '11111111-2222-4333-8444-555555555555',
      'generation': 1,
    });
    expect(pending.status, 200);
    expect(pending.body['disposition'], 'prepared');
    final locked = await _exchange(bridge, {
      'operation': 'lock',
      'installationId': fixture['localInstallationId'],
      'requestId': '11111111-2222-4333-8444-555555555555',
      'generation': 1,
      'matchId': 'match-watch-001',
      'contentHash': fixture['contentHash'],
      'readBack': true,
    });
    expect(locked.body['durable'], isTrue);
    final root =
        await composition.boundary.durableStore.readGenerationOneAuthorityRoot(
      'match-watch-001',
    );
    expect(root?.deviceId, fixture['localInstallationId']);
    await bridge.stop();
    final restarted = WatchProvisionDebugBridge(
      boundary: composition.boundary,
      phoneOriginDeviceId: identity.originDeviceId,
      port: 47233,
      correlationFile: file,
    );
    bridge = restarted;
    await restarted.start('match-watch-001');
    final invalid = await _exchange(restarted, {
      'operation': 'lock',
      'installationId': fixture['localInstallationId'],
      'requestId': '11111111-2222-4333-8444-555555555555',
      'generation': 1,
      'matchId': 'match-watch-001',
      'contentHash': fixture['contentHash'],
      'readBack': false,
    });
    expect(invalid.status, 409);
    expect(invalid.body['durable'], isFalse);
    expect(invalid.body['reason'], 'receipt-invalid');
    final other = await _exchange(restarted, {
      'operation': 'lock',
      'installationId': fixture['localInstallationId'],
      'requestId': '99999999-8888-4777-8666-555555555555',
      'generation': 1,
      'matchId': 'match-watch-001',
      'contentHash': fixture['contentHash'],
      'readBack': true,
    });
    expect(other.body['reason'], 'correlation');
    final again = await _exchange(restarted, {
      'operation': 'lock',
      'installationId': fixture['localInstallationId'],
      'requestId': '11111111-2222-4333-8444-555555555555',
      'generation': 1,
      'matchId': 'match-watch-001',
      'contentHash': fixture['contentHash'],
      'readBack': true,
    });
    expect(again.status, 200);
    expect(again.body['disposition'], 'locked');
    expect(again.body['reason'], 'idempotent-lock');
    final kept =
        await composition.boundary.durableStore.readGenerationOneAuthorityRoot(
      'match-watch-001',
    );
    expect(kept?.deviceId, root?.deviceId);
    expect(kept?.principalId, root?.principalId);
    final stored = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    expect(stored['requestId'], '11111111-2222-4333-8444-555555555555');
    expect(stored['phase'], 'locked');
    expect(stored['contentHash'], fixture['contentHash']);
    final recorded = await _exchange(restarted, {
      'operation': 'activation',
      'type': 'WATCH_ACTIVATED_V1',
      'installationId': fixture['localInstallationId'],
      'requestId': '11111111-2222-4333-8444-555555555555',
      'generation': 1,
      'matchId': 'match-watch-001',
      'contentHash': fixture['contentHash'],
      'readBack': true,
    });
    expect(recorded.body['disposition'], 'recorded');
    await restarted.stop();
    final reported = WatchProvisionDebugBridge(
      boundary: composition.boundary,
      phoneOriginDeviceId: identity.originDeviceId,
      port: 47234,
      correlationFile: file,
    );
    bridge = reported;
    expect(reported.lastActivation?['requestId'],
        '11111111-2222-4333-8444-555555555555');
    await reported.start('match-watch-001');
    final repeat = await _exchange(reported, {
      'operation': 'activation',
      'type': 'WATCH_ACTIVATED_V1',
      'installationId': fixture['localInstallationId'],
      'requestId': '11111111-2222-4333-8444-555555555555',
      'generation': 1,
      'matchId': 'match-watch-001',
      'contentHash': fixture['contentHash'],
      'readBack': true,
    });
    expect(repeat.body['disposition'], 'recorded');
    expect(repeat.body['requestId'], '11111111-2222-4333-8444-555555555555');
    final still =
        await composition.boundary.durableStore.readGenerationOneAuthorityRoot(
      'match-watch-001',
    );
    expect(still?.deviceId, root?.deviceId);
  });

  test('malformed JSON is refused and does not prepare a root', () async {
    await composition.boundary.prepareWatchOperatedMatch(
      canonicalMessage: canonical,
      phoneOriginDeviceId: identity.originDeviceId,
    );
    await bridge.start('match-watch-001');
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('http://${bridge.loopbackEndpoint}$forrefWatchProvisionPath'),
      );
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode('{'));
      final response = await request.close();
      final text = await utf8.decodeStream(response);
      expect(response.statusCode, 409);
      final body = (jsonDecode(text) as Map).cast<String, Object?>();
      expect(body['disposition'], 'refused');
      expect(body.containsKey('canonical'), isFalse);
    } finally {
      client.close(force: true);
    }
    expect(
      await composition.boundary.durableStore.readGenerationOneAuthorityRoot(
        'match-watch-001',
      ),
      isNull,
    );
  });

  test('listen reports recovery-required without changing the writer',
      () async {
    await composition.boundary.prepareWatchOperatedMatch(
      canonicalMessage: canonical,
      phoneOriginDeviceId: identity.originDeviceId,
    );
    expect(
      await bridge.start('match-watch-001'),
      WatchProvisionBridgeDisposition.listening,
    );
    final digest = encodeDigestHex(candidateDigestBytes(
      '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff',
    ));
    final witness = {
      'schema': watchWitnessSchema,
      'candidateKind': 'platform_uuid',
      'candidateDigest': digest,
      'digestVersion': 1,
      'evidenceGrade': watchEvidenceUnverifiedDevice,
      'sourceBuilds': 'identity-detect-031',
    };
    final prepared = await _post(bridge, {
      'operation': 'pending',
      'installationId': fixture['localInstallationId'],
      'requestId': '11111111-2222-4333-8444-555555555555',
      'generation': 1,
      'witness': witness,
    });
    expect(prepared['disposition'], 'prepared');
    expect(prepared.containsKey('canonical'), isTrue);
    final eventsBefore = await composition.boundary.durableStore
        .readWatchIdentityEvents('match-watch-001');
    expect(
      eventsBefore.map((event) => event.eventKind),
      contains('watch_witness_observed'),
    );
    final stageBefore =
        await composition.boundary.durableStore.readWatchProvisionStage(
      'match-watch-001',
    );
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('http://${bridge.loopbackEndpoint}/'),
      );
      final response = await request.close();
      final text = await utf8.decodeStream(response);
      final body = (jsonDecode(text) as Map).cast<String, Object?>();
      expect(response.statusCode, 200);
      expect(body['disposition'], 'listening');
      expect(body['writes'], 0);
    } finally {
      client.close(force: true);
    }
    final candidate = await _post(bridge, {
      'operation': 'pending',
      'installationId': 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
      'requestId': '99999999-8888-4777-8666-555555555555',
      'generation': 1,
      'witness': witness,
    });
    expect(candidate['disposition'], 'refused');
    expect(candidate['reason'], 'recovery-required');
    expect(candidate.containsKey('canonical'), isFalse);
    final stageAfter =
        await composition.boundary.durableStore.readWatchProvisionStage(
      'match-watch-001',
    );
    expect(stageAfter?.canonical, stageBefore?.canonical);
    expect(stageAfter?.writerDeviceId, stageBefore?.writerDeviceId);
    expect(stageAfter?.contentHash, stageBefore?.contentHash);
    expect(
      await composition.boundary.durableStore.readGenerationOneAuthorityRoot(
        'match-watch-001',
      ),
      isNull,
    );
    final auth =
        await composition.boundary.durableStore.authorizeInstallationEnrollment(
      matchId: 'match-watch-001',
      principalId: stageAfter!.principalId,
      previousInstallationId: stageAfter.writerDeviceId,
      installationId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
    );
    expect(auth, isA<WatchIdentityRefused>());
    expect((auth as WatchIdentityRefused).reason, 'authorization-unavailable');
  });

  test('a version-2 fingerprint does not invent a missing witness', () async {
    await composition.boundary.prepareWatchOperatedMatch(
      canonicalMessage: canonical,
      phoneOriginDeviceId: identity.originDeviceId,
    );
    expect(
      await bridge.start('match-watch-001'),
      WatchProvisionBridgeDisposition.listening,
    );
    final bytes = platformBytesV2('00112233445566778899aabbccddeeff')!;
    final witness = {
      'schema': watchWitnessSchema,
      'candidateKind': 'platform_uuid',
      'candidateDigest': encodeDigestHex(candidateDigestV2Bytes(bytes)),
      'digestVersion': watchCandidateDigestVersionV2,
      'evidenceGrade': watchEvidenceUnverifiedDevice,
      'sourceBuilds': 'identity-bytes32-032',
    };
    final other = await _post(bridge, {
      'operation': 'pending',
      'installationId': 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
      'requestId': '99999999-8888-4777-8666-555555555555',
      'generation': 1,
      'witness': witness,
    });
    expect(other['disposition'], 'refused');
    expect(other['reason'], 'installation');
    final events = await composition.boundary.durableStore
        .readWatchIdentityEvents('match-watch-001');
    expect(
      events.map((event) => event.eventKind),
      isNot(contains('watch_witness_observed')),
    );
    expect(
      events.map((event) => event.eventKind),
      isNot(contains('candidate_seen')),
    );
    final stage =
        await composition.boundary.durableStore.readWatchProvisionStage(
      'match-watch-001',
    );
    expect(stage?.writerDeviceId, fixture['localInstallationId']);
    final same = await _post(bridge, {
      'operation': 'pending',
      'installationId': fixture['localInstallationId'],
      'requestId': '11111111-2222-4333-8444-555555555555',
      'generation': 1,
      'witness': witness,
    });
    expect(same['disposition'], 'prepared');
    final observed = await composition.boundary.durableStore
        .readWatchIdentityEvents('match-watch-001');
    final witnessEvent = observed
        .where((event) => event.eventKind == 'watch_witness_observed')
        .single;
    expect(witnessEvent.digestVersion, watchCandidateDigestVersionV2);
    final repeat = await _post(bridge, {
      'operation': 'pending',
      'installationId': 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
      'requestId': '99999999-8888-4777-8666-555555555555',
      'generation': 1,
      'witness': witness,
    });
    expect(repeat['reason'], 'recovery-required');
    final after =
        await composition.boundary.durableStore.readWatchProvisionStage(
      'match-watch-001',
    );
    expect(after?.writerDeviceId, stage?.writerDeviceId);
    expect(after?.canonical, stage?.canonical);
    expect(
      await composition.boundary.durableStore.readGenerationOneAuthorityRoot(
        'match-watch-001',
      ),
      isNull,
    );
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
  return (await _exchange(bridge, body)).body;
}

Future<({int status, Map<String, Object?> body})> _exchange(
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
    return (
      status: response.statusCode,
      body: (jsonDecode(text) as Map).cast<String, Object?>(),
    );
  } finally {
    client.close(force: true);
  }
}
