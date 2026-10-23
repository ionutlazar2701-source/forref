import 'package:flutter/material.dart' hide ActivateIntent;
import 'package:simulator_presentation/simulator_presentation.dart';

/// Interactive FORREF watch reference surface.
///
/// The same widget runs on every device profile. Geometry is the parent's
/// constraint. Football actions are [WatchIntent]s.
class WatchReferenceApp extends StatelessWidget {
  const WatchReferenceApp({
    super.key,
    required this.state,
    required this.onIntent,
    this.degradedLabel,
    this.inputEpoch = 0,
  });

  final WatchPresentationState state;
  final void Function(WatchIntent intent) onIntent;
  final String? degradedLabel;

  /// Changes when focus is lost or the device changes.
  ///
  /// A press that started on an older epoch does not commit.
  final int inputEpoch;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF10283F),
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
                    color: Color(0xFFF4F9FC),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            );
          }
          return _FitBody(
            state: state,
            degradedLabel: degradedLabel,
            onIntent: onIntent,
            inputEpoch: inputEpoch,
          );
        },
      ),
    );
  }
}

class _FitBody extends StatelessWidget {
  const _FitBody({
    required this.state,
    required this.degradedLabel,
    required this.onIntent,
    required this.inputEpoch,
  });

  final WatchPresentationState state;
  final String? degradedLabel;
  final void Function(WatchIntent intent) onIntent;
  final int inputEpoch;

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
              style: const TextStyle(
                color: Color(0xFF5B7EA6),
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
              style: const TextStyle(
                color: Color(0xFFF4F9FC),
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
            style: const TextStyle(
              color: Color(0xFFF4F9FC),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: 'Roboto',
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _pages(),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _pages() {
    return switch (state.navigation.route) {
      WatchRoute.liveCore => _live(),
      WatchRoute.captureMenu => _capture(),
      WatchRoute.yellowFlow => _yellow(),
      WatchRoute.sendOffFlow => _sendOff(),
      WatchRoute.goalFlow => _goal(),
      WatchRoute.substitutionFlow => _substitution(),
      WatchRoute.disciplinaryAwareness => _awareness(),
      WatchRoute.history => _history(),
      WatchRoute.matchReport => _matchReport(),
    };
  }

  List<Widget> _live() {
    final ready = state.clock.kickOffAvailable;
    final clockText = state.clock.label ?? (ready ? 'Not started' : state.clock.phaseLabel);
    final showPhase = state.clock.phaseLabel != clockText;
    return [
      if (showPhase)
        Text(
          state.clock.phaseLabel,
          key: const Key('watch-phase'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: Color(0xFF26C0CA),
          ),
        ),
      Text(
        clockText,
        key: const Key('watch-clock'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Roboto', fontSize: 34, fontWeight: FontWeight.w700, color: Color(0xFFF4F9FC), height: 1.05),
      ),
      Text(
        state.score.label,
        key: const Key('watch-score'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFF4F9FC)),
      ),
      Text(
        '${state.homeTeamLabel} v ${state.awayTeamLabel}',
        key: const Key('watch-match-title'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Roboto', fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFB7C9D6)),
      ),
      if (ready) _kickOffButton(),
      if (!ready)
        _button('Capture', const OpenRouteIntent(WatchRoute.captureMenu, origin: IntentOrigin.watchUi)),
      _button('Match Report', const OpenRouteIntent(WatchRoute.matchReport, origin: IntentOrigin.watchUi)),
      if (!ready) ...[
        _button('Awareness', const OpenRouteIntent(WatchRoute.disciplinaryAwareness, origin: IntentOrigin.watchUi)),
        _button('History', const OpenRouteIntent(WatchRoute.history, origin: IntentOrigin.watchUi)),
      ],
      if (state.commit.label == ResearchCommitPhrases.saving)
        _button(
          'Resolve simulated outcome',
          const ResolveSimulatedCommitIntent(origin: IntentOrigin.watchUi),
        ),
      Text(
        state.header.identityLabel,
        style: const TextStyle(fontFamily: 'Roboto', fontSize: 13, color: Color(0xFFF4F9FC)),
      ),
      Text(
        'Phase ${state.header.scope.name}',
        style: const TextStyle(fontFamily: 'Roboto', fontSize: 13, color: Color(0xFFF4F9FC)),
      ),
    ];
  }

  List<Widget> _capture() {
    return [
      _button('Goal', const OfferGoalIntent(origin: IntentOrigin.watchUi), key: const Key('watch-capture-goal')),
      _button('Yellow', const OfferYellowIntent(origin: IntentOrigin.watchUi)),
      _button('Sending-off', const OpenRouteIntent(WatchRoute.sendOffFlow, origin: IntentOrigin.watchUi)),
      _button('Substitution', const OpenRouteIntent(WatchRoute.substitutionFlow, origin: IntentOrigin.watchUi)),
      _button('Back', const OpenRouteIntent(WatchRoute.liveCore, origin: IntentOrigin.watchUi)),
    ];
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
        style: TextStyle(fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFF4F9FC)),
      ),
      _button(
        state.homeTeamLabel,
        const SetTeamIntent(PresentationTeam.home, origin: IntentOrigin.watchUi),
        key: const Key('watch-goal-team-home'),
      ),
      _button(
        state.awayTeamLabel,
        const SetTeamIntent(PresentationTeam.away, origin: IntentOrigin.watchUi),
        key: const Key('watch-goal-team-away'),
      ),
      if (flow.scoringTeam != null)
        Text(
          teamLabel,
          key: const Key('watch-goal-selected-team'),
          style: const TextStyle(fontFamily: 'Roboto', fontSize: 13, color: Color(0xFFF4F9FC)),
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
          style: const TextStyle(fontFamily: 'Roboto', fontSize: 13, color: Color(0xFFF4F9FC)),
        ),
      if (flow.canRecord)
        _button(
          'Record Goal',
          const ActivateIntent(PresentationAction.goal, origin: IntentOrigin.watchUi),
          key: const Key('watch-record-goal'),
        )
      else if (flow.blockReason != null)
        Text(flow.blockReason!, style: const TextStyle(fontFamily: 'Roboto', fontSize: 12, color: Color(0xFFF4F9FC))),
      if (state.commit.label == ResearchCommitPhrases.saving)
        _button(
          'Resolve simulated outcome',
          const ResolveSimulatedCommitIntent(origin: IntentOrigin.watchUi),
          key: const Key('watch-resolve-goal'),
        ),
      _button('Back', const OpenRouteIntent(WatchRoute.liveCore, origin: IntentOrigin.watchUi)),
    ];
  }

  List<Widget> _matchReport() {
    return [
      const Text(
        'MATCH REPORT',
        key: Key('watch-match-report-heading'),
        style: TextStyle(fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFF4F9FC)),
      ),
      for (final entry in state.matchReport.entries)
        Text(
          _reportLine(entry),
          key: Key('watch-match-report-entry-${entry.sequence}'),
          style: const TextStyle(fontFamily: 'Roboto', fontSize: 12, color: Color(0xFFF4F9FC)),
        ),
      if (state.matchReport.entries.isEmpty)
        const Text(
          'No established events',
          key: Key('watch-match-report-empty'),
          style: TextStyle(fontFamily: 'Roboto', fontSize: 12, color: Color(0xFFF4F9FC)),
        ),
      _button('Back', const OpenRouteIntent(WatchRoute.liveCore, origin: IntentOrigin.watchUi)),
    ];
  }

