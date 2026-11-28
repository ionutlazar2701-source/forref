import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/match/new_match.dart';
import 'package:referee_phone/match_application/match_application_boundary.dart';
import 'package:referee_phone/officiate/watch_provision_debug_bridge.dart';

/// Historical phone correlation. Enrollment never writes this file.
const String historicalWatchCorrelationName =
    'forref_watch_provision_correlation_v1.json';

/// Isolated phone correlation for the enrollment fixture.
const String enrollWatchCorrelationName =
    'forref_watch_enroll_correlation_v1.json';

const String enrollHomeTeamId = 'forref-enroll-home';
const String enrollAwayTeamId = 'forref-enroll-away';

final RegExp _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// Read-only picture of the historical match and its correlation file.
class WatchEnrollmentLedger {
  const WatchEnrollmentLedger({
    required this.fileStatus,
    required this.fileBytes,
    required this.fileFingerprint,
    required this.matchId,
    required this.writerDeviceId,
    required this.contentHash,
    required this.principalId,
    required this.stage,
    required this.canonical,
    required this.identity,
    required this.rootPresent,
    required this.recordToken,
    required this.driftToken,
  });

  final String fileStatus;
  final int fileBytes;
  final String fileFingerprint;
  final String matchId;
  final String writerDeviceId;
  final String contentHash;
  final String principalId;
  final String stage;
  final String canonical;
  final String identity;
  final bool rootPresent;
  final String recordToken;
  final String driftToken;

  bool sameAs(WatchEnrollmentLedger other) {
    return fileStatus == other.fileStatus &&
        fileBytes == other.fileBytes &&
        fileFingerprint == other.fileFingerprint &&
        matchId == other.matchId &&
        writerDeviceId == other.writerDeviceId &&
        contentHash == other.contentHash &&
        principalId == other.principalId &&
        stage == other.stage &&
        canonical == other.canonical &&
        identity == other.identity &&
        rootPresent == other.rootPresent &&
        recordToken == other.recordToken &&
        driftToken == other.driftToken;
  }

  String get report {
    final hash =
        contentHash.length >= 8 ? contentHash.substring(0, 8) : contentHash;
    final eventCount = identity == 'none' || identity == 'absent'
        ? 0
        : identity.split('|').length;
    final eventFingerprint = _fnv32(utf8.encode(identity));
    return 'historical=$fileStatus bytes=$fileBytes fp=$fileFingerprint '
        'match=$matchId writer=$writerDeviceId hash8=$hash '
        'stage=$stage events=$eventCount eventfp=$eventFingerprint '
        'root=${rootPresent ? 1 : 0} records=$recordToken drift=$driftToken';
  }
}

class WatchEnrollmentOpen {
  const WatchEnrollmentOpen({
    required this.status,
    required this.matchId,
    required this.before,
    required this.after,
    required this.historicalUnchanged,
  });

  final String status;
  final String matchId;
  final WatchEnrollmentLedger before;
  final WatchEnrollmentLedger after;
  final bool historicalUnchanged;

  String get line {
    return 'FORREF_ENROLL tx=open status=$status match=$matchId '
        'same=${historicalUnchanged ? 1 : 0} ${before.report}';
  }
}

Future<WatchEnrollmentLedger> readWatchEnrollmentLedger({
  required Directory storageRoot,
  required SqliteDurableMatchStore store,
  required LocalMatchDatabase database,
}) async {
  final file = File('${storageRoot.path}/$historicalWatchCorrelationName');
  final bytes = _readBytes(file);
  final matchId = _matchIdOf(bytes.text);
  WatchProvisionPhoneStage? stage;
  var identity = 'absent';
  var rootPresent = false;
  var recordToken = 'absent';
  if (matchId.isNotEmpty) {
    stage = await store.readWatchProvisionStage(matchId);
    final events = await store.readWatchIdentityEvents(matchId);
    identity = _identityToken(events);
    rootPresent = await store.readGenerationOneAuthorityRoot(matchId) != null;
    recordToken = await _recordToken(store, matchId);
  }
  final driftToken = await _driftToken(database, matchId);
  return WatchEnrollmentLedger(
    fileStatus: bytes.status,
    fileBytes: bytes.bytes.length,
    fileFingerprint: _fnv32(bytes.bytes),
    matchId: matchId,
    writerDeviceId: stage?.writerDeviceId ?? '',
    contentHash: stage?.contentHash ?? '',
    principalId: stage?.principalId ?? '',
    stage: stage?.stage ?? '',
    canonical: stage?.canonical ?? '',
    identity: identity,
    rootPresent: rootPresent,
    recordToken: recordToken,
    driftToken: driftToken,
  );
}

