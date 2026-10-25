import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' hide ActivateIntent;
import 'package:hf_v2/hf_v2.dart';
import 'package:simulator_geometry/simulator_geometry.dart';
import 'package:simulator_hf_bridge/simulator_hf_bridge.dart';
import 'package:simulator_presentation/simulator_presentation.dart';
import 'package:simulator_sandbox/simulator_sandbox.dart';
import 'package:watch_reference_ui/watch_reference_ui.dart';

import 'src/lab_bridge.dart';
import 'src/lab_model.dart';
import 'src/lab_scaffold.dart';
import 'src/lab_theme.dart';
import 'src/paired_session.dart';

export 'src/lab_model.dart';
export 'src/paired_session.dart';
export 'src/lab_theme.dart' show LabColors, LabMetrics, labTitle, labIdentity;

enum ResearchPage {
  live,
  yellow,
  red,
  substitution,
  players,
  officials,
  commitment
}

/// Default factual shell. Huawei publishes case millimetres and a round
/// display, so the schematic shell is the most complete seed in the catalog.
const defaultShellProfileId = 'huawei-watch-gt4-46';

/// Second Compare device. Different shape and raster from the default shell.
const defaultCompareProfileId = 'amazfit-gts4';

/// Operator shell over the one research instrument.
///
/// Widgets do not append simulated records. Commit text comes from the instrument.
/// Workspace, inspector, compare ownership, and zoom are composition state.
class ResearchController extends ChangeNotifier {
  ResearchController({ResearchInstrument? instrument})
      : instrument = instrument ?? ResearchInstrument() {
    if (this.instrument.roster.isEmpty) {
      this.instrument.loadScenario(ScenarioId.s01YellowNoPrior);
    }
    watchRuntime = HfPresentationRuntime(instrument: this.instrument);
    _applyActiveLayout();
    this.instrument.noteProfileSelected(activeProfile.profileId);
    final shell = factualProfileById(defaultShellProfileId);
    if (shell != null) {
      watchRuntime.bindProfile(shell);
      shellProfileId = shell.identity.profileId;
      deviceShellVisible = true;
    }
    watchRuntime.bindMatchLabels(home: fixture.homeTeam, away: fixture.awayTeam);
    _ensureFootballTicker();
  }

  Timer? _footballTick;

  /// Widget tests leave this false so `pumpAndSettle` is not blocked.
  /// The Windows lab process starts the ticker after Kick-off.
  bool forceLiveClockInTest = false;

