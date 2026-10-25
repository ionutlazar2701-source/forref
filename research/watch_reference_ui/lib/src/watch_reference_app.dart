import 'package:flutter/material.dart' hide ActivateIntent;
import 'package:simulator_presentation/simulator_presentation.dart';

import 'watch_design.dart';

/// Interactive FORREF watch reference surface.
///
/// The same widget runs on every device profile. Geometry is the parent's
/// constraint. Football actions are [WatchIntent]s.
///
/// [face], [liveLayout], and [frame] are presentation. They are not match
/// records, clock evidence, or a stored mid-match preference.
enum _JourneyStep { chooser, team, participant }

class WatchReferenceApp extends StatefulWidget {
  const WatchReferenceApp({
    super.key,
    required this.state,
    required this.onIntent,
    this.degradedLabel,
    this.inputEpoch = 0,
    this.face = WatchFaceShape.rectangular,
    this.liveLayout = WatchLiveLayout.centered,
    this.frame = WatchDesignFrame.flow,
    this.language = WatchLanguage.en,
    this.showBeyondNominal = false,
    this.homeKit,
    this.awayKit,
    this.blockedFamilies = const {},
    this.selectionEnabled = true,
    this.onPresentationBack,
  });

  final WatchPresentationState state;
  final void Function(WatchIntent intent) onIntent;
  final String? degradedLabel;

  /// Changes when focus is lost or the device changes.
  ///
  /// A press that started on an older epoch does not commit.
  final int inputEpoch;
  final WatchFaceShape face;
  final WatchLiveLayout liveLayout;
  final WatchDesignFrame frame;
  final WatchLanguage language;
  final bool showBeyondNominal;
  final Color? homeKit;
  final Color? awayKit;
  final Set<WatchCaptureFamily> blockedFamilies;
  final bool selectionEnabled;

  /// Lab hook for the participant frame. It does not emit an activate intent.
  final VoidCallback? onPresentationBack;

  @override
  State<WatchReferenceApp> createState() => _WatchReferenceAppState();
}

class _WatchReferenceAppState extends State<WatchReferenceApp> {
  _JourneyStep _step = _JourneyStep.chooser;
  WatchCaptureFamily? _family;
  PresentationTeam? _team;

  @override
  void didUpdateWidget(WatchReferenceApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    final route = widget.state.navigation.route;
    if (route != WatchRoute.captureMenu ||
        widget.frame != WatchDesignFrame.flow) {
      _step = _JourneyStep.chooser;
      _family = null;
      _team = null;
    }
  }

  void _clearJourney() {
    _step = _JourneyStep.chooser;
    _family = null;
    _team = null;
  }

  void _chooseFamily(WatchCaptureFamily family) {
    if (!widget.state.navigation.canOpenCapture) return;
    if (widget.blockedFamilies.contains(family)) return;
    setState(() {
      _family = family;
      _team = null;
      _step = _JourneyStep.team;
    });
  }

  void _chooseTeam(PresentationTeam team) {
    final family = _family;
    widget.onIntent(SetTeamIntent(team, origin: IntentOrigin.watchUi));
    if (family == WatchCaptureFamily.substitution) {
      widget.onIntent(
        const OpenRouteIntent(
          WatchRoute.substitutionFlow,
          origin: IntentOrigin.watchUi,
        ),
      );
      setState(_clearJourney);
      return;
    }
    setState(() {
      _team = team;
      _step = _JourneyStep.participant;
    });
  }

  void _choosePlayer(PresentationParticipant person) {
    final family = _family;
    final team = _team;
    if (family == null || team == null) return;
    switch (family) {
      case WatchCaptureFamily.yellow:
        widget.onIntent(
          SelectParticipantIntent(person.id, origin: IntentOrigin.watchUi),
        );
        widget.onIntent(const OfferYellowIntent(origin: IntentOrigin.watchUi));
      case WatchCaptureFamily.red:
        widget.onIntent(
          SelectParticipantIntent(person.id, origin: IntentOrigin.watchUi),
        );
        widget.onIntent(
          const OpenRouteIntent(
            WatchRoute.sendOffFlow,
            origin: IntentOrigin.watchUi,
          ),
        );
      case WatchCaptureFamily.goal:
        widget.onIntent(const OfferGoalIntent(origin: IntentOrigin.watchUi));
        widget.onIntent(SetTeamIntent(team, origin: IntentOrigin.watchUi));
        widget.onIntent(
          SelectParticipantIntent(person.id, origin: IntentOrigin.watchUi),
        );
      case WatchCaptureFamily.substitution:
        return;
    }
    setState(_clearJourney);
  }

