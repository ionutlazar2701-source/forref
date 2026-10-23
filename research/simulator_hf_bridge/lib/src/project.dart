import 'package:hf_v2/hf_v2.dart';
import 'package:simulator_presentation/simulator_presentation.dart';

/// Projects a research snapshot into disposable presentation state.
///
/// This function does not append cautions, send-offs, or substitutions.
WatchPresentationState projectResearchSnapshot(
  ResearchTruthSnapshot snapshot, {
  required WatchRoute route,
  String? profileId,
  String? lastRejection,
  String homeTeamLabel = 'Home',
  String awayTeamLabel = 'Away',
}) {
  final teamContext = switch (snapshot.teamContext) {
    TeamContextKind.absent => PresentationTeamContext.absent,
    TeamContextKind.homeTrusted => PresentationTeamContext.home,
    TeamContextKind.awayTrusted => PresentationTeamContext.away,
    TeamContextKind.ambiguous => PresentationTeamContext.ambiguous,
  };
  final scope = _scope(snapshot.scope);
  final selected = _selected(snapshot);
  final inFlight = snapshot.inFlight;
  final frozen = inFlight == null
      ? null
      : FrozenCommandPresentation(
          action: _action(inFlight.kind),
          subjectId: inFlight.subjectId,
          scope: _scope(inFlight.scope),
          outId: inFlight.outId,
          inId: inFlight.inId,
          scoringTeam: inFlight.scoringTeam == null
              ? null
              : inFlight.scoringTeam == ResearchTeamSide.home
                  ? PresentationTeam.home
                  : PresentationTeam.away,
          goalScorerParticipantId: inFlight.goalScorerParticipantId,
          capturedMatchTimeLabel: inFlight.capturedMatchTimeLabel,
        );
  final homeGoals = snapshot.goals
      .where((goal) => goal.scoringTeam == ResearchTeamSide.home)
      .length;
  final awayGoals = snapshot.goals.length - homeGoals;
  final score = scoreFromGoalCounts(
    homeGoals: homeGoals,
    awayGoals: awayGoals,
    homeTeamLabel: homeTeamLabel,
    awayTeamLabel: awayTeamLabel,
  );
  final clock = snapshot.matchClockAvailable
      ? ClockPresentation(
          available: true,
          label: formatResearchMatchTime(snapshot.matchElapsedSeconds),
        )
      : ClockPresentation.unavailable;
  final commitRecognized = _recognized(snapshot.commitLabel);
  return WatchPresentationState(
    scenarioId: snapshot.scenarioId,
    profileId: profileId,
    header: MatchHeaderPresentation(
      scenarioId: snapshot.scenarioId,
      teamContext: teamContext,
      scope: scope,
      identityLabel: 'Research scenario ${snapshot.scenarioId}',
    ),
    clock: clock,
    score: score,
    selection: selected,
    discipline: DisciplinePresentation(
      awareness: switch (snapshot.priorCaution) {
        PriorCautionKnowledge.knownNone => PriorAwareness.knownNone,
        PriorCautionKnowledge.knownStanding => PriorAwareness.knownStanding,
        PriorCautionKnowledge.unavailable => PriorAwareness.unavailable,
        PriorCautionKnowledge.conflicted => PriorAwareness.conflicted,
      },
      awarenessLabel: snapshot.priorCautionLabel,
      cautionCount: snapshot.cautions.length,
      sendOffCount: snapshot.sendOffs.length,
      successorEstablished: snapshot.successorEstablished,
      yellowOffered: snapshot.yellowOffered,
      directSendOffOffered: snapshot.directSendOffOffered,
    ),
    substitution: SubstitutionPresentation(
      outId: snapshot.outId,
      inId: snapshot.inId,
      stageLabel: snapshot.substitutionStage.name,
    ),
    frozenCommand: frozen,
    commit: CommitPresentation(
      label: snapshot.commitLabel,
      recognizedResearchLabel: commitRecognized,
    ),
    navigation: NavigationPresentation(
      route: route,
      canOpenCapture: snapshot.freshInputEligible || snapshot.inFlight != null,
    ),
    roster: [
      for (final person in snapshot.roster)
        PresentationParticipant(
          id: person.id,
          team: person.team == ResearchTeamSide.home
              ? PresentationTeam.home
              : PresentationTeam.away,
          shirtLabel: person.shirtLabel,
          name: person.name,
        ),
    ],
    officials: [
      for (final official in snapshot.officials)
        PresentationOfficial(
          id: official.id,
          team: official.team == ResearchTeamSide.home
              ? PresentationTeam.home
              : PresentationTeam.away,
          name: official.name,
          roleLabel: official.roleLabel,
        ),
    ],
    recoveryLabel: snapshot.simulatedRecoveryDisclaimer
        ? ResearchCommitPhrases.simulatedRecovery
        : null,
    lastRejection: lastRejection,
    goalFlow: _goalFlow(snapshot),
    matchReport: _matchReport(snapshot, homeTeamLabel, awayTeamLabel),
    homeTeamLabel: homeTeamLabel,
    awayTeamLabel: awayTeamLabel,
  );
}

