import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/match/new_match.dart';
import 'package:referee_phone/match_application/match_application_boundary.dart';
import 'package:referee_phone/officiate/watch_enroll_session.dart';
import 'package:referee_phone/officiate/watch_provision_debug_bridge.dart';

/// Phone correlation for Connect Watch. It is not the historical file.
const String pairWatchCorrelationName = 'forref_watch_pair_correlation_v1.json';

const String pairHomeTeamId = 'forref-pair-home';
const String pairAwayTeamId = 'forref-pair-away';

/// Result of opening Connect Watch. The watch supplies the installation id.
class WatchPairingOpen {
  const WatchPairingOpen({
    required this.status,
    required this.matchId,
    required this.historicalUnchanged,
  });

  final String status;
  final String matchId;
  final bool historicalUnchanged;

  String get line =>
      'FORREF_PAIR tx=open status=$status match=$matchId same=${historicalUnchanged ? 1 : 0}';
}

/// Starts a listener for a match that has no writer until the watch speaks.
///
/// An existing pairing stage is left as stored. A different watch is refused
/// later by the bridge. This function does not prepare, cancel, or delete.
Future<WatchPairingOpen> openWatchPairing({
  required Directory storageRoot,
  required LocalMatchDatabase database,
  required MatchApplicationBoundary boundary,
  required String phoneOriginDeviceId,
  required String principalId,
  required WatchProvisionDebugBridge pairBridge,
  WatchProvisionDebugBridge? historicalBridge,
  DateTime? now,
}) async {
  final before = await readWatchEnrollmentLedger(
    storageRoot: storageRoot,
    store: boundary.durableStore,
    database: database,
  );
  Future<WatchPairingOpen> finish(String status, String matchId) async {
    final after = await readWatchEnrollmentLedger(
      storageRoot: storageRoot,
      store: boundary.durableStore,
      database: database,
    );
    final opened = WatchPairingOpen(
      status: status,
      matchId: matchId,
      historicalUnchanged: before.sameAs(after),
    );
    debugPrint(opened.line);
    return opened;
  }

  if (!kDebugMode) return finish('debug', '');
  if (principalId.isEmpty || phoneOriginDeviceId.isEmpty) {
    return finish('principal', '');
  }
  final historicalFile =
      File('${storageRoot.path}/$historicalWatchCorrelationName');
  final pairFile = File('${storageRoot.path}/$pairWatchCorrelationName');
  if (historicalFile.absolute.path == pairFile.absolute.path) {
    return finish('namespace', '');
  }
  final bridgePath = pairBridge.correlationFile?.path ?? '';
  if (!bridgePath.endsWith(pairWatchCorrelationName)) {
    return finish('namespace', '');
  }
  if (before.fileStatus == 'unreadable') {
    return finish('historical-unreadable', '');
  }
  if (!pairBridge.correlationIntact) {
    return finish('pair-correlation-corrupt', '');
  }

  var matchId = pairBridge.matchId ?? '';
  if (matchId.isEmpty) {
    final marked = await _pairMatches(database);
    if (marked.length > 1) return finish('pair-ambiguous', '');
    if (marked.length == 1) matchId = marked.single.matchId;
  }
  if (matchId.isNotEmpty && matchId == before.matchId) {
    return finish('namespace', matchId);
  }
  Match? match;
  if (matchId.isEmpty) {
    final created = newLocalMatch(now ?? DateTime.now().toUtc()).copyWith(
      teams: const Teams(
        home: Team(teamId: pairHomeTeamId, name: 'Pair Home'),
        away: Team(teamId: pairAwayTeamId, name: 'Pair Away'),
      ),
    );
    if (created.matchId == before.matchId) {
      return finish('namespace', created.matchId);
    }
    await database.upsertMatch(created);
    match = created;
    matchId = created.matchId;
  } else {
    match = await database.getMatch(matchId);
    if (match == null) return finish('pair-match-missing', matchId);
  }

  if (historicalBridge != null && !identical(historicalBridge, pairBridge)) {
    await historicalBridge.stop();
  }
  final listening = await pairBridge.listenForPairing(
    match: match,
    principalId: principalId,
  );
  final opened = await finish(
    listening == WatchProvisionBridgeDisposition.listening
        ? 'waiting'
        : listening.name,
    matchId,
  );
  if (!opened.historicalUnchanged) {
    await pairBridge.stop();
    return finish('historical-changed', matchId);
  }
  return opened;
}

Future<List<Match>> _pairMatches(LocalMatchDatabase database) async {
  final listed = await database.listNewestFirst();
  return [
    for (final match in listed)
      if (match.teams.home.teamId == pairHomeTeamId &&
          match.teams.away.teamId == pairAwayTeamId)
        match,
  ];
}
