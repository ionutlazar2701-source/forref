import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/sqlite_durable_match_store.dart';
import 'package:forref_match_persistence/watch_identity.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/match_application/match_application_boundary.dart';

/// Debug loopback for the watch provision handshake.
///
/// The Zepp Side Service calls this port. The body is the canonical watch
/// provision already stored by [MatchApplicationBoundary]. This is not a
/// production transport.
const int forrefWatchProvisionPort = 47221;

const String forrefWatchProvisionPath = '/watch-provision/v1';

final RegExp _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

enum WatchProvisionBridgeDisposition {
  stopped,
  listening,
  refused,
  missing,
  failed,
}

/// Builds a provision document from a match the phone already saved.
WatchProvisionDocument? documentForSavedMatch({
  required Match match,
  required String principalId,
  required String installationId,
}) {
  final homeName = match.teams.home.name;
  final awayName = match.teams.away.name;
  if (homeName == null ||
      awayName == null ||
      homeName.isEmpty ||
      awayName.isEmpty ||
      homeName != homeName.trim() ||
      awayName != awayName.trim()) {
    return null;
  }
  final homeId = match.teams.home.teamId;
  final awayId = match.teams.away.teamId;
  if (homeId.toUpperCase() == 'HOME' ||
      homeId.toUpperCase() == 'AWAY' ||
      awayId.toUpperCase() == 'HOME' ||
      awayId.toUpperCase() == 'AWAY' ||
      homeId == awayId) {
    return null;
  }
  if (!_uuid.hasMatch(installationId)) return null;
  final halfMs = match.settings.halfDurationSeconds * 1000;
  if (halfMs <= 0) return null;
  return WatchProvisionDocument(
    matchId: match.matchId,
    principalId: principalId,
    writerDeviceId: installationId,
    homeTeamId: homeId,
    homeName: homeName,
    awayTeamId: awayId,
    awayName: awayName,
    halfDurationMs: halfMs,
    provisionVersion: 1,
  );
}

class WatchProvisionDebugBridge extends ChangeNotifier {
  WatchProvisionDebugBridge({
    required this.boundary,
    required this.phoneOriginDeviceId,
    this.port = forrefWatchProvisionPort,
    this.correlationFile,
    bool Function()? debugPermitted,
  }) : _debugPermitted = debugPermitted ?? (() => true) {
    _loadCorrelation();
  }

  final MatchApplicationBoundary boundary;
  final String phoneOriginDeviceId;
  final int port;
  final File? correlationFile;
  final bool Function() _debugPermitted;

  HttpServer? _server;
  String? _matchId;
  String? _requestId;
  String? _installationId;
  String? _contentHash;
  String _phase = '';
  bool _correlationBroken = false;
  Future<void> _serial = Future<void>.value();
  Map<String, Object?>? _activation;
  WatchProvisionBridgeDisposition _disposition =
      WatchProvisionBridgeDisposition.stopped;

  String? get matchId => _matchId;

  String? get boundRequestId => _requestId;

  bool get correlationIntact => !_correlationBroken;

  Map<String, Object?>? get lastActivation => _activation;

  WatchProvisionBridgeDisposition get disposition => _disposition;

  bool get isListening => _server != null;

  String get loopbackEndpoint {
    final server = _server;
    if (server == null) return '';
    return '127.0.0.1:${server.port}';
  }

  Future<WatchProvisionDecision> prepareSavedMatch({
    required Match match,
    required String installationId,
    required String principalId,
  }) {
    final document = documentForSavedMatch(
      match: match,
      principalId: principalId,
      installationId: installationId,
    );
    if (document == null) {
      return Future<WatchProvisionDecision>.value(
        const WatchProvisionDecision(
          state: WatchProvisionState.configInvalid,
          trace: [WatchProvisionState.configInvalid],
          reason: 'match',
        ),
      );
    }
    if (_requestId != null && _matchId != null && _matchId != match.matchId) {
      return Future<WatchProvisionDecision>.value(
        const WatchProvisionDecision(
          state: WatchProvisionState.authorityConflict,
          trace: [WatchProvisionState.authorityConflict],
          reason: 'correlation-conflict',
        ),
      );
    }
    _matchId = match.matchId;
    return boundary.prepareWatchOperatedMatch(
      canonicalMessage: document.canonical,
      phoneOriginDeviceId: phoneOriginDeviceId,
    );
  }

