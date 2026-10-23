import 'package:flutter/material.dart';
import 'package:hf_v2/hf_v2.dart';
import 'package:simulator_geometry/simulator_geometry.dart';
import 'package:simulator_presentation/simulator_presentation.dart';

import '../research_app.dart';
import 'device_facts.dart';
import 'device_hero_stage.dart';
import 'device_selector.dart';
import 'lab_theme.dart';
import 'mobile_session_surface.dart';
import 'paired_link_panel.dart';

/// Desktop Simulation composition from the John master reference.
///
/// Scenario, phone, simulated pair, watch, and device controls sit together.
/// Command instrumentation and the event journal stay below the product.
class JohnSimulationBoard extends StatelessWidget {
  const JohnSimulationBoard({
    super.key,
    required this.controller,
    required this.regime,
    required this.profile,
  });

  final ResearchController controller;
  final LabLayoutRegime regime;
  final DeviceProfileV2 profile;

  @override
  Widget build(BuildContext context) {
    final wide = regime == LabLayoutRegime.wide || regime == LabLayoutRegime.desktop;
    return Padding(
      key: const Key('paired-focus'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: wide ? _wide() : _stacked(),
    );
  }

  Widget _wide() {
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 214, child: _ScenarioPanel(controller: controller)),
              const SizedBox(width: 10),
              Expanded(flex: 5, child: _MobileCard(controller: controller)),
              const SizedBox(width: 8),
              SizedBox(width: 156, child: PairedLinkPanel(controller: controller)),
              const SizedBox(width: 8),
              Expanded(flex: 5, child: _WatchCard(controller: controller, profile: profile, regime: regime)),
              const SizedBox(width: 10),
              SizedBox(width: 228, child: _DeviceControls(controller: controller, profile: profile)),
            ],
          ),
        ),
        OutcomeRibbon(controller: controller),
        const SizedBox(height: 8),
        SizedBox(height: 128, child: _EngineeringBand(controller: controller)),
      ],
    );
  }

  Widget _stacked() {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: 280, child: _ScenarioPanel(controller: controller)),
          const SizedBox(height: 8),
          SizedBox(height: 560, child: _MobileCard(controller: controller)),
          const SizedBox(height: 8),
          SizedBox(height: 220, child: PairedLinkPanel(controller: controller)),
          const SizedBox(height: 8),
          SizedBox(
            height: 520,
            child: _WatchCard(controller: controller, profile: profile, regime: regime),
          ),
          const SizedBox(height: 8),
          SizedBox(height: 360, child: _DeviceControls(controller: controller, profile: profile)),
          OutcomeRibbon(controller: controller),
          const SizedBox(height: 8),
          SizedBox(height: 160, child: _EngineeringBand(controller: controller)),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LabColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: LabColors.line),
      ),
      child: child,
    );
  }
}

class _ScenarioPanel extends StatelessWidget {
  const _ScenarioPanel({required this.controller});

  final ResearchController controller;

  @override
  Widget build(BuildContext context) {
    final instrument = controller.instrument;
    final clock = controller.watchRuntime.watchState.clock;
    final score = controller.watchRuntime.watchState.score;
    return _Panel(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        children: [
          const Text('SCENARIO CONTROLS', style: LabText.label),
          const SizedBox(height: 12),
          const Text('Active fixture', style: LabText.caption),
          DropdownButtonHideUnderline(
            child: DropdownButton<ScenarioId>(
              key: const Key('simulation-scenario'),
              value: instrument.scenarioId,
              isExpanded: true,
              style: DefaultTextStyle.of(context).style.merge(LabText.bodyStrong),
              items: [
                for (final id in ScenarioId.values)
                  DropdownMenuItem(value: id, child: Text(id.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (next) {
                if (next != null) controller.operatorLoadScenario(next);
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Research fixture. Not a production match.',
            style: LabText.caption,
          ),
          const SizedBox(height: 12),
          const Text('Match state', style: LabText.caption),
          Text(
            clock.phaseLabel,
            key: const Key('top-match'),
            style: LabText.bodyStrong,
          ),
          Text(controller.matchTitle, style: LabText.caption),
          const SizedBox(height: 12),
          const Text('Score', style: LabText.caption),
          if (!score.available)
            Text(score.label, style: LabText.bodyStrong)
          else
            Row(
              children: [
                _ScoreBox(label: 'Home', value: '${score.homeGoals ?? 0}'),
                const SizedBox(width: 8),
                _ScoreBox(label: 'Away', value: '${score.awayGoals ?? 0}'),
              ],
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('simulation-apply-scenario'),
            onPressed: () => controller.operatorLoadScenario(instrument.scenarioId),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Apply scenario'),
            style: FilledButton.styleFrom(
              backgroundColor: LabColors.navy,
              foregroundColor: LabColors.softWhite,
              minimumSize: const Size.fromHeight(40),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => controller.operatorLoadScenario(instrument.scenarioId),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reset session'),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            key: const Key('scenario-match-builder'),
            onPressed: () => controller.setWorkspace(LabWorkspace.matchBuilder),
            icon: const Icon(Icons.account_tree_outlined, size: 16),
            label: const Text('Match Builder'),
          ),
        ],
      ),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  const _ScoreBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: LabColors.softWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: LabColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: LabText.caption),
              Text(value, style: LabText.bodyStrong),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileCard extends StatelessWidget {
  const _MobileCard({required this.controller});

  final ResearchController controller;

  @override
  Widget build(BuildContext context) {
    final disconnected =
        controller.paired.connection == SimulatedConnectionState.simulatedDisconnect;
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.smartphone, size: 18, color: LabColors.navy),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mobile Session', style: LabText.panelTitle),
                      Text('Android / iOS reference (simulated)', style: LabText.caption),
                    ],
                  ),
                ),
                if (controller.showDeviceStatus)
                  _ConnectedChip(connected: !disconnected),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: MobileSessionSurface(controller: controller, compact: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchCard extends StatelessWidget {
  const _WatchCard({
    required this.controller,
    required this.profile,
    required this.regime,
  });

  final ResearchController controller;
  final DeviceProfileV2 profile;
  final LabLayoutRegime regime;

  @override
  Widget build(BuildContext context) {
    final disconnected =
        controller.paired.connection == SimulatedConnectionState.simulatedDisconnect;
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  const Icon(Icons.watch, size: 18, color: LabColors.navy),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Watch Session', style: LabText.panelTitle),
                        Text('FORREF Watch App (simulated)', style: LabText.caption),
                      ],
                    ),
                  ),
                  if (controller.showDeviceStatus)
                    _ConnectedChip(connected: !disconnected),
                ],
              ),
            ),
            Expanded(
              child: DeviceHeroStage(
                key: const Key('focus-stage'),
                controller: controller,
                profile: profile,
                zoom: controller.stageZoom,
                showCaption: false,
              ),
            ),
            StageFooter(controller: controller, profile: profile, regime: regime),
          ],
        ),
      ),
    );
  }
}

