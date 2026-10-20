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
      color: const Color(0xFFF8FAFC),
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
                color: Color(0xFF0B2A4A),
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
              color: Color(0xFF0B2A4A),
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
      WatchRoute.substitutionFlow => _substitution(),
      WatchRoute.disciplinaryAwareness => _awareness(),
      WatchRoute.history => _history(),
    };
  }

  List<Widget> _live() {
    return [
      _button('Capture', const OpenRouteIntent(WatchRoute.captureMenu, origin: IntentOrigin.watchUi)),
      _button('Awareness', const OpenRouteIntent(WatchRoute.disciplinaryAwareness, origin: IntentOrigin.watchUi)),
      _button('History', const OpenRouteIntent(WatchRoute.history, origin: IntentOrigin.watchUi)),
      if (state.commit.label == ResearchCommitPhrases.saving)
        _button(
          'Resolve simulated outcome',
          const ResolveSimulatedCommitIntent(origin: IntentOrigin.watchUi),
        ),
      Text(
        state.header.identityLabel,
        style: const TextStyle(fontFamily: 'Roboto', fontSize: 13, color: Color(0xFF0B2A4A)),
      ),
      Text(
        'Phase ${state.header.scope.name}',
        style: const TextStyle(fontFamily: 'Roboto', fontSize: 13, color: Color(0xFF0B2A4A)),
      ),
      Text(
        state.clock.label ?? 'Clock unavailable',
        style: const TextStyle(fontFamily: 'Roboto', fontSize: 13, color: Color(0xFF0B2A4A)),
      ),
      Text(
        state.score.label,
        style: const TextStyle(fontFamily: 'Roboto', fontSize: 13, color: Color(0xFF0B2A4A)),
      ),
    ];
  }

  List<Widget> _capture() {
    return [
      _button('Yellow', const OfferYellowIntent(origin: IntentOrigin.watchUi)),
      _button('Sending-off', const OpenRouteIntent(WatchRoute.sendOffFlow, origin: IntentOrigin.watchUi)),
      _button('Substitution', const OpenRouteIntent(WatchRoute.substitutionFlow, origin: IntentOrigin.watchUi)),
      _button('Back', const OpenRouteIntent(WatchRoute.liveCore, origin: IntentOrigin.watchUi)),
      const Text(
        'Goal capture is not offered by this research runtime.',
        style: TextStyle(fontFamily: 'Roboto', fontSize: 12, color: Color(0xFF0B2A4A)),
      ),
    ];
  }

  List<Widget> _yellow() {
    return [
      _button(
        'Record yellow',
        const ActivateIntent(PresentationAction.yellow, origin: IntentOrigin.watchUi),
      ),
      if (state.commit.label == ResearchCommitPhrases.saving)
        _button(
          'Resolve simulated outcome',
          const ResolveSimulatedCommitIntent(origin: IntentOrigin.watchUi),
        ),
      _button('Back', const OpenRouteIntent(WatchRoute.liveCore, origin: IntentOrigin.watchUi)),
      Text(state.discipline.awarenessLabel),
      for (final person in _visiblePeople())
        _button(
          '${person.team.name} ${person.shirtLabel} · ${person.id}',
          SelectParticipantIntent(person.id, origin: IntentOrigin.watchUi),
        ),
    ];
  }

  List<Widget> _sendOff() {
    return [
      _button(
        'Record direct send-off',
        const ActivateIntent(PresentationAction.directSendOff, origin: IntentOrigin.watchUi),
      ),
      _button(
        'Record second-caution send-off',
        const ActivateIntent(PresentationAction.secondCautionSendOff, origin: IntentOrigin.watchUi),
      ),
      _button('Offer direct send-off', const OfferDirectSendOffIntent(origin: IntentOrigin.watchUi)),
      const Text(
        'DIRECT and SECOND_CAUTION are separate final actions.',
        style: TextStyle(fontFamily: 'Roboto', fontSize: 12, color: Color(0xFF0B2A4A)),
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
    return [
      _button(
        'Record substitution',
        const ActivateIntent(PresentationAction.substitution, origin: IntentOrigin.watchUi),
      ),
      Text('OUT ${state.substitution.outId ?? '-'}  IN ${state.substitution.inId ?? '-'}'),
      for (final person in _visiblePeople()) ...[
        _button(
          'OUT ${person.shirtLabel} · ${person.id}',
          SelectOutIntent(person.id, origin: IntentOrigin.watchUi),
        ),
        _button(
          'IN ${person.shirtLabel} · ${person.id}',
          SelectInIntent(person.id, origin: IntentOrigin.watchUi),
        ),
      ],
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

  Widget _button(String label, WatchIntent intent) {
    return _HoldButton(
      label: label,
      inputEpoch: inputEpoch,
      onCommit: () => onIntent(intent),
    );
  }

  String _frozen(FrozenCommandPresentation command) {
    return 'Frozen ${command.action.name} ${command.subjectId ?? '-'} ${command.scope.name} OUT ${command.outId ?? '-'} IN ${command.inId ?? '-'}';
  }
}

class _HoldButton extends StatefulWidget {
  const _HoldButton({
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
