import 'package:flutter/material.dart';
import 'package:simulator_geometry/simulator_geometry.dart';
import 'package:simulator_presentation/simulator_presentation.dart';
import 'package:watch_reference_ui/watch_reference_ui.dart';

import '../research_app.dart';
import 'device_facts.dart';
import 'device_shell_stage.dart';
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
              child: DeviceShellStage(
                key: ValueKey('hero-$id-${interactive ? 'active' : 'mirror'}'),
                profile: profile,
                interactive: interactive,
                onPointerCancel: (pointerId) {
                  controller.instrument.pointerCancel(pointerId: pointerId);
                  controller.refresh();
                },
                child: RepaintBoundary(
                  key: Key('watch-viewport-$id'),
                  child: WatchReferenceApp(
                  key: Key('watch-$id-${interactive ? 'active' : 'mirror'}'),
                  state: controller.watchRuntime.watchState,
                  inputEpoch: controller.inputEpoch,
                  face: watchFaceFor(profile),
                  liveLayout: controller.watchLiveLayout,
                  frame: controller.watchDesignFrame,
                  language: controller.watchLanguage,
                  showBeyondNominal: controller.watchBeyondNominal,
                  onPresentationBack: interactive ? _presentationBack : null,
                  onIntent: interactive ? _dispatchWatch : _ignoreIntent,
                ),
                ),
              ),
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

  void _dispatchWatch(WatchIntent intent) {
    if (intent is SetTeamIntent &&
        controller.watchDesignFrame == WatchDesignFrame.team) {
      controller.setWatchDesignFrame(WatchDesignFrame.participant);
    }
    if (intent is OpenRouteIntent &&
        intent.route == WatchRoute.captureMenu &&
        controller.watchDesignFrame == WatchDesignFrame.team) {
      controller.setWatchDesignFrame(WatchDesignFrame.flow);
    }
    controller.dispatchWatch(intent);
  }

  void _presentationBack() {
    if (controller.watchDesignFrame == WatchDesignFrame.participant) {
      controller.setWatchDesignFrame(WatchDesignFrame.team);
    }
  }

  static void _ignoreIntent(WatchIntent intent) {}
}

/// Rectangular Jony layouts cover rectangle and rounded-rectangle displays.
/// Unknown shape does not invent a round mask.
WatchFaceShape watchFaceFor(DeviceProfileV2 profile) {
  final shape = profile.display.shape;
  if (!shape.hasValue || shape.value != ScreenShape.round) {
    return WatchFaceShape.rectangular;
  }
  return WatchFaceShape.round;
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
    final narrow =
        regime == LabLayoutRegime.narrow || regime == LabLayoutRegime.compact;
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            narrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      fidelity,
                      const SizedBox(height: 6),
                      Align(alignment: Alignment.centerRight, child: controls),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: fidelity),
                      const SizedBox(width: LabMetrics.gutter),
                      controls,
                    ],
                  ),
            const SizedBox(height: 6),
            _DesignControls(controller: controller),
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

class _DesignControls extends StatelessWidget {
  const _DesignControls({required this.controller});

  final ResearchController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        _SmallButton(
          key: const Key('stage-layout-centered'),
          label: 'Layout A',
          onPressed: () =>
              controller.setWatchLiveLayout(WatchLiveLayout.centered),
        ),
        _SmallButton(
          key: const Key('stage-layout-score-side'),
          label: 'Layout C',
          onPressed: () =>
              controller.setWatchLiveLayout(WatchLiveLayout.scoreSide),
        ),
        _SmallButton(
          key: const Key('stage-frame-flow'),
          label: 'Flow',
          onPressed: () =>
              controller.setWatchDesignFrame(WatchDesignFrame.flow),
        ),
        _SmallButton(
          key: const Key('stage-frame-team'),
          label: 'Team',
          onPressed: () =>
              controller.setWatchDesignFrame(WatchDesignFrame.team),
        ),
        _SmallButton(
          key: const Key('stage-frame-participant'),
          label: 'Players',
          onPressed: () =>
              controller.setWatchDesignFrame(WatchDesignFrame.participant),
        ),
        _SmallButton(
          key: const Key('stage-beyond'),
          label: controller.watchBeyondNominal ? 'Beyond on' : 'Beyond off',
          onPressed: () =>
              controller.setWatchBeyondNominal(!controller.watchBeyondNominal),
        ),
        _SmallButton(
          key: const Key('stage-language'),
          label: controller.watchLanguage == WatchLanguage.en ? 'EN' : 'RO',
          onPressed: () => controller.setWatchLanguage(
            controller.watchLanguage == WatchLanguage.en
                ? WatchLanguage.ro
                : WatchLanguage.en,
          ),
        ),
      ],
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
