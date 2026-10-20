import 'package:flutter/material.dart' hide ActivateIntent;
import 'package:hf_v2/hf_v2.dart';
import 'dart:io';

import 'package:simulator_geometry/simulator_geometry.dart';
import 'package:simulator_hf_bridge/simulator_hf_bridge.dart';
import 'package:simulator_presentation/simulator_presentation.dart';
import 'package:simulator_sandbox/simulator_sandbox.dart';
import 'package:watch_reference_ui/watch_reference_ui.dart';

import 'src/device_shell_stage.dart';
import 'src/device_stage.dart';
import 'src/lab_bridge.dart';
import 'src/lab_theme.dart';
import 'src/truth_inspector.dart';

enum ResearchPage { live, yellow, red, substitution, players, officials, commitment }

enum LabMode { focus, inspection }

enum LabPresentation { single, comparison }

/// Operator shell over the one research instrument.
///
/// Widgets do not append simulated records. Commit text comes from the instrument.
class ResearchController extends ChangeNotifier {
  ResearchController({ResearchInstrument? instrument})
      : instrument = instrument ?? ResearchInstrument() {
    watchRuntime = HfPresentationRuntime(instrument: this.instrument);
    _applyActiveLayout();
    this.instrument.noteProfileSelected(activeProfile.profileId);
  }

  final ResearchInstrument instrument;
  late final HfPresentationRuntime watchRuntime;
  ResearchPage page = ResearchPage.live;
  LabMode mode = LabMode.focus;
  LabPresentation presentation = LabPresentation.single;
  CalibrationMode calibration = CalibrationMode.fit;
  double zoom = 1;
  bool holdResolution = false;
  bool simulatedTouchOverride = false;
  HostDisplayEvidence hostEvidence = HostDisplayEvidence.unknown;
  String? importMessage;
  bool importAccepted = false;
  bool deviceShellVisible = false;
  String shellProfileId = 'amazfit-gts4';
  int inputEpoch = 0;
  String evidenceStamp = '';
  bool sandboxVisible = false;
  SandboxSession? sandboxSession;
  SandboxCaptureReport? sandboxReport;
  Directory? _sandboxRoot;

  final List<DeviceProfile> catalog = [...starterProfiles];
  DeviceProfile activeProfile = illustrativePhonePortrait;
  LayoutResolution activeLayout = LayoutResolution.notFit;

  bool get touchAllowed =>
      activeProfile.touchClaimedSupported || simulatedTouchOverride;

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

  void setMode(LabMode next) {
    mode = next;
    notifyListeners();
  }

  void setPresentation(LabPresentation next) {
    presentation = next;
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

  void openDeviceShell(String profileId) {
    final profile = factualProfileById(profileId);
    if (profile == null) return;
    inputEpoch += 1;
    instrument.cancelOpenInputForDeviceChange(profileId);
    watchRuntime.bindProfile(profile);
    deviceShellVisible = true;
    shellProfileId = profileId;
    notifyListeners();
  }

  Future<void> dispatchWatch(WatchIntent intent) async {
    await watchRuntime.dispatch(intent);
    notifyListeners();
  }

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

  Future<void> commitSandboxYellow() async {
    await showSandbox();
    sandboxReport = await sandboxSession!.commitYellow(
      captureIntentId: 'sim-intent-lab-yellow',
      participantId: sandboxParticipantId,
    );
    notifyListeners();
  }

  Future<void> abortSandboxYellow() async {
    await showSandbox();
    sandboxSession!.failNextCommit();
    sandboxReport = await sandboxSession!.commitYellow(
      captureIntentId: 'sim-intent-lab-abort',
      participantId: sandboxParticipantId,
    );
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
    final stored = await sandboxSession!.readBack('sim-yellow-sim-intent-lab-yellow');
    sandboxSession!.journal.observe(
      JournalEventKind.recordReadBack,
      stored == null ? 'missing after reopen' : 'reopen ${stored.recordId}',
    );
    final ids = await sandboxSession!.rebuildProjection();
    sandboxSession!.journal.observe(
      JournalEventKind.projectionRebuilt,
      'reopen ${ids.join(',')}',
    );
    notifyListeners();
  }

  Future<void> operatorHome14Yellow() async {
    await watchRuntime.dispatch(
      const SelectParticipantIntent('p-home-14', origin: IntentOrigin.operatorFixture),
    );
    await watchRuntime.dispatch(
      const OfferYellowIntent(origin: IntentOrigin.operatorFixture),
    );
    await watchRuntime.dispatch(
      const ActivateIntent(PresentationAction.yellow, origin: IntentOrigin.operatorFixture),
    );
    notifyListeners();
  }

  void closeDeviceShell() {
    if (!deviceShellVisible) return;
    inputEpoch += 1;
    instrument.cancelOpenInputForDeviceChange(activeProfile.profileId);
    deviceShellVisible = false;
    notifyListeners();
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
    importMessage = 'Loaded ${profile.profileId}. Evidence stays PROFILED until geometry checks pass.';
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
      instrument.relayout(unreachableResearchLayout, detail: activeLayout.label);
      return;
    }
    instrument.relayout(
      researchLayoutFrom(activeLayout),
      detail: '${activeProfile.profileId}:${activeLayout.label}',
    );
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
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ResearchScaffold(controller: controller),
      ),
    );
  }
}