class _ConnectedChip extends StatelessWidget {
  const _ConnectedChip({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F8EF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: connected ? const Color(0xFF1B8A4A) : LabColors.unknownFact),
          const SizedBox(width: 4),
          Text(
            connected ? 'Connected' : 'Simulated disconnect',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1B8A4A)),
          ),
        ],
      ),
    );
  }
}

class _DeviceControls extends StatelessWidget {
  const _DeviceControls({required this.controller, required this.profile});

  final ResearchController controller;
  final DeviceProfileV2 profile;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        children: [
          const Text('DEVICE & VIEW CONTROLS', style: LabText.label),
          const SizedBox(height: 12),
          const Text('Mobile device', style: LabText.caption),
          const Text('Reference phone', style: LabText.bodyStrong),
          const SizedBox(height: 10),
          const Text('Watch device', style: LabText.caption),
          DeviceSummaryButton(controller: controller, compact: true),
          const SizedBox(height: 4),
          Text(deviceDisplayName(profile), style: LabText.caption),
          const SizedBox(height: 12),
          const Text('View options', style: LabText.caption),
          CheckboxListTile(
            key: const Key('toggle-device-frame'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: controller.showHardwareFrame,
            title: const Text('Show device frame', style: LabText.body),
            onChanged: (value) => controller.setShowHardwareFrame(value ?? false),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: controller.showDeviceStatus,
            title: const Text('Show device status', style: LabText.body),
            onChanged: (value) => controller.setShowDeviceStatus(value ?? false),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: controller.phoneDark,
            title: const Text('Dark mode (device)', style: LabText.body),
            onChanged: (value) => controller.setPhoneDark(value ?? false),
          ),
          const SizedBox(height: 8),
          const Text('SIMULATION TOOLS', style: LabText.label),
          const SizedBox(height: 6),
          _tool(Icons.watch, 'Round watch', () => controller.openDeviceShell('huawei-watch-gt4-46')),
          _tool(Icons.watch_outlined, 'Rectangular watch', () => controller.openDeviceShell('amazfit-gts4')),
          _tool(Icons.straighten, 'Geometry stage', controller.openGeometryStage),
          const SizedBox(height: 10),
          const Text('DEVICE ACTIONS', style: LabText.label),
          const SizedBox(height: 6),
          _tool(Icons.compare_arrows, 'Compare devices', () => controller.setWorkspace(LabWorkspace.compare)),
        ],
      ),
    );
  }

  Widget _tool(IconData icon, String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Align(alignment: Alignment.centerLeft, child: Text(label)),
      ),
    );
  }
}

class _EngineeringBand extends StatelessWidget {
  const _EngineeringBand({required this.controller});

  final ResearchController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 3, child: _CommandStrip(controller: controller)),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: _JournalStrip(controller: controller)),
      ],
    );
  }
}

class _CommandStrip extends StatelessWidget {
  const _CommandStrip({required this.controller});

  final ResearchController controller;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('COMMAND LAB', style: LabText.label),
            const SizedBox(height: 6),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _chip('Home side', () => controller.operatorSetTeam(PresentationTeam.home)),
                  _chip('Away side', () => controller.operatorSetTeam(PresentationTeam.away)),
                  _chip('Match scope', () => controller.operatorSetScope(PresentationScope.match)),
                  _chip('Shoot-out scope', () => controller.operatorSetScope(PresentationScope.shootout)),
                  _chip('Return to live', controller.operatorReturnToLive),
                  _chip('Interrupt', controller.interrupt),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, VoidCallback onPressed) {
    return ActionChip(label: Text(label), onPressed: onPressed);
  }
}

class _JournalStrip extends StatelessWidget {
  const _JournalStrip({required this.controller});

  final ResearchController controller;

  @override
  Widget build(BuildContext context) {
    final events = controller.instrument.log.reversed.take(6).toList();
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'EVENT JOURNAL · RESEARCH LOG',
              style: LabText.label,
            ),
            const SizedBox(height: 4),
            const Text(
              'Not the Match Report.',
              style: LabText.caption,
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final event in events)
                    Text(
                      '${event.sequence}  ${event.kind.name}  ${event.detail}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LabText.caption,
                    ),
                  if (events.isEmpty)
                    const Text('No research log entries yet.', style: LabText.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
