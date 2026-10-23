/// Research interaction vocabulary. These values are not Match Records.
enum ResearchTeamSide { home, away }

enum TeamContextKind { absent, homeTrusted, awayTrusted, ambiguous }

enum SubjectKind { participant, official }

enum SubjectSelectionKind {
  none,
  participant,
  official,
  invalidated,
  unresolved,
}

enum PriorCautionKnowledge {
  knownNone,
  knownStanding,
  unavailable,
  conflicted,
}

enum SystemCommitKind { idle, saving, saved, notSaved, saveNotVerified }

enum ResearchScope { match, shootout, unresolved }

enum PresenceRank {
  onField,
  temporarilyOff,
  substitute,
  substituted,
  unknown,
  conflicted,
}

enum FinalActionKind {
  recordYellow,
  recordDirectSendOff,
  recordSecondCautionSendOff,
  recordSubstitution,
  recordGoal,
}

enum GoalFlowStage { inactive, selectTeam, selectScorer, readyToRecord }

/// Research sporting lifecycle. Not a production Match Record.
///
/// [matchNotStarted] has no football-time coordinate. A formatted `00:00`
/// is not this state.
enum ResearchMatchLifecycle { matchNotStarted, firstHalfRunning }

/// Period of an established research event. Only first half exists in S2.6A.
enum ResearchOccurrencePeriod { firstHalf }

/// Frozen football-time evidence. The label is a projection of [elapsedSeconds].
final class ResearchOccurrence {
  const ResearchOccurrence.firstHalf(this.elapsedSeconds)
      : period = ResearchOccurrencePeriod.firstHalf;

  final ResearchOccurrencePeriod period;
  final int elapsedSeconds;

  String get label => formatResearchMatchTime(elapsedSeconds);
}

/// Established research goal. Not a production Match Record.
final class SavedGoal {
  const SavedGoal({
    required this.eventId,
    required this.sequence,
    required this.scoringTeam,
    required this.scorerParticipantId,
    required this.matchTimeLabel,
    required this.originTrace,
    this.occurrence,
  });

  final String eventId;
  final int sequence;
  final ResearchTeamSide scoringTeam;
  final String scorerParticipantId;
  final String matchTimeLabel;
  final String originTrace;
  final ResearchOccurrence? occurrence;
}

String formatResearchMatchTime(int totalSeconds) {
  if (totalSeconds < 0) return 'Time unavailable';
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

enum SimulatedScriptedOutcome { success, failure, unknown }

enum SendOffPathwayLabel { direct, secondCaution }

enum SubstitutionStage {
  none,
  outOnly,
  inOnly,
  pairComplete,
  review,
  saving,
  saved,
  notSaved,
  saveNotVerified,
}

/// Research hit rectangle. Not a production layout law.
final class ResearchRect {
  const ResearchRect(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;

  bool contains(double x, double y) {
    return x >= left && y >= top && x < left + width && y < top + height;
  }

  bool overlaps(ResearchRect other) {
    return left < other.left + other.width &&
        other.left < left + width &&
        top < other.top + other.height &&
        other.top < top + height;
  }
}

final class ResearchLayout {
  const ResearchLayout({
    required this.yellow,
    required this.sendOff,
    required this.substitution,
    required this.roster,
  });

  static const phone = ResearchLayout(
    yellow: ResearchRect(16, 180, 150, 48),
    sendOff: ResearchRect(220, 180, 160, 48),
    substitution: ResearchRect(16, 250, 200, 48),
    roster: ResearchRect(16, 8, 320, 150),
  );

  final ResearchRect yellow;
  final ResearchRect sendOff;
  final ResearchRect substitution;
  final ResearchRect roster;

  ResearchRect regionFor(FinalActionKind kind) {
    return switch (kind) {
      FinalActionKind.recordYellow => yellow,
      FinalActionKind.recordDirectSendOff ||
      FinalActionKind.recordSecondCautionSendOff =>
        sendOff,
      FinalActionKind.recordSubstitution => substitution,
      FinalActionKind.recordGoal => yellow,
    };
  }
}

final class ResearchParticipant {
  const ResearchParticipant({
    required this.id,
    required this.team,
    required this.shirtLabel,
    required this.name,
    required this.presence,
  });

  final String id;
  final ResearchTeamSide team;
  final String shirtLabel;
  final String name;
  final PresenceRank presence;
}

final class ResearchOfficial {
  const ResearchOfficial({
    required this.id,
    required this.team,
    required this.name,
    required this.roleLabel,
  });

  final String id;
  final ResearchTeamSide team;
  final String name;
  final String roleLabel;
}

final class SavedCaution {
  const SavedCaution({
    required this.subjectId,
    required this.kind,
    required this.scope,
    this.eventId,
    this.sequence,
    this.matchTimeLabel,
    this.originTrace,
    this.occurrence,
  });

  final String subjectId;
  final SubjectKind kind;
  final ResearchScope scope;
  final String? eventId;
  final int? sequence;
  final String? matchTimeLabel;
  final String? originTrace;
  final ResearchOccurrence? occurrence;

  bool get reportable => sequence != null && matchTimeLabel != null;
}

final class SavedSendOff {
  const SavedSendOff({
    required this.subjectId,
    required this.kind,
    required this.scope,
    required this.pathway,
    this.eventId,
    this.sequence,
    this.matchTimeLabel,
    this.originTrace,
    this.occurrence,
  });

  final String subjectId;
  final SubjectKind kind;
  final ResearchScope scope;
  final SendOffPathwayLabel pathway;
  final String? eventId;
  final int? sequence;
  final String? matchTimeLabel;
  final String? originTrace;
  final ResearchOccurrence? occurrence;

  bool get reportable => sequence != null && matchTimeLabel != null;
}

final class SavedSubstitution {
  const SavedSubstitution({
    required this.outId,
    required this.inId,
    required this.team,
    this.eventId,
    this.sequence,
    this.matchTimeLabel,
    this.originTrace,
    this.occurrence,
  });

  final String outId;
  final String inId;
  final ResearchTeamSide team;
  final String? eventId;
  final int? sequence;
  final String? matchTimeLabel;
  final String? originTrace;
  final ResearchOccurrence? occurrence;

  bool get reportable => sequence != null && matchTimeLabel != null;
}

int presenceRankOrder(PresenceRank presence) {
  return switch (presence) {
    PresenceRank.onField => 0,
    PresenceRank.temporarilyOff => 1,
    PresenceRank.substitute => 2,
    PresenceRank.substituted => 3,
    PresenceRank.unknown => 4,
    PresenceRank.conflicted => 5,
  };
}
