import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/officiate/match_configuration_payload.dart';

/// Fixed loopback port for the debug configuration bridge.
///
/// The Zepp Side Service calls this exact port. A failed bind does not move
/// to another port.
const int forrefLocalBridgePort = 47221;

/// Path that returns one persisted [MatchConfigurationPayload].
const String forrefLocalBridgePath = '/match-configuration';

enum LocalBridgeDisposition { stopped, listening, refused, missing, failed }

/// Debug-only HTTP server on 127.0.0.1.
///
/// It reads the selected match from the phone database on every request and
/// returns the version 1 configuration projection. It does not start by
/// itself, does not bind any other interface, and does not run in release.
class LocalConfigurationBridge extends ChangeNotifier {
  LocalConfigurationBridge({
    required this.readPersistedMatch,
    this.port = forrefLocalBridgePort,
    bool Function()? debugPermitted,
  }) : _debugPermitted = debugPermitted ?? (() => true);

  final Future<Match?> Function(String matchId) readPersistedMatch;
  final int port;
  final bool Function() _debugPermitted;

  HttpServer? _server;
  String? _matchId;
  LocalBridgeDisposition _disposition = LocalBridgeDisposition.stopped;

  String? get selectedMatchId => _matchId;

  LocalBridgeDisposition get disposition => _disposition;

  bool get isListening => _server != null;

  int get boundPort => _server?.port ?? port;

  /// `127.0.0.1` and the bound port. Empty until the server is listening.
  String get loopbackEndpoint {
    final server = _server;
    if (server == null) return '';
    return '127.0.0.1:${server.port}';
  }

  Future<LocalBridgeDisposition> select(String matchId) {
    if (!_permitted) {
      return Future<LocalBridgeDisposition>.value(
          _set(LocalBridgeDisposition.refused));
    }
    return _remember(matchId);
  }

  Future<LocalBridgeDisposition> start(String matchId) async {
    if (!_permitted) {
      return _set(LocalBridgeDisposition.refused);
    }
    final selected = await _remember(matchId);
    if (selected == LocalBridgeDisposition.missing) return selected;
    if (_server != null) return _set(LocalBridgeDisposition.listening);
    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      if (!server.address.isLoopback || server.address.address != '127.0.0.1') {
        await server.close(force: true);
        return _set(LocalBridgeDisposition.failed);
      }
      _server = server;
      server.listen(_answer, onError: (Object _) {});
      debugPrint(
        'FORREF_B0 listening=$loopbackEndpoint match=$_matchId',
      );
      return _set(LocalBridgeDisposition.listening);
    } on Object {
      return _set(LocalBridgeDisposition.failed);
    }
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    if (server != null) {
      debugPrint('FORREF_B0 stopped match=$_matchId');
      await server.close(force: true);
    }
    _set(LocalBridgeDisposition.stopped);
  }

  bool get _permitted => kDebugMode && _debugPermitted();

  Future<LocalBridgeDisposition> _remember(String matchId) async {
    final match = await readPersistedMatch(matchId);
    if (match == null) return LocalBridgeDisposition.missing;
    _matchId = matchId;
    notifyListeners();
    return _disposition;
  }

  LocalBridgeDisposition _set(LocalBridgeDisposition value) {
    _disposition = value;
    notifyListeners();
    return value;
  }

  Future<void> _answer(HttpRequest request) async {
    final response = request.response;
    try {
      response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      response.headers.contentType = ContentType.json;
      if (request.method != 'GET' ||
          request.uri.path != forrefLocalBridgePath) {
        response.statusCode = request.method == 'GET'
            ? HttpStatus.notFound
            : HttpStatus.methodNotAllowed;
        _writeJson(response, const {'disposition': 'rejected'});
        debugPrint('FORREF_B0 served status=${response.statusCode}');
        return;
      }
      final matchId = _matchId;
      final match = matchId == null ? null : await readPersistedMatch(matchId);
      if (match == null) {
        response.statusCode = HttpStatus.notFound;
        _writeJson(response, const {'disposition': 'missing'});
        debugPrint('FORREF_B0 served status=404 match=$matchId');
        return;
      }
      response.statusCode = HttpStatus.ok;
      _writeJson(
        response,
        MatchConfigurationPayload.fromMatch(match).toJson(),
      );
      debugPrint('FORREF_B0 served status=200 match=${match.matchId}');
    } finally {
      await response.close();
    }
  }
}

void _writeJson(HttpResponse response, Map<String, Object?> body) {
  final bytes = utf8.encode(jsonEncode(body));
  response.contentLength = bytes.length;
  response.add(bytes);
}
