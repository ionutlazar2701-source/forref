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
}) {
  final teamContext = switch (snapshot.teamContext) {
    TeamContextKind.absent => PresentationTeamContext.absent,
    TeamContextKind.homeTrusted => PresentationTeamContext.home,
    TeamContextKind.awayTrusted => PresentationTeamContext.away,
    TeamContextKind.ambiguous => PresentationTeamContext.ambiguous,
  };
  final scope = _scope(snapshot.scope);
  final selected = _selected(snapshot);
  final frozen = snapshot.inFlight == null
      ? null
      : FrozenCommandPresentation(
          action: _action(snapshot.inFlight!.kind),
          subjectId: snapshot.inFlight!.subjectId,
          scope: _scope(snapshot.inFlight!.scope),
          outId: snapshot.inFlight!.outId,
          inId: snapshot.inFlight!.inId,
        );
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
    clock: ClockPresentation.unavailable,
    score: ScorePresentation.unavailable,
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
  );
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
