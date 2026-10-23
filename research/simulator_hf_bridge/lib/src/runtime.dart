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
    if (instrument == null) {
      _instrument.loadScenario(ScenarioId.s01YellowNoPrior);
    }
  }

  final ResearchInstrument _instrument;
  final StreamController<WatchPresentationState> _states =
      StreamController<WatchPresentationState>.broadcast();
  final List<IntentTraceEntry> _trace = [];
  WatchRoute _route = WatchRoute.liveCore;
  String? _profileId;
  String? _rejection;
  ProfileViewportContext? _viewport;
  String _homeTeamLabel = 'Home';
  String _awayTeamLabel = 'Away';
  bool _yellowCapture = false;
  bool _directCapture = false;

  ResearchInstrument get instrument => _instrument;

  ProfileViewportContext? get viewport => _viewport;

  void bindMatchLabels({required String home, required String away}) {
    _homeTeamLabel = home;
    _awayTeamLabel = away;
    if (!_states.isClosed) _states.add(watchState);
  }

  @override
  WatchPresentationState get watchState => projectResearchSnapshot(
        _instrument.snapshot,
        route: _route,
        profileId: _profileId,
        lastRejection: _rejection,
        homeTeamLabel: _homeTeamLabel,
        awayTeamLabel: _awayTeamLabel,
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
        if (route == WatchRoute.sendOffFlow) _directCapture = true;
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
      case OfferGoalIntent():
        _instrument.offerRecordGoal();
        _route = WatchRoute.goalFlow;
      case OfferYellowIntent():
        _yellowCapture = true;
        _instrument.offerRecordYellow();
        _route = WatchRoute.yellowFlow;
      case AdvanceMatchClockIntent(:final seconds):
        _instrument.advanceMatchClock(seconds);
      case OfferDirectSendOffIntent():
        _directCapture = true;
        _instrument.offerDirectSendOff();
        _route = WatchRoute.sendOffFlow;
      case SelectOutIntent(:final participantId):
        _instrument.selectOut(participantId);
        _route = WatchRoute.substitutionFlow;
      case SelectInIntent(:final participantId):
        _instrument.selectIn(participantId);
        _route = WatchRoute.substitutionFlow;
      case ActivateIntent(:final action, :final origin):
        final originTrace = intentOriginLabel(origin);
        switch (action) {
          case PresentationAction.goal:
            _instrument.accessibilityInvoke(
              FinalActionKind.recordGoal,
              originTrace: originTrace,
            );
            _finishProductRecordIfScriptedSuccess(FinalActionKind.recordGoal);
          case PresentationAction.yellow:
            if (_yellowCapture) _instrument.offerRecordYellow();
            _instrument.accessibilityInvoke(
              FinalActionKind.recordYellow,
              originTrace: originTrace,
            );
            _finishProductRecordIfScriptedSuccess(FinalActionKind.recordYellow);
            if (_instrument.commitKind == SystemCommitKind.saved) {
              _yellowCapture = false;
            }
          case PresentationAction.directSendOff:
            if (_directCapture) _instrument.offerDirectSendOff();
            _instrument.accessibilityInvoke(
              FinalActionKind.recordDirectSendOff,
              originTrace: originTrace,
            );
            _finishProductRecordIfScriptedSuccess(
              FinalActionKind.recordDirectSendOff,
            );
            if (_instrument.commitKind == SystemCommitKind.saved) {
              _directCapture = false;
            }
          case PresentationAction.secondCautionSendOff:
            _instrument.accessibilityInvoke(
              FinalActionKind.recordSecondCautionSendOff,
              originTrace: originTrace,
            );
            _finishProductRecordIfScriptedSuccess(
              FinalActionKind.recordSecondCautionSendOff,
            );
          case PresentationAction.substitution:
            _instrument.accessibilityInvoke(
              FinalActionKind.recordSubstitution,
              originTrace: originTrace,
            );
            _finishProductRecordIfScriptedSuccess(
              FinalActionKind.recordSubstitution,
            );
        }
      case ResolveSimulatedCommitIntent():
        _instrument.resolveSimulatedCommit();
        if (_instrument.commitKind == SystemCommitKind.saved &&
            _route != WatchRoute.liveCore &&
            _route != WatchRoute.matchReport) {
          _route = WatchRoute.liveCore;
        }
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
        _yellowCapture = false;
        _directCapture = false;
    }
  }

  /// Scripted success completes the frozen command in the same Record intent.
  ///
  /// Known failure and unknown stay in [SystemCommitKind.saving] until an
  /// explicit resolve. The command is still frozen before this resolve runs.
  void _finishProductRecordIfScriptedSuccess(FinalActionKind kind) {
    if (_instrument.pendingAction != kind) return;
    if (_instrument.commitKind != SystemCommitKind.saving) return;
    if (!_instrument.simulatedOutcomeIsSuccess(kind)) return;
    _instrument.resolveSimulatedCommit();
    if (_instrument.commitKind == SystemCommitKind.saved &&
        _route != WatchRoute.liveCore &&
        _route != WatchRoute.matchReport) {
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