GoalFlowPresentation _goalFlow(ResearchTruthSnapshot snapshot) {
  final stage = switch (snapshot.goalFlowStage) {
    GoalFlowStage.inactive => GoalFlowStagePresentation.inactive,
    GoalFlowStage.selectTeam => GoalFlowStagePresentation.selectTeam,
    GoalFlowStage.selectScorer => GoalFlowStagePresentation.selectScorer,
    GoalFlowStage.readyToRecord => GoalFlowStagePresentation.readyToRecord,
  };
  PresentationTeam? team;
  if (snapshot.teamContext == TeamContextKind.homeTrusted) {
    team = PresentationTeam.home;
  } else if (snapshot.teamContext == TeamContextKind.awayTrusted) {
    team = PresentationTeam.away;
  }
  final canRecord = snapshot.goalFlowStage == GoalFlowStage.readyToRecord &&
      snapshot.matchClockAvailable;
  return GoalFlowPresentation(
    stage: stage,
    scoringTeam: team,
    scorerParticipantId: snapshot.selectedSubjectId,
    reviewMatchTimeLabel: snapshot.matchClockAvailable
        ? formatResearchMatchTime(snapshot.matchElapsedSeconds)
        : null,
    canRecord: canRecord,
    blockReason: snapshot.matchClockAvailable
        ? null
        : 'Match time unavailable',
  );
}

MatchReportPresentation _matchReport(
  ResearchTruthSnapshot snapshot,
  String homeTeamLabel,
  String awayTeamLabel,
) {
  var home = 0;
  var away = 0;
  final rows = <({
    String eventId,
    int sequence,
    String matchTimeLabel,
    String teamLabel,
    String participantDisplay,
    String scoreAfterLabel,
    String originTrace,
  })>[];
  final sorted = [...snapshot.goals]..sort((a, b) => a.sequence.compareTo(b.sequence));
  for (final goal in sorted) {
    if (goal.scoringTeam == ResearchTeamSide.home) {
      home += 1;
    } else {
      away += 1;
    }
    ResearchParticipant? person;
    for (final candidate in snapshot.roster) {
      if (candidate.id == goal.scorerParticipantId) {
        person = candidate;
        break;
      }
    }
    final display = person == null
        ? goal.scorerParticipantId
        : '#${person.shirtLabel} ${person.name}';
    final teamLabel =
        goal.scoringTeam == ResearchTeamSide.home ? homeTeamLabel : awayTeamLabel;
    rows.add(
      (
        eventId: goal.eventId,
        sequence: goal.sequence,
        matchTimeLabel: goal.matchTimeLabel,
        teamLabel: teamLabel,
        participantDisplay: display,
        scoreAfterLabel: '$home–$away',
        originTrace: goal.originTrace,
      ),
    );
  }
  return matchReportFromGoals(rows);
}

bool _recognized(String label) {
  return label == ResearchCommitPhrases.idle ||
      label == ResearchCommitPhrases.saving ||
      label == ResearchCommitPhrases.simulatedSaved ||
      label == ResearchCommitPhrases.notSaved ||
      label == ResearchCommitPhrases.saveNotVerified;
}

PresentationScope _scope(ResearchScope scope) {
  return switch (scope) {
    ResearchScope.match => PresentationScope.match,
    ResearchScope.shootout => PresentationScope.shootout,
    ResearchScope.unresolved => PresentationScope.unresolved,
  };
}

PresentationAction _action(FinalActionKind kind) {
  return switch (kind) {
    FinalActionKind.recordYellow => PresentationAction.yellow,
    FinalActionKind.recordDirectSendOff => PresentationAction.directSendOff,
    FinalActionKind.recordSecondCautionSendOff =>
      PresentationAction.secondCautionSendOff,
    FinalActionKind.recordSubstitution => PresentationAction.substitution,
    FinalActionKind.recordGoal => PresentationAction.goal,
  };
}

SelectionPresentation _selected(ResearchTruthSnapshot snapshot) {
  final id = snapshot.selectedSubjectId;
  if (id == null) {
    return const SelectionPresentation(
      subjectId: null,
      subjectKind: null,
      shirtLabel: null,
      name: null,
      team: null,
    );
  }
  if (snapshot.selectedSubjectKind == SubjectKind.participant) {
    for (final person in snapshot.roster) {
      if (person.id == id) {
        return SelectionPresentation(
          subjectId: person.id,
          subjectKind: PresentationSubjectKind.participant,
          shirtLabel: person.shirtLabel,
          name: person.name,
          team: person.team == ResearchTeamSide.home
              ? PresentationTeam.home
              : PresentationTeam.away,
        );
      }
    }
  }
  if (snapshot.selectedSubjectKind == SubjectKind.official) {
    for (final official in snapshot.officials) {
      if (official.id == id) {
        return SelectionPresentation(
          subjectId: official.id,
          subjectKind: PresentationSubjectKind.official,
          shirtLabel: null,
          name: official.name,
          team: official.team == ResearchTeamSide.home
              ? PresentationTeam.home
              : PresentationTeam.away,
        );
      }
    }
  }
  return SelectionPresentation(
    subjectId: id,
    subjectKind: snapshot.selectedSubjectKind == SubjectKind.official
        ? PresentationSubjectKind.official
        : PresentationSubjectKind.participant,
    shirtLabel: null,
    name: null,
    team: null,
  );
}
