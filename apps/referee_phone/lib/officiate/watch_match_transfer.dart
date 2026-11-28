import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/match_application/match_application_boundary.dart';
import 'package:referee_phone/officiate/watch_enroll_session.dart';
import 'package:referee_phone/officiate/watch_pairing_session.dart';
import 'package:referee_phone/officiate/watch_provision_debug_bridge.dart';
import 'package:referee_phone/officiate/watch_transfer_registry.dart';

/// Phone correlation for a match sent to an already paired watch.
const String transferWatchCorrelationName =
    'forref_watch_transfer_correlation_v1.json';

/// Result of Send to Watch. The watch installation comes from pairing.
class WatchTransferOpen {
  const WatchTransferOpen({
    required this.status,
    required this.matchId,
    required this.historicalUnchanged,
    this.homeName = '',
    this.awayName = '',
    this.halfDurationMs = 0,
    this.contentHash = '',
  });

  final String status;
  final String matchId;
  final bool historicalUnchanged;
  final String homeName;
  final String awayName;
  final int halfDurationMs;
  final String contentHash;

  String get line => 'FORREF_TRANSFER tx=open status=$status match=$matchId '
      'same=${historicalUnchanged ? 1 : 0}';
}

/// Arms a saved match for the paired watch and waits for its read-back.
///
/// A pairing fixture is not accepted. An existing writer is not replaced.
/// Lock and activation are not called.
Future<WatchTransferOpen> sendMatchToWatch({
  required Directory storageRoot,
  required LocalMatchDatabase database,
  required MatchApplicationBoundary boundary,
  required String phoneOriginDeviceId,
  required String principalId,
  required Match match,
  required WatchProvisionDebugBridge transferBridge,
  WatchProvisionDebugBridge? historicalBridge,
  WatchProvisionDebugBridge? pairBridge,
  WatchProvisionDebugBridge? enrollBridge,
}) async {
  final before = await readWatchEnrollmentLedger(
    storageRoot: storageRoot,
    store: boundary.durableStore,
    database: database,
  );
  final pairBefore = await _pairSnapshot(storageRoot, boundary);

  Future<WatchTransferOpen> finish(String status, String matchId) async {
    final after = await readWatchEnrollmentLedger(
      storageRoot: storageRoot,
      store: boundary.durableStore,
      database: database,
    );
    final pairAfter = await _pairSnapshot(storageRoot, boundary);
    final opened = WatchTransferOpen(
      status: status,
      matchId: matchId,
      historicalUnchanged: before.sameAs(after) && pairBefore == pairAfter,
      homeName: transferBridge.transferResult?.homeName ?? '',
      awayName: transferBridge.transferResult?.awayName ?? '',
      halfDurationMs: transferBridge.transferResult?.halfDurationMs ?? 0,
      contentHash: transferBridge.transferResult?.contentHash ?? '',
    );
    debugPrint(opened.line);
    return opened;
  }

  if (!kDebugMode) return finish('debug', '');
  if (principalId.isEmpty || phoneOriginDeviceId.isEmpty) {
    return finish('principal', '');
  }
  final bridgePath = transferBridge.correlationFile?.path ?? '';
  if (!bridgePath.endsWith(transferWatchCorrelationName)) {
    return finish('namespace', '');
  }
  if (before.fileStatus == 'unreadable') {
    return finish('historical-unreadable', '');
  }
  if (!transferBridge.correlationIntact) {
    return finish('transfer-correlation-corrupt', '');
  }

  final paired = await readPairedWatch(
    storageRoot: storageRoot,
    database: database,
    boundary: boundary,
  );
  if (paired == null) return finish('unpaired', '');
  if (match.matchId == paired.matchId ||
      match.matchId == before.matchId ||
      _fixture(match)) {
    return finish('fixture', match.matchId);
  }
  if (match.status != MatchStatus.setup && match.status != MatchStatus.ready) {
    return finish('started', match.matchId);
  }
  final root =
      await boundary.durableStore.readGenerationOneAuthorityRoot(match.matchId);
  if (root != null) return finish('authority', match.matchId);
  final committed = await boundary.durableStore
      .readCommittedForMatchWithQuarantine(match.matchId);
  if (committed.records.isNotEmpty) return finish('records', match.matchId);

  final document = documentForSavedMatch(
    match: match,
    principalId: principalId,
    installationId: paired.installationId,
  );
  if (document == null) return finish('invalid', match.matchId);
  final registry = WatchTransferRegistry(
    File('${storageRoot.path}/${WatchTransferRegistry.fileName}'),
  );
  if (registry.file.existsSync() && registry.read() == null) {
    return finish('registry-corrupt', match.matchId);
  }
  final prior = registry.find(match.matchId);
  if (prior != null &&
      prior.contentHash.isNotEmpty &&
      prior.contentHash != document.contentHash) {
    return finish('conflict', match.matchId);
  }
  final storedHash = transferBridge.boundContentHash ?? '';
  if (transferBridge.matchId == match.matchId &&
      storedHash.isNotEmpty &&
      storedHash != document.contentHash) {
    return finish('conflict', match.matchId);
  }
  if (transferBridge.matchId != null &&
      transferBridge.matchId != match.matchId) {
    final released = await transferBridge.releaseForNextMatch();
    if (!released) return finish('storage', match.matchId);
  }

  final existing =
      await boundary.durableStore.readWatchProvisionStage(match.matchId);
  if (existing != null) {
    if (existing.writerDeviceId != paired.installationId) {
      return finish('writer-kept', match.matchId);
    }
    if (existing.contentHash != document.contentHash ||
        existing.principalId != principalId ||
        existing.stage != 'CONFIG_PREPARED') {
      return finish('conflict', match.matchId);
    }
  } else {
    final prepared = await transferBridge.prepareSavedMatch(
      match: match,
      installationId: paired.installationId,
      principalId: principalId,
    );
    if (prepared.state != WatchProvisionState.configPrepared ||
        prepared.contentHash != document.contentHash) {
      return finish('conflict', match.matchId);
    }
  }

  if (historicalBridge != null &&
      !identical(historicalBridge, transferBridge)) {
    await historicalBridge.stop();
  }
  if (pairBridge != null && !identical(pairBridge, transferBridge)) {
    await pairBridge.stop();
  }
  if (enrollBridge != null && !identical(enrollBridge, transferBridge)) {
    await enrollBridge.stop();
  }
  final listening = await transferBridge.listenForTransfer(match.matchId);
  final opened = await finish(
    listening == WatchProvisionBridgeDisposition.listening
        ? (transferBridge.transferResult?.code ?? 'waiting')
        : listening.name,
    match.matchId,
  );
  if (!opened.historicalUnchanged) {
    await transferBridge.stop();
    return finish('historical-changed', match.matchId);
  }
  return opened;
}

