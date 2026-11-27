import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/sqlite_durable_match_store.dart';
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
    bool Function()? debugPermitted,
  }) : _debugPermitted = debugPermitted ?? (() => true);

  final MatchApplicationBoundary boundary;
  final String phoneOriginDeviceId;
  final int port;
  final bool Function() _debugPermitted;

  HttpServer? _server;
  String? _matchId;
  String? _requestId;
  Map<String, Object?>? _activation;
  WatchProvisionBridgeDisposition _disposition =
      WatchProvisionBridgeDisposition.stopped;

  String? get matchId => _matchId;

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
      debugPrint('FORREF_PROVISION listening=$loopbackEndpoint match=$_matchId');
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
    try {
      response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      response.headers.contentType = ContentType.json;
      if (request.method != 'POST' || request.uri.path != forrefWatchProvisionPath) {
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
      response.statusCode = answer['disposition'] == 'prepared' ||
              answer['disposition'] == 'locked' ||
              answer['disposition'] == 'recorded'
          ? HttpStatus.ok
          : HttpStatus.conflict;
      _write(response, answer);
      debugPrint(
        'FORREF_PROVISION served disposition=${answer['disposition']} reason=${answer['reason']}',
      );
    } finally {
      await response.close();
    }
  }

  Future<Map<String, Object?>> handle(Map<String, Object?>? body) async {
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
    if (stage.writerDeviceId != installationId) return _refused('installation');
    if (_requestId != null && _requestId != requestId) {
      return _refused('correlation');
    }
    if (operation == 'pending') {
      return _pending(stage, installationId, requestId);
    }
    if (body['matchId'] != matchId || body['contentHash'] != stage.contentHash) {
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

  Map<String, Object?> _pending(
    WatchProvisionPhoneStage stage,
    String installationId,
    String requestId,
  ) {
    if (stage.stage != 'CONFIG_PREPARED' && stage.stage != 'PHONE_AUTHORITY_LOCKED') {
      return _refused('stage');
    }
    final document = parseWatchProvisionV1(stage.canonical).document;
    if (document == null || document.contentHash != stage.contentHash) {
      return _refused('canonical');
    }
    _requestId = requestId;
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
    if (durable) _requestId = requestId;
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
    _requestId = requestId;
    _activation = {
      'matchId': stage.matchId,
      'contentHash': stage.contentHash,
      'installationId': installationId,
      'requestId': requestId,
      'generation': 1,
    };
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
