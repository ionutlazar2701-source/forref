import 'dart:convert';
import 'dart:io';

/// One saved match sent to the paired watch. A new match is another entry.
class WatchTransferEntry {
  const WatchTransferEntry({
    required this.matchId,
    required this.phase,
    required this.contentHash,
    required this.installationId,
    required this.requestId,
    required this.homeName,
    required this.awayName,
    required this.halfDurationMs,
    this.generation = 1,
  });

  final String matchId;
  final String phase;
  final String contentHash;
  final String installationId;
  final String requestId;
  final String homeName;
  final String awayName;
  final int halfDurationMs;
  final int generation;

  WatchTransferEntry copyWith({String? phase, String? requestId}) {
    return WatchTransferEntry(
      matchId: matchId,
      phase: phase ?? this.phase,
      contentHash: contentHash,
      installationId: installationId,
      requestId: requestId ?? this.requestId,
      homeName: homeName,
      awayName: awayName,
      halfDurationMs: halfDurationMs,
      generation: generation,
    );
  }
}

/// Per-match transfer records. The active correlation file is only the
/// transaction in progress.
class WatchTransferRegistry {
  const WatchTransferRegistry(this.file);

  static const String fileName = 'forref_watch_transfer_registry_v1.json';

  final File file;

  List<WatchTransferEntry>? read() {
    if (!file.existsSync()) return const [];
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map || decoded['v'] != 1 || decoded['matches'] is! List) {
        return null;
      }
      final matches = <WatchTransferEntry>[];
      for (final raw in decoded['matches'] as List) {
        final entry = _entry(raw);
        if (entry == null) return null;
        matches.add(entry);
      }
      return matches;
    } on Object {
      return null;
    }
  }

  WatchTransferEntry? find(String matchId) {
    final matches = read();
    if (matches == null) return null;
    for (final entry in matches) {
      if (entry.matchId == matchId) return entry;
    }
    return null;
  }

  /// Writes [entry] and reads it back. An equal record is not written again.
  /// A different hash or installation is refused and the file stays.
  bool upsert(WatchTransferEntry entry) {
    if (!_phase(entry.phase) || entry.generation != 1) return false;
    final current = read();
    if (current == null) return false;
    final next = [...current];
    final index = next.indexWhere((item) => item.matchId == entry.matchId);
    if (index >= 0) {
      final stored = next[index];
      if (stored.contentHash.isNotEmpty &&
          entry.contentHash.isNotEmpty &&
          stored.contentHash != entry.contentHash) {
        return false;
      }
      if (stored.installationId.isNotEmpty &&
          entry.installationId.isNotEmpty &&
          stored.installationId != entry.installationId) {
        return false;
      }
      if (stored.phase == 'verified' && entry.phase != 'verified') return true;
      if (_same(stored, entry)) return true;
      next[index] = entry;
    } else {
      next.add(entry);
    }
    next.sort((a, b) => a.matchId.compareTo(b.matchId));
    final payload = <String, Object?>{
      'v': 1,
      'matches': [for (final item in next) _json(item)],
    };
    try {
      file.parent.createSync(recursive: true);
      final encoded = jsonEncode(payload);
      file.writeAsStringSync(encoded, flush: true);
      final back = file.readAsStringSync();
      if (back != encoded) return false;
      final checked = read();
      if (checked == null) return false;
      final saved = checked.where((item) => item.matchId == entry.matchId);
      if (saved.length != 1 || !_same(saved.single, entry)) return false;
      return true;
    } on Object {
      return false;
    }
  }
}

bool _phase(String phase) {
  return phase == 'waiting' ||
      phase == 'syncing' ||
      phase == 'verified' ||
      phase == 'retry';
}

bool _same(WatchTransferEntry left, WatchTransferEntry right) {
  return left.matchId == right.matchId &&
      left.phase == right.phase &&
      left.contentHash == right.contentHash &&
      left.installationId == right.installationId &&
      left.requestId == right.requestId &&
      left.homeName == right.homeName &&
      left.awayName == right.awayName &&
      left.halfDurationMs == right.halfDurationMs &&
      left.generation == right.generation;
}

WatchTransferEntry? _entry(Object? raw) {
  if (raw is! Map) return null;
  final matchId = raw['matchId'];
  final phase = raw['phase'];
  final contentHash = raw['contentHash'];
  final installationId = raw['installationId'];
  final requestId = raw['requestId'];
  final homeName = raw['homeName'];
  final awayName = raw['awayName'];
  final halfDurationMs = raw['halfDurationMs'];
  final generation = raw['generation'];
  if (matchId is! String ||
      matchId.isEmpty ||
      phase is! String ||
      !_phase(phase) ||
      contentHash is! String ||
      installationId is! String ||
      requestId is! String ||
      homeName is! String ||
      awayName is! String ||
      halfDurationMs is! int ||
      halfDurationMs <= 0 ||
      generation != 1) {
    return null;
  }
  return WatchTransferEntry(
    matchId: matchId,
    phase: phase,
    contentHash: contentHash,
    installationId: installationId,
    requestId: requestId,
    homeName: homeName,
    awayName: awayName,
    halfDurationMs: halfDurationMs,
  );
}

Map<String, Object?> _json(WatchTransferEntry entry) {
  return {
    'matchId': entry.matchId,
    'phase': entry.phase,
    'contentHash': entry.contentHash,
    'installationId': entry.installationId,
    'requestId': entry.requestId,
    'homeName': entry.homeName,
    'awayName': entry.awayName,
    'halfDurationMs': entry.halfDurationMs,
    'generation': entry.generation,
  };
}