  Future<WatchProvisionBridgeDisposition> start(String matchId) async {
    if (!_permitted) return _set(WatchProvisionBridgeDisposition.refused);
    final stage = await boundary.durableStore.readWatchProvisionStage(matchId);
    if (stage == null) return _set(WatchProvisionBridgeDisposition.missing);
    if (_requestId != null && _matchId != null && _matchId != matchId) {
      return _set(WatchProvisionBridgeDisposition.refused);
    }
    _matchId = matchId;
    if (_server != null) return _set(WatchProvisionBridgeDisposition.listening);
    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      if (!server.address.isLoopback || server.address.address != '127.0.0.1') {
        await server.close(force: true);
        return _set(WatchProvisionBridgeDisposition.failed);
      }
      _server = server;
      server.listen(_answer, onError: (Object _) {});
      debugPrint(
          'FORREF_PROVISION listening=$loopbackEndpoint match=$_matchId');
      return _set(WatchProvisionBridgeDisposition.listening);
    } on Object {
      return _set(WatchProvisionBridgeDisposition.failed);
    }
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    if (server != null) {
      debugPrint('FORREF_PROVISION stopped match=$_matchId');
      await server.close(force: true);
    }
    _set(WatchProvisionBridgeDisposition.stopped);
  }

  bool get _permitted => kDebugMode && _debugPermitted();

  WatchProvisionBridgeDisposition _set(WatchProvisionBridgeDisposition value) {
    _disposition = value;
    notifyListeners();
    return value;
  }

  Future<void> _answer(HttpRequest request) async {
    final response = request.response;
    final started = DateTime.now();
    try {
      response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      response.headers.contentType = ContentType.json;
      if (request.method == 'GET' &&
          (request.uri.path == '/' ||
              request.uri.path == forrefWatchProvisionPath)) {
        response.statusCode = HttpStatus.ok;
        _write(response, {
          'disposition': 'listening',
          'reason': 'listening',
          'writes': 0,
          'matchId': _matchId ?? '',
          'saved': false,
          'd1Certified': false,
        });
        debugPrint(
          'FORREF_PROVISION tx=listen method=GET match=${_matchId ?? ''} writes=0',
        );
        return;
      }
      if (request.method != 'POST' ||
          request.uri.path != forrefWatchProvisionPath) {
        response.statusCode = HttpStatus.notFound;
        _write(response, const {
          'disposition': 'refused',
          'reason': 'path',
          'saved': false,
          'd1Certified': false,
        });
        return;
      }
      final body = await _readBody(request);
      final answer = await handle(body);
      final disposition = answer['disposition'];
      response.statusCode = disposition == 'prepared' ||
              disposition == 'locked' ||
              disposition == 'recorded'
          ? HttpStatus.ok
          : disposition == 'unavailable'
              ? HttpStatus.serviceUnavailable
              : HttpStatus.conflict;
      _write(response, answer);
      debugPrint(
        'FORREF_PROVISION tx=response disposition=$disposition reason=${answer['reason'] ?? ''} http=${response.statusCode} elapsed=${DateTime.now().difference(started).inMilliseconds}',
      );
    } on Object {
      response.statusCode = HttpStatus.internalServerError;
      _write(response, const {
        'disposition': 'unavailable',
        'reason': 'bridge',
        'durable': false,
        'saved': false,
        'd1Certified': false,
      });
      debugPrint('FORREF_PROVISION tx=recover reason=bridge http=500');
    } finally {
      await response.close();
    }
  }

  Future<Map<String, Object?>> handle(Map<String, Object?>? body) {
    final run = _serial.then((_) => _handle(body));
    _serial = run.then((_) {}, onError: (Object _, StackTrace __) {});
    return run;
  }

  Future<Map<String, Object?>> _handle(Map<String, Object?>? body) async {
    if (_correlationBroken) return _refused('correlation-corrupt');
    if (!_permitted) {
      return _refused('debug');
    }
    if (body == null) return _refused('message');
    final operation = body['operation'];
    final installationId = body['installationId'];
    final requestId = body['requestId'];
    final generation = body['generation'];
    if (operation is! String ||
        installationId is! String ||
        !_uuid.hasMatch(installationId) ||
        requestId is! String ||
        !_uuid.hasMatch(requestId) ||
        generation != 1) {
      return _refused('message');
    }
    final matchId = _matchId;
    if (matchId == null) return _refused('missing');
    if (body['matchId'] != null && body['matchId'] != matchId) {
      return _refused('match');
    }
    final stage = await boundary.durableStore.readWatchProvisionStage(matchId);
    if (stage == null) return _refused('missing');
    if (body['principalId'] != null &&
        body['principalId'] != stage.principalId) {
      return _refused('principal');
    }
    if (stage.writerDeviceId != installationId) {
      return _classifyOther(stage, body, installationId, requestId);
    }
    if (_installationId != null && _installationId != installationId) {
      return _refused('correlation-conflict');
    }
    if (_requestId != null && _requestId != requestId) {
      return _refused('correlation');
    }
    debugPrint(
      'FORREF_PROVISION tx=bridge operation=$operation installation=$installationId request=$requestId match=$matchId',
    );
    _trace('request', operation, installationId, requestId);
    if (operation != 'pending' && _requestId == null) {
      return _refused('order');
    }
    if (operation == 'pending') {
      final prepared = _pending(stage, installationId, requestId);
      if (prepared['disposition'] == 'prepared') {
        await _observeWitness(stage, body, installationId, requestId);
      }
      return prepared;
    }
    if (body['matchId'] != matchId ||
        body['contentHash'] != stage.contentHash) {
      return _refused('binding');
    }
    if (body['canonical'] != null && body['canonical'] != stage.canonical) {
      return _refused('canonical');
    }
    if (operation == 'lock') {
      return _lock(stage, body, installationId, requestId);
    }
    if (operation == 'activation') {
      return _rememberActivation(stage, body, installationId, requestId);
    }
    return _refused('operation');
  }

  Future<Map<String, Object?>> _classifyOther(
    WatchProvisionPhoneStage stage,
    Map<String, Object?> body,
    String installationId,
    String requestId,
  ) async {
    final claim = _witnessClaim(body['witness']);
    if (claim.absent) return _refused('installation');
    final result = await boundary.durableStore.classifyWatchInstallation(
      matchId: stage.matchId,
      principalId: stage.principalId,
      installationId: installationId,
      requestId: requestId,
      candidateKind: claim.kind,
      digest: claim.digest,
      digestVersion: claim.digestVersion,
      witnessMalformed: claim.malformed,
      sourceBuilds: claim.sourceBuilds,
    );
    final reason = switch (result) {
      WatchIdentityAppended(:final reason) => reason,
      WatchIdentityRefused(:final reason) => reason,
    };
    final preview = claim.digest == null ? '' : digestPreview(claim.digest!);
    debugPrint(
      'FORREF_PROVISION tx=identity reason=$reason installation=$installationId request=$requestId match=${stage.matchId} preview=$preview v=${claim.digestVersion} grade=$watchEvidenceUnverifiedDevice',
    );
    return _refused(reason);
  }

  Future<void> _observeWitness(
    WatchProvisionPhoneStage stage,
    Map<String, Object?> body,
    String installationId,
    String requestId,
  ) async {
    final claim = _witnessClaim(body['witness']);
    if (claim.absent) return;
    if (claim.malformed || claim.digest == null) {
      debugPrint(
        'FORREF_PROVISION tx=identity reason=witness-malformed installation=$installationId request=$requestId match=${stage.matchId}',
      );
      return;
    }
    final result = await boundary.durableStore.observeWatchWitness(
      matchId: stage.matchId,
      principalId: stage.principalId,
      installationId: installationId,
      requestId: requestId,
      digest: claim.digest!,
      digestVersion: claim.digestVersion,
      sourceBuilds: claim.sourceBuilds,
    );
    final reason = switch (result) {
      WatchIdentityAppended(:final reason) => reason,
      WatchIdentityRefused(:final reason) => reason,
    };
    debugPrint(
      'FORREF_PROVISION tx=identity reason=$reason installation=$installationId request=$requestId match=${stage.matchId} preview=${digestPreview(claim.digest!)} v=${claim.digestVersion} grade=$watchEvidenceUnverifiedDevice',
    );
  }

  Map<String, Object?> _pending(
    WatchProvisionPhoneStage stage,
    String installationId,
    String requestId,
  ) {
    if (stage.stage != 'CONFIG_PREPARED' &&
        stage.stage != 'PHONE_AUTHORITY_LOCKED') {
      return _refused('stage');
    }
    final document = parseWatchProvisionV1(stage.canonical).document;
    if (document == null || document.contentHash != stage.contentHash) {
      return _refused('canonical');
    }
    _requestId = requestId;
    _installationId = installationId;
    _contentHash = stage.contentHash;
    if (!_persist(_forwardPhase('pending'))) {
      if (_phase != 'pending' && _phase != 'locked' && _phase != 'recorded') {
        _requestId = null;
        _installationId = null;
        _contentHash = null;
      }
      return _refused('correlation-write');
    }
    return {
      'disposition': 'prepared',
      'schema': 'forref.watch-provision.v1',
      'matchId': stage.matchId,
      'contentHash': stage.contentHash,
      'installationId': installationId,
      'requestId': requestId,
      'generation': 1,
      'canonical': stage.canonical,
      'homeName': document.homeName,
      'awayName': document.awayName,
      'saved': false,
      'd1Certified': false,
    };
  }

  Future<Map<String, Object?>> _lock(
    WatchProvisionPhoneStage stage,
    Map<String, Object?> body,
    String installationId,
    String requestId,
  ) async {
    final receipt = WatchConfigVerifiedReceipt(
      contentHash: stage.contentHash,
      writerDeviceId: installationId,
      generation: 1,
      readBack: body['readBack'] == true,
    );
    final decision = await boundary.lockWatchAuthority(
      canonicalMessage: stage.canonical,
      phoneOriginDeviceId: phoneOriginDeviceId,
      receipt: receipt,
      transportAvailable: true,
    );
    final durable = decision.state == WatchProvisionState.phoneAuthorityLocked;
    if (durable) {
      _requestId = requestId;
      _installationId = installationId;
      _contentHash = stage.contentHash;
      if (_phase != 'recorded') _persist(_forwardPhase('locked'));
    } else {
      _trace('recover', decision.reason, installationId, requestId);
    }
    return {
      'disposition': durable ? 'locked' : 'refused',
      'durable': durable,
      'state': decision.state.wire,
      'reason': decision.reason,
      'matchId': stage.matchId,
      'contentHash': stage.contentHash,
      'installationId': installationId,
      'requestId': requestId,
      'generation': 1,
      'saved': false,
      'd1Certified': false,
    };
  }

  Map<String, Object?> _rememberActivation(
    WatchProvisionPhoneStage stage,
    Map<String, Object?> body,
    String installationId,
    String requestId,
  ) {
    if (stage.stage != 'PHONE_AUTHORITY_LOCKED') return _refused('stage');
    if (body['readBack'] != true || body['type'] != 'WATCH_ACTIVATED_V1') {
      return _refused('receipt');
    }
    final recorded = <String, Object?>{
      'matchId': stage.matchId,
      'contentHash': stage.contentHash,
      'installationId': installationId,
      'requestId': requestId,
      'generation': 1,
    };
    _requestId = requestId;
    _installationId = installationId;
    _contentHash = stage.contentHash;
    _activation = recorded;
    if (!_persist('recorded')) {
      if (_phase != 'recorded') _activation = null;
      return _refused('correlation-write');
    }
    notifyListeners();
    return {
      'disposition': 'recorded',
      'reason': '',
      'matchId': stage.matchId,
      'contentHash': stage.contentHash,
      'installationId': installationId,
      'requestId': requestId,
      'generation': 1,
      'saved': false,
      'd1Certified': false,
    };
  }

  void _loadCorrelation() {
    final file = correlationFile;
    if (file == null || !file.existsSync()) return;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) {
        _correlationBroken = true;
        return;
      }
      final requestId = decoded['requestId'];
      final installationId = decoded['installationId'];
      final matchId = decoded['matchId'];
      final phase = decoded['phase'];
      final contentHash = decoded['contentHash'];
      if (decoded['v'] != 1 ||
          decoded['generation'] != 1 ||
          requestId is! String ||
          !_uuid.hasMatch(requestId) ||
          installationId is! String ||
          !_uuid.hasMatch(installationId) ||
          matchId is! String ||
          matchId.isEmpty ||
          contentHash is! String ||
          contentHash.length != 64 ||
          (phase != 'pending' && phase != 'locked' && phase != 'recorded')) {
        _correlationBroken = true;
        return;
      }
      _requestId = requestId;
      _installationId = installationId;
      _matchId = matchId;
      _contentHash = contentHash;
      _phase = phase;
      if (phase == 'recorded') {
        _activation = {
          'matchId': matchId,
          'contentHash': contentHash,
          'installationId': installationId,
          'requestId': requestId,
          'generation': 1,
        };
      }
    } on Object {
      _correlationBroken = true;
    }
  }

  String _forwardPhase(String next) {
    const rank = <String, int>{'': 0, 'pending': 1, 'locked': 2, 'recorded': 3};
    if ((rank[_phase] ?? 0) > (rank[next] ?? 0)) return _phase;
    return next;
  }

  bool _persist(String phase) {
    final previous = _phase;
    _phase = phase;
    final file = correlationFile;
    if (file == null) {
      _trace('transition', phase, _installationId ?? '', _requestId ?? '');
      return true;
    }
    final payload = <String, Object?>{
      'v': 1,
      'matchId': _matchId,
      'installationId': _installationId,
      'requestId': _requestId,
      'generation': 1,
      'contentHash': _contentHash,
      'phase': phase,
    };
    try {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(payload), flush: true);
      final back = jsonDecode(file.readAsStringSync());
      if (back is! Map ||
          back['requestId'] != _requestId ||
          back['phase'] != phase ||
          back['matchId'] != _matchId ||
          back['contentHash'] != _contentHash ||
          back['installationId'] != _installationId ||
          back['generation'] != 1) {
        _phase = previous;
        return false;
      }
      _trace('transition', phase, _installationId ?? '', _requestId ?? '');
      return true;
    } on Object {
      _phase = previous;
      return false;
    }
  }

  void _trace(String tx, String name, String installationId, String requestId) {
    debugPrint(
      'FORREF_PROVISION tx=$tx name=$name installation=$installationId request=$requestId match=$_matchId hash=${_contentHash ?? ''}',
    );
  }

  Map<String, Object?> _refused(String reason) {
    return {
      'disposition': 'refused',
      'reason': reason,
      'durable': false,
      'saved': false,
      'd1Certified': false,
    };
  }
}