/// Opens one isolated enrollment match and listens on the enroll bridge.
///
/// The historical correlation file, stage, identity events, and authority
/// root are read before and after. This function does not write that file,
/// cancel a stage, or lock a match.
Future<WatchEnrollmentOpen> openWatchEnrollment({
  required Directory storageRoot,
  required LocalMatchDatabase database,
  required MatchApplicationBoundary boundary,
  required String phoneOriginDeviceId,
  required String principalId,
  required String installationId,
  required WatchProvisionDebugBridge enrollBridge,
  WatchProvisionDebugBridge? historicalBridge,
  DateTime? now,
}) async {
  final before = await readWatchEnrollmentLedger(
    storageRoot: storageRoot,
    store: boundary.durableStore,
    database: database,
  );
  Future<WatchEnrollmentOpen> finish(
    String status,
    String matchId,
    WatchEnrollmentLedger after,
  ) {
    final opened = WatchEnrollmentOpen(
      status: status,
      matchId: matchId,
      before: before,
      after: after,
      historicalUnchanged: before.sameAs(after),
    );
    debugPrint(opened.line);
    return Future<WatchEnrollmentOpen>.value(opened);
  }

  if (!kDebugMode) {
    return finish('debug', '', before);
  }
  final historicalFile =
      File('${storageRoot.path}/$historicalWatchCorrelationName');
  final enrollFile = File('${storageRoot.path}/$enrollWatchCorrelationName');
  if (historicalFile.absolute.path == enrollFile.absolute.path) {
    return finish('namespace', '', before);
  }
  if (before.fileStatus == 'unreadable') {
    return finish('historical-unreadable', '', before);
  }
  final installation = installationId.trim();
  if (!_uuid.hasMatch(installation) || principalId.isEmpty) {
    return finish('installation', '', before);
  }
  if (!enrollBridge.correlationIntact) {
    return finish('enroll-correlation-corrupt', '', before);
  }

  final binding = _enrollBinding(enrollFile);
  if (binding.status == 'corrupt') {
    return finish('enroll-correlation-corrupt', '', before);
  }
  var matchId = '';
  if (binding.status == 'present') {
    if (binding.installationId != installation) {
      return finish('enroll-installation', binding.matchId, before);
    }
    if (binding.matchId == before.matchId && before.matchId.isNotEmpty) {
      return finish('namespace', binding.matchId, before);
    }
    matchId = binding.matchId;
  } else if (enrollBridge.matchId != null && enrollBridge.matchId!.isNotEmpty) {
    matchId = enrollBridge.matchId!;
  } else {
    final marked = await _markedMatches(database);
    if (marked.length > 1) {
      return finish('enroll-ambiguous', '', before);
    }
    if (marked.length == 1) matchId = marked.single.matchId;
  }
  if (matchId.isNotEmpty && matchId == before.matchId) {
    return finish('namespace', matchId, before);
  }

  if (matchId.isEmpty) {
    final created = newLocalMatch(now ?? DateTime.now().toUtc()).copyWith(
      teams: const Teams(
        home: Team(teamId: enrollHomeTeamId, name: 'Enroll Home'),
        away: Team(teamId: enrollAwayTeamId, name: 'Enroll Away'),
      ),
    );
    if (created.matchId == before.matchId) {
      return finish('namespace', created.matchId, before);
    }
    await database.upsertMatch(created);
    matchId = created.matchId;
  }

  final stage = await boundary.durableStore.readWatchProvisionStage(matchId);
  if (stage != null && stage.writerDeviceId != installation) {
    final after = await readWatchEnrollmentLedger(
      storageRoot: storageRoot,
      store: boundary.durableStore,
      database: database,
    );
    return finish('enroll-writer', matchId, after);
  }
  if (stage == null) {
    final match = await database.getMatch(matchId);
    if (match == null) {
      final after = await readWatchEnrollmentLedger(
        storageRoot: storageRoot,
        store: boundary.durableStore,
        database: database,
      );
      return finish('enroll-match-missing', matchId, after);
    }
    final prepared = await enrollBridge.prepareSavedMatch(
      match: match,
      installationId: installation,
      principalId: principalId,
    );
    if (prepared.state != WatchProvisionState.configPrepared) {
      final after = await readWatchEnrollmentLedger(
        storageRoot: storageRoot,
        store: boundary.durableStore,
        database: database,
      );
      return finish(prepared.reason, matchId, after);
    }
  }

  if (historicalBridge != null && !identical(historicalBridge, enrollBridge)) {
    await historicalBridge.stop();
  }
  final listening = await enrollBridge.start(matchId);
  final after = await readWatchEnrollmentLedger(
    storageRoot: storageRoot,
    store: boundary.durableStore,
    database: database,
  );
  if (!before.sameAs(after)) {
    await enrollBridge.stop();
    return finish('historical-changed', matchId, after);
  }
  if (listening != WatchProvisionBridgeDisposition.listening) {
    return finish(listening.name, matchId, after);
  }
  return finish(
      binding.status == 'present' ? 'reused' : 'listening', matchId, after);
}

