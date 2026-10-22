import 'package:flutter/material.dart';
import 'package:simulator_geometry/simulator_geometry.dart';

import '../research_app.dart';
import 'device_facts.dart';
import 'device_hero_stage.dart';
import 'lab_theme.dart';

/// Compare: two factual shells, one presentation state, one input owner.
///
/// The read-only mirror mounts the same WatchReferenceApp with pointers
/// ignored. No pointer coordinates are replayed between profiles.
class CompareWorkspace extends StatelessWidget {
  const CompareWorkspace(
      {super.key, required this.controller, required this.regime});

  final ResearchController controller;
  final LabLayoutRegime regime;

  @override
  Widget build(BuildContext context) {
    final primary = controller.shellProfile;
    final secondary = controller.compareProfile;
    if (primary == null || secondary == null) {
      return const Center(child: Text('SELECT A DEVICE', style: LabText.title));
    }
    final narrow = regime == LabLayoutRegime.narrow;
    final margin = narrow ? LabMetrics.gutter : LabMetrics.pageMargin;
    final state = controller.instrument.snapshot;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          margin, LabMetrics.gutter, margin, LabMetrics.tight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkspaceHeader(
            title: 'Compare devices',
            subtitle: LabWorkspace.compare.question,
            trailing:
                narrow ? null : const ContextChip(text: 'SAME SEMANTIC STATE'),
          ),
          const SizedBox(height: LabMetrics.tight),
          Expanded(
            child: narrow
                ? _NarrowCompare(
                    controller: controller,
                    primary: primary,
                    secondary: secondary)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: CompareCard(
                          controller: controller,
                          profile: primary,
                          interactive: controller.compareInputOnPrimary,
                        ),
                      ),
                      const SizedBox(width: LabMetrics.gutter),
                      Expanded(
                        child: CompareCard(
                          controller: controller,
                          profile: secondary,
                          interactive: !controller.compareInputOnPrimary,
                          selector: _SecondarySelector(controller: controller),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: LabMetrics.tight),
          Text(
            'Shared research truth · cautions ${state.cautions.length} · '
            'send-offs ${state.sendOffs.length} · substitutions ${state.substitutions.length} · '
            'one hf_v2 history',
            key: const Key('compare-shared-truth'),
            style: LabText.caption,
            textAlign: TextAlign.center,
          ),
          OutcomeRibbon(controller: controller),
        ],
      ),
    );
  }
}

class _NarrowCompare extends StatelessWidget {
  const _NarrowCompare({
    required this.controller,
    required this.primary,
    required this.secondary,
  });

  final ResearchController controller;
  final DeviceProfileV2 primary;
  final DeviceProfileV2 secondary;

  @override
  Widget build(BuildContext context) {
    final showPrimary = controller.compareInputOnPrimary;
    final shown = showPrimary ? primary : secondary;
    final other = showPrimary ? secondary : primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Narrow window: one target at a time. The other device stays a read-only mirror.',
          style: LabText.caption,
        ),
        const SizedBox(height: 6),
        Expanded(
          child: CompareCard(
              controller: controller, profile: shown, interactive: true),
        ),
        const SizedBox(height: 6),
        OutlinedButton(
          key: const Key('compare-switch-narrow'),
          onPressed: () =>
              controller.setCompareInputOwner(other.identity.profileId),
          child: Text('Show ${deviceShortName(other)} (READ ONLY until shown)'),
        ),
      ],
    );
  }
}

class CompareCard extends StatelessWidget {
  const CompareCard({
    super.key,
    required this.controller,
    required this.profile,
    required this.interactive,
    this.selector,
  });

  final ResearchController controller;
  final DeviceProfileV2 profile;
  final bool interactive;
  final Widget? selector;

  @override
  Widget build(BuildContext context) {
    final id = profile.identity.profileId;
    return Container(
      key: Key('compare-card-$id'),
      padding: const EdgeInsets.all(LabMetrics.gutter),
      decoration: BoxDecoration(
        color: LabColors.surface,
        border: Border.all(
            color: interactive ? LabColors.navy : LabColors.line,
            width: interactive ? 2 : 1),
        borderRadius: BorderRadius.circular(LabMetrics.surfaceRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _OwnerBadge(interactive: interactive, profileId: id),
              const Spacer(),
              if (!interactive)
                SizedBox(
                  height: 30,
                  child: OutlinedButton(
                    key: Key('compare-make-active-$id'),
                    onPressed: () => controller.setCompareInputOwner(id),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      side: const BorderSide(color: LabColors.line),
                    ),
                    child: const Text('Make active input',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(deviceDisplayName(profile),
              style: LabText.bodyStrong, textAlign: TextAlign.center),
          Text(
            '${deviceRasterLine(profile)} · ${deviceShapeLine(profile)}',
            style: LabText.caption,
            textAlign: TextAlign.center,
          ),
          Text(
            '${deviceEvidenceStageLabel(profile)} · ${shellFidelityLabel(profile)}',
            style: const TextStyle(
                color: LabColors.inkMuted, fontSize: 10, letterSpacing: 0.6),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: DeviceHeroStage(
              controller: controller,
              profile: profile,
              interactive: interactive,
              showCaption: false,
              overline: interactive
                  ? 'ACTIVE REFERENCE UI'
                  : 'MIRRORED STATE · READ ONLY',
            ),
          ),
          if (selector != null) ...[
            const SizedBox(height: 6),
            selector!,
          ],
        ],
      ),
    );
  }
}

class _OwnerBadge extends StatelessWidget {
  const _OwnerBadge({required this.interactive, required this.profileId});

  final bool interactive;
  final String profileId;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('compare-owner-$profileId'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: interactive ? LabColors.navy : LabColors.canvas,
        border:
            Border.all(color: interactive ? LabColors.navy : LabColors.line),
        borderRadius: BorderRadius.circular(LabMetrics.chipRadius),
      ),
      child: Text(
        interactive ? 'ACTIVE INPUT' : 'READ ONLY',
        style: TextStyle(
          color: interactive ? LabColors.softWhite : LabColors.navy,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SecondarySelector extends StatelessWidget {
  const _SecondarySelector({required this.controller});

  final ResearchController controller;

  @override
  Widget build(BuildContext context) {
    final options = [
      for (final profile in factualSeedProfiles)
        if (profile.identity.profileId != controller.shellProfileId) profile,
    ];
    return Row(
      children: [
        const Text('Second device', style: LabText.caption),
        const SizedBox(width: LabMetrics.tight),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const Key('compare-secondary'),
              value: controller.compareProfileId,
              isExpanded: true,
              isDense: true,
              style: LabText.body,
              items: [
                for (final profile in options)
                  DropdownMenuItem(
                    value: profile.identity.profileId,
                    child: Text(deviceDisplayName(profile),
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (next) {
                if (next != null) controller.selectCompareProfile(next);
              },
            ),
          ),
        ),
      ],
    );
  }
}
