import 'package:flutter/material.dart';
import 'package:simulator_geometry/simulator_geometry.dart';
import 'package:simulator_presentation/simulator_presentation.dart';
import 'package:watch_reference_ui/watch_reference_ui.dart';

import '../research_app.dart';
import 'device_facts.dart';
import 'device_shell_stage.dart';
import 'john_frames.dart';
import 'lab_theme.dart';

/// The hero: a factual schematic shell with the live WatchReferenceApp
/// mounted inside its aperture.
///
/// One presentation runtime feeds every instance. [interactive] false makes
/// the shell a read-only mirror: the aperture ignores pointers and the intent
/// callback is never reached.
class DeviceHeroStage extends StatelessWidget {
  const DeviceHeroStage({
    super.key,
    required this.controller,
    required this.profile,
    this.interactive = true,
    this.zoom = 1,
    this.showCaption = true,
    this.overline,
  });

  final ResearchController controller;
  final DeviceProfileV2 profile;
  final bool interactive;
  final double zoom;
  final bool showCaption;
  final String? overline;

  @override
  Widget build(BuildContext context) {
    final id = profile.identity.profileId;
    return Column(
      children: [
        if (overline != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(overline!,
                style: LabText.label, textAlign: TextAlign.center),
          ),
        Expanded(
          child: Center(
            child: FractionallySizedBox(
              widthFactor: zoom.clamp(0.3, 1.0),
              heightFactor: zoom.clamp(0.3, 1.0),
              child: _watchBody(id, interactive),
            ),
          ),
        ),
        if (showCaption)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              deviceDisplayName(profile),
              key: Key('stage-name-$id'),
              style: LabText.caption,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _watchBody(String id, bool interactive) {
    final app = WatchReferenceApp(
      key: Key('watch-$id-${interactive ? 'active' : 'mirror'}'),
      state: controller.watchRuntime.watchState,
      inputEpoch: controller.inputEpoch,
      onIntent: interactive ? controller.dispatchWatch : _ignoreIntent,
    );
    final frame =
        controller.showHardwareFrame ? johnFrameForProfile(profile) : null;
    if (frame == null) {
      return DeviceShellStage(
        key: ValueKey('hero-$id-${interactive ? 'active' : 'mirror'}'),
        profile: profile,
        interactive: interactive,
        onPointerCancel: (pointerId) {
          controller.instrument.pointerCancel(pointerId: pointerId);
          controller.refresh();
        },
        child: app,
      );
    }
    return PhotographicWatchFrame(
      key: ValueKey('photo-$id-${interactive ? 'active' : 'mirror'}'),
      frame: frame,
      child: app,
    );
  }

  static void _ignoreIntent(WatchIntent intent) {}
}

/// Compact fidelity + zoom strip under a stage. Evidence detail lives in the
/// Device Evidence inspector, one deliberate action away.
class StageFooter extends StatelessWidget {
  const StageFooter({
    super.key,
    required this.controller,
    required this.profile,
    required this.regime,
  });

  final ResearchController controller;
  final DeviceProfileV2 profile;
  final LabLayoutRegime regime;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 2000;
        return _footerBody(narrow);
      },
    );
  }

  Widget _footerBody(bool narrow) {
    final zoomLabel = controller.stageZoom >= 0.999
        ? 'FIT'
        : '${(controller.stageZoom * 100).round()}%';
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SmallButton(
          key: const Key('stage-zoom-out'),
          label: '−',
          onPressed: () => controller.setStageZoom(controller.stageZoom - 0.1),
        ),
        const SizedBox(width: 4),
        _SmallButton(
          key: const Key('stage-zoom-fit'),
          label: zoomLabel,
          onPressed: () => controller.setStageZoom(1),
        ),
        const SizedBox(width: 4),
        _SmallButton(
          key: const Key('stage-zoom-in'),
          label: '+',
          onPressed: () => controller.setStageZoom(controller.stageZoom + 0.1),
        ),
        const SizedBox(width: LabMetrics.tight),
        _SmallButton(
          key: const Key('view-device-evidence'),
          label: narrow ? 'Evidence' : 'View device evidence',
          onPressed: () =>
              controller.openInspector(InspectorSection.deviceEvidence),
        ),
      ],
    );
    final fidelity = Text(
      deviceStageFooterLine(profile),
      key: const Key('stage-fidelity'),
      style: const TextStyle(
          color: LabColors.inkMuted, fontSize: 10, letterSpacing: 0.6),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: LabColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: LabMetrics.tight),
        child: narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  fidelity,
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: controls,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(child: fidelity),
                  const SizedBox(width: LabMetrics.gutter),
                  controls,
                ],
              ),
      ),
    );
  }
}

/// Latest research outcome in literal vocabulary. Never a generic checkmark.
class OutcomeRibbon extends StatelessWidget {
  const OutcomeRibbon({
    super.key,
    required this.controller,
    this.alwaysVisible = false,
  });

  final ResearchController controller;
  final bool alwaysVisible;

  @override
  Widget build(BuildContext context) {
    final state = controller.watchRuntime.watchState;
    final label = state.commit.label;
    final trace = controller.watchRuntime.intentTrace;
    final idle =
        label == ResearchCommitPhrases.idle && state.frozenCommand == null;
    if (idle && !alwaysVisible) return const SizedBox.shrink();
    final origin = trace.isEmpty
        ? 'No input yet'
        : '${trace.last.originLabel} · ${trace.last.intentName}';
    final frozen = state.frozenCommand;
    final critical = label == ResearchCommitPhrases.notSaved ||
        label == ResearchCommitPhrases.saveNotVerified;
    return Container(
      margin: const EdgeInsets.only(top: LabMetrics.tight),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: LabColors.surface,
        border:
            Border.all(color: critical ? LabColors.attention : LabColors.line),
        borderRadius: BorderRadius.circular(LabMetrics.controlRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('RESEARCH RESULT', style: LabText.label),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  key: const Key('outcome-label'),
                  style: LabText.bodyStrong,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (frozen != null)
            Text(
              'In flight: ${frozen.action.name} ${frozen.subjectId ?? '-'} ${frozen.scope.name}'
              '${frozen.outId != null || frozen.inId != null ? ' OUT ${frozen.outId ?? '-'} IN ${frozen.inId ?? '-'}' : ''}',
              key: const Key('outcome-frozen'),
              style: LabText.caption,
            ),
          Text(
            origin,
            key: const Key('intent-origin-trace'),
            style: LabText.caption,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class WorkspaceHeader extends StatelessWidget {
  const WorkspaceHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: LabText.title),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: LabText.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: LabMetrics.gutter),
          trailing!,
        ],
      ],
    );
  }
}

class ContextChip extends StatelessWidget {
  const ContextChip({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: LabColors.surface,
        border: Border.all(color: LabColors.line),
        borderRadius: BorderRadius.circular(LabMetrics.chipRadius),
      ),
      child: Text(text, style: LabText.caption),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: LabColors.navy,
          side: const BorderSide(color: LabColors.line),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(32, 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LabMetrics.chipRadius),
          ),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
