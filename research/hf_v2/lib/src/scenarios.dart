import 'model.dart';

enum ScenarioId {
  s01YellowNoPrior,
  s02YellowOnePrior,
  s03YellowPriorUnavailable,
  s04YellowPriorConflicted,
  s05Y2SendOffContinuation,
  s06Y2InterruptThenSendOff,
  s07RapidRepeatAfterY2,
  s08DirectRedWithPriorYellow,
  s09Home14ThenAway14,
  s10SimilarOfficials,
  s11SubstitutionOutFirst,
  s12SubstitutionInFirst,
  s13SubstitutionInterruptAfterFirst,
  s14SubstitutionInterruptAfterPair,
  s15InterruptWhileSaving,
  s16SaveNotVerified,
  s17FinishLaterSimulatedRestart,
  s18MatchToShootout,
  s19SentOffHistoricalReview,
  s20GoalMatchReport,
  vDuplicateShirt,
  vCrossTeamShirt,
  vSimilarNames,
  vLongOfficialName,
  vTemporarilyOff,
  vSubstituted,
  vStaleStatus,
  vUnavailableStatus,
  vConflictedStatus,
  vTeamTrusted,
  vTeamAbsent,
}

final class ScenarioFixture {
  const ScenarioFixture({
    required this.id,
    required this.pitchTruth,
    required this.digitalTruth,
    required this.unfinishedTruth,
    required this.p0Failure,
    required this.team,
    required this.scope,
    required this.priorCaution,
    required this.roster,
    required this.officials,
    required this.script,
    this.initialSelection = SubjectSelectionKind.participant,
    this.initialParticipantId = 'p-home-9',
    this.initialOfficialId,
    this.initialOutId,
    this.initialInId,
    this.initialSubstitutionStage = SubstitutionStage.none,
    this.initialCommit = SystemCommitKind.idle,
    this.seededCautions = const [],
    this.seededSendOffs = const [],
    this.successorAlreadyEstablished = false,
    this.predecessorKind,
    this.simulatedRecoveryDisclaimer = false,
    this.initialMatchElapsedSeconds = 0,
    this.matchClockAvailable = true,
  });

  final ScenarioId id;
  final String pitchTruth;
  final String digitalTruth;
  final String unfinishedTruth;
  final String p0Failure;
  final TeamContextKind team;
  final ResearchScope scope;
  final PriorCautionKnowledge priorCaution;
  final List<ResearchParticipant> roster;
  final List<ResearchOfficial> officials;
  final Map<FinalActionKind, SimulatedScriptedOutcome> script;
  final SubjectSelectionKind initialSelection;
  final String? initialParticipantId;
  final String? initialOfficialId;
  final String? initialOutId;
  final String? initialInId;
  final SubstitutionStage initialSubstitutionStage;
  final SystemCommitKind initialCommit;
  final List<SavedCaution> seededCautions;
  final List<SavedSendOff> seededSendOffs;
  final bool successorAlreadyEstablished;
  final FinalActionKind? predecessorKind;
  final bool simulatedRecoveryDisclaimer;
  final int initialMatchElapsedSeconds;
  final bool matchClockAvailable;
}

const _successScript = {
  FinalActionKind.recordYellow: SimulatedScriptedOutcome.success,
  FinalActionKind.recordDirectSendOff: SimulatedScriptedOutcome.success,
  FinalActionKind.recordSecondCautionSendOff: SimulatedScriptedOutcome.success,
  FinalActionKind.recordSubstitution: SimulatedScriptedOutcome.success,
  FinalActionKind.recordGoal: SimulatedScriptedOutcome.success,
};

ScenarioFixture scenarioFixture(ScenarioId id) {
  final built = _fixtures[id];
  if (built == null) {
    throw StateError('Missing scenario fixture ${id.name}');
  }
  return built;
}

List<ScenarioId> get coreScenarios => ScenarioId.values
    .where((id) => id.name.startsWith('s'))
    .toList(growable: false);

final Map<ScenarioId, ScenarioFixture> _fixtures = {
  for (final fixture in _buildFixtures()) fixture.id: fixture,
};

