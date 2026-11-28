import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:forref_match_persistence/watch_identity.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/match/new_match.dart';
import 'package:referee_phone/officiate/watch_enroll_session.dart';
import 'package:referee_phone/officiate/watch_pairing_session.dart';
import 'package:referee_phone/officiate/watch_provision_debug_bridge.dart';

const historicalInstallation = '11111111-1111-4111-8111-111111111111';
const watchInstallation = '22222222-2222-4222-8222-222222222222';
const otherInstallation = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
const watchRequest = '44444444-4444-4444-8444-444444444444';
const port = 47261;

void main() {
  late Directory temp;
  late LocalMatchDatabase database;
  late MatchApplicationComposition composition;
  late PhoneCaptureIdentity identity;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('watch_pair_');
    database = LocalMatchDatabase.memory();
    composition = await MatchApplicationComposition.open(storageRoot: temp);
    identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
  });

  tearDown(() async {
    await composition.close();
    await database.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('the watch supplies the writer and a later watch is kept out', () async {
    final opened = await _openPairing(temp, database, composition, identity);
    expect(opened.open.status, 'waiting');
    expect(opened.open.historicalUnchanged, isTrue);
    expect(
      await composition.boundary.durableStore
          .readWatchProvisionStage(opened.open.matchId),
      isNull,
    );
    final historicalBefore = await composition.boundary.durableStore
        .readWatchProvisionStage(opened.historicalMatchId);

    final malformed = await _post(opened.bridge, {
      'operation': 'pending',
      'installationId': 'NOT-A-UUID',
      'requestId': watchRequest,
      'generation': 1,
    });
    expect(malformed['reason'], 'message');
    expect(
      await composition.boundary.durableStore
          .readWatchProvisionStage(opened.open.matchId),
      isNull,
    );

    final verified = await _post(opened.bridge, {
      'operation': 'pending',
      'installationId': watchInstallation,
      'requestId': watchRequest,
      'generation': 1,
      'witness': _witness(),
    });
    expect(verified['disposition'], 'prepared');
    expect(opened.bridge.pairingResult?.code, 'verified');
    expect(opened.bridge.pairingResult?.storedWriter, watchInstallation);
    var stage = await composition.boundary.durableStore
        .readWatchProvisionStage(opened.open.matchId);
    expect(stage?.writerDeviceId, watchInstallation);
    expect(
      (await composition.boundary.durableStore
              .readWatchIdentityEvents(opened.open.matchId))
          .where((event) => event.eventKind == 'watch_witness_observed'),
      hasLength(1),
    );

    final replay = await _post(opened.bridge, {
      'operation': 'pending',
      'installationId': watchInstallation,
      'requestId': watchRequest,
      'generation': 1,
      'witness': _witness(),
    });
    expect(replay['disposition'], 'prepared');
    expect(opened.bridge.pairingResult?.code, 'replay');
    expect(
      (await composition.boundary.durableStore
              .readWatchIdentityEvents(opened.open.matchId))
          .where((event) => event.eventKind == 'watch_witness_observed'),
      hasLength(1),
    );

    final other = await _post(opened.bridge, {
      'operation': 'pending',
      'installationId': otherInstallation,
      'requestId': '55555555-5555-4555-8555-555555555555',
      'generation': 1,
      'witness': _witness(),
    });
    expect(other['disposition'], 'refused');
    expect(other['reason'], 'recovery-required');
    expect(opened.bridge.pairingResult?.code, 'writer-kept');
    expect(opened.bridge.pairingResult?.storedWriter, watchInstallation);
    expect(opened.bridge.pairingResult?.requestInstallation, otherInstallation);
    stage = await composition.boundary.durableStore
        .readWatchProvisionStage(opened.open.matchId);
    expect(stage?.writerDeviceId, watchInstallation);
    expect(
      await composition.boundary.durableStore.readGenerationOneAuthorityRoot(
        opened.open.matchId,
      ),
      isNull,
    );
    final historicalAfter = await composition.boundary.durableStore
        .readWatchProvisionStage(opened.historicalMatchId);
    expect(historicalAfter?.writerDeviceId, historicalBefore?.writerDeviceId);
    expect(historicalAfter?.canonical, historicalBefore?.canonical);
    expect(historicalAfter?.contentHash, historicalBefore?.contentHash);

    final again = await openWatchPairing(
      storageRoot: temp,
      database: database,
      boundary: composition.boundary,
      phoneOriginDeviceId: identity.originDeviceId,
      principalId: identity.authorityPrincipalId,
      pairBridge: opened.bridge,
      historicalBridge: opened.historical,
    );
    expect(again.status, 'waiting');
    expect(again.matchId, opened.open.matchId);
    expect(
      (await database.listNewestFirst())
          .where((match) =>
              match.teams.home.teamId == pairHomeTeamId &&
              match.teams.away.teamId == pairAwayTeamId)
          .length,
      1,
    );
  });

  test('a stopped pairing listener resumes on the same match', () async {
    final opened = await _openPairing(temp, database, composition, identity);
    await opened.bridge.stop();
    expect(opened.bridge.isListening, isFalse);
    expect(
      await opened.bridge.resumePairing(),
      WatchProvisionBridgeDisposition.listening,
    );
    expect(opened.bridge.matchId, opened.open.matchId);
    expect(opened.bridge.acceptingFirstWriter, isTrue);
    final verified = await _post(opened.bridge, {
      'operation': 'pending',
      'installationId': watchInstallation,
      'requestId': watchRequest,
      'generation': 1,
      'witness': _witness(),
    });
    expect(verified['disposition'], 'prepared');
    expect(opened.bridge.pairingResult?.code, 'verified');
    final section = File(
      'lib/features/settings/watch_provision_debug_section.dart',
    ).readAsStringSync();
    final connect = section.substring(
      section.indexOf('Future<void> _connectWatch()'),
      section.indexOf('void _onPairing()'),
    );
    expect(connect.contains('_installation'), isFalse);
    expect(connect.contains('openWatchPairing'), isTrue);
    expect(section.contains('resumePairing()'), isTrue);
  });
}

class _OpenedPairing {
  const _OpenedPairing(
    this.bridge,
    this.historical,
    this.open,
    this.historicalMatchId,
  );
  final WatchProvisionDebugBridge bridge;
  final WatchProvisionDebugBridge historical;
  final WatchPairingOpen open;
  final String historicalMatchId;
}

Future<_OpenedPairing> _openPairing(
  Directory temp,
  LocalMatchDatabase database,
  MatchApplicationComposition composition,
  PhoneCaptureIdentity identity,
) async {
  final historical = newLocalMatch(DateTime.utc(2026, 11, 28)).copyWith(
    teams: const Teams(
      home: Team(teamId: 'team-north-001', name: 'North'),
      away: Team(teamId: 'team-south-001', name: 'South'),
    ),
  );
  await database.upsertMatch(historical);
  final document = documentForSavedMatch(
    match: historical,
    principalId: identity.authorityPrincipalId,
    installationId: historicalInstallation,
  );
  expect(document, isNotNull);
  await composition.boundary.prepareWatchOperatedMatch(
    canonicalMessage: document!.canonical,
    phoneOriginDeviceId: identity.originDeviceId,
  );
  final stage = await composition.boundary.durableStore
      .readWatchProvisionStage(historical.matchId);
  final historicalFile = File('${temp.path}/$historicalWatchCorrelationName');
  historicalFile.writeAsStringSync(
    jsonEncode({
      'v': 1,
      'generation': 1,
      'phase': 'pending',
      'requestId': '33333333-3333-4333-8333-333333333333',
      'installationId': historicalInstallation,
      'matchId': historical.matchId,
      'contentHash': stage!.contentHash,
    }),
    flush: true,
  );
  final historicalBridge = WatchProvisionDebugBridge(
    boundary: composition.boundary,
    phoneOriginDeviceId: identity.originDeviceId,
    port: port,
    correlationFile: historicalFile,
  );
  addTearDown(historicalBridge.stop);
  expect(
    await historicalBridge.start(historical.matchId),
    WatchProvisionBridgeDisposition.listening,
  );
  final pairBridge = WatchProvisionDebugBridge(
    boundary: composition.boundary,
    phoneOriginDeviceId: identity.originDeviceId,
    port: port,
    correlationFile: File('${temp.path}/$pairWatchCorrelationName'),
  );
  addTearDown(pairBridge.stop);
  final opened = await openWatchPairing(
    storageRoot: temp,
    database: database,
    boundary: composition.boundary,
    phoneOriginDeviceId: identity.originDeviceId,
    principalId: identity.authorityPrincipalId,
    pairBridge: pairBridge,
    historicalBridge: historicalBridge,
  );
  return _OpenedPairing(
    pairBridge,
    historicalBridge,
    opened,
    historical.matchId,
  );
}

Map<String, Object?> _witness() {
  final bytes = platformBytesV2('00112233445566778899aabbccddeeff')!;
  return {
    'schema': watchWitnessSchema,
    'candidateKind': 'platform_uuid',
    'candidateDigest': encodeDigestHex(candidateDigestV2Bytes(bytes)),
    'digestVersion': watchCandidateDigestVersionV2,
    'evidenceGrade': watchEvidenceUnverifiedDevice,
    'sourceBuilds': 'watch-pair-034',
  };
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
