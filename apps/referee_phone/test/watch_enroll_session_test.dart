import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:forref_match_persistence/watch_identity.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/match/new_match.dart';
import 'package:referee_phone/officiate/watch_enroll_session.dart';
import 'package:referee_phone/officiate/watch_provision_debug_bridge.dart';

const historicalInstallation = '11111111-1111-4111-8111-111111111111';
const currentInstallation = '22222222-2222-4222-8222-222222222222';
const otherInstallation = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
const watchRequest = '44444444-4444-4444-8444-444444444444';
const port = 47241;

void main() {
  late Directory temp;
  late LocalMatchDatabase database;
  late MatchApplicationComposition composition;
  late PhoneCaptureIdentity identity;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('watch_enroll_');
    database = LocalMatchDatabase.memory();
    composition = await MatchApplicationComposition.open(storageRoot: temp);
    identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
  });

  tearDown(() async {
    await composition.close();
    await database.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('enrollment listens on a new match and leaves the historical records',
      () async {
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
    final prepared = await composition.boundary.prepareWatchOperatedMatch(
      canonicalMessage: document!.canonical,
      phoneOriginDeviceId: identity.originDeviceId,
    );
    expect(prepared.state, WatchProvisionState.configPrepared);
    final stage = await composition.boundary.durableStore
        .readWatchProvisionStage(historical.matchId);
    expect(stage, isNotNull);
    expect(
      await composition.boundary.durableStore.readGenerationOneAuthorityRoot(
        historical.matchId,
      ),
      isNull,
    );
    final historicalEvents = await composition.boundary.durableStore
        .readWatchIdentityEvents(historical.matchId);
    expect(historicalEvents.map((event) => event.eventKind), [
      'prepare_intent',
    ]);
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
    final historicalBytes = historicalFile.readAsBytesSync();
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
    expect(historicalFile.readAsBytesSync(), historicalBytes);

    final enrollFile = File('${temp.path}/$enrollWatchCorrelationName');
    final enrollBridge = WatchProvisionDebugBridge(
      boundary: composition.boundary,
      phoneOriginDeviceId: identity.originDeviceId,
      port: port,
      correlationFile: enrollFile,
    );
    addTearDown(enrollBridge.stop);
    final opened = await openWatchEnrollment(
      storageRoot: temp,
      database: database,
      boundary: composition.boundary,
      phoneOriginDeviceId: identity.originDeviceId,
      principalId: identity.authorityPrincipalId,
      installationId: currentInstallation,
      enrollBridge: enrollBridge,
      historicalBridge: historicalBridge,
    );
    expect(opened.status, 'listening');
    expect(opened.historicalUnchanged, isTrue);
    expect(opened.matchId, isNot(historical.matchId));
    expect(opened.before.writerDeviceId, historicalInstallation);
    expect(opened.before.rootPresent, isFalse);
    expect(opened.before.recordToken, 'count=0');
    expect(historicalBridge.isListening, isFalse);
    expect(enrollBridge.isListening, isTrue);
    expect(historicalFile.readAsBytesSync(), historicalBytes);
    expect(enrollFile.existsSync(), isFalse);

    final listening = await _get(enrollBridge);
    expect(listening['disposition'], 'listening');
    expect(listening['writes'], 0);
    expect(listening['matchId'], opened.matchId);

    final bytes = platformBytesV2('00112233445566778899aabbccddeeff')!;
    final witness = {
      'schema': watchWitnessSchema,
      'candidateKind': 'platform_uuid',
      'candidateDigest': encodeDigestHex(candidateDigestV2Bytes(bytes)),
      'digestVersion': watchCandidateDigestVersionV2,
      'evidenceGrade': watchEvidenceUnverifiedDevice,
      'sourceBuilds': 'identity-enroll-033',
    };
    final observed = await _post(enrollBridge, {
      'operation': 'pending',
      'installationId': currentInstallation,
      'requestId': watchRequest,
      'generation': 1,
      'witness': witness,
    });
    expect(observed['disposition'], 'prepared');
    expect(observed['matchId'], opened.matchId);
    final enrollEvents = await composition.boundary.durableStore
        .readWatchIdentityEvents(opened.matchId);
    final witnesses = enrollEvents
        .where((event) => event.eventKind == 'watch_witness_observed')
        .toList();
    expect(witnesses, hasLength(1));
    expect(witnesses.single.observedInstallationId, currentInstallation);
    expect(witnesses.single.digestVersion, watchCandidateDigestVersionV2);
    expect(witnesses.single.protocolRequestId, watchRequest);
    final projection = await composition.boundary.durableStore
        .readWatchIdentityProjection(opened.matchId);
    expect(projection.state, 'witnessed');
    expect(projection.eligibleDigestVersion, watchCandidateDigestVersionV2);

    final replay = await _post(enrollBridge, {
      'operation': 'pending',
      'installationId': currentInstallation,
      'requestId': watchRequest,
      'generation': 1,
      'witness': witness,
    });
    expect(replay['disposition'], 'prepared');
    expect(
      (await composition.boundary.durableStore
              .readWatchIdentityEvents(opened.matchId))
          .where((event) => event.eventKind == 'watch_witness_observed'),
      hasLength(1),
    );

    final conflictedWitness = Map<String, Object?>.from(witness);
    conflictedWitness['digestVersion'] = watchCandidateDigestVersion;
    final conflicted = await _post(enrollBridge, {
      'operation': 'pending',
      'installationId': currentInstallation,
      'requestId': watchRequest,
      'generation': 1,
      'witness': conflictedWitness,
    });
    expect(conflicted['disposition'], 'prepared');
    final afterConflict = await composition.boundary.durableStore
        .readWatchIdentityEvents(opened.matchId);
    expect(
      afterConflict.where(
        (event) => event.eventKind == 'watch_witness_observed',
      ),
      hasLength(1),
    );
    expect(
      afterConflict
          .where((event) => event.eventKind == 'watch_witness_observed')
          .single
          .digestVersion,
      watchCandidateDigestVersionV2,
    );

    final other = await _post(enrollBridge, {
      'operation': 'pending',
      'installationId': otherInstallation,
      'requestId': '55555555-5555-4555-8555-555555555555',
      'generation': 1,
      'witness': witness,
    });
    expect(other['disposition'], 'refused');
    expect(other['reason'], 'recovery-required');
    expect(other.containsKey('canonical'), isFalse);
    final afterOther = await composition.boundary.durableStore
        .readWatchIdentityEvents(opened.matchId);
    expect(
      afterOther.where((event) => event.eventKind == 'watch_witness_observed'),
      hasLength(1),
    );
    final enrollStage = await composition.boundary.durableStore
        .readWatchProvisionStage(opened.matchId);
    expect(enrollStage?.writerDeviceId, currentInstallation);

    final historicalAfter = await composition.boundary.durableStore
        .readWatchProvisionStage(historical.matchId);
    expect(historicalAfter?.writerDeviceId, stage.writerDeviceId);
    expect(historicalAfter?.contentHash, stage.contentHash);
    expect(historicalAfter?.principalId, stage.principalId);
    expect(historicalAfter?.canonical, stage.canonical);
    expect(historicalAfter?.stage, stage.stage);
    expect(
      await composition.boundary.durableStore.readGenerationOneAuthorityRoot(
        historical.matchId,
      ),
      isNull,
    );
    expect(
      await composition.boundary.durableStore.readCommittedForMatch(
        historical.matchId,
      ),
      isEmpty,
    );
    final historicalEventsAfter = await composition.boundary.durableStore
        .readWatchIdentityEvents(historical.matchId);
    expect(
      historicalEventsAfter.map((event) => event.eventId),
      historicalEvents.map((event) => event.eventId),
    );
    expect(historicalFile.readAsBytesSync(), historicalBytes);
    final storedHistorical = await database.getMatch(historical.matchId);
    expect(
      storedHistorical?.updatedAt.toUtc().microsecondsSinceEpoch,
      historical.updatedAt.toUtc().microsecondsSinceEpoch,
    );

    final matchesBefore = (await database.listNewestFirst()).length;
    final again = await openWatchEnrollment(
      storageRoot: temp,
      database: database,
      boundary: composition.boundary,
      phoneOriginDeviceId: identity.originDeviceId,
      principalId: identity.authorityPrincipalId,
      installationId: currentInstallation,
      enrollBridge: enrollBridge,
      historicalBridge: historicalBridge,
    );
    expect(again.status, 'reused');
    expect(again.matchId, opened.matchId);
    expect(again.historicalUnchanged, isTrue);
    expect((await database.listNewestFirst()).length, matchesBefore);
    expect(historicalFile.readAsBytesSync(), historicalBytes);
    expect(enrollFile.readAsStringSync(),
        isNot(historicalFile.readAsStringSync()));
    final described = await describeWatchEnrollment(
      storageRoot: temp,
      store: composition.boundary.durableStore,
      database: database,
      installationId: currentInstallation,
    );
    expect(described, contains('eligible=1'));
    expect(described, contains('witnesses=1'));
    expect(described, contains('match=${historical.matchId}'));
    expect(described, contains('writer=$historicalInstallation'));
    expect(described.contains(stage.canonical), isFalse);
  });

  test('a corrupt enroll file and a blank installation do not change history',
      () async {
    final historicalFile = File('${temp.path}/$historicalWatchCorrelationName');
    const historicalBody = '{"matchId":"historical-match","kept":true}';
    historicalFile.writeAsStringSync(historicalBody, flush: true);
    final enrollFile = File('${temp.path}/$enrollWatchCorrelationName');
    enrollFile.writeAsStringSync('{', flush: true);
    final enrollBridge = WatchProvisionDebugBridge(
      boundary: composition.boundary,
      phoneOriginDeviceId: identity.originDeviceId,
      port: port,
      correlationFile: enrollFile,
    );
    addTearDown(enrollBridge.stop);
    final opened = await openWatchEnrollment(
      storageRoot: temp,
      database: database,
      boundary: composition.boundary,
      phoneOriginDeviceId: identity.originDeviceId,
      principalId: identity.authorityPrincipalId,
      installationId: currentInstallation,
      enrollBridge: enrollBridge,
    );
    expect(opened.status, 'enroll-correlation-corrupt');
    expect(opened.historicalUnchanged, isTrue);
    expect(enrollFile.readAsStringSync(), '{');
    expect(historicalFile.readAsStringSync(), historicalBody);
    expect(await database.listNewestFirst(), isEmpty);

    final blankBridge = WatchProvisionDebugBridge(
      boundary: composition.boundary,
      phoneOriginDeviceId: identity.originDeviceId,
      port: port + 1,
      correlationFile: File('${temp.path}/forref_watch_enroll_blank.json'),
    );
    addTearDown(blankBridge.stop);
    final blank = await openWatchEnrollment(
      storageRoot: temp,
      database: database,
      boundary: composition.boundary,
      phoneOriginDeviceId: identity.originDeviceId,
      principalId: identity.authorityPrincipalId,
      installationId: ' ',
      enrollBridge: blankBridge,
    );
    expect(blank.status, 'installation');
    expect(historicalFile.readAsStringSync(), historicalBody);
    expect(await database.listNewestFirst(), isEmpty);
    final source =
        File('lib/officiate/watch_enroll_session.dart').readAsStringSync();
    expect(source.contains('writeAsString'), isFalse);
    expect(source.contains('deleteSync'), isFalse);
    expect(source.contains('cancelPrepared'), isFalse);
    expect(source.contains(historicalWatchCorrelationName), isTrue);
    expect(source.contains(enrollWatchCorrelationName), isTrue);
  });

  test('a matching enrollment request observes the current writer', () async {
    final logs = _capturePrint();
    final opened = await _openEnrollment(temp, database, composition, identity);
    final response = await _post(opened.bridge, {
      'operation': 'pending',
      'installationId': currentInstallation,
      'requestId': watchRequest,
      'generation': 1,
      'witness': _witness(),
    });
    expect(response['disposition'], 'prepared');
    final line = _writerLine(logs);
    expect(line, contains('equal=1'));
    expect(line, contains('mismatch-at=none'));
    expect(line, contains('branch=current-writer'));
    expect(line, contains('observe=1'));
    expect(line, contains('disposition=prepared'));
    expect(line, contains('inspect-changed=none'));
    expect(line, contains('namespace=enroll'));
    expect(line, contains('stage-match=${opened.matchId}'));
    expect(line, contains('request-installation=$currentInstallation'));
    expect(line, contains('stored-writer=$currentInstallation'));
    expect(line, contains('column-canonical=1'));
    expect(line.contains('Enroll Home'), isFalse);
    expect(line.contains('forref.watch-provision'), isFalse);
    final events = await composition.boundary.durableStore
        .readWatchIdentityEvents(opened.matchId);
    expect(
      events.where((event) => event.eventKind == 'watch_witness_observed'),
      hasLength(1),
    );
    final stage = await composition.boundary.durableStore
        .readWatchProvisionStage(opened.matchId);
    expect(stage?.writerDeviceId, currentInstallation);
    final inspection = await composition.boundary.inspectWatchProvision(
      matchId: opened.matchId,
      requestedContentHash: stage!.contentHash,
      requestedWriterDeviceId: currentInstallation,
      requestedPrincipalId: stage.principalId,
    );
    expect(inspection.changed, isEmpty);
    expect(
      await composition.boundary.durableStore.readGenerationOneAuthorityRoot(
        opened.matchId,
      ),
      isNull,
    );
  });

  test(
      'a mismatched request is another installation and Inspect still matches the stored writer',
      () async {
    final logs = _capturePrint();
    final opened = await _openEnrollment(temp, database, composition, identity);
    final response = await _post(opened.bridge, {
      'operation': 'pending',
      'installationId': otherInstallation,
      'requestId': '55555555-5555-4555-8555-555555555555',
      'generation': 1,
      'witness': _witness(),
    });
    expect(response['disposition'], 'refused');
    expect(response['reason'], 'installation');
    expect(response.containsKey('canonical'), isFalse);
    final line = _writerLine(logs);
    expect(line, contains('equal=0'));
    expect(line, contains('mismatch-at=0'));
    expect(line, contains('branch=other-installation'));
    expect(line, contains('observe=0'));
    expect(line, contains('disposition=refused'));
    expect(line, contains('reason=installation'));
    expect(line, contains('inspect-changed=writer-device'));
    expect(line, contains('request-installation=$otherInstallation'));
    expect(line, contains('stored-writer=$currentInstallation'));
    expect(line, contains('mismatch-request-unit=61'));
    expect(line, contains('mismatch-stored-unit=32'));
    expect(line, contains('namespace=enroll'));
    expect(line.contains('Enroll Home'), isFalse);
    final events = await composition.boundary.durableStore
        .readWatchIdentityEvents(opened.matchId);
    expect(
      events.where((event) => event.eventKind == 'watch_witness_observed'),
      isEmpty,
    );
    final stage = await composition.boundary.durableStore
        .readWatchProvisionStage(opened.matchId);
    expect(stage?.writerDeviceId, currentInstallation);
    final typed = await composition.boundary.inspectWatchProvision(
      matchId: opened.matchId,
      requestedContentHash: stage!.contentHash,
      requestedWriterDeviceId: currentInstallation,
      requestedPrincipalId: stage.principalId,
    );
    expect(typed.changed, isEmpty);
    final requested = await composition.boundary.inspectWatchProvision(
      matchId: opened.matchId,
      requestedContentHash: stage.contentHash,
      requestedWriterDeviceId: otherInstallation,
      requestedPrincipalId: stage.principalId,
    );
    expect(requested.changed, ['writer-device']);
    expect(requested.writerDeviceId, currentInstallation);
    expect(
      await composition.boundary.durableStore.readGenerationOneAuthorityRoot(
        opened.matchId,
      ),
      isNull,
    );
  });

  test('a second enrollment open does not retarget a listening writer',
      () async {
    const staleInstallation = '33333333-3333-4333-8333-333333333333';
    final opened = await _openEnrollment(temp, database, composition, identity);
    final historicalFile = File('${temp.path}/$historicalWatchCorrelationName');
    final historicalBytes = historicalFile.readAsBytesSync();
    final again = await openWatchEnrollment(
      storageRoot: temp,
      database: database,
      boundary: composition.boundary,
      phoneOriginDeviceId: identity.originDeviceId,
      principalId: identity.authorityPrincipalId,
      installationId: staleInstallation,
      enrollBridge: opened.bridge,
      historicalBridge: opened.historical,
    );
    expect(again.status, 'enroll-writer');
    expect(again.matchId, opened.matchId);
    expect(opened.bridge.isListening, isTrue);
    expect(historicalFile.readAsBytesSync(), historicalBytes);
    var stage = await composition.boundary.durableStore
        .readWatchProvisionStage(opened.matchId);
    expect(stage?.writerDeviceId, currentInstallation);

    final logs = _capturePrint();
    final refused = await _post(opened.bridge, {
      'operation': 'pending',
      'installationId': staleInstallation,
      'requestId': '66666666-6666-4666-8666-666666666666',
      'generation': 1,
      'witness': _witness(),
    });
    expect(refused['disposition'], 'refused');
    expect(refused['reason'], 'installation');
    final refusedLine = _writerLine(logs);
    expect(refusedLine, contains('branch=other-installation'));
    expect(refusedLine, contains('observe=0'));
    expect(refusedLine, contains('stored-writer=$currentInstallation'));
    expect(refusedLine, contains('request-installation=$staleInstallation'));
    stage = await composition.boundary.durableStore
        .readWatchProvisionStage(opened.matchId);
    expect(stage?.writerDeviceId, currentInstallation);

    logs.clear();
    final observed = await _post(opened.bridge, {
      'operation': 'pending',
      'installationId': currentInstallation,
      'requestId': watchRequest,
      'generation': 1,
      'witness': _witness(),
    });
    expect(observed['disposition'], 'prepared');
    final observedLine = _writerLine(logs);
    expect(observedLine, contains('branch=current-writer'));
    expect(observedLine, contains('observe=1'));
    expect(observedLine, contains('equal=1'));
    final events = await composition.boundary.durableStore
        .readWatchIdentityEvents(opened.matchId);
    expect(
      events.where((event) => event.eventKind == 'watch_witness_observed'),
      hasLength(1),
    );
    stage = await composition.boundary.durableStore
        .readWatchProvisionStage(opened.matchId);
    expect(stage?.writerDeviceId, currentInstallation);
    expect(historicalFile.readAsBytesSync(), historicalBytes);
    expect(
      await composition.boundary.durableStore.readGenerationOneAuthorityRoot(
        opened.matchId,
      ),
      isNull,
    );
  });
}

class _OpenedEnrollment {
  const _OpenedEnrollment(this.bridge, this.historical, this.matchId);
  final WatchProvisionDebugBridge bridge;
  final WatchProvisionDebugBridge historical;
  final String matchId;
}

Future<_OpenedEnrollment> _openEnrollment(
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
  final enrollBridge = WatchProvisionDebugBridge(
    boundary: composition.boundary,
    phoneOriginDeviceId: identity.originDeviceId,
    port: port,
    correlationFile: File('${temp.path}/$enrollWatchCorrelationName'),
  );
  addTearDown(enrollBridge.stop);
  final opened = await openWatchEnrollment(
    storageRoot: temp,
    database: database,
    boundary: composition.boundary,
    phoneOriginDeviceId: identity.originDeviceId,
    principalId: identity.authorityPrincipalId,
    installationId: currentInstallation,
    enrollBridge: enrollBridge,
    historicalBridge: historicalBridge,
  );
  expect(opened.status, 'listening');
  expect(opened.historicalUnchanged, isTrue);
  return _OpenedEnrollment(enrollBridge, historicalBridge, opened.matchId);
}

List<String> _capturePrint() {
  final logs = <String>[];
  final previous = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) logs.add(message);
  };
  addTearDown(() {
    debugPrint = previous;
  });
  return logs;
}

String _writerLine(List<String> logs) {
  return logs.singleWhere((line) => line.contains('tx=writer-compare'));
}

Map<String, Object?> _witness() {
  final bytes = platformBytesV2('00112233445566778899aabbccddeeff')!;
  return {
    'schema': watchWitnessSchema,
    'candidateKind': 'platform_uuid',
    'candidateDigest': encodeDigestHex(candidateDigestV2Bytes(bytes)),
    'digestVersion': watchCandidateDigestVersionV2,
    'evidenceGrade': watchEvidenceUnverifiedDevice,
    'sourceBuilds': 'identity-enroll-033',
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

Future<Map<String, Object?>> _get(WatchProvisionDebugBridge bridge) async {
  final client = HttpClient();
  try {
    final request =
        await client.getUrl(Uri.parse('http://${bridge.loopbackEndpoint}/'));
    final response = await request.close();
    final text = await utf8.decodeStream(response);
    return (jsonDecode(text) as Map).cast<String, Object?>();
  } finally {
    client.close(force: true);
  }
}