Future<String> describeWatchEnrollment({
  required Directory storageRoot,
  required SqliteDurableMatchStore store,
  required LocalMatchDatabase database,
  required String installationId,
}) async {
  final ledger = await readWatchEnrollmentLedger(
    storageRoot: storageRoot,
    store: store,
    database: database,
  );
  final enrollFile = File('${storageRoot.path}/$enrollWatchCorrelationName');
  final binding = _enrollBinding(enrollFile);
  var witnesses = 0;
  var eligible = 'absent';
  if (binding.status == 'present') {
    final events = await store.readWatchIdentityEvents(binding.matchId);
    witnesses = events
        .where((event) => event.eventKind == 'watch_witness_observed')
        .length;
    final projection = await store.readWatchIdentityProjection(binding.matchId);
    final stage = await store.readWatchProvisionStage(binding.matchId);
    final current = installationId.trim();
    eligible = stage != null &&
            stage.writerDeviceId == current &&
            projection.state == 'witnessed' &&
            projection.eligibleDigestVersion == watchCandidateDigestVersionV2
        ? '1'
        : '0';
  }
  final line = 'FORREF_ENROLL tx=read enroll=${binding.status} '
      'match=${binding.matchId} witnesses=$witnesses eligible=$eligible '
      '${ledger.report}';
  debugPrint(line);
  return line;
}

class _FileBytes {
  const _FileBytes(this.status, this.bytes, this.text);
  final String status;
  final List<int> bytes;
  final String text;
}

class _EnrollBinding {
  const _EnrollBinding(this.status, this.matchId, this.installationId);
  final String status;
  final String matchId;
  final String installationId;
}

_FileBytes _readBytes(File file) {
  if (!file.existsSync()) return const _FileBytes('absent', <int>[], '');
  try {
    final bytes = file.readAsBytesSync();
    return _FileBytes('present', bytes, utf8.decode(bytes));
  } on Object {
    return const _FileBytes('unreadable', <int>[], '');
  }
}

String _matchIdOf(String text) {
  if (text.isEmpty) return '';
  try {
    final decoded = jsonDecode(text);
    if (decoded is! Map) return '';
    final matchId = decoded['matchId'];
    if (matchId is! String || matchId.isEmpty) return '';
    return matchId;
  } on Object {
    return '';
  }
}

_EnrollBinding _enrollBinding(File file) {
  final read = _readBytes(file);
  if (read.status != 'present') return const _EnrollBinding('absent', '', '');
  try {
    final decoded = jsonDecode(read.text);
    if (decoded is! Map || decoded['v'] != 1 || decoded['generation'] != 1) {
      return const _EnrollBinding('corrupt', '', '');
    }
    final matchId = decoded['matchId'];
    final installationId = decoded['installationId'];
    final requestId = decoded['requestId'];
    final contentHash = decoded['contentHash'];
    final phase = decoded['phase'];
    if (matchId is! String ||
        matchId.isEmpty ||
        installationId is! String ||
        !_uuid.hasMatch(installationId) ||
        requestId is! String ||
        !_uuid.hasMatch(requestId) ||
        contentHash is! String ||
        contentHash.length != 64 ||
        (phase != 'pending' && phase != 'locked' && phase != 'recorded')) {
      return const _EnrollBinding('corrupt', '', '');
    }
    return _EnrollBinding('present', matchId, installationId);
  } on Object {
    return const _EnrollBinding('corrupt', '', '');
  }
}

Future<List<Match>> _markedMatches(LocalMatchDatabase database) async {
  final listed = await database.listNewestFirst();
  return [
    for (final match in listed)
      if (match.teams.home.teamId == enrollHomeTeamId &&
          match.teams.away.teamId == enrollAwayTeamId)
        match,
  ];
}

String _identityToken(List<WatchIdentityEvent> events) {
  if (events.isEmpty) return 'none';
  final parts = <String>[
    for (final event in events)
      '${event.eventSequence}:${event.eventId}:${event.eventKind}:'
          '${event.observedInstallationId}:${event.digestVersion}:'
          '${event.protocolRequestId}:${_fnv32(event.candidateDigest ?? const <int>[])}',
  ];
  return parts.join('|');
}

Future<String> _recordToken(
  SqliteDurableMatchStore store,
  String matchId,
) async {
  try {
    final records = await store.readCommittedForMatch(matchId);
    return 'count=${records.length}';
  } on Object {
    return 'quarantine';
  }
}

Future<String> _driftToken(LocalMatchDatabase database, String matchId) async {
  if (matchId.isEmpty) return 'absent';
  final match = await database.getMatch(matchId);
  if (match == null) return 'absent';
  return '${match.updatedAt.toUtc().microsecondsSinceEpoch}:'
      '${match.status.name}:'
      '${match.teams.home.teamId}:'
      '${match.teams.away.teamId}';
}

String _fnv32(List<int> bytes) {
  var hash = 0x811c9dc5;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
