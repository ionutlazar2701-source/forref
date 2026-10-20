import 'dart:async';

import 'package:hf_v2/hf_v2.dart';
import 'package:simulator_geometry/simulator_geometry.dart';
import 'package:simulator_presentation/simulator_presentation.dart';

import 'project.dart';

/// Binds one research instrument to the presentation runtime.
///
/// Watch intents call accepted instrument methods. They do not append the
/// caution, send-off, or substitution lists themselves.
final class HfPresentationRuntime implements SimulatorPresentationRuntime {
  HfPresentationRuntime({ResearchInstrument? instrument})
      : _instrument = instrument ?? ResearchInstrument() {
    _instrument.loadScenario(ScenarioId.s01YellowNoPrior);
  }

  final ResearchInstrument _instrument;
  final StreamController<WatchPresentationState> _states =
      StreamController<WatchPresentationState>.broadcast();
  final List<IntentTraceEntry> _trace = [];
  WatchRoute _route = WatchRoute.liveCore;
  String? _profileId;
  String? _rejection;
  ProfileViewportContext? _viewport;

  ResearchInstrument get instrument => _instrument;

  ProfileViewportContext? get viewport => _viewport;

  @override
  WatchPresentationState get watchState => projectResearchSnapshot(
        _instrument.snapshot,
        route: _route,
        profileId: _profileId,
        lastRejection: _rejection,
      );

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
    _rejection = null;
    _apply(intent);
    if (!_states.isClosed) _states.add(watchState);
  }

  void bindProfile(DeviceProfileV2 profile) {
    _profileId = profile.identity.profileId;
    _viewport = viewportContextFor(profile);
    _instrument.noteProfileSelected(profile.identity.profileId);
    if (!_states.isClosed) _states.add(watchState);
  }

  void _apply(WatchIntent intent) {
    switch (intent) {
      case OpenRouteIntent(:final route):
        _route = route;
        _instrument.enterSurface(route.name);
      case SetTeamIntent(:final team):
        _instrument.setTeam(
          team == PresentationTeam.home
              ? ResearchTeamSide.home
              : ResearchTeamSide.away,
        );
      case SelectParticipantIntent(:final participantId):
        _instrument.selectParticipant(participantId);
      case SelectOfficialIntent(:final officialId):
        _instrument.selectOfficial(officialId);
      case SetScopeIntent(:final scope):
        _instrument.setScope(switch (scope) {
          PresentationScope.match => ResearchScope.match,
          PresentationScope.shootout => ResearchScope.shootout,
          PresentationScope.unresolved => ResearchScope.unresolved,
        });
      case OfferYellowIntent():
        _instrument.offerRecordYellow();
        _route = WatchRoute.yellowFlow;
      case OfferDirectSendOffIntent():
        _instrument.offerDirectSendOff();
        _route = WatchRoute.sendOffFlow;
      case SelectOutIntent(:final participantId):
        _instrument.selectOut(participantId);
        _route = WatchRoute.substitutionFlow;
      case SelectInIntent(:final participantId):
        _instrument.selectIn(participantId);
        _route = WatchRoute.substitutionFlow;
      case ActivateIntent(:final action):
        _instrument.accessibilityInvoke(switch (action) {
          PresentationAction.yellow => FinalActionKind.recordYellow,
          PresentationAction.directSendOff =>
            FinalActionKind.recordDirectSendOff,
          PresentationAction.secondCautionSendOff =>
            FinalActionKind.recordSecondCautionSendOff,
          PresentationAction.substitution => FinalActionKind.recordSubstitution,
        });
      case ResolveSimulatedCommitIntent():
        _instrument.resolveSimulatedCommit();
      case AcknowledgeUnknownIntent():
        _instrument.acknowledgeUnknownOutcome();
      case FocusLostIntent():
        _instrument.focusLost();
      case CancelForDeviceChangeIntent(:final profileId):
        _instrument.cancelOpenInputForDeviceChange(profileId);
        _profileId = profileId;
      case BindProfileIntent(:final profileId):
        _profileId = profileId;
        _instrument.noteProfileSelected(profileId);
      case LoadScenarioIntent(:final scenarioId):
        final match = _scenario(scenarioId);
        if (match == null) {
          _rejection = 'Unknown research scenario $scenarioId';
          _instrument.noteInputRejected('unknown-scenario');
          return;
        }
        _instrument.loadScenario(match);
        _route = WatchRoute.liveCore;
    }
  }

  ScenarioId? _scenario(String name) {
    for (final id in ScenarioId.values) {
      if (id.name == name) return id;
    }
    return null;
  }
}
