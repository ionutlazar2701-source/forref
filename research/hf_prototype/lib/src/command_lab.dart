import 'package:flutter/material.dart';
import 'package:hf_v2/hf_v2.dart';
import 'package:simulator_geometry/simulator_geometry.dart';
import 'package:simulator_presentation/simulator_presentation.dart';

import '../research_app.dart';
import 'device_facts.dart';
import 'device_hero_stage.dart';
import 'geometry_diagnostic.dart';
import 'lab_theme.dart';

/// Command Lab: contextual rail beside the dominant device.
class CommandLabWorkspace extends StatelessWidget {
  const CommandLabWorkspace(
      {super.key, required this.controller, required this.regime});

  final ResearchController controller;
  final LabLayoutRegime regime;

  @override
  Widget build(BuildContext context) {
    final profile = controller.shellProfile;
    if (controller.geometryStageVisible || profile == null) {
      return GeometryDiagnosticStage(controller: controller, regime: regime);
    }
    final margin = regime == LabLayoutRegime.narrow
        ? LabMetrics.gutter
        : LabMetrics.pageMargin;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          margin, LabMetrics.gutter, margin, LabMetrics.tight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkspaceHeader(
            title: 'Command Lab',
            subtitle: LabWorkspace.commandLab.question,
            trailing: regime == LabLayoutRegime.narrow
                ? null
                : ContextChip(text: deviceDisplayName(profile)),
          ),
          const SizedBox(height: LabMetrics.tight),
          Expanded(
            child: DeviceHeroStage(
              key: const Key('command-stage'),
              controller: controller,
              profile: profile,
              zoom: controller.stageZoom,
              overline: 'ACTIVE REFERENCE UI · $watchUiOriginLabel',
            ),
          ),
          OutcomeRibbon(controller: controller, alwaysVisible: true),
          const SizedBox(height: LabMetrics.tight),
          StageFooter(controller: controller, profile: profile, regime: regime),
        ],
      ),
    );
  }
}

/// Left contextual rail. Every control is an operator action over existing
/// controller APIs. Nothing here writes a record directly.
class CommandRail extends StatefulWidget {
  const CommandRail(
      {super.key, required this.controller, required this.regime});

  final ResearchController controller;
  final LabLayoutRegime regime;

  @override
  State<CommandRail> createState() => _CommandRailState();
}