  void _chooseOfficial(PresentationOfficial official) {
    if (_family != WatchCaptureFamily.yellow) return;
    widget.onIntent(
      SelectOfficialIntent(official.id, origin: IntentOrigin.watchUi),
    );
    widget.onIntent(const OfferYellowIntent(origin: IntentOrigin.watchUi));
    setState(_clearJourney);
  }

  @override
  Widget build(BuildContext context) {
    final design = _designSurface(widget);
    return Material(
      color: design ? WatchPalette.deepNavy : const Color(0xFFF8FAFC),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 120 || constraints.maxHeight < 180) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'LAYOUT NOT FIT FOR THIS PROFILE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF0B2A4A),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            );
          }
          return _FitBody(
            state: widget.state,
            degradedLabel: widget.degradedLabel,
            onIntent: widget.onIntent,
            inputEpoch: widget.inputEpoch,
            face: widget.face,
            liveLayout: widget.liveLayout,
            frame: widget.frame,
            language: widget.language,
            showBeyondNominal: widget.showBeyondNominal,
            homeKit: widget.homeKit,
            awayKit: widget.awayKit,
            blockedFamilies: widget.blockedFamilies,
            selectionEnabled: widget.selectionEnabled,
            onPresentationBack: widget.onPresentationBack,
            design: design,
            journeyStep: _step,
            journeyFamily: _family,
            journeyTeam: _team,
            onJourneyFamily: _chooseFamily,
            onJourneyTeam: _chooseTeam,
            onJourneyPlayer: _choosePlayer,
            onJourneyOfficial: _chooseOfficial,
            onJourneyBackToChooser: () => setState(_clearJourney),
            onJourneyBackToTeam: () =>
                setState(() => _step = _JourneyStep.team),
          );
        },
      ),
    );
  }

  bool _designSurface(WatchReferenceApp app) {
    if (app.frame != WatchDesignFrame.flow) return true;
    if (_step != _JourneyStep.chooser) return true;
    final route = app.state.navigation.route;
    return route == WatchRoute.liveCore || route == WatchRoute.captureMenu;
  }
}

class _FitBody extends StatelessWidget {
  const _FitBody({
    required this.state,
    required this.degradedLabel,
    required this.onIntent,
    required this.inputEpoch,
    required this.face,
    required this.liveLayout,
    required this.frame,
    required this.language,
    required this.showBeyondNominal,
    required this.homeKit,
    required this.awayKit,
    required this.blockedFamilies,
    required this.selectionEnabled,
    required this.onPresentationBack,
    required this.design,
    required this.journeyStep,
    required this.journeyFamily,
    required this.journeyTeam,
    required this.onJourneyFamily,
    required this.onJourneyTeam,
    required this.onJourneyPlayer,
    required this.onJourneyOfficial,
    required this.onJourneyBackToChooser,
    required this.onJourneyBackToTeam,
  });

