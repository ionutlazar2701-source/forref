import 'model.dart';
import 'recovery_claim.dart';
import 'research_log.dart';
import 'scenarios.dart';
import 'snapshot.dart';

final class _PointerTrack {
  _PointerTrack({
    required this.pointerId,
    required this.x,
    required this.y,
    required this.captured,
    required this.generation,
  });

  final int pointerId;
  final double x;
  final double y;
  final FinalActionKind? captured;
  final int generation;
  bool consumed = false;
}

/// Identity frozen when a research action is activated.
///
/// Later team, subject, scope, or pair edits belong to the unfinished layer.
/// They do not retarget a command that is already saving.
final class _ActivatedCommand {
  const _ActivatedCommand({
    required this.kind,
    required this.subjectId,
    required this.subjectKind,
    required this.scope,
    required this.outId,
    required this.inId,
    this.scoringTeam,
    this.goalScorerParticipantId,
    this.capturedMatchTimeLabel,
    this.originTrace = 'research',
  });

  final FinalActionKind kind;
  final String? subjectId;
  final SubjectKind? subjectKind;
  final ResearchScope scope;
  final String? outId;
  final String? inId;
  final ResearchTeamSide? scoringTeam;
  final String? goalScorerParticipantId;
  final String? capturedMatchTimeLabel;
  final String originTrace;
}

/// Deterministic research session.
///
/// Pitch context, digital simulation, unfinished selection, and commit outcome
/// stay in separate fields. Nothing here writes production Match Memory.
final class ResearchInstrument {
  ResearchInstrument({
    this.loggingEnabled = true,
    ResearchLogSink? sink,
  }) : _sink = sink;

  bool loggingEnabled;
  final ResearchLogSink? _sink;
  final List<ResearchLogEvent> _events = [];
  int _sequence = 0;

  ScenarioId scenarioId = ScenarioId.s01YellowNoPrior;
  String pitchTruth = '';
  String expectedDigitalTruth = '';
  String expectedUnfinishedTruth = '';
  String p0Failure = '';
  bool simulatedRecoveryDisclaimer = false;

  TeamContextKind teamContext = TeamContextKind.absent;
  ResearchScope scope = ResearchScope.match;
  PriorCautionKnowledge priorCaution = PriorCautionKnowledge.knownNone;

  List<ResearchParticipant> roster = const [];
  List<ResearchOfficial> officials = const [];

  SubjectSelectionKind selectionKind = SubjectSelectionKind.none;
  String? selectedParticipantId;
  String? selectedOfficialId;

  String? outId;
  String? inId;
  SubstitutionStage substitutionStage = SubstitutionStage.none;

  bool yellowOffered = false;
  bool directSendOffOffered = false;

  SystemCommitKind commitKind = SystemCommitKind.idle;
  FinalActionKind? pendingAction;
  FinalActionKind? lastActivated;
  _ActivatedCommand? _activated;

  final List<SavedCaution> cautions = [];
  final List<SavedSendOff> sendOffs = [];
  final List<SavedSubstitution> substitutions = [];
  final List<SavedGoal> goals = [];

  int matchElapsedSeconds = 0;
  bool matchClockAvailable = true;
  GoalFlowStage goalFlowStage = GoalFlowStage.inactive;
  bool goalOffered = false;
  int _reportSequence = 0;
  String _pendingOriginTrace = 'research';

  final Map<FinalActionKind, SimulatedScriptedOutcome> _script = {
    FinalActionKind.recordYellow: SimulatedScriptedOutcome.success,
    FinalActionKind.recordDirectSendOff: SimulatedScriptedOutcome.success,
    FinalActionKind.recordSecondCautionSendOff:
        SimulatedScriptedOutcome.success,
    FinalActionKind.recordSubstitution: SimulatedScriptedOutcome.success,
    FinalActionKind.recordGoal: SimulatedScriptedOutcome.success,
  };

  ResearchLayout layout = ResearchLayout.phone;
  final Map<int, _PointerTrack> _open = {};
  int _generation = 0;
  int _successorGeneration = -1;
  bool successorEstablished = false;
  FinalActionKind? armedKind;
  FinalActionKind? predecessorKind;
  bool _unknownAcknowledged = true;

  List<ResearchLogEvent> get log => List.unmodifiable(_events);

  bool get productionMatchMemoryWrites => false;

  bool get claimsProductionRecovery =>
      RecoveryClaim.claimsProductionRecoveryGuarantee;

  String get recoveryBanner => RecoveryClaim.finishLaterLabel;