  bool get _underWidgetTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  void _ensureFootballTicker() {
    final run = instrument.liveClockArmed &&
        (forceLiveClockInTest || !_underWidgetTest);
    if (!run) {
      _footballTick?.cancel();
      _footballTick = null;
      return;
    }
    if (_footballTick != null) return;
    // One shared pulse per second. It does not rebuild on every frame, and
    // it does not re-read wall-clock time. Both surfaces rebuild from the
    // instrument when the displayed second changes.
    _footballTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (instrument.noteLiveElapsed(const Duration(seconds: 1))) {
        notifyListeners();
      }
    });
  }

  void stopFootballTicker() {
    _footballTick?.cancel();
    _footballTick = null;
  }

  /// Test double for the one-second pulse. Notifies both surfaces.
  void applyLiveElapsed(Duration delta) {
    if (instrument.noteLiveElapsed(delta)) notifyListeners();
  }

  @override
  void dispose() {
    stopFootballTicker();
    super.dispose();
  }

  final ResearchInstrument instrument;
  late final HfPresentationRuntime watchRuntime;

  // Composition state. None of it is sporting truth.
  LabWorkspace workspace = LabWorkspace.focus;
  InspectorSection? inspector;
  double stageZoom = 1;

  /// Presentation-only watch design controls. They do not write research records.
  WatchLiveLayout watchLiveLayout = WatchLiveLayout.centered;
  WatchDesignFrame watchDesignFrame = WatchDesignFrame.flow;
  bool watchBeyondNominal = false;
  WatchLanguage watchLanguage = WatchLanguage.en;
  String compareProfileId = defaultCompareProfileId;
  bool compareInputOnPrimary = true;
  bool deviceSelectorOpen = false;
  bool commandRailOpen = false;
  int layoutEpoch = 0;

  ResearchPage page = ResearchPage.live;
  CalibrationMode calibration = CalibrationMode.fit;
  double zoom = 1;
  bool holdResolution = false;
  bool simulatedTouchOverride = false;
  HostDisplayEvidence hostEvidence = HostDisplayEvidence.unknown;
  String? importMessage;
  bool importAccepted = false;
  bool deviceShellVisible = false;
  String shellProfileId = defaultShellProfileId;
  int inputEpoch = 0;
  String evidenceStamp = '';
  ResearchFixture fixture = ResearchFixture.defaults;
  PairedSessionState paired = PairedSessionState.initial(ResearchFixture.defaults);
  final List<String> pairedPresentationJournal = [];
  bool sandboxVisible = false;
  SandboxSession? sandboxSession;
  SandboxCaptureReport? sandboxReport;
  Directory? _sandboxRoot;

  final List<DeviceProfile> catalog = [...starterProfiles];
  DeviceProfile activeProfile = illustrativePhonePortrait;
  LayoutResolution activeLayout = LayoutResolution.notFit;

  bool get touchAllowed =>
      activeProfile.touchClaimedSupported || simulatedTouchOverride;

  bool get inspectorOpen => inspector != null;

  /// Evidence stamps are capture metadata, not state. Setting one through
  /// here repaints the footer so a frame carries the stamp taken for it.
  void setEvidenceStamp(String stamp) {
    evidenceStamp = stamp;
    notifyListeners();
  }

  bool get geometryStageVisible => !deviceShellVisible;

  LabRuntime get runtime =>
      sandboxVisible ? LabRuntime.integrationSandbox : LabRuntime.research;

  DeviceProfileV2? get shellProfile => factualProfileById(shellProfileId);

  DeviceProfileV2? get compareProfile => factualProfileById(compareProfileId);

  /// The device that owns Compare input. The other one is a read-only mirror.
  String get compareInputOwnerId =>
      compareInputOnPrimary ? shellProfileId : compareProfileId;

  // ---------------------------------------------------------------------------
  // Composition. These never touch the instrument.

  void setWorkspace(LabWorkspace next) {
    if (next == workspace) return;
    workspace = next;
    commandRailOpen = false;
    notifyListeners();
  }

  void openInspector(InspectorSection section) {
    inspector = section;
    notifyListeners();
  }

  void closeInspector() {
    if (inspector == null) return;
    inspector = null;
    notifyListeners();
  }

  void toggleInspector() {
    inspector = inspector == null ? InspectorSection.truth : null;
    notifyListeners();
  }

  void setStageZoom(double next) {
    stageZoom = next.clamp(0.5, 1.0);
    notifyListeners();
  }

  void _setDesign(void Function() apply) {
    apply();
    inputEpoch += 1;
    notifyListeners();
  }

  void setWatchLiveLayout(WatchLiveLayout next) {
    if (next == watchLiveLayout) return;
    _setDesign(() => watchLiveLayout = next);
  }

  void setWatchDesignFrame(WatchDesignFrame next) {
    if (next == watchDesignFrame) return;
    _setDesign(() => watchDesignFrame = next);
  }

  void setWatchBeyondNominal(bool next) {
    if (next == watchBeyondNominal) return;
    _setDesign(() => watchBeyondNominal = next);
  }

  void setWatchLanguage(WatchLanguage next) {
    if (next == watchLanguage) return;
    _setDesign(() => watchLanguage = next);
  }

  void setDeviceSelectorOpen(bool open) {
    if (deviceSelectorOpen == open) return;
    deviceSelectorOpen = open;
    notifyListeners();
  }

  void setCommandRailOpen(bool open) {
    if (commandRailOpen == open) return;
    commandRailOpen = open;
    notifyListeners();
  }

  /// Window regime change while a press may be held. Uses the same epoch
  /// mechanism as focus loss. It does not remap coordinates.
  void layoutRegimeChanged() {
    layoutEpoch += 1;
    inputEpoch += 1;
    instrument.focusLost();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Research scenario and legacy geometry stage.

  void load(ScenarioId id) {
    instrument.loadScenario(id);
    page = ResearchPage.live;
    _applyActiveLayout();
    notifyListeners();
  }

  void resetScenario() {
    load(instrument.scenarioId);
  }

  void show(ResearchPage next) {
    page = next;
    instrument.enterSurface(next.name);
    if (next == ResearchPage.yellow) instrument.offerRecordYellow();
    if (next == ResearchPage.red && !instrument.sendOffContinuationVisible) {
      instrument.offerDirectSendOff();
    }
    notifyListeners();
  }

  void setCalibration(CalibrationMode next) {
    calibration = next;
    notifyListeners();
  }

  void setZoom(double next) {
    zoom = next.clamp(0.25, 3);
    notifyListeners();
  }

  void setHold(bool value) {
    holdResolution = value;
    notifyListeners();
  }

  void setTouchOverride(bool value) {
    simulatedTouchOverride = value;
    notifyListeners();
  }

  void setHostEvidence(HostDisplayEvidence evidence) {
    hostEvidence = evidence;
    notifyListeners();
  }

  /// Selects the factual target device. Cancels open input, binds the
  /// presentation runtime, creates no record.
  void openDeviceShell(String profileId) {
    final profile = factualProfileById(profileId);
    if (profile == null) return;
    inputEpoch += 1;
    instrument.cancelOpenInputForDeviceChange(profileId);
    watchRuntime.bindProfile(profile);
    deviceShellVisible = true;
    deviceSelectorOpen = false;
    if (profileId == compareProfileId) {
      compareProfileId =
          shellProfileId == profileId ? _otherSeed(profileId) : shellProfileId;
    }
    shellProfileId = profileId;
    notifyListeners();
  }

  void selectCompareProfile(String profileId) {
    final profile = factualProfileById(profileId);
    if (profile == null || profileId == shellProfileId) return;
    inputEpoch += 1;
    instrument.cancelOpenInputForDeviceChange(compareInputOwnerId);
    compareProfileId = profileId;
    notifyListeners();
  }

  /// Moves Compare input to the other device. Cancels any held gesture.
  void setCompareInputOwner(String profileId) {
    final onPrimary = profileId == shellProfileId;
    if (!onPrimary && profileId != compareProfileId) return;
    if (onPrimary == compareInputOnPrimary) return;
    inputEpoch += 1;
    instrument.cancelOpenInputForDeviceChange(profileId);
    compareInputOnPrimary = onPrimary;
    notifyListeners();
  }

  String get matchTitle => fixture.matchName;

  Future<void> dispatchWatch(WatchIntent intent) async {
    await watchRuntime.dispatch(intent);
    _notePairedIntent(intent);
    _ensureFootballTicker();
    notifyListeners();
  }

  Future<void> dispatchMobile(WatchIntent intent) async {
    await dispatchWatch(intent);
  }

  void _notePairedIntent(WatchIntent intent) {
    final origin = originFromIntent(intent.origin);
    paired = paired.afterIntent(origin: origin, intentName: intent.name);
    pairedPresentationJournal.add(
      '${pairedPresentationJournal.length + 1} ${origin.label} ${intent.name}',
    );
  }

  /// Loads deterministic research fixture state. Does not write Match Memory.
  Future<void> applyResearchFixture(ResearchFixture next) async {
    fixture = next;
    watchRuntime.bindMatchLabels(home: next.homeTeam, away: next.awayTeam);
    paired = PairedSessionState.initial(next).afterIntent(
      origin: SimulatedActionOrigin.systemScenario,
      intentName: 'fixture:${next.scenarioId.name}',
    );
    openDeviceShell(next.watchProfileId);
    await watchRuntime.dispatch(
      LoadScenarioIntent(next.scenarioId.name,
          origin: IntentOrigin.operatorFixture),
    );
    page = ResearchPage.live;
    _applyActiveLayout();
    notifyListeners();
  }

  void setSimulatedDisconnect(bool disconnected) {
    paired = PairedSessionState(
      fixture: fixture,
      connection: disconnected
          ? SimulatedConnectionState.simulatedDisconnect
          : SimulatedConnectionState.pairActive,
      lastOrigin: paired.lastOrigin,
      lastIntentName: paired.lastIntentName,
      mobileUpdated: paired.mobileUpdated,
      watchUpdated: paired.watchUpdated,
      propagationNote: disconnected
          ? 'SIMULATED DISCONNECT · shared truth frozen in instrument'
          : 'SHARED MATCH STATE · SIMULATED PAIR',
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Operator fixture actions. Every one goes through the runtime with an
  // explicit operatorFixture origin so the trace stays distinguishable.

  Future<void> operatorLoadScenario(ScenarioId id) async {
    await watchRuntime.dispatch(
      LoadScenarioIntent(id.name, origin: IntentOrigin.operatorFixture),
    );
    page = ResearchPage.live;
    _applyActiveLayout();
    notifyListeners();
  }

  Future<void> operatorSetTeam(PresentationTeam team) =>
      dispatchWatch(SetTeamIntent(team, origin: IntentOrigin.operatorFixture));

  Future<void> operatorSetScope(PresentationScope scope) => dispatchWatch(
      SetScopeIntent(scope, origin: IntentOrigin.operatorFixture));

  Future<void> operatorHome14Yellow() async {
    await watchRuntime.dispatch(
      const SelectParticipantIntent('p-home-14',
          origin: IntentOrigin.operatorFixture),
    );
    await watchRuntime.dispatch(
      const OfferYellowIntent(origin: IntentOrigin.operatorFixture),
    );
    await watchRuntime.dispatch(
      const ActivateIntent(PresentationAction.yellow,
          origin: IntentOrigin.operatorFixture),
    );
    notifyListeners();
  }

  Future<void> operatorResolveSimulatedCommit() => dispatchWatch(
      const ResolveSimulatedCommitIntent(origin: IntentOrigin.operatorFixture));

  Future<void> operatorAcknowledgeUnknown() => dispatchWatch(
      const AcknowledgeUnknownIntent(origin: IntentOrigin.operatorFixture));

  Future<void> operatorReturnToLive() =>
      dispatchWatch(const OpenRouteIntent(WatchRoute.liveCore,
          origin: IntentOrigin.operatorFixture));

  void interrupt() {
    instrument.interrupt();
    notifyListeners();
  }

  void resume() {
    instrument.resume();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Journal snapshot and sandbox. The sandbox is an explicit operation. It is
  // never reached from a watch tap.

  void showJournalSnapshot({
    required String headline,
    required String detail,
    required List<String> lines,
  }) {
    sandboxVisible = true;
    sandboxReport = null;
    journalHeadline = headline;
    journalDetail = detail;
    journalLines = lines;
    inspector = InspectorSection.eventJournal;
    notifyListeners();
  }

  String? journalHeadline;
  String? journalDetail;
  List<String> journalLines = const [];

  Future<void> showSandbox() async {
    sandboxVisible = true;
    if (sandboxSession == null) {
      _sandboxRoot = await Directory.systemTemp.createTemp('forref-sim-lab-');
      sandboxSession = await SandboxSession.open(
        simulatorRoot: _sandboxRoot!,
        sessionId: 'lab-session01',
      );
    }
    notifyListeners();
  }

  void leaveSandbox() {
    if (!sandboxVisible) return;
    sandboxVisible = false;
    notifyListeners();
  }

  Future<void> commitSandboxYellow() async {
    await showSandbox();
    sandboxReport = await sandboxSession!.commitYellow(
      captureIntentId: 'sim-intent-lab-yellow',
      participantId: sandboxParticipantId,
    );
    inspector = InspectorSection.eventJournal;
    notifyListeners();
  }

  Future<void> abortSandboxYellow() async {
    await showSandbox();
    sandboxSession!.failNextCommit();
    sandboxReport = await sandboxSession!.commitYellow(
      captureIntentId: 'sim-intent-lab-abort',
      participantId: sandboxParticipantId,
    );
    inspector = InspectorSection.eventJournal;
    notifyListeners();
  }

  Future<void> reopenSandbox() async {
    final root = _sandboxRoot;
    if (root == null || sandboxSession == null) return;
    await sandboxSession!.close();
    sandboxSession = await SandboxSession.open(
      simulatorRoot: root,
      sessionId: 'lab-session01',
    );
    final stored =
        await sandboxSession!.readBack('sim-yellow-sim-intent-lab-yellow');
    sandboxSession!.journal.observe(
      JournalEventKind.recordReadBack,
      stored == null ? 'missing after reopen' : 'reopen ${stored.recordId}',
    );
    final ids = await sandboxSession!.rebuildProjection();
    sandboxSession!.journal.observe(
      JournalEventKind.projectionRebuilt,
      'reopen ${ids.join(',')}',
    );
    inspector = InspectorSection.eventJournal;
    notifyListeners();
  }

  /// Clears the observer only. The sqlite row stays.
  void clearSandboxJournal() {
    sandboxSession?.journal.clear();
    journalLines = const [];
    journalHeadline = null;
    journalDetail = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Night I geometry diagnostic stage. Advanced route, not the default.

  void openGeometryStage() {
    if (!deviceShellVisible) return;
    inputEpoch += 1;
    instrument.cancelOpenInputForDeviceChange(activeProfile.profileId);
    deviceShellVisible = false;
    notifyListeners();
  }

  void closeDeviceShell() => openGeometryStage();

  void closeGeometryStage() {
    if (deviceShellVisible) return;
    openDeviceShell(shellProfileId);
  }

  void selectProfile(String profileId) {
    DeviceProfile? next;
    for (final profile in catalog) {
      if (profile.profileId == profileId) next = profile;
    }
    if (next == null || next.profileId == activeProfile.profileId) return;
    instrument.cancelOpenInputForDeviceChange(next.profileId);
    activeProfile = next;
    _applyActiveLayout();
    instrument.noteProfileSelected(next.profileId);
    notifyListeners();
  }

  void importProfile(String raw) {
    final result = parseProfile(raw);
    if (result is ProfileRejected) {
      importAccepted = false;
      importMessage = result.violations.map((item) => item.message).join(' ');
      notifyListeners();
      return;
    }
    final profile = (result as ProfileAccepted).profile;
    catalog.removeWhere((item) => item.profileId == profile.profileId);
    catalog.add(profile);
    importAccepted = true;
    importMessage =
        'Loaded ${profile.profileId}. Evidence stays PROFILED until geometry checks pass.';
    if (profile.profileId != activeProfile.profileId) {
      instrument.cancelOpenInputForDeviceChange(profile.profileId);
      activeProfile = profile;
      _applyActiveLayout();
      instrument.noteProfileSelected(profile.profileId);
    }
    notifyListeners();
  }

  void devicePointerDown({
    required String profileId,
    required int pointerId,
    required double deviceX,
    required double deviceY,
    required bool inside,
  }) {
    if (profileId != activeProfile.profileId) return;
    if (!touchAllowed) {
      instrument.noteInputRejected(
        'touch-${activeProfile.capability(InputChannel.touchscreen).name}',
      );
      notifyListeners();
      return;
    }
    if (!inside || !activeLayout.fits) {
      instrument.noteInputRejected('outside-visible-or-safe');
      notifyListeners();
      return;
    }
    instrument.pointerDown(pointerId: pointerId, x: deviceX, y: deviceY);
    notifyListeners();
  }

  void devicePointerUp({
    required String profileId,
    required int pointerId,
    required double deviceX,
    required double deviceY,
  }) {
    if (profileId != activeProfile.profileId) return;
    if (!touchAllowed) return;
    instrument.pointerUp(pointerId: pointerId, x: deviceX, y: deviceY);
    if (!holdResolution && instrument.commitKind == SystemCommitKind.saving) {
      instrument.resolveSimulatedCommit();
    }
    notifyListeners();
  }

  void devicePointerCancel(String profileId, int pointerId) {
    if (profileId != activeProfile.profileId) return;
    instrument.pointerCancel(pointerId: pointerId);
    notifyListeners();
  }

  void resolveHeldCommit() {
    instrument.resolveSimulatedCommit();
    notifyListeners();
  }

  void focusLost() {
    inputEpoch += 1;
    instrument.focusLost();
    notifyListeners();
  }

  void refresh() {
    notifyListeners();
  }

  void _applyActiveLayout() {
    activeLayout = placementFor(activeProfile);
    if (!activeLayout.fits) {
      instrument.relayout(unreachableResearchLayout,
          detail: activeLayout.label);
      return;
    }
    instrument.relayout(
      researchLayoutFrom(activeLayout),
      detail: '${activeProfile.profileId}:${activeLayout.label}',
    );
  }

  String _otherSeed(String profileId) {
    for (final profile in factualSeedProfiles) {
      if (profile.identity.profileId != profileId) {
        return profile.identity.profileId;
      }
    }
    return profileId;
  }
}

class ResearchApp extends StatelessWidget {
  const ResearchApp({super.key, required this.controller});

  final ResearchController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: labTitle,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0B2A4A),
        fontFamily: 'Roboto',
      ),
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => LabScaffold(controller: controller),
      ),
    );
  }
}
