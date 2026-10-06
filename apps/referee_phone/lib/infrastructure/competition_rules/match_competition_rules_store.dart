import 'dart:convert';
import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';

/// Explicit per-match competition rules for terminal eligibility and capture.
///
/// Stored beside Match Memory, not inferred from legacy [Match] status or UI
/// labels.
final class MatchCompetitionRulesStore {
  MatchCompetitionRulesStore(Directory storageRoot)
      : _file = File('${storageRoot.path}/forref_match_competition_rules.json');

  static const unresolvedDefault = CompetitionRulesContext(
    rulesetId: 'ifab',
    disciplinarySystem: DisciplinarySystem.unresolved,
  );

  final File _file;

  Future<CompetitionRulesContext> loadForMatch(String matchId) async {
    final all = await _readAll();
    return all[matchId] ?? unresolvedDefault;
  }

  Future<void> saveForMatch(
    String matchId,
    CompetitionRulesContext rules,
  ) async {
    final all = await _readAll();
    all[matchId] = rules;
    await _writeAll(all);
  }

  /// Creates an explicit unresolved rules entry for a new match.
  Future<void> ensureForMatch(String matchId) async {
    final all = await _readAll();
    if (all.containsKey(matchId)) return;
    all[matchId] = unresolvedDefault;
    await _writeAll(all);
  }

  Future<Map<String, CompetitionRulesContext>> _readAll() async {
    if (!_file.existsSync()) return {};
    late final String raw;
    try {
      raw = await _file.readAsString();
    } on FileSystemException {
      return {};
    }
    if (raw.trim().isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw FormatException('Stored competition rules are invalid');
    }
    final out = <String, CompetitionRulesContext>{};
    for (final entry in decoded.entries) {
      if (entry.key is! String || entry.value is! Map) {
        throw FormatException('Stored competition rules are invalid');
      }
      out[entry.key as String] = _decode(entry.value as Map);
    }
    return out;
  }

  Future<void> _writeAll(Map<String, CompetitionRulesContext> all) async {
    if (!_file.parent.existsSync()) {
      _file.parent.createSync(recursive: true);
    }
    final encoded = <String, Object?>{};
    for (final entry in all.entries) {
      encoded[entry.key] = _encode(entry.value);
    }
    await _file.writeAsString(jsonEncode(encoded), flush: true);
  }

  CompetitionRulesContext _decode(Map<dynamic, dynamic> json) {
    final rulesetId = json['rulesetId'];
    if (rulesetId is! String || rulesetId.isEmpty) {
      throw FormatException('Stored rulesetId is invalid');
    }
    return CompetitionRulesContext(
      rulesetId: rulesetId,
      additionalPlayingPhase: _decodeDisposition(json['additionalPlayingPhase']),
      penaltyShootOutAfterMatchEnd:
          json['penaltyShootOutAfterMatchEnd'] == true,
      disciplinarySystem: _decodeDisciplinarySystem(json['disciplinarySystem']),
    );
  }

  DisciplinarySystem _decodeDisciplinarySystem(Object? value) {
    if (value == null) return DisciplinarySystem.unresolved;
    if (value is! String) {
      throw FormatException('Stored disciplinarySystem is invalid');
    }
    final parsed = DisciplinarySystemWire.parseWire(value);
    if (parsed == null) {
      throw FormatException('Stored disciplinarySystem is invalid');
    }
    return parsed;
  }

  AdditionalPlayingPhaseDisposition _decodeDisposition(Object? value) {
    if (value == null) {
      return AdditionalPlayingPhaseDisposition.unresolved;
    }
    if (value is! String) {
      throw FormatException('Stored additionalPlayingPhase is invalid');
    }
    final parsed = AdditionalPlayingPhaseDispositionWire.parseWire(value);
    if (parsed == null) {
      throw FormatException('Stored additionalPlayingPhase is invalid');
    }
    return parsed;
  }

  Map<String, Object?> _encode(CompetitionRulesContext rules) {
    return {
      'rulesetId': rules.rulesetId,
      if (rules.additionalPlayingPhase !=
          AdditionalPlayingPhaseDisposition.unresolved)
        'additionalPlayingPhase': rules.additionalPlayingPhase.wireValue,
      if (rules.penaltyShootOutAfterMatchEnd)
        'penaltyShootOutAfterMatchEnd': true,
      if (rules.disciplinarySystem != DisciplinarySystem.unresolved)
        'disciplinarySystem': rules.disciplinarySystem.wireValue,
    };
  }
}