  String get commitLabel => switch (commitKind) {
        SystemCommitKind.idle => 'Idle',
        SystemCommitKind.saving => 'Saving — simulated',
        SystemCommitKind.saved => RecoveryClaim.simulatedSavedLabel,
        SystemCommitKind.notSaved => RecoveryClaim.notSavedLabel,
        SystemCommitKind.saveNotVerified => RecoveryClaim.saveNotVerifiedLabel,
      };

  String get priorCautionLabel => switch (priorCaution) {
        PriorCautionKnowledge.knownNone => 'Known verified absence',
        PriorCautionKnowledge.knownStanding =>
          'Known standing caution count $focusSavedCautionCount',
        PriorCautionKnowledge.unavailable => 'Prior caution unavailable',
        PriorCautionKnowledge.conflicted => 'Prior caution conflicted',
      };

  ResearchParticipant? get selectedParticipant {
    final id = selectedParticipantId;
    if (id == null) return null;
    for (final person in roster) {
      if (person.id == id) return person;
    }
    return null;
  }

  ResearchOfficial? get selectedOfficial {
    final id = selectedOfficialId;
    if (id == null) return null;
    for (final official in officials) {
      if (official.id == id) return official;
    }
    return null;
  }

  SubjectKind? get selectedKind => switch (selectionKind) {
        SubjectSelectionKind.participant => SubjectKind.participant,
        SubjectSelectionKind.official => SubjectKind.official,
        _ => null,
      };

  String? get selectedSubjectId => switch (selectionKind) {
        SubjectSelectionKind.participant => selectedParticipantId,
        SubjectSelectionKind.official => selectedOfficialId,
        _ => null,
      };

  bool get twoCautionsRecorded {
    final id = selectedSubjectId;
    final kind = selectedKind;
    if (id == null || kind == null) return false;
    return savedCautionCount(id, kind, scope) >= 2;
  }

  bool get sendingOffRecorded {
    final id = selectedSubjectId;
    final kind = selectedKind;
    if (id == null || kind == null) return false;
    return sendOffs.any(
      (item) =>
          item.subjectId == id && item.kind == kind && item.scope == scope,
    );
  }

  bool get activeCautionSurface {
    if (priorCaution == PriorCautionKnowledge.unavailable ||
        priorCaution == PriorCautionKnowledge.conflicted) {
      return false;
    }
    return !sendingOffRecorded;
  }

  bool get sendOffContinuationVisible =>
      twoCautionsRecorded && !sendingOffRecorded;

  bool get substitutionRecorded => substitutions.isNotEmpty;

  int get focusSavedCautionCount {
    final id = selectedSubjectId;
    final kind = selectedKind;
    if (id == null || kind == null) return 0;
    return savedCautionCount(id, kind, scope);
  }

  int savedCautionCount(String subjectId, SubjectKind kind, ResearchScope scope) {
    var count = 0;
    for (final caution in cautions) {
      if (caution.subjectId == subjectId &&
          caution.kind == kind &&
          caution.scope == scope) {
        count += 1;
      }
    }
    return count;
  }

  List<ResearchParticipant> get rankedRoster {
    final copy = [...roster];
    copy.sort((a, b) {
      final byPresence =
          presenceRankOrder(a.presence).compareTo(presenceRankOrder(b.presence));
      if (byPresence != 0) return byPresence;
      return a.id.compareTo(b.id);
    });
    return copy;
  }

  String get behaviorSignature {
    return [
      scenarioId.name,
      teamContext.name,
      scope.name,
      priorCaution.name,
      selectionKind.name,
      selectedParticipantId ?? '-',
      selectedOfficialId ?? '-',
      outId ?? '-',
      inId ?? '-',
      substitutionStage.name,
      commitKind.name,
      '${cautions.length}',
      '${sendOffs.length}',
      '${substitutions.length}',
      twoCautionsRecorded ? 'two' : 'not-two',
      sendingOffRecorded ? 'sent' : 'not-sent',
      successorEstablished ? 'successor' : 'no-successor',
      armedKind?.name ?? '-',
      yellowOffered ? 'yellow-offered' : 'yellow-hidden',
      simulatedRecoveryDisclaimer ? 'sim-recovery' : 'no-sim-recovery',
    ].join('|');
  }

