import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/match/new_match.dart';
import 'package:referee_phone/officiate/watch_enroll_session.dart';
import 'package:referee_phone/officiate/watch_match_transfer.dart';
import 'package:referee_phone/officiate/watch_pairing_session.dart';
import 'package:referee_phone/officiate/watch_provision_debug_bridge.dart';
import 'package:referee_phone/officiate/watch_sync_coordinator.dart';
import 'package:referee_phone/officiate/watch_transfer_registry.dart';

const historicalInstallation = '11111111-1111-4111-8111-111111111111';
const watchInstallation = '22222222-2222-4222-8222-222222222222';
const otherInstallation = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
const watchRequest = '44444444-4444-4444-8444-444444444444';
const port = 47271;

void main() {
  late Directory temp;
  late LocalMatchDatabase database;
  late MatchApplicationComposition composition;
  late PhoneCaptureIdentity identity;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('watch_transfer_');
    database = LocalMatchDatabase.memory();
    composition = await MatchApplicationComposition.open(storageRoot: temp);
    identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
  });

  tearDown(() async {
    await composition.close();
    await database.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('a saved 45-minute match is verified only after the watch read-back',
      () async {
    final paired = await _pair(temp, database, composition, identity);
    final historicalBefore =
        await _stage(composition, paired.historicalMatchId);
    final match = _officiating();
    await database.upsertMatch(match);
    final document = documentForSavedMatch(
      match: match,
      principalId: identity.authorityPrincipalId,
      installationId: watchInstallation,
    );
    expect(document, isNotNull);
    expect(document!.halfDurationMs, 45 * 60 * 1000);
    expect(document.homeName, 'North');
    expect(document.awayName, 'South');

    final opened = await _send(temp, database, composition, identity, match);
    expect(opened.open.status, 'waiting');
    expect(opened.open.historicalUnchanged, isTrue);
    final stage = await _stage(composition, match.matchId);
    expect(stage?.writerDeviceId, watchInstallation);
    expect(stage?.stage, 'CONFIG_PREPARED');
    expect(stage?.contentHash, document.contentHash);
    expect(stage?.canonical, contains(match.matchId));
    expect(
      await composition.boundary.durableStore
          .readGenerationOneAuthorityRoot(match.matchId),
      isNull,
    );

    final pending = await _post(opened.bridge, {
      'operation': 'pending',
      'installationId': watchInstallation,
      'requestId': watchRequest,
      'generation': 1,
      'witness': _witness(),
    });
    expect(pending['disposition'], 'prepared');
    expect(pending['matchId'], match.matchId);
    expect(pending['contentHash'], document.contentHash);
    expect(pending['canonical'], document.canonical);
    expect(opened.bridge.transferResult?.code, 'syncing');

    final verified = await _post(opened.bridge, {
      'operation': 'verified',
      'type': 'WATCH_PROVISION_VERIFIED_V1',
      'readBack': true,
      'installationId': watchInstallation,
      'writerDeviceId': watchInstallation,
      'requestId': watchRequest,
      'matchId': match.matchId,
      'contentHash': document.contentHash,
      'generation': 1,
    });
    expect(verified['disposition'], 'verified');
    expect(verified['homeName'], 'North');
    expect(verified['awayName'], 'South');
    expect(verified['halfDurationMs'], 45 * 60 * 1000);
    expect(verified['durable'], isFalse);
    expect(opened.bridge.transferResult?.code, 'verified');
    expect(
      (await composition.boundary.durableStore
              .readCommittedForMatchWithQuarantine(match.matchId))
          .records,
      isEmpty,
    );

    final replay = await _post(opened.bridge, {
      'operation': 'verified',
      'type': 'WATCH_PROVISION_VERIFIED_V1',
      'readBack': true,
      'installationId': watchInstallation,
      'writerDeviceId': watchInstallation,
      'requestId': watchRequest,
      'matchId': match.matchId,
      'contentHash': document.contentHash,
      'generation': 1,
    });
    expect(replay['reason'], 'replay');
    expect(opened.bridge.transferResult?.code, 'replay');
    expect(
      (await composition.boundary.durableStore
              .readWatchIdentityEvents(match.matchId))
          .where((event) => event.eventKind == 'watch_witness_observed'),
      hasLength(1),
    );
    final keptAfterReplay = await _stage(composition, match.matchId);
    expect(keptAfterReplay?.writerDeviceId, stage?.writerDeviceId);
    expect(keptAfterReplay?.contentHash, stage?.contentHash);
    expect(
      await composition.boundary.durableStore
          .readGenerationOneAuthorityRoot(match.matchId),
      isNull,
    );

    final other = await _post(opened.bridge, {
      'operation': 'pending',
      'installationId': otherInstallation,
      'requestId': '55555555-5555-4555-8555-555555555555',
      'generation': 1,
      'witness': _witness(),
    });
    expect(other['disposition'], 'refused');
    expect(opened.bridge.transferResult?.code, 'writer-kept');
    expect((await _stage(composition, match.matchId))?.writerDeviceId,
        watchInstallation);

    final historicalAfter = await _stage(composition, paired.historicalMatchId);
    expect(historicalAfter?.writerDeviceId, historicalBefore?.writerDeviceId);
    expect(historicalAfter?.contentHash, historicalBefore?.contentHash);
    expect((await _stage(composition, paired.pairMatchId))?.writerDeviceId,
        watchInstallation);

    await opened.bridge.stop();
    final restarted = WatchProvisionDebugBridge(
      boundary: composition.boundary,
      phoneOriginDeviceId: identity.originDeviceId,
      port: port,
      correlationFile: File('${temp.path}/$transferWatchCorrelationName'),
    );
    addTearDown(restarted.stop);
    final again = await sendMatchToWatch(
      storageRoot: temp,
      database: database,
      boundary: composition.boundary,
      phoneOriginDeviceId: identity.originDeviceId,
      principalId: identity.authorityPrincipalId,
      match: match,
      transferBridge: restarted,
    );
    expect(again.status, 'replay');
    expect(again.historicalUnchanged, isTrue);
    final restartedStage = await _stage(composition, match.matchId);
    expect(restartedStage?.contentHash, stage?.contentHash);
    expect(restartedStage?.writerDeviceId, watchInstallation);
  });

  test('a different configuration, a live match, and the pairing fixture stop',
      () async {
    await _pair(temp, database, composition, identity);
    final match = _officiating();
    await database.upsertMatch(match);
    final otherDocument = documentForSavedMatch(
      match: match.copyWith(
        teams: const Teams(
          home: Team(teamId: 'team-north-001', name: 'North'),
          away: Team(teamId: 'team-south-001', name: 'Other'),
        ),
      ),
      principalId: identity.authorityPrincipalId,
      installationId: watchInstallation,
    );
    await composition.boundary.prepareWatchOperatedMatch(
      canonicalMessage: otherDocument!.canonical,
      phoneOriginDeviceId: identity.originDeviceId,
    );
    final stored = await _stage(composition, match.matchId);
    final conflict = await _send(temp, database, composition, identity, match);
    expect(conflict.open.status, 'conflict');
    final afterConflict = await _stage(composition, match.matchId);
    expect(afterConflict?.contentHash, stored?.contentHash);
    expect(afterConflict?.writerDeviceId, stored?.writerDeviceId);

    final live = await _send(
      temp,
      database,
      composition,
      identity,
      match.copyWith(status: MatchStatus.live),
    );
    expect(live.open.status, 'started');

    final pairs = await database.listNewestFirst();
    final fixture = pairs.firstWhere(
      (item) => item.teams.home.teamId == pairHomeTeamId,
    );
    final refused = await _send(temp, database, composition, identity, fixture);
    expect(refused.open.status, 'fixture');

    final section = File(
      'lib/features/settings/watch_provision_debug_section.dart',
    ).readAsStringSync();
    final send = section.substring(
      section.indexOf('Future<void> _sendToWatch()'),
      section.indexOf('void _onTransfer()'),
    );
    expect(send.contains('_installation'), isFalse);
    expect(send.contains('sendMatchToWatch'), isTrue);
    expect(section.contains('resumeTransfer()'), isTrue);
    expect(section.contains('SUBMIT_WATCH_LOCK_V1'), isFalse);
    expect(section.contains('_pairBridge?.stop()'), isFalse);
    expect(section.contains('_transferBridge?.stop()'), isFalse);
    expect(section.contains('detachUi()'), isTrue);
  });

  test('three saved matches stay verified and the listener survives navigation',
      () async {
    await _pair(temp, database, composition, identity);
    final sync = WatchSyncCoordinator();
    addTearDown(sync.close);
    sync.bind(
      storageRoot: temp,
      boundary: composition.boundary,
      database: database,
      phoneOriginDeviceId: identity.originDeviceId,
      principalId: identity.authorityPrincipalId,
    );
    final bridge = sync.requireTransferBridge();
    final matches = [
      _named(DateTime.utc(2026, 11, 28, 13), 'Alpha', 'Red'),
      _named(DateTime.utc(2026, 11, 28, 14), 'Beta', 'Blue'),
      _named(DateTime.utc(2026, 11, 28, 15), 'Gamma', 'Gold'),
    ];
    for (final match in matches) {
      await database.upsertMatch(match);
      final opened = await sendMatchToWatch(
        storageRoot: temp,
        database: database,
        boundary: composition.boundary,
        phoneOriginDeviceId: identity.originDeviceId,
        principalId: identity.authorityPrincipalId,
        match: match,
        transferBridge: bridge,
        pairBridge: sync.pairBridge,
      );
      expect(opened.status, 'waiting');
      final document = documentForSavedMatch(
        match: match,
        principalId: identity.authorityPrincipalId,
        installationId: watchInstallation,
      )!;
      final hinted = await _post(bridge, {
        'operation': 'pending',
        'installationId': watchInstallation,
        'requestId': watchRequest,
        'matchId': 'previous-match',
        'generation': 1,
        'witness': _witness(),
      });
      expect(hinted['successor'], isTrue);
      expect(hinted['matchId'], match.matchId);
      final pending = await _post(bridge, {
        'operation': 'pending',
        'installationId': watchInstallation,
        'requestId': '55555555-5555-4555-8555-555555555555',
        'generation': 1,
        'witness': _witness(),
      });
      expect(pending['disposition'], 'prepared');
      expect(pending['contentHash'], document.contentHash);
      expect(bridge.transferResult?.code, 'syncing');
      final verified = await _post(bridge, {
        'operation': 'verified',
        'type': 'WATCH_PROVISION_VERIFIED_V1',
        'readBack': true,
        'installationId': watchInstallation,
        'writerDeviceId': watchInstallation,
        'requestId': '55555555-5555-4555-8555-555555555555',
        'matchId': match.matchId,
        'contentHash': document.contentHash,
        'generation': 1,
      });
      expect(verified['disposition'], 'verified');
      expect(verified['homeName'], match.teams.home.name);
      expect(verified['durable'], isFalse);
      expect(
        await composition.boundary.durableStore
            .readGenerationOneAuthorityRoot(match.matchId),
        isNull,
      );
    }
    sync.detachUi();
    final registry = WatchTransferRegistry(
      File('${temp.path}/${WatchTransferRegistry.fileName}'),
    ).read();
    expect(registry, isNotNull);
    expect(registry!.map((entry) => entry.homeName).toSet(), {
      'Alpha',
      'Beta',
      'Gamma',
    });
    final again = await sendMatchToWatch(
      storageRoot: temp,
      database: database,
      boundary: composition.boundary,
      phoneOriginDeviceId: identity.originDeviceId,
      principalId: identity.authorityPrincipalId,
      match: matches.first,
      transferBridge: bridge,
      pairBridge: sync.pairBridge,
    );
    expect(again.status, 'replay');
    final replay = await _post(bridge, {
      'operation': 'verified',
      'type': 'WATCH_PROVISION_VERIFIED_V1',
      'readBack': true,
      'installationId': watchInstallation,
      'writerDeviceId': watchInstallation,
      'requestId': '55555555-5555-4555-8555-555555555555',
      'matchId': matches.first.matchId,
      'contentHash': documentForSavedMatch(
        match: matches.first,
        principalId: identity.authorityPrincipalId,
        installationId: watchInstallation,
      )!
          .contentHash,
      'generation': 1,
    });
    expect(replay['reason'], 'replay');
    expect(
      WatchTransferRegistry(
        File('${temp.path}/${WatchTransferRegistry.fileName}'),
      ).read(),
      hasLength(3),
    );
    final changed = matches.first.copyWith(
      teams: const Teams(
        home: Team(teamId: 'team-north-001', name: 'Alpha'),
        away: Team(teamId: 'team-other-001', name: 'Other'),
      ),
    );
    await database.upsertMatch(changed);
    final conflicted = await sendMatchToWatch(
      storageRoot: temp,
      database: database,
      boundary: composition.boundary,
      phoneOriginDeviceId: identity.originDeviceId,
      principalId: identity.authorityPrincipalId,
      match: changed,
      transferBridge: bridge,
      pairBridge: sync.pairBridge,
    );
    expect(conflicted.status, 'conflict');
    expect(
      WatchTransferRegistry(
        File('${temp.path}/${WatchTransferRegistry.fileName}'),
      )
          .read()!
          .singleWhere((entry) => entry.matchId == changed.matchId)
          .homeName,
      'Alpha',
    );
    final still = await _post(bridge, {
      'operation': 'pending',
      'installationId': watchInstallation,
      'requestId': '66666666-6666-4666-8666-666666666666',
      'generation': 1,
      'witness': _witness(),
    });
    expect(still['disposition'], 'prepared');
    await sync.close();
  });
}

Match _named(DateTime kickoff, String home, String away) {
  return newLocalMatch(kickoff).copyWith(
    teams: Teams(
      home: Team(teamId: 'team-${home.toLowerCase()}', name: home),
      away: Team(teamId: 'team-${away.toLowerCase()}', name: away),
    ),
  );
}

Match _officiating() {
  return newLocalMatch(DateTime.utc(2026, 11, 28, 12)).copyWith(
    teams: const Teams(
      home: Team(teamId: 'team-north-001', name: 'North'),
      away: Team(teamId: 'team-south-001', name: 'South'),
    ),
  );
}

Future<WatchProvisionPhoneStage?> _stage(
  MatchApplicationComposition composition,
  String matchId,
) {
  return composition.boundary.durableStore.readWatchProvisionStage(matchId);
}

class _Paired {
  const _Paired(this.historicalMatchId, this.pairMatchId);
  final String historicalMatchId;
  final String pairMatchId;
}

Future<_Paired> _pair(
  Directory temp,
  LocalMatchDatabase database,
  MatchApplicationComposition composition,
  PhoneCaptureIdentity identity,
) async {
  final historical = newLocalMatch(DateTime.utc(2026, 11, 28)).copyWith(
    teams: const Teams(
      home: Team(teamId: 'team-hist-001', name: 'Hist Home'),
      away: Team(teamId: 'team-hist-002', name: 'Hist Away'),
    ),
  );
  await database.upsertMatch(historical);
  final document = documentForSavedMatch(
    match: historical,
    principalId: identity.authorityPrincipalId,
    installationId: historicalInstallation,
  );
  await composition.boundary.prepareWatchOperatedMatch(
    canonicalMessage: document!.canonical,
    phoneOriginDeviceId: identity.originDeviceId,
  );
  final stage = await _stage(composition, historical.matchId);
  File('${temp.path}/$historicalWatchCorrelationName').writeAsStringSync(
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
    correlationFile: File('${temp.path}/$historicalWatchCorrelationName'),
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
  expect(opened.status, 'waiting');
  final posted = await _post(pairBridge, {
    'operation': 'pending',
    'installationId': watchInstallation,
    'requestId': watchRequest,
    'generation': 1,
    'witness': _witness(),
  });
  expect(posted['disposition'], 'prepared');
  await pairBridge.stop();
  return _Paired(historical.matchId, opened.matchId);
}

Future<({WatchTransferOpen open, WatchProvisionDebugBridge bridge})> _send(
  Directory temp,
  LocalMatchDatabase database,
  MatchApplicationComposition composition,
  PhoneCaptureIdentity identity,
  Match match,
) async {
  final bridge = WatchProvisionDebugBridge(
    boundary: composition.boundary,
    phoneOriginDeviceId: identity.originDeviceId,
    port: port,
    correlationFile: File('${temp.path}/$transferWatchCorrelationName'),
  );
  addTearDown(bridge.stop);
  final opened = await sendMatchToWatch(
    storageRoot: temp,
    database: database,
    boundary: composition.boundary,
    phoneOriginDeviceId: identity.originDeviceId,
    principalId: identity.authorityPrincipalId,
    match: match,
    transferBridge: bridge,
  );
  return (open: opened, bridge: bridge);
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