  final WatchPresentationState state;
  final String? degradedLabel;
  final void Function(WatchIntent intent) onIntent;
  final int inputEpoch;
  final WatchFaceShape face;
  final WatchLiveLayout liveLayout;
  final WatchDesignFrame frame;
  final WatchLanguage language;
  final bool showBeyondNominal;
  final Color? homeKit;
  final Color? awayKit;
  final Set<WatchCaptureFamily> blockedFamilies;
  final bool selectionEnabled;
  final VoidCallback? onPresentationBack;
  final bool design;
  final _JourneyStep journeyStep;
  final WatchCaptureFamily? journeyFamily;
  final PresentationTeam? journeyTeam;
  final void Function(WatchCaptureFamily family) onJourneyFamily;
  final void Function(PresentationTeam team) onJourneyTeam;
  final void Function(PresentationParticipant person) onJourneyPlayer;
  final void Function(PresentationOfficial official) onJourneyOfficial;
  final VoidCallback onJourneyBackToChooser;
  final VoidCallback onJourneyBackToTeam;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (degradedLabel != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Text(
              'DEGRADED — $degradedLabel',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: design ? WatchPalette.steel : const Color(0xFF5B7EA6),
                fontSize: 11,
                fontFamily: 'Roboto',
              ),
            ),
          ),
        if (state.frozenCommand != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Text(
              _frozen(state.frozenCommand!),
              key: const Key('watch-frozen-command'),
              style: TextStyle(
                color: design ? WatchPalette.ink : const Color(0xFF0B2A4A),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'Roboto',
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          child: Text(
            state.commit.label,
            key: const Key('watch-commit-label'),
            style: TextStyle(
              color: design ? WatchPalette.steel : const Color(0xFF0B2A4A),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: 'Roboto',
            ),
          ),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (frame == WatchDesignFrame.team) return _teamFrame(journey: false);
    if (frame == WatchDesignFrame.participant)
      return _participantFrame(journey: false);
    if (state.navigation.route == WatchRoute.liveCore) {
      return _liveSurface();
    }
    if (state.navigation.route == WatchRoute.captureMenu) {
      return switch (journeyStep) {
        _JourneyStep.chooser => _captureSurface(),
        _JourneyStep.team => _teamFrame(journey: true),
        _JourneyStep.participant => _participantFrame(journey: true),
      };
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _pages(),
      ),
    );
  }

  Widget _liveSurface() {
    return WatchLiveSurface(
      state: state,
      face: face,
      layout: liveLayout,
      language: language,
      showBeyondNominal: showBeyondNominal,
      inputEpoch: inputEpoch,
      onCapture: () => onIntent(
        const OpenRouteIntent(WatchRoute.captureMenu,
            origin: IntentOrigin.watchUi),
      ),
      onKickOffArm: () => onIntent(
        const ArmKickOffIntent(origin: IntentOrigin.watchUi),
      ),
      onKickOffCommit: () => onIntent(
        const ConfirmKickOffIntent(origin: IntentOrigin.watchUi),
      ),
      onCautions: () => onIntent(
        const OpenRouteIntent(
          WatchRoute.disciplinaryAwareness,
          origin: IntentOrigin.watchUi,
        ),
      ),
      onMatchReport: () => onIntent(
        const OpenRouteIntent(WatchRoute.matchReport,
            origin: IntentOrigin.watchUi),
      ),
      onHistory: () => onIntent(
        const OpenRouteIntent(WatchRoute.history, origin: IntentOrigin.watchUi),
      ),
      onResolve: state.commit.label == ResearchCommitPhrases.saving
          ? () => onIntent(
                const ResolveSimulatedCommitIntent(
                    origin: IntentOrigin.watchUi),
              )
          : null,
    );
  }

  Widget _captureSurface() {
    return WatchCaptureSurface(
      face: face,
      language: language,
      inputEpoch: inputEpoch,
      blocked: blockedFamilies,
      onBack: () => onIntent(
        const OpenRouteIntent(WatchRoute.liveCore,
            origin: IntentOrigin.watchUi),
      ),
      onLiveMatch: () => onIntent(
        const OpenRouteIntent(WatchRoute.liveCore,
            origin: IntentOrigin.watchUi),
      ),
      onFamily: onJourneyFamily,
    );
  }

  Widget _teamFrame({required bool journey}) {
    final familyLabel = switch (journeyFamily) {
      WatchCaptureFamily.yellow => watchCopy(language, 'yellowCard'),
      WatchCaptureFamily.red => watchCopy(language, 'redCard'),
      WatchCaptureFamily.goal => watchCopy(language, 'goal'),
      WatchCaptureFamily.substitution => watchCopy(language, 'sub'),
      null => null,
    };
    return WatchTeamSurface(
      state: state,
      face: face,
      language: language,
      inputEpoch: inputEpoch,
      homeKit: homeKit,
      awayKit: awayKit,
      eventLabel: journey ? familyLabel : null,
      onTeam: journey
          ? onJourneyTeam
          : (team) => onIntent(
                SetTeamIntent(team, origin: IntentOrigin.watchUi),
              ),
      onBack: () {
        if (journey) {
          onJourneyBackToChooser();
          return;
        }
        onIntent(
          const OpenRouteIntent(WatchRoute.captureMenu,
              origin: IntentOrigin.watchUi),
        );
        onPresentationBack?.call();
      },
    );
  }

  Widget _participantFrame({required bool journey}) {
    final eventLabel = journey
        ? switch (journeyFamily) {
            WatchCaptureFamily.yellow => watchCopy(language, 'yellowCard'),
            WatchCaptureFamily.red => watchCopy(language, 'redCard'),
            WatchCaptureFamily.goal => watchCopy(language, 'goal'),
            WatchCaptureFamily.substitution => watchCopy(language, 'sub'),
            null => 'Participant',
          }
        : switch (state.navigation.route) {
            WatchRoute.yellowFlow => 'Yellow Card',
            WatchRoute.sendOffFlow => 'Red Card',
            WatchRoute.goalFlow => 'Goal',
            WatchRoute.substitutionFlow => 'Substitution',
            _ => 'Participant',
          };
    return WatchParticipantSurface(
      state: state,
      face: face,
      language: language,
      inputEpoch: inputEpoch,
      selectionEnabled: selectionEnabled,
      eventLabel: eventLabel,
      teamFilter: journey ? journeyTeam : null,
      officialsEnabled: !journey || journeyFamily == WatchCaptureFamily.yellow,
      onPlayer: journey
          ? onJourneyPlayer
          : (person) => onIntent(
                SelectParticipantIntent(person.id,
                    origin: IntentOrigin.watchUi),
              ),
      onOfficial: journey
          ? onJourneyOfficial
          : (official) => onIntent(
                SelectOfficialIntent(official.id, origin: IntentOrigin.watchUi),
              ),
      onBack: () {
        if (journey) {
          onJourneyBackToTeam();
          return;
        }
        final back = onPresentationBack;
        if (back != null) {
          back();
          return;
        }
        onIntent(
          const OpenRouteIntent(WatchRoute.captureMenu,
              origin: IntentOrigin.watchUi),
        );
      },
    );
  }

  List<Widget> _pages() {
    return switch (state.navigation.route) {
      WatchRoute.liveCore => const <Widget>[],
      WatchRoute.captureMenu => const <Widget>[],
      WatchRoute.yellowFlow => _yellow(),
      WatchRoute.sendOffFlow => _sendOff(),
      WatchRoute.goalFlow => _goal(),
      WatchRoute.substitutionFlow => _substitution(),
      WatchRoute.disciplinaryAwareness => _awareness(),
      WatchRoute.history => _history(),
      WatchRoute.matchReport => _matchReport(),
    };
  }

  List<Widget> _goal() {
    final flow = state.goalFlow;
    final reviewTime = flow.reviewMatchTimeLabel ?? 'Time unavailable';
    final teamLabel = flow.scoringTeam == PresentationTeam.home
        ? state.homeTeamLabel
        : flow.scoringTeam == PresentationTeam.away
            ? state.awayTeamLabel
            : '—';
    String? scorerLabel;
    if (flow.scorerParticipantId != null) {
      for (final person in state.roster) {
        if (person.id == flow.scorerParticipantId) {
          scorerLabel = '#${person.shirtLabel} ${person.name}';
          break;
        }
      }
    }
    return [
      const Text(
        'GOAL',
        style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0B2A4A)),
      ),
      _button(
        state.homeTeamLabel,
        const SetTeamIntent(PresentationTeam.home,
            origin: IntentOrigin.watchUi),
        key: const Key('watch-goal-team-home'),
      ),
      _button(
        state.awayTeamLabel,
        const SetTeamIntent(PresentationTeam.away,
            origin: IntentOrigin.watchUi),
        key: const Key('watch-goal-team-away'),
      ),
      if (flow.scoringTeam != null)
        Text(
          teamLabel,
          key: const Key('watch-goal-selected-team'),
          style: const TextStyle(
              fontFamily: 'Roboto', fontSize: 13, color: Color(0xFF0B2A4A)),
        ),
      for (final person in _goalScorers())
        _button(
          '#${person.shirtLabel} ${person.name}',
          SelectParticipantIntent(person.id, origin: IntentOrigin.watchUi),
          key: Key('watch-goal-scorer-${person.id}'),
        ),
      if (flow.stage == GoalFlowStagePresentation.readyToRecord ||
          state.frozenCommand?.action == PresentationAction.goal)
        Text(
          'GOAL\n$teamLabel\n${scorerLabel ?? '—'}\n$reviewTime',
          key: const Key('watch-goal-review'),
          style: const TextStyle(
              fontFamily: 'Roboto', fontSize: 13, color: Color(0xFF0B2A4A)),
        ),
      if (flow.canRecord)
        _button(
          'Record Goal',
          const ActivateIntent(PresentationAction.goal,
              origin: IntentOrigin.watchUi),
          key: const Key('watch-record-goal'),
        )
      else if (flow.blockReason != null)
        Text(flow.blockReason!,
            style: const TextStyle(
                fontFamily: 'Roboto', fontSize: 12, color: Color(0xFF0B2A4A))),
      if (state.commit.label == ResearchCommitPhrases.saving)
        _button(
          'Resolve simulated outcome',
          const ResolveSimulatedCommitIntent(origin: IntentOrigin.watchUi),
          key: const Key('watch-resolve-goal'),
        ),
      _button(
          'Back',
          const OpenRouteIntent(WatchRoute.liveCore,
              origin: IntentOrigin.watchUi)),
    ];
  }

  List<Widget> _matchReport() {
    return [
      const Text(
        'MATCH REPORT',
        key: Key('watch-match-report-heading'),
        style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0B2A4A)),
      ),
      for (final entry in state.matchReport.entries)
        Text(
          _reportLine(entry),
          key: Key('watch-match-report-entry-${entry.sequence}'),
          style: const TextStyle(
              fontFamily: 'Roboto', fontSize: 12, color: Color(0xFF0B2A4A)),
        ),
      if (state.matchReport.entries.isEmpty)
        const Text(
          'No established events',
          key: Key('watch-match-report-empty'),
          style: TextStyle(
              fontFamily: 'Roboto', fontSize: 12, color: Color(0xFF0B2A4A)),
        ),
      _button(
          'Back',
          const OpenRouteIntent(WatchRoute.liveCore,
              origin: IntentOrigin.watchUi)),
    ];
  }

  List<PresentationParticipant> _goalScorers() {
    final team = state.goalFlow.scoringTeam;
    if (team == null) return const [];
    return [
      for (final person in state.roster)
        if (person.team == team) person
    ];
  }

  List<Widget> _yellow() {
    final time = state.frozenCommand?.capturedMatchTimeLabel ??
        (state.clock.available ? state.clock.label : null);
    return [
      const Text('YELLOW',
          style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0B2A4A))),
      _button(
          state.homeTeamLabel,
          const SetTeamIntent(PresentationTeam.home,
              origin: IntentOrigin.watchUi),
          key: const Key('watch-yellow-team-home')),
      _button(
          state.awayTeamLabel,
          const SetTeamIntent(PresentationTeam.away,
              origin: IntentOrigin.watchUi),
          key: const Key('watch-yellow-team-away')),
      Text(state.discipline.awarenessLabel,
          key: const Key('watch-prior-awareness')),
      if (time != null)
        Text('Match time $time',
            key: const Key('watch-yellow-review-time'),
            style: const TextStyle(
                fontFamily: 'Roboto', fontSize: 13, color: Color(0xFF0B2A4A))),
      for (final person in _visiblePeople())
        _button(
          '#${person.shirtLabel} ${person.name}',
          SelectParticipantIntent(person.id, origin: IntentOrigin.watchUi),
          key: Key('watch-yellow-subject-${person.id}'),
        ),
      _button(
        'Record yellow',
        const ActivateIntent(PresentationAction.yellow,
            origin: IntentOrigin.watchUi),
        key: const Key('watch-record-yellow'),
      ),
      if (state.commit.label == ResearchCommitPhrases.saving)
        _button(
          'Resolve simulated outcome',
          const ResolveSimulatedCommitIntent(origin: IntentOrigin.watchUi),
          key: const Key('watch-resolve-yellow'),
        ),
      _button(
          'Back',
          const OpenRouteIntent(WatchRoute.liveCore,
              origin: IntentOrigin.watchUi)),
    ];
  }

  List<Widget> _sendOff() {
    final time = state.frozenCommand?.capturedMatchTimeLabel ??
        (state.clock.available ? state.clock.label : null);
    return [
      _button(
          state.homeTeamLabel,
          const SetTeamIntent(PresentationTeam.home,
              origin: IntentOrigin.watchUi),
          key: const Key('watch-sendoff-team-home')),
      _button(
          state.awayTeamLabel,
          const SetTeamIntent(PresentationTeam.away,
              origin: IntentOrigin.watchUi),
          key: const Key('watch-sendoff-team-away')),
      for (final person in _visiblePeople())
        _button(
          '#${person.shirtLabel} ${person.name}',
          SelectParticipantIntent(person.id, origin: IntentOrigin.watchUi),
          key: Key('watch-sendoff-subject-${person.id}'),
        ),
      if (time != null)
        Text('Match time $time',
            key: const Key('watch-sendoff-review-time'),
            style: const TextStyle(
                fontFamily: 'Roboto', fontSize: 13, color: Color(0xFF0B2A4A))),
      _button(
        'Record direct send-off',
        const ActivateIntent(PresentationAction.directSendOff,
            origin: IntentOrigin.watchUi),
        key: const Key('watch-record-direct-sendoff'),
      ),
      _button(
        'Record second-caution send-off',
        const ActivateIntent(PresentationAction.secondCautionSendOff,
            origin: IntentOrigin.watchUi),
        key: const Key('watch-record-second-sendoff'),
      ),
      _button('Offer direct send-off',
          const OfferDirectSendOffIntent(origin: IntentOrigin.watchUi)),
      const Text(
        'DIRECT and SECOND_CAUTION are separate final actions.',
        style: TextStyle(
            fontFamily: 'Roboto', fontSize: 12, color: Color(0xFF0B2A4A)),
      ),
      if (state.commit.label == ResearchCommitPhrases.saving)
        _button(
          'Resolve simulated outcome',
          const ResolveSimulatedCommitIntent(origin: IntentOrigin.watchUi),
        ),
      _button(
          'Back',
          const OpenRouteIntent(WatchRoute.liveCore,
              origin: IntentOrigin.watchUi)),
    ];
  }

  List<Widget> _substitution() {
    final time = state.frozenCommand?.capturedMatchTimeLabel ??
        (state.clock.available ? state.clock.label : null);
    return [
      _button(
          state.homeTeamLabel,
          const SetTeamIntent(PresentationTeam.home,
              origin: IntentOrigin.watchUi),
          key: const Key('watch-sub-team-home')),
      _button(
          state.awayTeamLabel,
          const SetTeamIntent(PresentationTeam.away,
              origin: IntentOrigin.watchUi),
          key: const Key('watch-sub-team-away')),
      Text(
          'OUT ${state.substitution.outId ?? '-'}  IN ${state.substitution.inId ?? '-'}'),
      if (time != null)
        Text('Match time $time',
            key: const Key('watch-sub-review-time'),
            style: const TextStyle(
                fontFamily: 'Roboto', fontSize: 13, color: Color(0xFF0B2A4A))),
      for (final person in _visiblePeople()) ...[
        _button(
          'OUT #${person.shirtLabel} ${person.name}',
          SelectOutIntent(person.id, origin: IntentOrigin.watchUi),
          key: Key('watch-sub-out-${person.id}'),
        ),
        _button(
          'IN #${person.shirtLabel} ${person.name}',
          SelectInIntent(person.id, origin: IntentOrigin.watchUi),
          key: Key('watch-sub-in-${person.id}'),
        ),
      ],
      _button(
        'Record substitution',
        const ActivateIntent(PresentationAction.substitution,
            origin: IntentOrigin.watchUi),
        key: const Key('watch-record-substitution'),
      ),
      if (state.commit.label == ResearchCommitPhrases.saving)
        _button(
          'Resolve simulated outcome',
          const ResolveSimulatedCommitIntent(origin: IntentOrigin.watchUi),
        ),
      _button(
          'Back',
          const OpenRouteIntent(WatchRoute.liveCore,
              origin: IntentOrigin.watchUi)),
    ];
  }

  List<Widget> _awareness() {
    return [
      Text(state.discipline.awarenessLabel),
      Text('Successor established: ${state.discipline.successorEstablished}'),
      Text('Cautions ${state.discipline.cautionCount}'),
      Text('Send-offs ${state.discipline.sendOffCount}'),
      _button(
          'Back',
          const OpenRouteIntent(WatchRoute.liveCore,
              origin: IntentOrigin.watchUi)),
    ];
  }

  List<Widget> _history() {
    return [
      Text('Cautions recorded ${state.discipline.cautionCount}'),
      Text('Send-offs recorded ${state.discipline.sendOffCount}'),
      Text('Substitution ${state.substitution.stageLabel}'),
      _button(
          'Back',
          const OpenRouteIntent(WatchRoute.liveCore,
              origin: IntentOrigin.watchUi)),
    ];
  }

  List<PresentationParticipant> _visiblePeople() {
    final team = switch (state.header.teamContext) {
      PresentationTeamContext.home => PresentationTeam.home,
      PresentationTeamContext.away => PresentationTeam.away,
      PresentationTeamContext.absent ||
      PresentationTeamContext.ambiguous =>
        null,
    };
    if (team == null) return state.roster;
    return [
      for (final person in state.roster)
        if (person.team == team) person,
    ];
  }

  Widget _button(String label, WatchIntent intent, {Key? key}) {
    return _HoldButton(
      key: key,
      label: label,
      inputEpoch: inputEpoch,
      onCommit: () => onIntent(intent),
    );
  }

  String _reportLine(MatchReportEntryPresentation entry) {
    final headline = matchReportKindLabel(entry.kind);
    final buffer = StringBuffer('${entry.matchTimeLabel} $headline\n'
        '${entry.teamLabel} · ${entry.participantDisplay}');
    if (entry.details != null) buffer.write('\n${entry.details}');
    if (entry.scoreAfterLabel != null) {
      buffer.write('\nScore ${entry.scoreAfterLabel}');
    }
    return buffer.toString();
  }

  String _frozen(FrozenCommandPresentation command) {
    if (command.action == PresentationAction.goal) {
      return 'Frozen goal team ${command.scoringTeam?.name ?? '-'} scorer ${command.goalScorerParticipantId ?? '-'} time ${command.capturedMatchTimeLabel ?? '-'}';
    }
    return 'Frozen ${command.action.name} ${command.subjectId ?? '-'} ${command.scope.name} OUT ${command.outId ?? '-'} IN ${command.inId ?? '-'}';
  }
}

class _HoldButton extends StatefulWidget {
  const _HoldButton({
    super.key,
    required this.label,
    required this.inputEpoch,
    required this.onCommit,
  });

  final String label;
  final int inputEpoch;
  final VoidCallback onCommit;

  @override
  State<_HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<_HoldButton> {
  int? _pointer;
  int? _epoch;

  bool _contains(Offset global) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return false;
    return box.size.contains(box.globalToLocal(global));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (!mounted) return;
          _pointer = event.pointer;
          _epoch = widget.inputEpoch;
        },
        onPointerMove: (event) {
          if (!mounted || _pointer != event.pointer) return;
          if (!_contains(event.position)) _pointer = null;
        },
        onPointerUp: (event) {
          if (!mounted) return;
          final commit = _pointer == event.pointer &&
              _epoch == widget.inputEpoch &&
              _contains(event.position);
          _pointer = null;
          if (commit) widget.onCommit();
        },
        onPointerCancel: (event) {
          if (!mounted) return;
          if (_pointer == event.pointer) _pointer = null;
        },
        child: SizedBox(
          height: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF0B2A4A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  color: Color(0xFFF8FAFC),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