  void loadScenario(ScenarioId id) {
    final fixture = scenarioFixture(id);
    scenarioId = id;
    pitchTruth = fixture.pitchTruth;
    expectedDigitalTruth = fixture.digitalTruth;
    expectedUnfinishedTruth = fixture.unfinishedTruth;
    p0Failure = fixture.p0Failure;
    simulatedRecoveryDisclaimer = fixture.simulatedRecoveryDisclaimer;
    teamContext = fixture.team;
    scope = fixture.scope;
    priorCaution = fixture.priorCaution;
    roster = List.of(fixture.roster);
    officials = List.of(fixture.officials);
    selectionKind = fixture.initialSelection;
    selectedParticipantId = fixture.initialParticipantId;
    selectedOfficialId = fixture.initialOfficialId;
    outId = fixture.initialOutId;
    inId = fixture.initialInId;
    substitutionStage = fixture.initialSubstitutionStage;
    yellowOffered = false;
    directSendOffOffered = false;
    commitKind = fixture.initialCommit;
    pendingAction = null;
    lastActivated = null;
    _activated = null;
    cautions
      ..clear()
      ..addAll(fixture.seededCautions);
    sendOffs
      ..clear()
      ..addAll(fixture.seededSendOffs);
    substitutions.clear();
    goals.clear();
    matchElapsedSeconds = fixture.initialMatchElapsedSeconds;
    matchClockAvailable = fixture.matchClockAvailable;
    goalFlowStage = GoalFlowStage.inactive;
    goalOffered = false;
    _reportSequence = 0;
    _script
      ..clear()
      ..addAll(fixture.script);
    layout = ResearchLayout.phone;
    _open.clear();
    _generation = 0;
    _successorGeneration = -1;
    successorEstablished = fixture.successorAlreadyEstablished;
    if (successorEstablished) _successorGeneration = 0;
    armedKind = null;
    predecessorKind = fixture.predecessorKind;
    _unknownAcknowledged = commitKind != SystemCommitKind.saveNotVerified;
    _events.clear();
    _sequence = 0;
    _log(ResearchLogKind.scenarioStarted, id.name);
    _log(ResearchLogKind.priorCautionShown, priorCautionLabel);
    _log(ResearchLogKind.surfaceEntered, 'live');
  }

  void reset() {
    loadScenario(scenarioId);
  }

  void enterSurface(String surface) {
    _log(ResearchLogKind.surfaceEntered, surface);
  }

  void setTeam(ResearchTeamSide side) {
    final next = side == ResearchTeamSide.home
        ? TeamContextKind.homeTrusted
        : TeamContextKind.awayTrusted;
    final manual = teamContext == TeamContextKind.homeTrusted ||
        teamContext == TeamContextKind.awayTrusted;
    teamContext = next;
    _log(
      manual
          ? ResearchLogKind.teamManuallyChanged
          : ResearchLogKind.teamContextApplied,
      side.name,
    );
    if (goalFlowStage != GoalFlowStage.inactive) {
      selectedParticipantId = null;
      selectedOfficialId = null;
      selectionKind = SubjectSelectionKind.none;
      goalFlowStage = GoalFlowStage.selectScorer;
    }
    _invalidateForTeam(side);
  }

  void selectParticipant(String id) {
    final person = _participant(id);
    if (person == null) {
      selectionKind = SubjectSelectionKind.unresolved;
      _log(ResearchLogKind.userCorrection, 'unknown-participant');
      return;
    }
    if (!_teamMatches(person.team)) {
      selectionKind = SubjectSelectionKind.unresolved;
      _log(ResearchLogKind.userCorrection, 'participant-outside-team');
      return;
    }
    selectedParticipantId = person.id;
    selectedOfficialId = null;
    selectionKind = SubjectSelectionKind.participant;
    yellowOffered = false;
    directSendOffOffered = false;
    if (goalFlowStage == GoalFlowStage.selectScorer ||
        goalFlowStage == GoalFlowStage.selectTeam) {
      goalFlowStage = GoalFlowStage.readyToRecord;
    }
    _log(ResearchLogKind.subjectSelected, person.id);
  }

  void selectOfficial(String id) {
    final official = _official(id);
    if (official == null) {
      selectionKind = SubjectSelectionKind.unresolved;
      return;
    }
    if (!_teamMatches(official.team)) {
      selectionKind = SubjectSelectionKind.unresolved;
      return;
    }
    selectedOfficialId = official.id;
    selectedParticipantId = null;
    selectionKind = SubjectSelectionKind.official;
    yellowOffered = false;
    directSendOffOffered = false;
    _log(ResearchLogKind.officialSelected, official.id);
  }

  void setScope(ResearchScope next) {
    scope = next;
    yellowOffered = false;
    directSendOffOffered = false;
    successorEstablished = false;
    armedKind = null;
    _log(ResearchLogKind.scope, next.name);
  }

  void offerRecordYellow() {
    if (!_readyForDiscipline()) return;
    _exitGoalFlow();
    yellowOffered = true;
    directSendOffOffered = false;
    _log(ResearchLogKind.surfaceEntered, 'yellow');
  }