  List<PresentationParticipant> _goalScorers() {
    final team = state.goalFlow.scoringTeam;
    if (team == null) return const [];
    return [for (final person in state.roster) if (person.team == team) person];
  }

  List<Widget> _yellow() {
    final time = state.frozenCommand?.capturedMatchTimeLabel ??
        (state.clock.available ? state.clock.label : null);
    return [
      const Text('YELLOW', style: TextStyle(fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFF4F9FC))),
      _button(state.homeTeamLabel, const SetTeamIntent(PresentationTeam.home, origin: IntentOrigin.watchUi), key: const Key('watch-yellow-team-home')),
      _button(state.awayTeamLabel, const SetTeamIntent(PresentationTeam.away, origin: IntentOrigin.watchUi), key: const Key('watch-yellow-team-away')),
      Text(state.discipline.awarenessLabel, key: const Key('watch-prior-awareness')),
      if (time != null)
        Text('Match time $time', key: const Key('watch-yellow-review-time'), style: const TextStyle(fontFamily: 'Roboto', fontSize: 13, color: Color(0xFFF4F9FC))),
      for (final person in _visiblePeople())
        _button(
          '#${person.shirtLabel} ${person.name}',
          SelectParticipantIntent(person.id, origin: IntentOrigin.watchUi),
          key: Key('watch-yellow-subject-${person.id}'),
        ),
      _button(
        'Record yellow',
        const ActivateIntent(PresentationAction.yellow, origin: IntentOrigin.watchUi),
        key: const Key('watch-record-yellow'),
      ),
      if (state.commit.label == ResearchCommitPhrases.saving)
        _button(
          'Resolve simulated outcome',
          const ResolveSimulatedCommitIntent(origin: IntentOrigin.watchUi),
          key: const Key('watch-resolve-yellow'),
        ),
      _button('Back', const OpenRouteIntent(WatchRoute.liveCore, origin: IntentOrigin.watchUi)),
    ];
  }

  List<Widget> _sendOff() {
    final time = state.frozenCommand?.capturedMatchTimeLabel ??
        (state.clock.available ? state.clock.label : null);
    return [
      _button(state.homeTeamLabel, const SetTeamIntent(PresentationTeam.home, origin: IntentOrigin.watchUi), key: const Key('watch-sendoff-team-home')),
      _button(state.awayTeamLabel, const SetTeamIntent(PresentationTeam.away, origin: IntentOrigin.watchUi), key: const Key('watch-sendoff-team-away')),
      for (final person in _visiblePeople())
        _button(
          '#${person.shirtLabel} ${person.name}',
          SelectParticipantIntent(person.id, origin: IntentOrigin.watchUi),
          key: Key('watch-sendoff-subject-${person.id}'),
        ),
      if (time != null)
        Text('Match time $time', key: const Key('watch-sendoff-review-time'), style: const TextStyle(fontFamily: 'Roboto', fontSize: 13, color: Color(0xFFF4F9FC))),
      _button(
        'Record direct send-off',
        const ActivateIntent(PresentationAction.directSendOff, origin: IntentOrigin.watchUi),
        key: const Key('watch-record-direct-sendoff'),
      ),
      _button(
        'Record second-caution send-off',
        const ActivateIntent(PresentationAction.secondCautionSendOff, origin: IntentOrigin.watchUi),
        key: const Key('watch-record-second-sendoff'),
      ),
      _button('Offer direct send-off', const OfferDirectSendOffIntent(origin: IntentOrigin.watchUi)),
      const Text(
        'DIRECT and SECOND_CAUTION are separate final actions.',
        style: TextStyle(fontFamily: 'Roboto', fontSize: 12, color: Color(0xFFF4F9FC)),
      ),
      if (state.commit.label == ResearchCommitPhrases.saving)
        _button(
          'Resolve simulated outcome',
          const ResolveSimulatedCommitIntent(origin: IntentOrigin.watchUi),
        ),
      _button('Back', const OpenRouteIntent(WatchRoute.liveCore, origin: IntentOrigin.watchUi)),
    ];
  }

  List<Widget> _substitution() {
    final time = state.frozenCommand?.capturedMatchTimeLabel ??
        (state.clock.available ? state.clock.label : null);
    return [
      _button(state.homeTeamLabel, const SetTeamIntent(PresentationTeam.home, origin: IntentOrigin.watchUi), key: const Key('watch-sub-team-home')),
      _button(state.awayTeamLabel, const SetTeamIntent(PresentationTeam.away, origin: IntentOrigin.watchUi), key: const Key('watch-sub-team-away')),
      Text('OUT ${state.substitution.outId ?? '-'}  IN ${state.substitution.inId ?? '-'}'),
      if (time != null)
        Text('Match time $time', key: const Key('watch-sub-review-time'), style: const TextStyle(fontFamily: 'Roboto', fontSize: 13, color: Color(0xFFF4F9FC))),
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
        const ActivateIntent(PresentationAction.substitution, origin: IntentOrigin.watchUi),
        key: const Key('watch-record-substitution'),
      ),
      if (state.commit.label == ResearchCommitPhrases.saving)
        _button(
          'Resolve simulated outcome',
          const ResolveSimulatedCommitIntent(origin: IntentOrigin.watchUi),
        ),
      _button('Back', const OpenRouteIntent(WatchRoute.liveCore, origin: IntentOrigin.watchUi)),
    ];
  }

  List<Widget> _awareness() {
    return [
      Text(state.discipline.awarenessLabel),
      Text('Successor established: ${state.discipline.successorEstablished}'),
      Text('Cautions ${state.discipline.cautionCount}'),
      Text('Send-offs ${state.discipline.sendOffCount}'),
      _button('Back', const OpenRouteIntent(WatchRoute.liveCore, origin: IntentOrigin.watchUi)),
    ];
  }

  List<Widget> _history() {
    return [
      Text('Cautions recorded ${state.discipline.cautionCount}'),
      Text('Send-offs recorded ${state.discipline.sendOffCount}'),
      Text('Substitution ${state.substitution.stageLabel}'),
      _button('Back', const OpenRouteIntent(WatchRoute.liveCore, origin: IntentOrigin.watchUi)),
    ];
  }

  List<PresentationParticipant> _visiblePeople() {
    final team = switch (state.header.teamContext) {
      PresentationTeamContext.home => PresentationTeam.home,
      PresentationTeamContext.away => PresentationTeam.away,
      PresentationTeamContext.absent || PresentationTeamContext.ambiguous => null,
    };
    if (team == null) return state.roster;
    return [
      for (final person in state.roster)
        if (person.team == team) person,
    ];
  }

  Widget _kickOffButton() {
    return _HoldButton(
      key: const Key('watch-kick-off'),
      label: 'Kick-off',
      inputEpoch: inputEpoch,
      onArm: () => onIntent(
        const ArmKickOffIntent(origin: IntentOrigin.watchUi),
      ),
      onCommit: () => onIntent(
        const ConfirmKickOffIntent(origin: IntentOrigin.watchUi),
      ),
    );
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
    this.onArm,
  });

  final String label;
  final int inputEpoch;
  final VoidCallback onCommit;
  final VoidCallback? onArm;

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
          widget.onArm?.call();
        },
        onPointerMove: (event) {
          if (!mounted || _pointer != event.pointer) return;
          if (!_contains(event.position)) _pointer = null;
        },
        onPointerUp: (event) {
          if (!mounted) return;
          final commit =
              _pointer == event.pointer &&
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
              color: const Color(0xFF1A5270),
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
