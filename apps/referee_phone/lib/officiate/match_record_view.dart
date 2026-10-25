import 'package:forref_match_core/forref_match_core.dart';
import 'package:match_core/match_core.dart';

import '../infrastructure/identity/phone_capture_identity.dart';
import '../match_application/match_application_boundary.dart';

/// How far a read of Match Memory got. Empty history is not a numeral score.
enum MatchRecordAvailability { noCommittedRecords, readable, unavailable }

enum MatchRecordScoreKind { known, unavailable, conflicted }

enum MatchRecordFactKind {
  goal,
  matchStarted,
  periodStarted,
  periodEnded,
  matchEnded,
  other,
}

final class MatchRecordFact {
  const MatchRecordFact({
    required this.originSequence,
    required this.kind,
    this.teamId,
    this.periodIndex,
  });

  final int originSequence;
  final MatchRecordFactKind kind;
  final String? teamId;
  final int? periodIndex;
}

/// Read-only facts for one match. This value does not authorize a write.
final class MatchRecordView {
  const MatchRecordView({
    required this.availability,
    required this.scoreKind,
    required this.facts,
    required this.phaseUnavailable,
    required this.matchStarted,
    required this.matchNormallyEnded,
    required this.legacyFullTime,
    this.homeGoals,
    this.awayGoals,
    this.committedCount,
  });

  final MatchRecordAvailability availability;
  final MatchRecordScoreKind scoreKind;
  final int? homeGoals;
  final int? awayGoals;
  final List<MatchRecordFact> facts;
  final bool phaseUnavailable;
  final bool matchStarted;
  final bool matchNormallyEnded;
  final bool legacyFullTime;
  final int? committedCount;

  static const unavailable = MatchRecordView(
    availability: MatchRecordAvailability.unavailable,
    scoreKind: MatchRecordScoreKind.unavailable,
    facts: [],
    phaseUnavailable: true,
    matchStarted: false,
    matchNormallyEnded: false,
    legacyFullTime: false,
  );
}

/// Reads committed Match Memory and projects it. Does not commit.
Future<MatchRecordView> loadMatchRecordView({
  required MatchApplicationBoundary? boundary,
  required String matchId,
  required MatchStatus legacyStatus,
  required String homeTeamId,
  required String awayTeamId,
}) async {
  if (boundary == null) return MatchRecordView.unavailable;
  try {
    final records = await boundary.durableStore.readCommittedForMatch(matchId);
    final projection = await boundary.project(
      matchId,
      evaluatedAuthorityGeneration:
          PhoneCaptureIdentity.initialAuthorityGeneration,
    );
    final score = await boundary.readScoreProjection(
      matchId: matchId,
      evaluatedAuthorityGeneration:
          PhoneCaptureIdentity.initialAuthorityGeneration,
      homeTeamId: MatchTeamId(homeTeamId),
      awayTeamId: MatchTeamId(awayTeamId),
    );
    return assembleMatchRecordView(
      records: records,
      projection: projection,
      score: score,
      legacyStatus: legacyStatus,
      homeTeamId: homeTeamId,
      awayTeamId: awayTeamId,
    );
  } catch (_) {
    return MatchRecordView.unavailable;
  }
}

MatchRecordView assembleMatchRecordView({
  required List<MatchRecord> records,
  required MatchProjectionState projection,
  required ScoreProjection score,
  required MatchStatus legacyStatus,
  required String homeTeamId,
  required String awayTeamId,
}) {
  final legacyFullTime = legacyStatus == MatchStatus.fullTime;
  if (records.isEmpty) {
    return MatchRecordView(
      availability: MatchRecordAvailability.noCommittedRecords,
      scoreKind: MatchRecordScoreKind.unavailable,
      facts: const [],
      phaseUnavailable: false,
      matchStarted: false,
      matchNormallyEnded: false,
      legacyFullTime: legacyFullTime,
      committedCount: 0,
    );
  }

  final temporalTrust = projection.trustFor(ProjectionFacet.temporal);
  final temporal = TemporalMatchProjection.derive(
    projection: projection,
    records: records,
  );
  final startCount = records.where(_isMatchStarted).length;
  final phaseKnown =
      temporalTrust == ProjectionTrust.trusted && startCount == 1;
  final ordered = [...records]..sort(deterministicRecordOrder);
  final facts = <MatchRecordFact>[
    for (final record in ordered)
      if (_factFor(record, includeStart: phaseKnown) case final fact?) fact,
  ];

  final homeGoals =
      score is KnownScore ? score.goalsByTeam[MatchTeamId(homeTeamId)] : null;
  final awayGoals =
      score is KnownScore ? score.goalsByTeam[MatchTeamId(awayTeamId)] : null;
  final scoreKind = switch (score) {
    KnownScore() when homeGoals != null && awayGoals != null =>
      MatchRecordScoreKind.known,
    ScoreConflicted() => MatchRecordScoreKind.conflicted,
    _ => MatchRecordScoreKind.unavailable,
  };

  return MatchRecordView(
    availability: MatchRecordAvailability.readable,
    scoreKind: scoreKind,
    homeGoals: scoreKind == MatchRecordScoreKind.known ? homeGoals : null,
    awayGoals: scoreKind == MatchRecordScoreKind.known ? awayGoals : null,
    facts: facts,
    phaseUnavailable: !phaseKnown,
    matchStarted: phaseKnown && temporal.matchStarted,
    matchNormallyEnded: phaseKnown && temporal.matchNormallyEnded,
    legacyFullTime: legacyFullTime,
    committedCount: records.length,
  );
}

MatchRecordFact? _factFor(MatchRecord record, {required bool includeStart}) {
  final payload = record.payload;
  if (payload is GoalPayload) {
    return MatchRecordFact(
      originSequence: record.originSequence,
      kind: MatchRecordFactKind.goal,
      teamId: payload.scoringTeamId.value,
    );
  }
  if (payload is! TemporalTransitionPayload) {
    return MatchRecordFact(
      originSequence: record.originSequence,
      kind: MatchRecordFactKind.other,
    );
  }
  final kind = switch (payload.semanticType) {
    V1SemanticTypeCode.matchStarted when includeStart =>
      MatchRecordFactKind.matchStarted,
    V1SemanticTypeCode.periodStarted when includeStart =>
      MatchRecordFactKind.periodStarted,
    V1SemanticTypeCode.periodEnded when includeStart =>
      MatchRecordFactKind.periodEnded,
    V1SemanticTypeCode.matchEnded when includeStart =>
      MatchRecordFactKind.matchEnded,
    _ => null,
  };
  if (kind == null) return null;
  return MatchRecordFact(
    originSequence: record.originSequence,
    kind: kind,
    periodIndex: payload.period?.index,
  );
}

bool _isMatchStarted(MatchRecord record) {
  final payload = record.payload;
  return payload is TemporalTransitionPayload &&
      payload.semanticType == V1SemanticTypeCode.matchStarted;
}
