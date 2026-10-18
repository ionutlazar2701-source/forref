import 'dart:convert';
import 'dart:io';

import 'package:live_core_a/src/order_generator.dart';
import 'package:live_core_a/src/thresholds.dart';
import 'package:live_core_a/src/trial_record.dart';

/// Research session aggregate (no invented trials when participant list is empty).
class ResearchSession {
  ResearchSession({
    required this.sessionId,
    required this.orderSeed,
    List<String>? participantOpaqueIds,
    List<TrialRecord>? trials,
  })  : participantOpaqueIds = List<String>.from(participantOpaqueIds ?? []),
        trials = List<TrialRecord>.from(trials ?? []);

  final String sessionId;
  final int orderSeed;
  final List<String> participantOpaqueIds;
  final List<TrialRecord> trials;

  List<OrderEntry> get plannedOrder =>
      generateCounterbalancedOrder(seed: orderSeed);

  /// Does not invent trial results for participants that were never recorded.
  List<TrialRecord> get recordedTrialsOnly => List<TrialRecord>.from(trials);

  Map<String, Object?> toJson() => {
        'schema': 'live_core_a.session.v1',
        'sessionId': sessionId,
        'orderSeed': orderSeed,
        'participantOpaqueIds': participantOpaqueIds,
        'thresholds': InstrumentAThresholds.toJson(),
        'plannedOrder': plannedOrder.map((e) => e.toJson()).toList(),
        'trials': trials.map((t) => t.toJson()).toList(),
        'disclaimer':
            'No human participants were tested by this export; instrumentation only.',
      };

  static ResearchSession fromJson(Map<String, Object?> json) {
    final trialsRaw = json['trials'] as List<Object?>? ?? [];
    return ResearchSession(
      sessionId: json['sessionId']! as String,
      orderSeed: json['orderSeed']! as int,
      participantOpaqueIds: (json['participantOpaqueIds'] as List<Object?>?)
              ?.map((e) => e! as String)
              .toList() ??
          [],
      trials: trialsRaw
          .map((e) => TrialRecord.fromJson(e! as Map<String, Object?>))
          .toList(),
    );
  }
}

/// Writes JSON export only when [directory] is provided by the caller.
/// Never returns Saved/D1 acknowledgement or writes match-database filenames.
Future<File> exportSessionJson({
  required ResearchSession session,
  required Directory directory,
  String fileName = 'live_core_a_session_export.json',
}) async {
  if (_looksLikeMatchDatabaseName(fileName)) {
    throw ArgumentError.value(
      fileName,
      'fileName',
      'must not resemble a match database file',
    );
  }
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }
  final file = File('${directory.path}/$fileName');
  final encoded = const JsonEncoder.withIndent('  ').convert(session.toJson());
  await file.writeAsString(encoded);
  return file;
}

bool _looksLikeMatchDatabaseName(String name) {
  final lower = name.toLowerCase();
  return lower.contains('match') &&
      (lower.endsWith('.db') ||
          lower.endsWith('.sqlite') ||
          lower.contains('match_memory'));
}

/// Parse exported JSON back into an identical logical session (round-trip).
ResearchSession parseSessionJson(String source) {
  final decoded = jsonDecode(source) as Map<String, Object?>;
  return ResearchSession.fromJson(decoded);
}

/// Explicitly not a durability / Saved acknowledgement type.
Never savedAcknowledgement() {
  throw UnsupportedError(
    'live_core_a does not provide Saved or D1 acknowledgements',
  );
}