  void offerRecordGoal() {
    if (commitKind == SystemCommitKind.saving ||
        commitKind == SystemCommitKind.saveNotVerified) {
      return;
    }
    goalOffered = true;
    goalFlowStage = GoalFlowStage.selectTeam;
    teamContext = TeamContextKind.absent;
    selectedParticipantId = null;
    selectedOfficialId = null;
    selectionKind = SubjectSelectionKind.none;
    yellowOffered = false;
    directSendOffOffered = false;
    _log(ResearchLogKind.surfaceEntered, 'goal');
  }

  void advanceMatchClock(int seconds) {
    if (!matchClockAvailable || seconds <= 0) return;
    matchElapsedSeconds += seconds;
    _log(ResearchLogKind.userCorrection, 'clock-advance:$seconds');
  }

  void noteIntentOriginTrace(String trace) {
    _pendingOriginTrace = trace;
  }

  void _exitGoalFlow() {
    goalOffered = false;
    goalFlowStage = GoalFlowStage.inactive;
  }

  void offerDirectSendOff() {
    if (!_readyForDiscipline()) return;
    directSendOffOffered = true;
    yellowOffered = false;
    successorEstablished = false;
    _log(ResearchLogKind.surfaceEntered, 'direct-send-off');
  }

  void selectOut(String id) {
    final person = _participant(id);
    if (person == null || !_teamMatches(person.team)) return;
    if (id == inId) {
      _log(ResearchLogKind.userCorrection, 'out-equals-in');
      return;
    }
    outId = id;
    substitutionStage =
        inId == null ? SubstitutionStage.outOnly : SubstitutionStage.review;
    if (inId != null) _log(ResearchLogKind.pairReviewed, '$outId>$inId');
    _log(ResearchLogKind.outSelected, id);
  }

  void selectIn(String id) {
    final person = _participant(id);
    if (person == null || !_teamMatches(person.team)) return;
    if (id == outId) {
      _log(ResearchLogKind.userCorrection, 'in-equals-out');
      return;
    }
    if (outId != null) {
      final out = _participant(outId!);
      if (out != null && out.team != person.team) {
        _log(ResearchLogKind.userCorrection, 'cross-team');
        return;
      }
    }
    inId = id;
    substitutionStage =
        outId == null ? SubstitutionStage.inOnly : SubstitutionStage.review;
    _log(ResearchLogKind.inSelected, id);
    if (outId != null) _log(ResearchLogKind.pairReviewed, '$outId>$inId');
  }

  void reorderRoster(List<String> ids) {
    final byId = {for (final person in roster) person.id: person};
    final next = <ResearchParticipant>[];
    for (final id in ids) {
      final person = byId[id];
      if (person != null) next.add(person);
    }
    for (final person in roster) {
      if (!ids.contains(person.id)) next.add(person);
    }
    roster = next;
  }

  void setScriptedOutcome(
    FinalActionKind kind,
    SimulatedScriptedOutcome outcome,
  ) {
    _script[kind] = outcome;
  }

  void pointerDown({
    required int pointerId,
    required double x,
    required double y,
  }) {
    _log(ResearchLogKind.pointerDown, '$pointerId@${_point(x, y)}');
    final captured = _capture(x, y);
    _open[pointerId] = _PointerTrack(
      pointerId: pointerId,
      x: x,
      y: y,
      captured: captured,
      generation: _generation,
    );
    armedKind = captured;
    if (captured != null) {
      _log(ResearchLogKind.finalActionArmed, captured.name);
    }
  }

  void pointerUp({
    required int pointerId,
    required double x,
    required double y,
  }) {
    _log(ResearchLogKind.pointerUp, '$pointerId@${_point(x, y)}');
    final track = _open.remove(pointerId);
    armedKind = _nextArmed();
    if (track == null || track.consumed || track.captured == null) return;
    if (_isSuccessor(track.captured!) &&
        track.generation < _successorGeneration) {
      return;
    }
    _activate(track.captured!);
  }

  void pointerCancel({required int pointerId}) {
    _open.remove(pointerId);
    armedKind = _nextArmed();
    _log(ResearchLogKind.pointerCancelled, '$pointerId');
  }

  /// Completes the action captured by a pointer that is still down.
  ///
  /// The release of that pointer cannot start a different action.
  void commitCapturedActionWhileHeld(int pointerId) {
    final track = _open[pointerId];
    if (track == null || track.consumed || track.captured == null) return;
    track.consumed = true;
    armedKind = _nextArmed();
    _activate(track.captured!);
  }

  void focusLost() {
    _log(ResearchLogKind.focusLost, 'open:${_open.length}');
    _open.clear();
    armedKind = null;
  }

  void relayout(ResearchLayout next, {String detail = 'relayout'}) {
    layout = next;
    _log(ResearchLogKind.layoutChanged, detail);
  }

