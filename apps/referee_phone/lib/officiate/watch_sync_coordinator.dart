import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/match_application/match_application_boundary.dart';
import 'package:referee_phone/officiate/watch_match_transfer.dart';
import 'package:referee_phone/officiate/watch_pairing_session.dart';
import 'package:referee_phone/officiate/watch_provision_debug_bridge.dart';
import 'package:referee_phone/officiate/watch_transfer_registry.dart';

/// Application-owned pairing and match sync.
///
/// The Settings screen does not own these bridges. Leaving that screen does
/// not close them. Closing the app process does.
///
/// Paired is the stored installation. Ready means the debug listener is
/// bound. Offline means the last bind failed and the installation was kept.
/// Reconnecting is a bind in progress. This listener is loopback HTTP inside
/// the debug process. It is not a Bluetooth socket, and an active match does
/// not need it. Zepp reaches it only while the Zepp app is running. Android
/// does not keep the listener after this process ends. The next launch binds
/// it again from the stored pairing, without a new UUID.
class WatchSyncCoordinator extends ChangeNotifier {
  WatchProvisionDebugBridge? _pair;
  WatchProvisionDebugBridge? _transfer;
  String link = 'unpaired';
  Directory? _root;
  MatchApplicationBoundary? _boundary;
  LocalMatchDatabase? _database;
  String _origin = '';
  String _principal = '';

  WatchProvisionDebugBridge? get pairBridge => _pair;
  WatchProvisionDebugBridge? get transferBridge => _transfer;

  void bind({
    required Directory storageRoot,
    required MatchApplicationBoundary boundary,
    required LocalMatchDatabase database,
    required String phoneOriginDeviceId,
    required String principalId,
  }) {
    _root = storageRoot;
    _boundary = boundary;
    _database = database;
    _origin = phoneOriginDeviceId;
    _principal = principalId;
  }

  WatchProvisionDebugBridge requireTransferBridge() {
    final root = _root;
    final boundary = _boundary;
    if (root == null || boundary == null) {
      throw StateError('sync context');
    }
    return _transfer ??= WatchProvisionDebugBridge(
      boundary: boundary,
      phoneOriginDeviceId: _origin,
      correlationFile: File('${root.path}/$transferWatchCorrelationName'),
    );
  }

  WatchProvisionDebugBridge requirePairBridge() {
    final root = _root;
    final boundary = _boundary;
    if (root == null || boundary == null) {
      throw StateError('sync context');
    }
    return _pair ??= WatchProvisionDebugBridge(
      boundary: boundary,
      phoneOriginDeviceId: _origin,
      correlationFile: File('${root.path}/$pairWatchCorrelationName'),
    );
  }

  WatchTransferEntry? entryFor(String? matchId) {
    final root = _root;
    if (root == null || matchId == null || matchId.isEmpty) return null;
    return WatchTransferRegistry(
      File('${root.path}/${WatchTransferRegistry.fileName}'),
    ).find(matchId);
  }

  String phaseFor(String? matchId) => entryFor(matchId)?.phase ?? '';

  void noteLink(String value) {
    if (link == value) return;
    link = value;
    notifyListeners();
  }

  /// Widget disposal. The bridges stay up.
  void detachUi() {}

  Future<void> resumeTransfer() => restore();

  Future<void> resumePairing() => restore();

  Future<void> restore() async {
    final root = _root;
    final boundary = _boundary;
    final database = _database;
    if (root == null || boundary == null || database == null) return;
    if (!kDebugMode || _origin.isEmpty || _principal.isEmpty) return;
    final paired = await readPairedWatch(
      storageRoot: root,
      database: database,
      boundary: boundary,
    );
    if (paired == null) {
      noteLink('unpaired');
      return;
    }
    if (_transfer?.disposition == WatchProvisionBridgeDisposition.listening ||
        _pair?.disposition == WatchProvisionBridgeDisposition.listening) {
      noteLink('ready');
      return;
    }
    noteLink('reconnecting');
    final stored = WatchTransferRegistry(
      File('${root.path}/${WatchTransferRegistry.fileName}'),
    ).read();
    WatchTransferEntry? inflight;
    if (stored != null) {
      for (final entry in stored) {
        if (entry.phase == 'waiting' || entry.phase == 'syncing') {
          inflight = entry;
        }
      }
    }
    if (inflight != null) {
      await _pair?.stop();
      final started = await requireTransferBridge().listenForTransfer(
        inflight.matchId,
      );
      noteLink(
        started == WatchProvisionBridgeDisposition.listening
            ? 'ready'
            : 'offline',
      );
      return;
    }
    final match = await database.getMatch(paired.matchId);
    if (match == null) {
      noteLink('offline');
      return;
    }
    await _transfer?.stop();
    final started = await requirePairBridge().listenForPairing(
      match: match,
      principalId: _principal,
    );
    noteLink(
      started == WatchProvisionBridgeDisposition.listening
          ? 'ready'
          : 'offline',
    );
  }

  Future<void> close() async {
    await _pair?.stop();
    await _transfer?.stop();
  }
}
