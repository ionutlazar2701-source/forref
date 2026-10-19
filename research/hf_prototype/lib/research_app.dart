import 'package:flutter/material.dart';
import 'package:hf_v2/hf_v2.dart';

/// Operator-facing research shell. It is not registered in the phone app.
class ResearchController extends ChangeNotifier {
  ResearchController({ResearchInstrument? instrument})
      : instrument = instrument ?? ResearchInstrument() {
    this.instrument.loadScenario(ScenarioId.s01YellowNoPrior);
  }

  final ResearchInstrument instrument;
  ResearchPage page = ResearchPage.live;
  bool operatorOpen = false;

  void load(ScenarioId id) {
    instrument.loadScenario(id);
    page = ResearchPage.live;
    notifyListeners();
  }

  void show(ResearchPage next) {
    page = next;
    operatorOpen = false;
    instrument.enterSurface(next.name);
    if (next == ResearchPage.yellow) instrument.offerRecordYellow();
    if (next == ResearchPage.red && !instrument.sendOffContinuationVisible) {
      instrument.offerDirectSendOff();
    }
    notifyListeners();
  }

  void openOperator() {
    operatorOpen = true;
    notifyListeners();
  }

  void closeOperator() {
    operatorOpen = false;
    notifyListeners();
  }

  void pointerDown(double x, double y, int pointerId) {
    instrument.pointerDown(pointerId: pointerId, x: x, y: y);
    notifyListeners();
  }

  void pointerUp(double x, double y, int pointerId) {
    instrument.pointerUp(pointerId: pointerId, x: x, y: y);
    if (instrument.commitKind == SystemCommitKind.saving) {
      instrument.resolveSimulatedCommit();
    }
    notifyListeners();
  }

  void pointerCancel(int pointerId) {
    instrument.pointerCancel(pointerId: pointerId);
    notifyListeners();
  }

  void focusLost() {
    instrument.focusLost();
    notifyListeners();
  }

  void refresh() {
    notifyListeners();
  }
}

enum ResearchPage { live, yellow, red, substitution, players, officials, commitment }

class ResearchApp extends StatelessWidget {
  const ResearchApp({super.key, required this.controller});

  final ResearchController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FORREF RESEARCH PROTOTYPE',
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
    return Focus(
      autofocus: true,
      onFocusChange: (focused) {
        if (!focused) controller.focusLost();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ColoredBox(
                color: Color(0xFF4A148C),
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'FORREF RESEARCH PROTOTYPE',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Wrap(
                  spacing: 6,
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
                      label: const Text('Operator'),
                      onPressed: controller.openOperator,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: controller.operatorOpen
                    ? OperatorPanel(controller: controller)
                    : CaptureColumn(controller: controller),
              ),
              if (instrument.simulatedRecoveryDisclaimer)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(RecoveryClaim.finishLaterLabel),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CaptureColumn extends StatelessWidget {
  const CaptureColumn({super.key, required this.controller});

  final ResearchController controller;

  @override
  Widget build(BuildContext context) {
    final instrument = controller.instrument;
    return KeyedSubtree(
      key: const Key('research-capture'),
        child: _PointerLayer(
        onDown: controller.pointerDown,
        onUp: controller.pointerUp,
        onCancel: controller.pointerCancel,
        child: Stack(
          key: const Key('research-hit-stack'),
          children: [
            Positioned(
              left: 16,
              top: 8,
              right: 16,
              child: Text(instrument.priorCautionLabel),
            ),
            Positioned(
              left: 16,
              top: 36,
              right: 16,
              child: Text(instrument.pitchTruth),
            ),
            Positioned(
              left: 16,
              top: 72,
              right: 16,
              child: Text(
                'Subject ${instrument.selectionKind.name} ${instrument.selectedParticipantId ?? '-'}',
              ),
            ),
            Positioned(
              left: 16,
              top: 96,
              right: 16,
              child: Text(instrument.commitLabel),
            ),
            if (instrument.twoCautionsRecorded)
              const Positioned(
                left: 16,
                top: 120,
                child: Text('Two cautions recorded'),
              ),
            if (instrument.sendingOffRecorded)
              const Positioned(
                left: 16,
                top: 144,
                child: Text('Sending-off recorded'),
              ),
            if (controller.page == ResearchPage.players ||
                controller.page == ResearchPage.substitution)
              Positioned(
                left: ResearchLayout.phone.roster.left,
                top: ResearchLayout.phone.roster.top,
                width: ResearchLayout.phone.roster.width,
                height: ResearchLayout.phone.roster.height,
                child: ListView(
                  children: [
                    for (final person in instrument.rankedRoster)
                      Text('${person.shirtLabel} ${person.name} ${person.id}'),
                  ],
                ),
              ),
            if (controller.page == ResearchPage.officials)
              Positioned(
                left: 16,
                top: 160,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final official in instrument.officials)
                      Text('${official.name} — ${official.roleLabel}'),
                  ],
                ),
              ),
            if (controller.page == ResearchPage.yellow)
              _target(
                ResearchLayout.phone.yellow,
                'Record yellow',
              ),
            if (controller.page == ResearchPage.red ||
                instrument.sendOffContinuationVisible)
              _target(
                ResearchLayout.phone.sendOff,
                'Record sending-off',
              ),
            if (controller.page == ResearchPage.substitution)
              _target(
                ResearchLayout.phone.substitution,
                'Record substitution',
              ),
            if (controller.page == ResearchPage.red)
              Positioned(
                left: 16,
                top: 160,
                child: TextButton(
                  onPressed: () {
                    controller.instrument.offerDirectSendOff();
                    controller.refresh();
                  },
                  child: const Text('Direct pathway'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PointerLayer extends StatelessWidget {
  const _PointerLayer({
    required this.onDown,
    required this.onUp,
    required this.onCancel,
    required this.child,
  });

  final void Function(double x, double y, int pointerId) onDown;
  final void Function(double x, double y, int pointerId) onUp;
  final void Function(int pointerId) onCancel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) => _local(context, event, onDown),
      onPointerUp: (event) => _local(context, event, onUp),
      onPointerCancel: (event) => onCancel(event.pointer),
      child: child,
    );
  }

  static void _local(
    BuildContext context,
    PointerEvent event,
    void Function(double x, double y, int pointerId) apply,
  ) {
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final local = box.globalToLocal(event.position);
    apply(local.dx, local.dy, event.pointer);
  }
}

class OperatorPanel extends StatelessWidget {
  const OperatorPanel({super.key, required this.controller});

  final ResearchController controller;

  @override
  Widget build(BuildContext context) {
    final instrument = controller.instrument;
    return KeyedSubtree(
      key: const Key('research-operator'),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text('Scenario'),
          for (final id in ScenarioId.values)
            ListTile(
              title: Text(id.name),
              onTap: () => controller.load(id),
            ),
          TextButton(
            onPressed: () {
              instrument.interrupt();
              controller.refresh();
            },
            child: const Text('Interrupt'),
          ),
          TextButton(
            onPressed: controller.closeOperator,
            child: const Text('Back to capture'),
          ),
          const Text('Research log'),
          for (final event in instrument.log)
            Text('${event.kind.name} ${event.detail}'),
        ],
      ),
    );
  }
}

Widget _target(ResearchRect rect, String label) {
  return Positioned(
    left: rect.left,
    top: rect.top,
    width: rect.width,
    height: rect.height,
    child: ColoredBox(
      color: const Color(0xFFE0E0E0),
      child: Center(child: Text(label, textAlign: TextAlign.center)),
    ),
  );
}