class ResearchScaffold extends StatelessWidget {
  const ResearchScaffold({super.key, required this.controller});

  final ResearchController controller;

  @override
  Widget build(BuildContext context) {
    final instrument = controller.instrument;
    final snapshot = instrument.snapshot;
    return Focus(
      autofocus: true,
      onFocusChange: (focused) {
        if (!focused) controller.focusLost();
      },
      child: RepaintBoundary(
        key: const Key('lab-boundary'),
        child: Scaffold(
        backgroundColor: LabColors.softWhite,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ColoredBox(
              color: LabColors.turquoise,
              child: SizedBox(height: 3),
            ),
            ColoredBox(
              color: LabColors.navy,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        labTitle,
                        style: TextStyle(
                          color: LabColors.softWhite,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Text(
                      labIdentity,
                      style: TextStyle(color: LabColors.softWhite, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => controller.setMode(
                        controller.mode == LabMode.focus
                            ? LabMode.inspection
                            : LabMode.focus,
                      ),
                      child: Text(
                        controller.mode == LabMode.focus ? 'Inspection' : 'Focus',
                        style: const TextStyle(color: LabColors.softWhite),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _StatusStrip(snapshot: snapshot),
            Expanded(
              child: controller.mode == LabMode.inspection
                  ? _InspectionBody(controller: controller, snapshot: snapshot)
                  : _FocusBody(controller: controller),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.snapshot});

  final ResearchTruthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final subject = snapshot.selectedSubjectId ?? '-';
    final cautionCount = snapshot.cautions
        .where(
          (item) => item.subjectId == subject && item.scope == snapshot.scope,
        )
        .length;
    final twoCautions = snapshot.cautions
            .where(
              (item) =>
                  item.subjectId == subject &&
                  item.kind == snapshot.selectedSubjectKind &&
                  item.scope == snapshot.scope,
            )
            .length >=
        2;
    final sentOff = snapshot.sendOffs.any(
      (item) => item.subjectId == subject && item.scope == snapshot.scope,
    );
    final inFlight = snapshot.inFlight;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${snapshot.commitLabel} | ${snapshot.scope.name} cautions $cautionCount',
            style: const TextStyle(color: LabColors.navy, fontSize: 12),
          ),
          Text(
            'Subject ${snapshot.selectionKind.name} $subject',
            style: const TextStyle(color: LabColors.navy, fontSize: 12),
          ),
          if (twoCautions)
            const Text(
              'Two cautions recorded',
              style: TextStyle(color: LabColors.navy, fontSize: 12),
            ),
          Text(
            snapshot.sendOffPresence,
            style: const TextStyle(color: LabColors.navy, fontSize: 12),
          ),
          if (sentOff)
            const Text(
              'Sending-off recorded',
              style: TextStyle(color: LabColors.navy, fontSize: 12),
            ),
          Text(
            snapshot.priorCautionLabel,
            style: const TextStyle(color: LabColors.navy, fontSize: 12),
          ),
          Text(
            inFlight == null
                ? 'In flight: none'
                : 'In flight: ${inFlight.kind.name} ${inFlight.subjectId ?? '-'} ${inFlight.scope.name} OUT ${inFlight.outId ?? '-'} IN ${inFlight.inId ?? '-'}',
            style: const TextStyle(color: LabColors.navy, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _FocusBody extends StatelessWidget {
  const _FocusBody({required this.controller});

  final ResearchController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _StageRow(controller: controller)),
        _ContextStrip(controller: controller),
        _SelectionStrip(controller: controller),
        if (controller.sandboxVisible) _SandboxJournal(controller: controller),
      ],
    );
  }
}

class _InspectionBody extends StatelessWidget {
  const _InspectionBody({required this.controller, required this.snapshot});

  final ResearchController controller;
  final ResearchTruthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 280, child: _OperatorRail(controller: controller)),
              Expanded(child: _StageRow(controller: controller)),
              SizedBox(width: 300, child: TruthInspector(snapshot: snapshot)),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: _TraceStrip(instrument: controller.instrument),
        ),
      ],
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.controller});

  final ResearchController controller;

  @override
  Widget build(BuildContext context) {
    final shell = factualProfileById(controller.shellProfileId);
    if (controller.deviceShellVisible && shell != null) {
      final viewport = viewportContextFor(shell);
      final trace = controller.watchRuntime.intentTrace;
      final lastTrace = trace.isEmpty
          ? 'Intent trace: none'
          : '${trace.last.originLabel} ${trace.last.intentName}';
      return Column(
        children: [
          Text(lastTrace, key: const Key('intent-origin-trace')),
          Expanded(
            child: DeviceShellStage(
              key: ValueKey(shell.identity.profileId),
              profile: shell,
              stamp: controller.evidenceStamp,
              onPointerCancel: (pointerId) {
                controller.instrument.pointerCancel(pointerId: pointerId);
                controller.refresh();
              },
              child: WatchReferenceApp(
                state: controller.watchRuntime.watchState,
                degradedLabel: viewport.usesNativeLogicalViewport ? null : viewport.basisLabel,
                inputEpoch: controller.inputEpoch,
                onIntent: (intent) {
                  controller.dispatchWatch(intent);
                },
              ),
            ),
          ),
        ],
      );
    }
    final profiles = controller.presentation == LabPresentation.single
        ? [controller.activeProfile]
        : starterProfiles;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final profile in profiles)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _stage(profile),
            ),
          ),
      ],
    );
  }

  Widget _stage(DeviceProfile profile) {
    final interactive = profile.profileId == controller.activeProfile.profileId;
    final placement = interactive ? controller.activeLayout : placementFor(profile);
    final page = controller.page;
    final continuation = controller.instrument.sendOffContinuationVisible;
    return DeviceStage(
      profile: profile,
      placement: placement,
      interactive: interactive,
      calibration: controller.calibration,
      zoom: controller.zoom,
      host: controller.hostEvidence,
      showYellow: page == ResearchPage.yellow,
      showSendOff: page == ResearchPage.red || continuation,
      showSubstitution: page == ResearchPage.substitution,
      onDeviceDown: (x, y, pointerId, inside) {
        controller.devicePointerDown(
          profileId: profile.profileId,
          pointerId: pointerId,
          deviceX: x,
          deviceY: y,
          inside: inside,
        );
      },
      onDeviceUp: (x, y, pointerId) {
        controller.devicePointerUp(
          profileId: profile.profileId,
          pointerId: pointerId,
          deviceX: x,
          deviceY: y,
        );
      },
      onDeviceCancel: (pointerId) {
        controller.devicePointerCancel(profile.profileId, pointerId);
      },
    );
  }
}