bool _fixture(Match match) {
  final home = match.teams.home.teamId;
  final away = match.teams.away.teamId;
  return (home == pairHomeTeamId && away == pairAwayTeamId) ||
      (home == enrollHomeTeamId && away == enrollAwayTeamId);
}

class PairedWatch {
  const PairedWatch(this.matchId, this.installationId);
  final String matchId;
  final String installationId;
}

Future<PairedWatch?> readPairedWatch({
  required Directory storageRoot,
  required LocalMatchDatabase database,
  required MatchApplicationBoundary boundary,
}) async {
  final file = File('${storageRoot.path}/$pairWatchCorrelationName');
  var matchId = '';
  if (file.existsSync()) {
    try {
      final text = file.readAsStringSync();
      final match = RegExp(r'"matchId":"([^"]+)"').firstMatch(text);
      matchId = match?.group(1) ?? '';
    } on Object {
      return null;
    }
  }
  if (matchId.isEmpty) {
    final listed = await database.listNewestFirst();
    final marked = [
      for (final item in listed)
        if (item.teams.home.teamId == pairHomeTeamId &&
            item.teams.away.teamId == pairAwayTeamId)
          item,
    ];
    if (marked.length != 1) return null;
    matchId = marked.single.matchId;
  }
  final stage = await boundary.durableStore.readWatchProvisionStage(matchId);
  if (stage == null || stage.writerDeviceId.isEmpty) return null;
  final projection =
      await boundary.durableStore.readWatchIdentityProjection(matchId);
  if (projection.eligibleDigest == null) return null;
  return PairedWatch(matchId, stage.writerDeviceId);
}

Future<String> _pairSnapshot(
  Directory storageRoot,
  MatchApplicationBoundary boundary,
) async {
  final file = File('${storageRoot.path}/$pairWatchCorrelationName');
  final bytes = file.existsSync() ? file.readAsBytesSync() : const <int>[];
  var matchId = '';
  final match =
      RegExp(r'"matchId":"([^"]+)"').firstMatch(String.fromCharCodes(bytes));
  matchId = match?.group(1) ?? '';
  final stage = matchId.isEmpty
      ? null
      : await boundary.durableStore.readWatchProvisionStage(matchId);
  return '${bytes.length}:${stage?.writerDeviceId ?? ''}:${stage?.contentHash ?? ''}:${stage?.stage ?? ''}';
}