/// Read-only description of the phone correlation file. It never includes a
/// canonical document.
String describeDebugCorrelation(String? text) {
  if (text == null || text.trim().isEmpty) return 'correlation=absent';
  try {
    final decoded = jsonDecode(text);
    if (decoded is! Map) return 'correlation=corrupt';
    final requestId = decoded['requestId'];
    final phase = decoded['phase'];
    final matchId = decoded['matchId'];
    final contentHash = decoded['contentHash'];
    final generation = decoded['generation'];
    if (requestId is! String ||
        phase is! String ||
        matchId is! String ||
        contentHash is! String ||
        generation != 1) {
      return 'correlation=corrupt';
    }
    return 'correlation request=$requestId phase=$phase generation=1 match=$matchId hash=$contentHash';
  } on Object {
    return 'correlation=corrupt';
  }
}

final class _WitnessClaim {
  const _WitnessClaim({
    required this.absent,
    required this.malformed,
    required this.kind,
    required this.digest,
    required this.digestVersion,
    required this.sourceBuilds,
  });

  final bool absent;
  final bool malformed;
  final String kind;
  final Uint8List? digest;
  final int digestVersion;
  final String sourceBuilds;
}

_WitnessClaim _witnessClaim(Object? witness) {
  if (witness == null) {
    return const _WitnessClaim(
      absent: true,
      malformed: false,
      kind: 'absent',
      digest: null,
      digestVersion: 0,
      sourceBuilds: '',
    );
  }
  if (witness is! Map) {
    return const _WitnessClaim(
      absent: false,
      malformed: true,
      kind: 'absent',
      digest: null,
      digestVersion: 0,
      sourceBuilds: '',
    );
  }
  final version = witness['digestVersion'];
  if (witness.containsKey('uuid') ||
      witness.containsKey('platformUuid') ||
      witness['schema'] != watchWitnessSchema ||
      (version != watchCandidateDigestVersion &&
          version != watchCandidateDigestVersionV2) ||
      witness['evidenceGrade'] != watchEvidenceUnverifiedDevice) {
    return const _WitnessClaim(
      absent: false,
      malformed: true,
      kind: 'absent',
      digest: null,
      digestVersion: 0,
      sourceBuilds: '',
    );
  }
  final builds = witness['sourceBuilds'];
  final sourceBuilds = builds is String ? builds : '';
  final kind = witness['candidateKind'];
  if (kind == 'absent' || kind == 'model_only') {
    return _WitnessClaim(
      absent: false,
      malformed: false,
      kind: kind as String,
      digest: null,
      digestVersion: version as int,
      sourceBuilds: sourceBuilds,
    );
  }
  if (kind != 'platform_uuid') {
    return _WitnessClaim(
      absent: false,
      malformed: true,
      kind: 'absent',
      digest: null,
      digestVersion: 0,
      sourceBuilds: sourceBuilds,
    );
  }
  final hex = witness['candidateDigest'];
  final digest = hex is String ? decodeDigestHex(hex) : null;
  if (digest == null) {
    return _WitnessClaim(
      absent: false,
      malformed: true,
      kind: 'platform_uuid',
      digest: null,
      digestVersion: 0,
      sourceBuilds: sourceBuilds,
    );
  }
  return _WitnessClaim(
    absent: false,
    malformed: false,
    kind: 'platform_uuid',
    digest: digest,
    digestVersion: version as int,
    sourceBuilds: sourceBuilds,
  );
}

Future<Map<String, Object?>?> _readBody(HttpRequest request) async {
  final chunks = <int>[];
  await for (final chunk in request) {
    chunks.addAll(chunk);
    if (chunks.length > 16384) return null;
  }
  if (chunks.isEmpty) return null;
  try {
    final decoded = jsonDecode(utf8.decode(chunks));
    if (decoded is Map) return decoded.cast<String, Object?>();
  } on FormatException {
    return null;
  }
  return null;
}

void _write(HttpResponse response, Map<String, Object?> body) {
  final bytes = utf8.encode(jsonEncode(body));
  response.contentLength = bytes.length;
  response.add(bytes);
}