class _ContextStrip extends StatelessWidget {
  const _ContextStrip({required this.controller});

  final ResearchController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final page in ResearchPage.values)
            ActionChip(
              label: Text(page.name),
              onPressed: () => controller.show(page),
            ),
          ActionChip(
            label: const Text('Home'),
            onPressed: () {
              controller.instrument.setTeam(ResearchTeamSide.home);
              controller.refresh();
            },
          ),
          ActionChip(
            label: const Text('Away'),
            onPressed: () {
              controller.instrument.setTeam(ResearchTeamSide.away);
              controller.refresh();
            },
          ),
          ActionChip(
            label: const Text('Match scope'),
            onPressed: () {
              controller.instrument.setScope(ResearchScope.match);
              controller.refresh();
            },
          ),
          ActionChip(
            label: const Text('Shoot-out scope'),
            onPressed: () {
              controller.instrument.setScope(ResearchScope.shootout);
              controller.refresh();
            },
          ),
          for (final profile in starterProfiles)
            ActionChip(
              label: Text(shortProfileLabel(profile)),
              onPressed: () => controller.selectProfile(profile.profileId),
            ),
          ActionChip(
            label: const Text('Geometry stage'),
            onPressed: controller.closeDeviceShell,
          ),
          ActionChip(
            label: const Text('Integration sandbox'),
            onPressed: controller.showSandbox,
          ),
          if (controller.sandboxVisible) ...[
            ActionChip(
              label: const Text('Sandbox yellow'),
              onPressed: controller.commitSandboxYellow,
            ),
            ActionChip(
              label: const Text('Sandbox abort'),
              onPressed: controller.abortSandboxYellow,
            ),
            ActionChip(
              label: const Text('Sandbox reopen'),
              onPressed: controller.reopenSandbox,
            ),
          ],
          if (controller.deviceShellVisible) ...[
            const Text(
              'Command Lab',
              style: TextStyle(color: LabColors.navy, fontWeight: FontWeight.w700),
            ),
            ActionChip(
              label: const Text('Operator fixture: yellow Home 14'),
              onPressed: controller.operatorHome14Yellow,
            ),
          ],
          for (final profile in factualSeedProfiles)
            ActionChip(
              label: Text(_factualChipLabel(profile)),
              onPressed: () => controller.openDeviceShell(profile.identity.profileId),
            ),
          ActionChip(
            label: Text(
              controller.presentation == LabPresentation.single
                  ? 'Compare devices'
                  : 'Single device',
            ),
            onPressed: () => controller.setPresentation(
              controller.presentation == LabPresentation.single
                  ? LabPresentation.comparison
                  : LabPresentation.single,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionStrip extends StatelessWidget {
  const _SelectionStrip({required this.controller});

  final ResearchController controller;

  @override
  Widget build(BuildContext context) {
    final page = controller.page;
    final instrument = controller.instrument;
    if (page != ResearchPage.substitution &&
        page != ResearchPage.players &&
        page != ResearchPage.officials &&
        page != ResearchPage.red) {
      return const SizedBox(height: 4);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Referee selection — not a final action',
            style: TextStyle(color: LabColors.steel, fontSize: 11),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (page == ResearchPage.red)
                  TextButton(
                    onPressed: () {
                      instrument.offerDirectSendOff();
                      controller.refresh();
                    },
                    child: const Text('Direct pathway'),
                  ),
                if (page == ResearchPage.substitution)
                  for (final person in instrument.rankedRoster) ...[
                    TextButton(
                      onPressed: () {
                        instrument.selectOut(person.id);
                        controller.refresh();
                      },
                      child: Text('Out ${person.id}'),
                    ),
                    TextButton(
                      onPressed: () {
                        instrument.selectIn(person.id);
                        controller.refresh();
                      },
                      child: Text('In ${person.id}'),
                    ),
                  ],
                if (page == ResearchPage.officials)
                  for (final official in instrument.officials)
                    TextButton(
                      onPressed: () {
                        instrument.selectOfficial(official.id);
                        controller.refresh();
                      },
                      child: Text('${official.name} — ${official.roleLabel}'),
                    ),
                if (page == ResearchPage.players)
                  for (final person in instrument.rankedRoster)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${person.shirtLabel} ${person.name} ${person.presence.name}',
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OperatorRail extends StatefulWidget {
  const _OperatorRail({required this.controller});

  final ResearchController controller;

  @override
  State<_OperatorRail> createState() => _OperatorRailState();
}

class _OperatorRailState extends State<_OperatorRail> {
  final _import = TextEditingController();

  @override
  void dispose() {
    _import.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final instrument = controller.instrument;
    return ListView(
      key: const Key('research-operator'),
      padding: const EdgeInsets.all(12),
      children: [
        const Text(
          'Scenario',
          style: TextStyle(color: LabColors.navy, fontWeight: FontWeight.w700),
        ),
        for (final id in ScenarioId.values)
          ListTile(
            dense: true,
            title: Text(id.name),
            onTap: () => controller.load(id),
          ),
        TextButton(
          onPressed: controller.resetScenario,
          child: const Text('Reset scenario'),
        ),
        TextButton(
          onPressed: () {
            instrument.interrupt();
            controller.refresh();
          },
          child: const Text('Interrupt'),
        ),
        TextButton(
          onPressed: () {
            instrument.resume();
            controller.refresh();
          },
          child: const Text('Simulated resume'),
        ),
        const Divider(),
        const Text(
          'Calibration request',
          style: TextStyle(color: LabColors.navy, fontWeight: FontWeight.w700),
        ),
        Wrap(
          spacing: 6,
          children: [
            ActionChip(
              label: const Text('FIT'),
              onPressed: () => controller.setCalibration(CalibrationMode.fit),
            ),
            ActionChip(
              label: const Text('Request raster 1:1'),
              onPressed: () => controller.setCalibration(CalibrationMode.raster1to1),
            ),
            ActionChip(
              label: const Text('Request physical 1:1'),
              onPressed: () => controller.setCalibration(CalibrationMode.physical1to1),
            ),
          ],
        ),
        Wrap(
          spacing: 6,
          children: [
            TextButton(
              onPressed: () => controller.setZoom(controller.zoom / 1.25),
              child: const Text('Zoom out'),
            ),
            TextButton(
              onPressed: () => controller.setZoom(controller.zoom * 1.25),
              child: const Text('Zoom in'),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Hold simulated resolution'),
          value: controller.holdResolution,
          onChanged: controller.setHold,
        ),
        TextButton(
          onPressed: controller.resolveHeldCommit,
          child: const Text('Resolve simulated commit'),
        ),
        if (!controller.activeProfile.touchClaimedSupported)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'SIMULATED TOUCH OVERRIDE — not a device capability',
            ),
            value: controller.simulatedTouchOverride,
            onChanged: controller.setTouchOverride,
          ),
        TextButton(
          onPressed: () {
            instrument.acknowledgeUnknownOutcome();
            controller.refresh();
          },
          child: const Text('Acknowledge unknown — does not submit'),
        ),
        const Divider(),
        const Text(
          'Import profile JSON',
          style: TextStyle(color: LabColors.navy, fontWeight: FontWeight.w700),
        ),
        TextField(
          key: const Key('profile-import'),
          controller: _import,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Paste a schema version 1 profile',
            border: OutlineInputBorder(),
          ),
        ),
        TextButton(
          onPressed: () => controller.importProfile(_import.text),
          child: const Text('Apply profile JSON'),
        ),
        if (controller.importMessage != null) Text(controller.importMessage!),
      ],
    );
  }
}

class _TraceStrip extends StatelessWidget {
  const _TraceStrip({required this.instrument});

  final ResearchInstrument instrument;

  @override
  Widget build(BuildContext context) {
    final events = instrument.log.reversed.take(8).toList();
    return DecoratedBox(
      key: const Key('research-trace'),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: LabColors.steel)),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          const Text(
            'Interaction trace',
            style: TextStyle(color: LabColors.navy, fontWeight: FontWeight.w700, fontSize: 12),
          ),
          for (final event in events)
            Text(
              '${event.sequence} ${event.kind.name} ${event.detail}',
              style: const TextStyle(fontSize: 11, color: LabColors.navy),
            ),
        ],
      ),
    );
  }
}

