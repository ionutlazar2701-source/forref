import 'package:flutter/material.dart';

import '../research_app.dart';
import 'device_selector.dart';
import 'lab_assets.dart';
import 'lab_theme.dart';

/// Calm persistent app bar. Context only: match, device, runtime, inspector.
///
/// No SHA, no profile id, no scenario dump.
class LabTopBar extends StatelessWidget {
  const LabTopBar({super.key, required this.controller, required this.regime});

  final ResearchController controller;
  final LabLayoutRegime regime;

  @override
  Widget build(BuildContext context) {
    final narrow = regime == LabLayoutRegime.narrow;
    final compact = regime == LabLayoutRegime.compact || narrow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ColoredBox(
          color: LabColors.turquoise,
          child: SizedBox(height: 3),
        ),
        ColoredBox(
          color: LabColors.navy,
          child: SizedBox(
            height: LabMetrics.topBarHeight,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: LabMetrics.gutter),
              child: Row(
                children: [
                  const _Brand(),
                  const SizedBox(width: LabMetrics.gutter),
                  Expanded(
                    child: Row(
                      children: [
                        if (!compact) ...[
                          Flexible(
                            child: _ContextPill(
                              key: Key('top-match'),
                              label: 'MATCH',
                              value: controller.matchTitle,
                            ),
                          ),
                          const SizedBox(width: LabMetrics.tight),
                        ],
                        Flexible(
                          child: DeviceSummaryButton(
                              controller: controller, compact: compact),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: LabMetrics.tight),
                  _RuntimeControl(controller: controller, compact: compact),
                  const SizedBox(width: LabMetrics.tight),
                  _InspectorControl(controller: controller, compact: compact),
                  if (regime == LabLayoutRegime.wide) ...[
                    const SizedBox(width: LabMetrics.gutter),
                    const Text(labIdentity,
                        key: Key('top-identity'), style: LabText.onNavy),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          LabAssets.logo,
          key: const Key('sim-lab-logo'),
          height: 28,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        const SizedBox(width: 8),
        const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(labBrand, style: LabText.onNavyStrong),
            Text(
              labBrandSub,
              style: TextStyle(
                color: LabColors.softWhite,
                fontSize: 10,
                letterSpacing: 1.6,
                height: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ContextPill extends StatelessWidget {
  const _ContextPill({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: LabMetrics.controlHeight - 6,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: LabColors.steel),
        borderRadius: BorderRadius.circular(LabMetrics.controlRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label · ',
            style: const TextStyle(
                color: LabColors.softWhite, fontSize: 11, letterSpacing: 0.6),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: LabColors.softWhite,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuntimeControl extends StatelessWidget {
  const _RuntimeControl({required this.controller, required this.compact});

  final ResearchController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final runtime = controller.runtime;
    return PopupMenuButton<LabRuntime>(
      key: const Key('runtime-control'),
      tooltip: 'Runtime',
      onSelected: (next) {
        if (next == LabRuntime.research) {
          controller.leaveSandbox();
        } else {
          controller.showSandbox();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          key: Key('runtime-research'),
          value: LabRuntime.research,
          child: Text('Research — hf_v2 simulated truth'),
        ),
        const PopupMenuItem(
          key: Key('runtime-sandbox'),
          value: LabRuntime.integrationSandbox,
          child: Text('Integration Sandbox — file-backed SQLite'),
        ),
      ],
      child: Container(
        height: LabMetrics.controlHeight - 6,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: LabColors.steel),
          borderRadius: BorderRadius.circular(LabMetrics.controlRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact)
              const Text(
                'RUNTIME · ',
                style: TextStyle(
                    color: LabColors.softWhite,
                    fontSize: 11,
                    letterSpacing: 0.6),
              ),
            Text(
              runtime.label,
              key: const Key('top-runtime'),
              style: const TextStyle(
                color: LabColors.softWhite,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 16, color: LabColors.softWhite),
          ],
        ),
      ),
    );
  }
}

class _InspectorControl extends StatelessWidget {
  const _InspectorControl({required this.controller, required this.compact});

  final ResearchController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final open = controller.inspectorOpen;
    return SizedBox(
      height: LabMetrics.controlHeight - 6,
      child: FilledButton.tonal(
        key: const Key('inspector-toggle'),
        onPressed: controller.toggleInspector,
        style: FilledButton.styleFrom(
          backgroundColor: open ? LabColors.softWhite : LabColors.navyDeep,
          foregroundColor: open ? LabColors.navy : LabColors.softWhite,
          side: const BorderSide(color: LabColors.steel),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LabMetrics.controlRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Text(
          open
              ? (compact ? 'Close' : 'Close inspector')
              : (compact ? 'Inspect' : 'Inspect evidence'),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Second slim row: primary workspaces.
class WorkspaceBar extends StatelessWidget {
  const WorkspaceBar(
      {super.key, required this.controller, required this.regime});

  final ResearchController controller;
  final LabLayoutRegime regime;

  @override
  Widget build(BuildContext context) {
    final narrow = regime == LabLayoutRegime.narrow;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: LabColors.surface,
        border: Border(bottom: BorderSide(color: LabColors.line)),
      ),
      child: SizedBox(
        height: LabMetrics.workspaceBarHeight,
        child: narrow
            ? _NarrowWorkspaceSelector(controller: controller)
            : Row(
                children: [
                  const SizedBox(width: LabMetrics.gutter),
                  for (final workspace in LabWorkspace.values)
                    _WorkspaceTab(
                      workspace: workspace,
                      selected: controller.workspace == workspace,
                      onTap: () => controller.setWorkspace(workspace),
                    ),
                  const Spacer(),
                  if (controller.workspace == LabWorkspace.commandLab &&
                      (regime == LabLayoutRegime.compact))
                    Padding(
                      padding: const EdgeInsets.only(right: LabMetrics.gutter),
                      child: TextButton.icon(
                        key: const Key('commands-drawer-button'),
                        onPressed: () => controller.setCommandRailOpen(true),
                        icon: const Icon(Icons.tune, size: 16),
                        label: const Text('Commands'),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _WorkspaceTab extends StatelessWidget {
  const _WorkspaceTab({
    required this.workspace,
    required this.selected,
    required this.onTap,
  });

  final LabWorkspace workspace;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('workspace-${workspace.name}'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? LabColors.turquoise : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          workspace.label,
          style: TextStyle(
            color: selected ? LabColors.navy : LabColors.inkMuted,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _NarrowWorkspaceSelector extends StatelessWidget {
  const _NarrowWorkspaceSelector({required this.controller});

  final ResearchController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: LabMetrics.gutter),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<LabWorkspace>(
                key: const Key('workspace-dropdown'),
                value: controller.workspace,
                isExpanded: true,
                style: DefaultTextStyle.of(context).style.merge(LabText.bodyStrong),
                items: [
                  for (final workspace in LabWorkspace.values)
                    DropdownMenuItem(
                      value: workspace,
                      child: Text(workspace.label),
                    ),
                ],
                onChanged: (next) {
                  if (next != null) controller.setWorkspace(next);
                },
              ),
            ),
          ),
          if (controller.workspace == LabWorkspace.commandLab)
            TextButton.icon(
              key: const Key('commands-drawer-button'),
              onPressed: () => controller.setCommandRailOpen(true),
              icon: const Icon(Icons.tune, size: 16),
              label: const Text('Commands'),
            ),
        ],
      ),
    );
  }
}

/// Footer. Research identity and runtime honesty. The evidence stamp appears
/// only when a visual test sets it.
class LabFooter extends StatelessWidget {
  const LabFooter({super.key, required this.controller, required this.regime});

  final ResearchController controller;
  final LabLayoutRegime regime;

  @override
  Widget build(BuildContext context) {
    final stamp = controller.evidenceStamp;
    // The top bar carries the identity only when wide. Below that it lives
    // here, so it is on screen exactly once in every regime.
    final note = regime == LabLayoutRegime.wide ? labFooterNote : labIdentity;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: LabColors.surface,
        border: Border(top: BorderSide(color: LabColors.line)),
      ),
      child: SizedBox(
        height: stamp.isEmpty
            ? LabMetrics.footerHeight
            : LabMetrics.footerHeight + 14,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: LabMetrics.gutter),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      controller.runtime.footer,
                      key: const Key('footer-runtime'),
                      style: const TextStyle(
                        color: LabColors.inkMuted,
                        fontSize: 10,
                        letterSpacing: 0.8,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    note,
                    key: const Key('footer-identity'),
                    style: const TextStyle(
                      color: LabColors.inkMuted,
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              if (stamp.isNotEmpty)
                Text(
                  stamp,
                  key: const Key('evidence-stamp'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: LabColors.inkMuted, fontSize: 9),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
