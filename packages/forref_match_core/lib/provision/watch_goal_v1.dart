import 'dart:convert';

import '../match_team.dart';
import '../record_kind.dart';
import '../semantics/match_record_semantic_type.dart';
import '../semantics/v1_semantic_payload.dart';
import 'sha256_hex.dart';

/// Local watch Goal envelope. Field meaning follows [GoalPayload].
///
/// This is not adapter storage JSON and it is not a D1 certificate.
const String watchGoalSchemaV1 = 'forref.watch-goal.v1';

const String watchGoalLocalRecordLabel =
    'LOCAL RECORD VERIFIED — D1 UNCERTIFIED';

final class WatchGoalEnvelope {
  const WatchGoalEnvelope({
    required this.matchId,
    required this.recordId,
    required this.captureIntentId,
    required this.scoringTeamId,
    required this.principalId,
    required this.writerDeviceId,
    required this.originSequence,
  });

  final String matchId;
  final String recordId;
  final String captureIntentId;
  final String scoringTeamId;
  final String principalId;
  final String writerDeviceId;
  final int originSequence;

  String get canonical => canonicalWatchGoalV1(this);

  String get contentHash => sha256Hex(canonical);

  /// The sporting meaning this envelope is allowed to carry.
  GoalPayload get goalPayload => GoalPayload(
        scoringTeamId: MatchTeamId(scoringTeamId),
        captureIntentId: captureIntentId,
      );

  RecordKind get recordKind => RecordKind.humanDetermination;
}

String canonicalWatchGoalV1(WatchGoalEnvelope entry) {
  return '{"schema":"$watchGoalSchemaV1",'
      '"matchId":${jsonEncode(entry.matchId)},'
      '"recordKind":"${RecordKind.humanDetermination.name}",'
      '"semanticType":"${V1SemanticTypeCode.goal.wireValue}",'
      '"authority":{"scope":"MAIN_REFEREE",'
      '"principalId":${jsonEncode(entry.principalId)},'
      '"generation":1,'
      '"writerDeviceId":${jsonEncode(entry.writerDeviceId)}},'
      '"origin":{"deviceId":${jsonEncode(entry.writerDeviceId)},'
      '"sequence":${entry.originSequence},'
      '"recordId":${jsonEncode(entry.recordId)}},'
      '"captureIntentId":${jsonEncode(entry.captureIntentId)},'
      '"scoringTeamId":${jsonEncode(entry.scoringTeamId)}}';
}

WatchGoalEnvelope? parseWatchGoalV1(String raw) {
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  final candidate = WatchGoalEnvelope(
    matchId: decoded['matchId'] as String? ?? '',
    recordId: (decoded['origin'] is Map)
        ? ((decoded['origin'] as Map)['recordId'] as String? ?? '')
        : '',
    captureIntentId: decoded['captureIntentId'] as String? ?? '',
    scoringTeamId: decoded['scoringTeamId'] as String? ?? '',
    principalId: (decoded['authority'] is Map)
        ? ((decoded['authority'] as Map)['principalId'] as String? ?? '')
        : '',
    writerDeviceId: (decoded['authority'] is Map)
        ? ((decoded['authority'] as Map)['writerDeviceId'] as String? ?? '')
        : '',
    originSequence: (decoded['origin'] is Map)
        ? ((decoded['origin'] as Map)['sequence'] as int? ?? 0)
        : 0,
  );
  if (candidate.canonical != raw.trim()) return null;
  if (candidate.goalPayload.semanticType != V1SemanticTypeCode.goal) {
    return null;
  }
  return candidate;
}