List<ScenarioFixture> _buildFixtures() {
  final roster = _roster();
  final officials = _officials();
  SavedCaution caution(String id, [ResearchScope scope = ResearchScope.match]) {
    return SavedCaution(
      subjectId: id,
      kind: SubjectKind.participant,
      scope: scope,
    );
  }

  ScenarioFixture base({
    required ScenarioId id,
    required String pitch,
    required String digital,
    required String unfinished,
    required String p0,
    TeamContextKind team = TeamContextKind.homeTrusted,
    ResearchScope scope = ResearchScope.match,
    PriorCautionKnowledge prior = PriorCautionKnowledge.knownNone,
    List<SavedCaution> seeded = const [],
    List<SavedSendOff> sendOffs = const [],
    SubjectSelectionKind selection = SubjectSelectionKind.participant,
    String? participantId = 'p-home-9',
    String? officialId,
    String? outId,
    String? inId,
    SubstitutionStage substitution = SubstitutionStage.none,
    SystemCommitKind commit = SystemCommitKind.idle,
    bool successor = false,
    bool simulatedRecovery = false,
    Map<FinalActionKind, SimulatedScriptedOutcome> script = _successScript,
    List<ResearchParticipant>? people,
    List<ResearchOfficial>? staff,
    int initialMatchElapsedSeconds = 0,
    bool matchClockAvailable = true,
  }) {
    return ScenarioFixture(
      id: id,
      pitchTruth: pitch,
      digitalTruth: digital,
      unfinishedTruth: unfinished,
      p0Failure: p0,
      team: team,
      scope: scope,
      priorCaution: prior,
      roster: people ?? roster,
      officials: staff ?? officials,
      script: script,
      initialSelection: selection,
      initialParticipantId: participantId,
      initialOfficialId: officialId,
      initialOutId: outId,
      initialInId: inId,
      initialSubstitutionStage: substitution,
      initialCommit: commit,
      seededCautions: seeded,
      seededSendOffs: sendOffs,
      successorAlreadyEstablished: successor,
      predecessorKind:
          successor ? FinalActionKind.recordYellow : null,
      simulatedRecoveryDisclaimer: simulatedRecovery,
      initialMatchElapsedSeconds: initialMatchElapsedSeconds,
      matchClockAvailable: matchClockAvailable,
    );
  }

  return [
    base(
      id: ScenarioId.s01YellowNoPrior,
      pitch: 'Home 9 is cautioned. No earlier caution happened.',
      digital: 'Known verified absence before this yellow.',
      unfinished: 'Subject selected. Yellow not saved.',
      p0: 'Showing a standing caution before a simulated save.',
    ),
    base(
      id: ScenarioId.s02YellowOnePrior,
      pitch: 'Home 9 already has one standing caution.',
      digital: 'One saved research caution. Not two.',
      unfinished: 'Second yellow not committed.',
      p0: 'Saying two cautions are recorded before the second save.',
      prior: PriorCautionKnowledge.knownStanding,
      seeded: [caution('p-home-9')],
    ),
    base(
      id: ScenarioId.s03YellowPriorUnavailable,
      pitch: 'A caution may have happened. The record is incomplete.',
      digital: 'Prior caution unavailable. Not known none.',
      unfinished: 'No new yellow saved.',
      p0: 'Rendering unavailable history as verified absence.',
      prior: PriorCautionKnowledge.unavailable,
    ),
    base(
      id: ScenarioId.s04YellowPriorConflicted,
      pitch: 'Caution history disagrees with itself.',
      digital: 'Prior caution conflicted. Not known none.',
      unfinished: 'No new yellow saved.',
      p0: 'Rendering conflicted history as verified absence.',
      prior: PriorCautionKnowledge.conflicted,
    ),
    base(
      id: ScenarioId.s05Y2SendOffContinuation,
      pitch: 'Home 9 receives a second caution. The referee has not sent the player off.',
      digital: 'One saved caution. SEND_OFF absent until a fresh action.',
      unfinished: 'Second yellow not saved. Send-off not armed.',
      p0: 'A yellow gesture also records a sending-off.',
      prior: PriorCautionKnowledge.knownStanding,
      seeded: [caution('p-home-9')],
    ),
    base(
      id: ScenarioId.s06Y2InterruptThenSendOff,
      pitch: 'Second caution is given. The referee attends to the wall before sending off.',
      digital: 'SEND_OFF stays absent across the interruption.',
      unfinished: 'Send-off needs a new action after resume.',
      p0: 'Interruption records a sending-off.',
      prior: PriorCautionKnowledge.knownStanding,
      seeded: [caution('p-home-9')],
    ),
    base(
      id: ScenarioId.s07RapidRepeatAfterY2,
      pitch: 'The finger taps the yellow control twice.',
      digital: 'At most the yellow save. SEND_OFF absent.',
      unfinished: 'The second tap is not a sending-off.',
      p0: 'Repeat contact on the yellow location records SEND_OFF.',
      prior: PriorCautionKnowledge.knownStanding,
      seeded: [caution('p-home-9')],
    ),
    base(
      id: ScenarioId.s08DirectRedWithPriorYellow,
      pitch: 'Home 9 already has a yellow. The referee sends the player off directly.',
      digital: 'Pathway DIRECT. The prior yellow is not a second-caution dependency.',
      unfinished: 'Direct send-off not saved until its own action.',
      p0: 'Inferring second-caution from the prior yellow.',
      prior: PriorCautionKnowledge.knownStanding,
      seeded: [caution('p-home-9')],
    ),
    base(
      id: ScenarioId.s09Home14ThenAway14,
      pitch: 'The referee tapped Home 14, then realized it was Away 14.',
      digital: 'No caution saved for either 14.',
      unfinished: 'Home 14 must be invalidated by the team change.',
      p0: 'Home 14 remains selected as Away 14.',
      participantId: 'p-home-14',
    ),
    base(
      id: ScenarioId.s10SimilarOfficials,
      pitch: 'Two home staff share the name Alex Popescu and different roles.',
      digital: 'No official caution saved.',
      unfinished: 'No official is selected until the referee chooses one.',
      p0: 'Auto-selecting an official from a similar name.',
      selection: SubjectSelectionKind.none,
      participantId: null,
    ),
    base(
      id: ScenarioId.s11SubstitutionOutFirst,
      pitch: 'Home 9 leaves. Home 7 enters. The substitution is not complete until recorded.',
      digital: 'No substitution recorded.',
      unfinished: 'OUT may be selected. IN and record are still open.',
      p0: 'OUT-only becomes a recorded substitution.',
      selection: SubjectSelectionKind.none,
      participantId: null,
    ),
    base(
      id: ScenarioId.s12SubstitutionInFirst,
      pitch: 'The referee names the entering player first.',
      digital: 'No substitution recorded.',
      unfinished: 'IN-only is not a substitution.',
      p0: 'IN-only becomes a recorded substitution.',
      selection: SubjectSelectionKind.none,
      participantId: null,
    ),
    base(
      id: ScenarioId.s13SubstitutionInterruptAfterFirst,
      pitch: 'The referee names OUT and is interrupted.',
      digital: 'No substitution recorded.',
      unfinished: 'OUT remains OUT after resume.',
      p0: 'Interruption clears or swaps OUT.',
      selection: SubjectSelectionKind.none,
      participantId: null,
    ),
    base(
      id: ScenarioId.s14SubstitutionInterruptAfterPair,
      pitch: 'OUT and IN are named. The referee has not recorded the substitution.',
      digital: 'No substitution recorded.',
      unfinished: 'The pair stays in review. Roles do not reverse.',
      p0: 'Interruption or roster reorder reverses OUT and IN.',
      selection: SubjectSelectionKind.none,
      participantId: null,
    ),
    base(
      id: ScenarioId.s15InterruptWhileSaving,
      pitch: 'A yellow is in the simulated save when the phone is interrupted.',
      digital: 'No new caution is saved by the interruption.',
      unfinished: 'Outcome becomes save not verified, not saved and not a known failure.',
      p0: 'Interruption marks the event saved.',
      prior: PriorCautionKnowledge.knownNone,
    ),
    base(
      id: ScenarioId.s16SaveNotVerified,
      pitch: 'The simulated commit ends without a known result.',
      digital: 'The caution is not saved and not marked as a known failure.',
      unfinished: 'A blind new submission is refused.',
      p0: 'Unknown outcome displayed as Saved or Not saved.',
      script: {
        FinalActionKind.recordYellow: SimulatedScriptedOutcome.unknown,
        FinalActionKind.recordDirectSendOff: SimulatedScriptedOutcome.unknown,
        FinalActionKind.recordSecondCautionSendOff:
            SimulatedScriptedOutcome.unknown,
        FinalActionKind.recordSubstitution: SimulatedScriptedOutcome.unknown,
      },
    ),
    base(
      id: ScenarioId.s17FinishLaterSimulatedRestart,
      pitch: 'The referee leaves the action and comes back later.',
      digital: 'No production recovery is claimed. One prior caution remains only if it was already saved.',
      unfinished: 'Save not verified stays distinct from not saved.',
      p0: 'Labeling this restart as a production recovery guarantee.',
      prior: PriorCautionKnowledge.knownStanding,
      seeded: [caution('p-home-9')],
      commit: SystemCommitKind.saveNotVerified,
      simulatedRecovery: true,
    ),
    base(
      id: ScenarioId.s18MatchToShootout,
      pitch: 'Match caution stands. The next action is in the shoot-out.',
      digital: 'Match and shoot-out ledgers stay separate.',
      unfinished: 'Shoot-out does not inherit the match caution as its own ledger.',
      p0: 'Combining match and shoot-out cautions into one count.',
      prior: PriorCautionKnowledge.knownStanding,
      seeded: [caution('p-home-9')],
    ),
    base(
      id: ScenarioId.s19SentOffHistoricalReview,
      pitch: 'Home 9 was sent off after two cautions. The history is still inspectable.',
      digital: 'Two cautions remain. Active caution surface is closed by the saved send-off.',
      unfinished: 'No new yellow is offered by history review.',
      p0: 'Deleting yellow history because of the send-off.',
      prior: PriorCautionKnowledge.knownStanding,
      seeded: [caution('p-home-9'), caution('p-home-9')],
      sendOffs: [
        SavedSendOff(
          subjectId: 'p-home-9',
          kind: SubjectKind.participant,
          scope: ResearchScope.match,
          pathway: SendOffPathwayLabel.secondCaution,
        ),
      ],
    ),
    base(
      id: ScenarioId.s20GoalMatchReport,
      pitch: 'Research match for Goal capture and Match Report review.',
      digital: 'Score and report follow established goals only.',
      unfinished: 'No goal is saved until simulated success completes.',
      p0: 'Inventing goals, scorers, or match times without establishment.',
      team: TeamContextKind.absent,
      scope: ResearchScope.match,
      selection: SubjectSelectionKind.none,
      participantId: null,
      people: _goalOpsRoster(),
      initialMatchElapsedSeconds: 0,
    ),
    base(
      id: ScenarioId.vDuplicateShirt,
      pitch: 'Two home players wear 7.',
      digital: 'Each player id stays distinct.',
      unfinished: 'Shirt 7 does not select both.',
      p0: 'Two players with shirt 7 collapse to one id.',
      people: _roster(duplicateShirt: true),
    ),
    base(
      id: ScenarioId.vCrossTeamShirt,
      pitch: 'Home 14 and Away 14 are both on the pitch.',
      digital: 'The shirt label is not the id.',
      unfinished: 'Home 14 is selected.',
      p0: 'Away 14 is treated as the selected home player.',
      participantId: 'p-home-14',
    ),
    base(
      id: ScenarioId.vSimilarNames,
      pitch: 'Two outfield players have similar names.',
      digital: 'No event saved.',
      unfinished: 'The selected id is the one the referee tapped.',
      p0: 'A similar name replaces the selected id.',
      people: _roster(similarNames: true),
    ),
    base(
      id: ScenarioId.vLongOfficialName,
      pitch: 'A team official has a long name and role.',
      digital: 'No official caution saved.',
      unfinished: 'The official is not selected until tapped.',
      p0: 'Truncation selects a different official.',
      selection: SubjectSelectionKind.none,
      participantId: null,
      staff: _officials(longName: true),
    ),
    base(
      id: ScenarioId.vTemporarilyOff,
      pitch: 'Home 9 is temporarily off the pitch and still identifiable.',
      digital: 'No event saved.',
      unfinished: 'The player remains in the roster.',
      p0: 'Temporary absence hides the player.',
      participantId: 'p-home-temp',
      people: _roster(),
    ),
    base(
      id: ScenarioId.vSubstituted,
      pitch: 'A substituted player remains identifiable.',
      digital: 'No new substitution is saved by recognition.',
      unfinished: 'The substituted player is still listed.',
      p0: 'Substituted status removes the player from the roster.',
      participantId: 'p-home-subbed',
    ),
    base(
      id: ScenarioId.vStaleStatus,
      pitch: 'Status on screen may be stale. Identity is not.',
      digital: 'No event saved.',
      unfinished: 'The same id remains selected.',
      p0: 'Stale status mints a new id.',
      participantId: 'p-home-9',
    ),
    base(
      id: ScenarioId.vUnavailableStatus,
      pitch: 'Presence is unknown.',
      digital: 'Unknown presence is not converted into on-field certainty.',
      unfinished: 'The player is still listed.',
      p0: 'Unknown presence hides the player or invents on-field.',
      participantId: 'p-home-unknown',
    ),
    base(
      id: ScenarioId.vConflictedStatus,
      pitch: 'Presence evidence conflicts.',
      digital: 'Conflicted presence is not a verified on-field state.',
      unfinished: 'The player is still listed.',
      p0: 'Conflicted presence is shown as a normal on-field player without a mark.',
      participantId: 'p-home-conflict',
    ),
    base(
      id: ScenarioId.vTeamTrusted,
      pitch: 'The scenario already trusts Home.',
      digital: 'No event saved.',
      unfinished: 'A team tap is optional.',
      p0: 'Ignoring the established home context.',
    ),
    base(
      id: ScenarioId.vTeamAbsent,
      pitch: 'No team is trusted yet.',
      digital: 'No event saved.',
      unfinished: 'Subject stays unresolved until a team exists.',
      p0: 'Inferring a team from the last screen side.',
      team: TeamContextKind.absent,
      selection: SubjectSelectionKind.none,
      participantId: null,
    ),
  ];
}

