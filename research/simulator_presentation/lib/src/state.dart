/// Routes the watch reference app can show.
enum WatchRoute {
  liveCore,
  captureMenu,
  yellowFlow,
  sendOffFlow,
  substitutionFlow,
  disciplinaryAwareness,
  history,
}

enum PresentationTeam { home, away }

enum PresentationTeamContext { absent, home, away, ambiguous }

enum PresentationScope { match, shootout, unresolved }

enum PresentationSubjectKind { participant, official }

enum PriorAwareness { knownNone, knownStanding, unavailable, conflicted }

enum PresentationAction {
  yellow,
  directSendOff,
  secondCautionSendOff,
  substitution,
}

/// Research-mode commit text. These phrases are not production D1.
abstract final class ResearchCommitPhrases {
  static const idle = 'Idle';
  static const saving = 'Saving — simulated';
  static const simulatedSaved = 'SIMULATED SAVED — not production D1';
  static const notSaved = 'NOT SAVED — known simulated failure';
  static const saveNotVerified = 'SAVE NOT VERIFIED — outcome is not known';
  static const simulatedRecovery = 'SIMULATED RECOVERY BEHAVIOR';
}

final class MatchHeaderPresentation {
  const MatchHeaderPresentation({
    required this.scenarioId,
    required this.teamContext,
    required this.scope,
    required this.identityLabel,
  });

  final String scenarioId;
  final PresentationTeamContext teamContext;
  final PresentationScope scope;
  final String identityLabel;
}

final class ClockPresentation {
  const ClockPresentation({required this.available, required this.label});

  final bool available;
  final String? label;

  static const unavailable = ClockPresentation(
    available: false,
    label: 'Clock unavailable',
  );
}

final class ScorePresentation {
  const ScorePresentation({
    required this.available,
    required this.label,
    this.homeGoals,
    this.awayGoals,
  });

  final bool available;
  final String label;
  final int? homeGoals;
  final int? awayGoals;

  static const unavailable = ScorePresentation(
    available: false,
    label: 'Score unavailable',
  );
}

final class SelectionPresentation {
  const SelectionPresentation({
    required this.subjectId,
    required this.subjectKind,
    required this.shirtLabel,
    required this.name,
    required this.team,
  });

  final String? subjectId;
  final PresentationSubjectKind? subjectKind;
  final String? shirtLabel;
  final String? name;
  final PresentationTeam? team;
}

final class DisciplinePresentation {
  const DisciplinePresentation({
    required this.awareness,
    required this.awarenessLabel,
    required this.cautionCount,
    required this.sendOffCount,
    required this.successorEstablished,
    required this.yellowOffered,
    required this.directSendOffOffered,
  });

  final PriorAwareness awareness;
  final String awarenessLabel;
  final int cautionCount;
  final int sendOffCount;
  final bool successorEstablished;
  final bool yellowOffered;
  final bool directSendOffOffered;
}

final class SubstitutionPresentation {
  const SubstitutionPresentation({
    required this.outId,
    required this.inId,
    required this.stageLabel,
  });

  final String? outId;
  final String? inId;
  final String stageLabel;
}

final class FrozenCommandPresentation {
  const FrozenCommandPresentation({
    required this.action,
    required this.subjectId,
    required this.scope,
    required this.outId,
    required this.inId,
  });

  final PresentationAction action;
  final String? subjectId;
  final PresentationScope scope;
  final String? outId;
  final String? inId;
}

final class CommitPresentation {
  const CommitPresentation({
    required this.label,
    required this.recognizedResearchLabel,
  });

  final String label;
  final bool recognizedResearchLabel;
}

final class NavigationPresentation {
  const NavigationPresentation({
    required this.route,
    required this.canOpenCapture,
  });

  final WatchRoute route;
  final bool canOpenCapture;
}

final class PresentationParticipant {
  const PresentationParticipant({
    required this.id,
    required this.team,
    required this.shirtLabel,
    required this.name,
  });

  final String id;
  final PresentationTeam team;
  final String shirtLabel;
  final String name;
}

final class PresentationOfficial {
  const PresentationOfficial({
    required this.id,
    required this.team,
    required this.name,
    required this.roleLabel,
  });

  final String id;
  final PresentationTeam team;
  final String name;
  final String roleLabel;
}

/// Disposable watch read model.
///
/// Shirt label is display text. [SelectionPresentation.subjectId] is identity.
final class WatchPresentationState {
  const WatchPresentationState({
    required this.scenarioId,
    required this.profileId,
    required this.header,
    required this.clock,
    required this.score,
    required this.selection,
    required this.discipline,
    required this.substitution,
    required this.frozenCommand,
    required this.commit,
    required this.navigation,
    required this.roster,
    required this.officials,
    required this.recoveryLabel,
    required this.lastRejection,
  });

  final String scenarioId;
  final String? profileId;
  final MatchHeaderPresentation header;
  final ClockPresentation clock;
  final ScorePresentation score;
  final SelectionPresentation selection;
  final DisciplinePresentation discipline;
  final SubstitutionPresentation substitution;
  final FrozenCommandPresentation? frozenCommand;
  final CommitPresentation commit;
  final NavigationPresentation navigation;
  final List<PresentationParticipant> roster;
  final List<PresentationOfficial> officials;
  final String? recoveryLabel;
  final String? lastRejection;

  static const empty = WatchPresentationState(
    scenarioId: '',
    profileId: null,
    header: MatchHeaderPresentation(
      scenarioId: '',
      teamContext: PresentationTeamContext.absent,
      scope: PresentationScope.unresolved,
      identityLabel: 'No research scenario loaded',
    ),
    clock: ClockPresentation.unavailable,
    score: ScorePresentation.unavailable,
    selection: SelectionPresentation(
      subjectId: null,
      subjectKind: null,
      shirtLabel: null,
      name: null,
      team: null,
    ),
    discipline: DisciplinePresentation(
      awareness: PriorAwareness.unavailable,
      awarenessLabel: 'Prior caution unavailable',
      cautionCount: 0,
      sendOffCount: 0,
      successorEstablished: false,
      yellowOffered: false,
      directSendOffOffered: false,
    ),
    substitution: SubstitutionPresentation(
      outId: null,
      inId: null,
      stageLabel: 'none',
    ),
    frozenCommand: null,
    commit: CommitPresentation(label: ResearchCommitPhrases.idle, recognizedResearchLabel: true),
    navigation: NavigationPresentation(route: WatchRoute.liveCore, canOpenCapture: false),
    roster: [],
    officials: [],
    recoveryLabel: null,
    lastRejection: null,
  );
}