class _CommandRailState extends State<CommandRail> {
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
    final sandbox = controller.runtime == LabRuntime.integrationSandbox;
    return Material(
      color: LabColors.surface,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: LabColors.line)),
        ),
        child: ListView(
          key: const Key('research-operator'),
          padding: const EdgeInsets.fromLTRB(
              LabMetrics.gutter, LabMetrics.gutter, LabMetrics.gutter, 32),
          children: [
            const Text('OPERATOR TOOLS', style: LabText.label),
            const SizedBox(height: 4),
            const Text('Command Lab', style: LabText.title),
            const SizedBox(height: 4),
            const Text(
              'Fixture actions are injected by an operator. Watch gestures remain inside the device.',
              style: LabText.caption,
            ),
            if (widget.regime == LabLayoutRegime.compact ||
                widget.regime == LabLayoutRegime.narrow)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('commands-drawer-close'),
                  onPressed: () => controller.setCommandRailOpen(false),
                  child: const Text('Close commands'),
                ),
              ),
            const _GroupHeader(
                title: 'SCENARIO', origin: operatorFixtureOriginLabel),
            DropdownButtonHideUnderline(
              child: DropdownButton<ScenarioId>(
                key: const Key('scenario-dropdown'),
                value: instrument.scenarioId,
                isExpanded: true,
                style: LabText.body,
                items: [
                  for (final id in ScenarioId.values)
                    DropdownMenuItem(value: id, child: Text(id.name)),
                ],
                onChanged: (next) {
                  if (next != null) controller.operatorLoadScenario(next);
                },
              ),
            ),
            _RailButton(
              label: 'Reset scenario',
              onPressed: () =>
                  controller.operatorLoadScenario(instrument.scenarioId),
            ),
            const _GroupHeader(
                title: 'INTERACTION', origin: operatorFixtureOriginLabel),
            _RailButton(
              label: 'Team: Home',
              onPressed: () =>
                  controller.operatorSetTeam(PresentationTeam.home),
            ),
            _RailButton(
              label: 'Team: Away',
              onPressed: () =>
                  controller.operatorSetTeam(PresentationTeam.away),
            ),
            _RailButton(
              label: 'Scope: match',
              onPressed: () =>
                  controller.operatorSetScope(PresentationScope.match),
            ),
            _RailButton(
              label: 'Scope: shoot-out',
              onPressed: () =>
                  controller.operatorSetScope(PresentationScope.shootout),
            ),
            _RailButton(
              label: 'Operator fixture: yellow Home 14',
              onPressed: controller.operatorHome14Yellow,
            ),
            _RailButton(
              label: 'Return watch to Live',
              onPressed: controller.operatorReturnToLive,
            ),
            const _GroupHeader(
                title: 'FAILURE / COMMIT', origin: operatorFixtureOriginLabel),
            _RailButton(label: 'Interrupt', onPressed: controller.interrupt),
            _RailButton(
                label: 'Simulated resume', onPressed: controller.resume),
            SwitchListTile(
              key: const Key('hold-resolution'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title:
                  const Text('Hold simulated resolution', style: LabText.body),
              value: controller.holdResolution,
              onChanged: controller.setHold,
            ),
            _RailButton(
              label: 'Resolve simulated commit',
              onPressed: controller.operatorResolveSimulatedCommit,
            ),
            _RailButton(
              label: 'Acknowledge unknown — does not submit',
              onPressed: controller.operatorAcknowledgeUnknown,
            ),
            const _GroupHeader(
                title: 'RUNTIME · SANDBOX', origin: sandboxOriginLabel),
            const Text(
              'Explicit sandbox operations. They are not caused by watch taps.',
              style: LabText.caption,
            ),
            if (!sandbox)
              _RailButton(
                key: const Key('open-sandbox'),
                label: 'Open integration sandbox',
                onPressed: controller.showSandbox,
              )
            else ...[
              _RailButton(
                key: const Key('sandbox-yellow'),
                label: 'Sandbox yellow',
                onPressed: controller.commitSandboxYellow,
              ),
              _RailButton(
                key: const Key('sandbox-abort'),
                label: 'Sandbox abort',
                onPressed: controller.abortSandboxYellow,
              ),
              _RailButton(
                key: const Key('sandbox-reopen'),
                label: 'Sandbox reopen',
                onPressed: controller.reopenSandbox,
              ),
              _RailButton(
                key: const Key('sandbox-clear-journal'),
                label: 'Clear journal (observer only)',
                onPressed: controller.clearSandboxJournal,
              ),
              _RailButton(
                key: const Key('leave-sandbox'),
                label: 'Back to Research runtime',
                onPressed: controller.leaveSandbox,
              ),
            ],
            ExpansionTile(
              key: const Key('advanced-group'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const _GroupHeader(
                  title: 'ADVANCED', origin: 'GEOMETRY DIAGNOSTIC'),
              children: [
                _RailButton(
                  key: const Key('open-geometry-stage'),
                  label: 'Geometry diagnostic stage',
                  onPressed: controller.openGeometryStage,
                ),
                const SizedBox(height: 4),
                const Text('Calibration request', style: LabText.caption),
                Wrap(
                  spacing: 6,
                  children: [
                    ActionChip(
                      label: const Text('FIT'),
                      onPressed: () =>
                          controller.setCalibration(CalibrationMode.fit),
                    ),
                    ActionChip(
                      label: const Text('Request raster 1:1'),
                      onPressed: () =>
                          controller.setCalibration(CalibrationMode.raster1to1),
                    ),
                    ActionChip(
                      label: const Text('Request physical 1:1'),
                      onPressed: () => controller
                          .setCalibration(CalibrationMode.physical1to1),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    TextButton(
                      onPressed: () =>
                          controller.setZoom(controller.zoom / 1.25),
                      child: const Text('Zoom out'),
                    ),
                    TextButton(
                      onPressed: () =>
                          controller.setZoom(controller.zoom * 1.25),
                      child: const Text('Zoom in'),
                    ),
                  ],
                ),
                if (!controller.activeProfile.touchClaimedSupported)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      'SIMULATED TOUCH OVERRIDE — not a device capability',
                      style: LabText.caption,
                    ),
                    value: controller.simulatedTouchOverride,
                    onChanged: controller.setTouchOverride,
                  ),
                const SizedBox(height: 4),
                const Text('Import profile JSON', style: LabText.caption),
                TextField(
                  key: const Key('profile-import'),
                  controller: _import,
                  maxLines: 4,
                  style: LabText.caption,
                  decoration: const InputDecoration(
                    hintText: 'Paste a schema version 1 profile',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                _RailButton(
                  label: 'Apply profile JSON',
                  onPressed: () => controller.importProfile(_import.text),
                ),
                if (controller.importMessage != null)
                  Text(controller.importMessage!, style: LabText.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, required this.origin});

  final String title;
  final String origin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: LabMetrics.gutter, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: LabText.label),
          Text(
            origin,
            style: const TextStyle(
              color: LabColors.inkMuted,
              fontSize: 10,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Operator control. Outlined and left-aligned so it never resembles the
/// filled navy buttons inside the watch.
class _RailButton extends StatelessWidget {
  const _RailButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SizedBox(
        height: 36,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: LabColors.navy,
            alignment: Alignment.centerLeft,
            side: const BorderSide(color: LabColors.line),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LabMetrics.chipRadius),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
