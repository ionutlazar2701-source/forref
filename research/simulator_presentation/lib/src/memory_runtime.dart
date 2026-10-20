import 'dart:async';

import 'intent.dart';
import 'runtime.dart';
import 'state.dart';

/// In-memory presentation stand-in.
///
/// It records navigation, team, and selection requests. It has no caution
/// list, no send-off list, and no substitution list. Activate does not
/// invent a saved outcome.
final class InMemoryPresentationRuntime implements SimulatorPresentationRuntime {
  InMemoryPresentationRuntime() : _state = WatchPresentationState.empty;

  WatchPresentationState _state;
  final StreamController<WatchPresentationState> _states =
      StreamController<WatchPresentationState>.broadcast();
  final List<IntentTraceEntry> _trace = [];

  @override
  WatchPresentationState get watchState => _state;

  @override
  Stream<WatchPresentationState> get watchStates => _states.stream;

  @override
  List<IntentTraceEntry> get intentTrace => List.unmodifiable(_trace);

  @override
  Future<void> dispatch(WatchIntent intent) async {
    _trace.add(
      IntentTraceEntry(
        sequence: _trace.length + 1,
        origin: intent.origin,
        intentName: intent.name,
        detail: intentOriginLabel(intent.origin),
      ),
    );
    _state = _reduce(_state, intent);
    if (!_states.isClosed) _states.add(_state);
  }

  WatchPresentationState _reduce(WatchPresentationState current, WatchIntent intent) {
    return switch (intent) {
      OpenRouteIntent(:final route) => _copy(
          current,
          navigation: NavigationPresentation(
            route: route,
            canOpenCapture: current.navigation.canOpenCapture,
          ),
        ),
      SetTeamIntent(:final team) => _copy(
          current,
          header: MatchHeaderPresentation(
            scenarioId: current.scenarioId,
            teamContext: team == PresentationTeam.home
                ? PresentationTeamContext.home
                : PresentationTeamContext.away,
            scope: current.header.scope,
            identityLabel: current.header.identityLabel,
          ),
          selection: const SelectionPresentation(
            subjectId: null,
            subjectKind: null,
            shirtLabel: null,
            name: null,
            team: null,
          ),
        ),
      BindProfileIntent(:final profileId) => _copy(current, profileId: profileId),
      ActivateIntent() => _copy(
          current,
          lastRejection: 'In-memory runtime cannot activate a sporting action.',
        ),
      _ => _copy(
          current,
          lastRejection: 'In-memory runtime does not apply ${intent.name}.',
        ),
    };
  }

  WatchPresentationState _copy(
    WatchPresentationState current, {
    String? profileId,
    MatchHeaderPresentation? header,
    SelectionPresentation? selection,
    NavigationPresentation? navigation,
    String? lastRejection,
  }) {
    return WatchPresentationState(
      scenarioId: current.scenarioId,
      profileId: profileId ?? current.profileId,
      header: header ?? current.header,
      clock: current.clock,
      score: current.score,
      selection: selection ?? current.selection,
      discipline: current.discipline,
      substitution: current.substitution,
      frozenCommand: current.frozenCommand,
      commit: current.commit,
      navigation: navigation ?? current.navigation,
      roster: current.roster,
      officials: current.officials,
      recoveryLabel: current.recoveryLabel,
      lastRejection: lastRejection,
    );
  }
}
