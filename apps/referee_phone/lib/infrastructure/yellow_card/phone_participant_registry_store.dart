import 'dart:convert';
import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';

/// Durable roster-to-[MatchParticipantId] mapping for one match.
///
/// This is not Match Memory authority. It preserves stable participant ids and
/// the display snapshot taken at registration so legacy squad edits cannot
/// silently relabel an authoritative participant.
final class PhoneParticipantRegistryEntry {
  const PhoneParticipantRegistryEntry({
    required this.matchParticipantId,
    required this.rosterParticipantId,
    required this.teamSide,
    required this.initialStatus,
    this.registeredShirtNumber,
    this.registeredName,
  });

  final MatchParticipantId matchParticipantId;
  final String rosterParticipantId;
  final ParticipantTeamSide teamSide;
  final ParticipantStatusAtDetermination initialStatus;
  final int? registeredShirtNumber;
  final String? registeredName;

  Map<String, Object?> toJson() => {
        'matchParticipantId': matchParticipantId.value,
        'rosterParticipantId': rosterParticipantId,
        'teamSide': teamSide.wireValue,
        'initialStatus': initialStatus.wireValue,
        if (registeredShirtNumber != null)
          'registeredShirtNumber': registeredShirtNumber,
        if (registeredName != null) 'registeredName': registeredName,
      };

  static PhoneParticipantRegistryEntry fromJson(Map<String, Object?> json) {
    return PhoneParticipantRegistryEntry(
      matchParticipantId:
          MatchParticipantId(json['matchParticipantId']! as String),
      rosterParticipantId: json['rosterParticipantId']! as String,
      teamSide: ParticipantTeamSideWire.parseWire(json['teamSide']! as String)!,
      initialStatus: ParticipantStatusAtDeterminationWire.parseWire(
        json['initialStatus']! as String,
      )!,
      registeredShirtNumber: json['registeredShirtNumber'] as int?,
      registeredName: json['registeredName'] as String?,
    );
  }
}

/// File-backed participant registry keyed by match id.
final class PhoneParticipantRegistryStore {
  PhoneParticipantRegistryStore(Directory storageRoot)
      : _file = File(
          '${storageRoot.path}/forref_participant_registry.json',
        );

  final File _file;

  Future<List<PhoneParticipantRegistryEntry>> loadForMatch(
    String matchId,
  ) async {
    final raw = _readAll()[matchId];
    if (raw == null) return const [];
    return [
      for (final entry in raw)
        PhoneParticipantRegistryEntry.fromJson(
          Map<String, Object?>.from(entry as Map),
        ),
    ];
  }

  Future<PhoneParticipantRegistryEntry?> entryForRosterId({
    required String matchId,
    required String rosterParticipantId,
  }) async {
    for (final entry in await loadForMatch(matchId)) {
      if (entry.rosterParticipantId == rosterParticipantId) return entry;
    }
    return null;
  }

  Future<void> saveEntry(
    String matchId,
    PhoneParticipantRegistryEntry entry,
  ) async {
    final all = _readAll();
    final entries = [
      for (final existing in all[matchId] ?? const <Object?>[])
        PhoneParticipantRegistryEntry.fromJson(
          Map<String, Object?>.from(existing as Map),
        ),
    ];
    final index = entries.indexWhere(
      (candidate) =>
          candidate.rosterParticipantId == entry.rosterParticipantId,
    );
    if (index >= 0) {
      entries[index] = entry;
    } else {
      entries.add(entry);
    }
    all[matchId] = entries.map((item) => item.toJson()).toList();
    _writeAll(all);
  }

  Map<String, List<Object?>> _readAll() {
    if (!_file.existsSync()) return {};
    final decoded = jsonDecode(_file.readAsStringSync());
    if (decoded is! Map) return {};
    return decoded.map(
      (key, value) => MapEntry(
        key as String,
        [
          for (final entry in value as List) entry,
        ],
      ),
    );
  }

  void _writeAll(Map<String, List<Object?>> all) {
    _file.parent.createSync(recursive: true);
    _file.writeAsStringSync(jsonEncode(all));
  }
}