  /// Drops an open pointer sequence when the active device changes.
  ///
  /// Does not resolve a commit and does not append a research record.
  void cancelOpenInputForDeviceChange(String profileId) {
    final open = _open.length;
    _open.clear();
    armedKind = null;
    _generation += 1;
    _log(ResearchLogKind.pointerCancelled, 'device-change:open=$open');
    _log(ResearchLogKind.activeDeviceChanged, profileId);
  }

  void noteProfileSelected(String profileId) {
    _log(ResearchLogKind.profileSelected, profileId);
  }

  void noteInputRejected(String reason) {
    _log(ResearchLogKind.inputRejected, reason);
  }

  void accessibilityInvoke(
    FinalActionKind kind, {
    String originTrace = 'research',
  }) {
    if (_open.isNotEmpty) return;
    if (!eligible(kind)) return;
    if (_isSuccessor(kind) && !successorEstablished) return;
    _pendingOriginTrace = originTrace;
    _activate(kind);
  }

  void resolveSimulatedCommit() {
    final pending = pendingAction;
    final command = _activated;
    if (commitKind != SystemCommitKind.saving ||
        pending == null ||
        command == null ||
        command.kind != pending) {
      return;
    }
    final outcome = _script[pending] ?? SimulatedScriptedOutcome.unknown;
    switch (outcome) {
      case SimulatedScriptedOutcome.success:
        final wrote = _applySuccess(command);
        if (wrote) {
          commitKind = SystemCommitKind.saved;
          _unknownAcknowledged = true;
        } else {
          commitKind = SystemCommitKind.saveNotVerified;
          _unknownAcknowledged = false;
        }
      case SimulatedScriptedOutcome.failure:
        commitKind = SystemCommitKind.notSaved;
        _unknownAcknowledged = true;
        if (pending == FinalActionKind.recordSubstitution) {
          substitutionStage = SubstitutionStage.notSaved;
        }
      case SimulatedScriptedOutcome.unknown:
        commitKind = SystemCommitKind.saveNotVerified;
        _unknownAcknowledged = false;
        if (pending == FinalActionKind.recordSubstitution) {
          substitutionStage = SubstitutionStage.saveNotVerified;
        }
    }
    pendingAction = null;
    _activated = null;
    _log(ResearchLogKind.simulatedCommitOutcome, '$pending:${commitKind.name}');
  }

  void interrupt() {
    _log(ResearchLogKind.interruption, commitKind.name);
    if (commitKind == SystemCommitKind.saving) {
      commitKind = SystemCommitKind.saveNotVerified;
      pendingAction = null;
      _activated = null;
      _unknownAcknowledged = false;
      _open.clear();
      armedKind = null;
    }
  }

  void resume() {
    _log(ResearchLogKind.resume, commitKind.name);
  }

  /// Does not submit a new research action.
  void acknowledgeUnknownOutcome() {
    if (commitKind != SystemCommitKind.saveNotVerified) return;
    _unknownAcknowledged = true;
    commitKind = SystemCommitKind.idle;
    _log(ResearchLogKind.userCorrection, 'acknowledge-unknown');
  }

  bool submitWhileUnverified() {
    if (commitKind == SystemCommitKind.saveNotVerified ||
        !_unknownAcknowledged) {
      _log(ResearchLogKind.userCorrection, 'blind-resubmit-refused');
      return false;
    }
    return false;
  }

  void markCompleted() {
    _log(ResearchLogKind.scenarioCompleted, scenarioId.name);
  }

  void markAbandoned() {
    _log(ResearchLogKind.scenarioAbandoned, scenarioId.name);
  }

  bool eligible(FinalActionKind kind) {
    if (commitKind == SystemCommitKind.saving) return false;
    if (commitKind == SystemCommitKind.saveNotVerified) return false;
    if (!_unknownAcknowledged) return false;
    return switch (kind) {
      FinalActionKind.recordYellow =>
        yellowOffered && _readyForDiscipline(),
      FinalActionKind.recordDirectSendOff =>
        directSendOffOffered && _readyForDiscipline(),
      FinalActionKind.recordSecondCautionSendOff =>
        successorEstablished &&
            twoCautionsRecorded &&
            !sendingOffRecorded &&
            _readyForDiscipline(),
      FinalActionKind.recordSubstitution =>
        matchClockAvailable &&
            substitutionStage == SubstitutionStage.review &&
            outId != null &&
            inId != null &&
            outId != inId,
      FinalActionKind.recordGoal => _readyForGoalRecord(),
    };
  }

  int _nextReportSequence() {
    _reportSequence += 1;
    return _reportSequence;
  }

  String? _captureTimeLabel() {
    if (!matchClockAvailable) return null;
    return formatResearchMatchTime(matchElapsedSeconds);
  }