List<ResearchParticipant> _goalOpsRoster() {
  return [
    const ResearchParticipant(
      id: 'p-home-9',
      team: ResearchTeamSide.home,
      shirtLabel: '9',
      name: 'Popescu',
      presence: PresenceRank.onField,
    ),
    const ResearchParticipant(
      id: 'p-home-14',
      team: ResearchTeamSide.home,
      shirtLabel: '14',
      name: 'Mihai Pop',
      presence: PresenceRank.onField,
    ),
    const ResearchParticipant(
      id: 'p-away-14',
      team: ResearchTeamSide.away,
      shirtLabel: '14',
      name: 'Radu Stan',
      presence: PresenceRank.onField,
    ),
    const ResearchParticipant(
      id: 'p-away-11',
      team: ResearchTeamSide.away,
      shirtLabel: '11',
      name: 'Matei Ionescu',
      presence: PresenceRank.onField,
    ),
  ];
}

List<ResearchParticipant> _roster({
  bool duplicateShirt = false,
  bool similarNames = false,
}) {
  return [
    ResearchParticipant(
      id: 'p-home-9',
      team: ResearchTeamSide.home,
      shirtLabel: '9',
      name: similarNames ? 'Andrei Pop' : 'Andrei Ionescu',
      presence: PresenceRank.onField,
    ),
    ResearchParticipant(
      id: 'p-home-14',
      team: ResearchTeamSide.home,
      shirtLabel: '14',
      name: similarNames ? 'Andrei Popa' : 'Mihai Pop',
      presence: PresenceRank.onField,
    ),
    ResearchParticipant(
      id: 'p-away-14',
      team: ResearchTeamSide.away,
      shirtLabel: '14',
      name: 'Radu Stan',
      presence: PresenceRank.onField,
    ),
    ResearchParticipant(
      id: 'p-home-7',
      team: ResearchTeamSide.home,
      shirtLabel: '7',
      name: 'Luca Dima',
      presence: PresenceRank.onField,
    ),
    ResearchParticipant(
      id: duplicateShirt ? 'p-home-7b' : 'p-home-12',
      team: ResearchTeamSide.home,
      shirtLabel: duplicateShirt ? '7' : '12',
      name: 'Ioan Marin',
      presence: PresenceRank.substitute,
    ),
    const ResearchParticipant(
      id: 'p-home-temp',
      team: ResearchTeamSide.home,
      shirtLabel: '4',
      name: 'Vlad Enache',
      presence: PresenceRank.temporarilyOff,
    ),
    const ResearchParticipant(
      id: 'p-home-subbed',
      team: ResearchTeamSide.home,
      shirtLabel: '11',
      name: 'Paul Nistor',
      presence: PresenceRank.substituted,
    ),
    const ResearchParticipant(
      id: 'p-home-unknown',
      team: ResearchTeamSide.home,
      shirtLabel: '18',
      name: 'Unknown Presence',
      presence: PresenceRank.unknown,
    ),
    const ResearchParticipant(
      id: 'p-home-conflict',
      team: ResearchTeamSide.home,
      shirtLabel: '19',
      name: 'Conflicted Presence',
      presence: PresenceRank.conflicted,
    ),
  ];
}

List<ResearchOfficial> _officials({bool longName = false}) {
  return [
    const ResearchOfficial(
      id: 'o-alex-assistant',
      team: ResearchTeamSide.home,
      name: 'Alex Popescu',
      roleLabel: 'assistant coach',
    ),
    const ResearchOfficial(
      id: 'o-alex-doctor',
      team: ResearchTeamSide.home,
      name: 'Alex Popescu',
      roleLabel: 'team doctor',
    ),
    ResearchOfficial(
      id: 'o-long',
      team: ResearchTeamSide.home,
      name: longName
          ? 'Alexandru-Constantin Popescu-Ionescu'
          : 'Alexandru Popescu',
      roleLabel: longName
          ? 'head of delegation and matchday operations lead'
          : 'head of delegation',
    ),
  ];
}