class _SandboxJournal extends StatelessWidget {
  const _SandboxJournal({required this.controller});

  final ResearchController controller;

  @override
  Widget build(BuildContext context) {
    final report = controller.sandboxReport;
    final journal = controller.sandboxSession?.journal.entries ?? const [];
    final seeded = controller.journalLines;
    return SizedBox(
      height: 240,
      child: DecoratedBox(
        key: const Key('event-journal'),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: LabColors.navy)),
          color: Color(0xFFF8FAFC),
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          children: [
            Text(
              controller.journalHeadline ??
                  (report == null
                      ? 'Event Journal · Integration Sandbox · no capture yet'
                      : 'Event Journal · ${report.label} · ${report.measurementLabel}'),
              style: const TextStyle(
                color: LabColors.navy,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            if (controller.evidenceStamp.isNotEmpty)
              Text(
                controller.evidenceStamp,
                style: const TextStyle(color: LabColors.steel, fontSize: 11),
              ),
            if (controller.journalDetail != null)
              Text(
                controller.journalDetail!,
                style: const TextStyle(color: LabColors.navy, fontSize: 12),
              ),
            if (report != null)
              Text(
                'intent ${report.captureIntentId} record ${report.recordId ?? '-'} '
                'bytes ${report.encodedBytes} file ${report.fileBytesBefore}->${report.fileBytesAfter} '
                'records ${report.recordCount}',
                style: const TextStyle(color: LabColors.navy, fontSize: 12),
              ),
            for (final line in seeded)
              Text(line, style: const TextStyle(color: LabColors.navy, fontSize: 11)),
            for (final entry in journal)
              Text(
                '${entry.sequence} ${entry.kind.name} ${entry.detail}',
                style: const TextStyle(color: LabColors.navy, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}

String _factualChipLabel(DeviceProfileV2 profile) {
  final model = profile.identity.model.value ?? profile.identity.profileId;
  final variant = profile.identity.variant.value;
  if (variant == null) return model;
  return '$model $variant';
}