  bool _readyForGoalRecord() {
    if (!goalOffered || goalFlowStage != GoalFlowStage.readyToRecord) {
      return false;
    }
    if (!matchClockAvailable) return false;
    final side = _trustedTeamSide();
    if (side == null) return false;
    final scorerId = selectedParticipantId;
    if (scorerId == null ||
        selectionKind != SubjectSelectionKind.participant) {
      return false;
    }
    final person = _participant(scorerId);
    if (person == null || person.team != side) return false;
    return true;
  }

  ResearchTeamSide? _trustedTeamSide() {
    return switch (teamContext) {
      TeamContextKind.homeTrusted => ResearchTeamSide.home,
      TeamContextKind.awayTrusted => ResearchTeamSide.away,
      _ => null,
    };
  }

  bool _readyForDiscipline() {
    if (!matchClockAvailable) return false;
    final teamOk = teamContext == TeamContextKind.homeTrusted ||
        teamContext == TeamContextKind.awayTrusted;
    final subjectOk = selectionKind == SubjectSelectionKind.participant ||
        selectionKind == SubjectSelectionKind.official;
    final scopeOk =
        scope == ResearchScope.match || scope == ResearchScope.shootout;
    return teamOk && subjectOk && scopeOk;
  }

  bool _teamMatches(ResearchTeamSide side) {
    return switch (teamContext) {
      TeamContextKind.homeTrusted => side == ResearchTeamSide.home,
      TeamContextKind.awayTrusted => side == ResearchTeamSide.away,
      TeamContextKind.absent || TeamContextKind.ambiguous => false,
    };
  }

  void _invalidateForTeam(ResearchTeamSide side) {
    final participant = selectedParticipant;
    if (participant != null && participant.team != side) {
      selectedParticipantId = null;
      selectionKind = SubjectSelectionKind.invalidated;
      yellowOffered = false;
      directSendOffOffered = false;
      _log(ResearchLogKind.subjectInvalidated, participant.id);
    }
    final official = selectedOfficial;
    if (official != null && official.team != side) {
      selectedOfficialId = null;
      selectionKind = SubjectSelectionKind.invalidated;
      yellowOffered = false;
      directSendOffOffered = false;
      _log(ResearchLogKind.subjectInvalidated, official.id);
    }
    final out = outId == null ? null : _participant(outId!);
    if (out != null && out.team != side) outId = null;
    final incoming = inId == null ? null : _participant(inId!);
    if (incoming != null && incoming.team != side) inId = null;
    if (outId == null && inId == null) {
      substitutionStage = SubstitutionStage.none;
    } else if (outId != null && inId == null) {
      substitutionStage = SubstitutionStage.outOnly;
    } else if (outId == null && inId != null) {
      substitutionStage = SubstitutionStage.inOnly;
    }
  }

  FinalActionKind? _capture(double x, double y) {
    final kind = _hit(x, y);
    if (kind == null || !eligible(kind)) return null;
    if (_isSuccessor(kind)) {
      if (_open.values.any((track) => track.generation < _successorGeneration)) {
        return null;
      }
      if (!successorEstablished || _generation < _successorGeneration) {
        return null;
      }
      final predecessor = predecessorKind;
      if (predecessor != null &&
          layout.regionFor(predecessor).contains(x, y)) {
        return null;
      }
    }
    return kind;
  }

  FinalActionKind? _hit(double x, double y) {
    final inYellow = layout.yellow.contains(x, y);
    final inSendOff = layout.sendOff.contains(x, y);
    final inSub = layout.substitution.contains(x, y);
    if (inYellow && yellowOffered) return FinalActionKind.recordYellow;
    if (inYellow) return null;
    if (inSendOff && directSendOffOffered) {
      return FinalActionKind.recordDirectSendOff;
    }
    if (inSendOff && sendOffContinuationVisible) {
      return FinalActionKind.recordSecondCautionSendOff;
    }
    if (inSub) return FinalActionKind.recordSubstitution;
    return null;
  }

  bool _isSuccessor(FinalActionKind kind) {
    return kind == FinalActionKind.recordSecondCautionSendOff;
  }

  void _activate(FinalActionKind kind) {
    if (!eligible(kind)) return;
    if (commitKind == SystemCommitKind.saving) return;
    predecessorKind = kind == FinalActionKind.recordSecondCautionSendOff
        ? FinalActionKind.recordYellow
        : kind;
    pendingAction = kind;
    lastActivated = kind;
    final side = kind == FinalActionKind.recordGoal ? _trustedTeamSide() : null;
    _activated = _ActivatedCommand(
      kind: kind,
      subjectId: kind == FinalActionKind.recordGoal
          ? selectedParticipantId
          : selectedSubjectId,
      subjectKind: kind == FinalActionKind.recordGoal
          ? SubjectKind.participant
          : selectedKind,
      scope: scope,
      outId: outId,
      inId: inId,
      scoringTeam: side,
      goalScorerParticipantId:
          kind == FinalActionKind.recordGoal ? selectedParticipantId : null,
      capturedMatchTimeLabel: _captureTimeLabel(),
      originTrace: _pendingOriginTrace,
    );
    commitKind = SystemCommitKind.saving;
    yellowOffered = false;
    directSendOffOffered = false;
    if (kind == FinalActionKind.recordSubstitution) {
      substitutionStage = SubstitutionStage.saving;
    }
    _log(ResearchLogKind.finalActionActivated, kind.name);
    _log(ResearchLogKind.frozenCommand, _frozenDetail(_activated!));
    _log(ResearchLogKind.simulatedCommitStarted, kind.name);
  }

  /// Writes the command captured at activation. Returns false when that
  /// snapshot cannot produce a record, and writes nothing in that case.
  bool _applySuccess(_ActivatedCommand command) {
    switch (command.kind) {
      case FinalActionKind.recordYellow:
        final subjectId = command.subjectId;
        final subjectKind = command.subjectKind;
        if (subjectId == null ||
            subjectKind == null ||
            command.capturedMatchTimeLabel == null) {
          return false;
        }
        final seq = _nextReportSequence();
        cautions.add(
          SavedCaution(
            subjectId: subjectId,
            kind: subjectKind,
            scope: command.scope,
            eventId: 'yellow-$seq',
            sequence: seq,
            matchTimeLabel: command.capturedMatchTimeLabel,
            originTrace: command.originTrace,
          ),
        );
        if (savedCautionCount(subjectId, subjectKind, command.scope) >= 2) {
          successorEstablished = true;
          _generation += 1;
          _successorGeneration = _generation;
          predecessorKind = FinalActionKind.recordYellow;
          armedKind = null;
        }
        _logAppended(command, 'cautions:${cautions.length}');
        return true;
      case FinalActionKind.recordDirectSendOff:
        final subjectId = command.subjectId;
        final subjectKind = command.subjectKind;
        if (subjectId == null ||
            subjectKind == null ||
            command.capturedMatchTimeLabel == null) {
          return false;
        }
        final seqDirect = _nextReportSequence();
        sendOffs.add(
          SavedSendOff(
            subjectId: subjectId,
            kind: subjectKind,
            scope: command.scope,
            pathway: SendOffPathwayLabel.direct,
            eventId: 'sendoff-direct-$seqDirect',
            sequence: seqDirect,
            matchTimeLabel: command.capturedMatchTimeLabel,
            originTrace: command.originTrace,
          ),
        );
        _logAppended(command, 'sendOffs:${sendOffs.length}');
        return true;
      case FinalActionKind.recordSecondCautionSendOff:
        final subjectId = command.subjectId;
        final subjectKind = command.subjectKind;
        if (subjectId == null ||
            subjectKind == null ||
            command.capturedMatchTimeLabel == null) {
          return false;
        }
        final seqSecond = _nextReportSequence();
        sendOffs.add(
          SavedSendOff(
            subjectId: subjectId,
            kind: subjectKind,
            scope: command.scope,
            pathway: SendOffPathwayLabel.secondCaution,
            eventId: 'sendoff-second-$seqSecond',
            sequence: seqSecond,
            matchTimeLabel: command.capturedMatchTimeLabel,
            originTrace: command.originTrace,
          ),
        );
        successorEstablished = false;
        _logAppended(command, 'sendOffs:${sendOffs.length}');
        return true;
      case FinalActionKind.recordSubstitution:
        final out = command.outId;
        final incoming = command.inId;
        final person = out == null ? null : _participant(out);
        if (out == null ||
            incoming == null ||
            out == incoming ||
            person == null ||
            command.capturedMatchTimeLabel == null) {
          return false;
        }
        final seqSub = _nextReportSequence();
        substitutions.add(
          SavedSubstitution(
            outId: out,
            inId: incoming,
            team: person.team,
            eventId: 'substitution-$seqSub',
            sequence: seqSub,
            matchTimeLabel: command.capturedMatchTimeLabel,
            originTrace: command.originTrace,
          ),
        );
        substitutionStage = SubstitutionStage.saved;
        _logAppended(command, 'substitutions:${substitutions.length}');
        return true;
      case FinalActionKind.recordGoal:
        final team = command.scoringTeam;
        final scorerId = command.goalScorerParticipantId;
        final timeLabel = command.capturedMatchTimeLabel;
        if (team == null ||
            scorerId == null ||
            timeLabel == null ||
            !matchClockAvailable) {
          return false;
        }
        final person = _participant(scorerId);
        if (person == null || person.team != team) return false;
        final seqGoal = _nextReportSequence();
        goals.add(
          SavedGoal(
            eventId: 'goal-$seqGoal',
            sequence: seqGoal,
            scoringTeam: team,
            scorerParticipantId: scorerId,
            matchTimeLabel: timeLabel,
            originTrace: command.originTrace,
          ),
        );
        _exitGoalFlow();
        _logAppended(command, 'goals:${goals.length}');
        return true;
    }
  }

  void _logAppended(_ActivatedCommand command, String collection) {
    _log(
      ResearchLogKind.researchRecordAppended,
      '${command.kind.name}|$collection|subject:${command.subjectId ?? '-'}|scope:${command.scope.name}|out:${command.outId ?? '-'}|in:${command.inId ?? '-'}',
    );
  }

  FinalActionKind? _nextArmed() {
    for (final track in _open.values) {
      if (!track.consumed && track.captured != null) return track.captured;
    }
    return null;
  }

  ResearchParticipant? _participant(String id) {
    for (final person in roster) {
      if (person.id == id) return person;
    }
    return null;
  }

  ResearchOfficial? _official(String id) {
    for (final official in officials) {
      if (official.id == id) return official;
    }
    return null;
  }

  int get activePointerCount => _open.length;

  bool get freshInputEligible =>
      commitKind == SystemCommitKind.idle &&
      _unknownAcknowledged &&
      _open.isEmpty &&
      armedKind == null &&
      _activated == null;

  ActivatedCommandSnapshot? get inFlightCommand {
    final command = _activated;
    if (command == null || commitKind != SystemCommitKind.saving) return null;
    return ActivatedCommandSnapshot(
      kind: command.kind,
      subjectId: command.subjectId,
      subjectKind: command.subjectKind,
      scope: command.scope,
      outId: command.outId,
      inId: command.inId,
      scoringTeam: command.scoringTeam,
      goalScorerParticipantId: command.goalScorerParticipantId,
      capturedMatchTimeLabel: command.capturedMatchTimeLabel,
    );
  }

  ResearchTruthSnapshot get snapshot {
    return ResearchTruthSnapshot(
      scenarioId: scenarioId.name,
      pitchTruth: pitchTruth,
      expectedDigitalTruth: expectedDigitalTruth,
      expectedUnfinishedTruth: expectedUnfinishedTruth,
      p0Failure: p0Failure,
      priorCaution: priorCaution,
      priorCautionLabel: priorCautionLabel,
      cautions: List.unmodifiable([...cautions]),
      sendOffs: List.unmodifiable([...sendOffs]),
      substitutions: List.unmodifiable([...substitutions]),
      goals: List.unmodifiable([...goals]),
      matchElapsedSeconds: matchElapsedSeconds,
      matchClockAvailable: matchClockAvailable,
      goalFlowStage: goalFlowStage,
      goalOffered: goalOffered,
      roster: List.unmodifiable([...roster]),
      officials: List.unmodifiable([...officials]),
      teamContext: teamContext,
      scope: scope,
      selectionKind: selectionKind,
      yellowOffered: yellowOffered,
      directSendOffOffered: directSendOffOffered,
      selectedSubjectId: selectedSubjectId,
      selectedSubjectKind: selectedKind,
      outId: outId,
      inId: inId,
      substitutionStage: substitutionStage,
      inFlight: inFlightCommand,
      commitKind: commitKind,
      commitLabel: commitLabel,
      armedKind: armedKind,
      predecessorKind: predecessorKind,
      successorEstablished: successorEstablished,
      activePointerCount: activePointerCount,
      freshInputEligible: freshInputEligible,
      simulatedRecoveryDisclaimer: simulatedRecoveryDisclaimer,
    );
  }

  String _point(double x, double y) =>
      '${x.toStringAsFixed(2)},${y.toStringAsFixed(2)}';

  String _frozenDetail(_ActivatedCommand command) {
    return '${command.kind.name}|subject:${command.subjectId ?? '-'}|kind:${command.subjectKind?.name ?? '-'}|scope:${command.scope.name}|out:${command.outId ?? '-'}|in:${command.inId ?? '-'}|goalTeam:${command.scoringTeam?.name ?? '-'}|goalScorer:${command.goalScorerParticipantId ?? '-'}|goalTime:${command.capturedMatchTimeLabel ?? '-'}';
  }

  void _log(ResearchLogKind kind, String detail) {
    if (!loggingEnabled) return;
    final event = ResearchLogEvent(
      kind: kind,
      scenarioId: scenarioId.name,
      detail: detail,
      sequence: _sequence + 1,
    );
    try {
      _sink?.call(event);
      _events.add(event);
      _sequence += 1;
    } catch (_) {
      // A broken research log must not change the interaction.
    }
  }
}
