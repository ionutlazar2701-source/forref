import 'package:flutter/material.dart';

import '../research_app.dart';
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
    return ColoredBox(
      color: LabColors.navy,
      child: SizedBox(
        height: LabMetrics.topBarHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: LabMetrics.gutter),
          child: Row(
            children: [
              const _Brand(),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (regime == LabLayoutRegime.wide ||
                            regime == LabLayoutRegime.desktop) ...[
                          for (final workspace in [
                            LabWorkspace.focus,
                            LabWorkspace.commandLab,
                            LabWorkspace.compare,
                          ])
                            _WorkspaceTab(
                              workspace: workspace,
                              selected: controller.workspace == workspace,
                              onTap: () => controller.setWorkspace(workspace),
                            ),
                          _MatchBuilderLink(
                            selected: controller.workspace == LabWorkspace.matchBuilder,
                            onTap: () => controller.setWorkspace(LabWorkspace.matchBuilder),
                          ),
                        ],
                        const SizedBox(width: 8),
                        _RuntimeControl(controller: controller, compact: compact),
                        const SizedBox(width: 8),
                        _InspectorControl(controller: controller, compact: true),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 3, height: 16, child: ColoredBox(color: LabColors.turquoise)),
        SizedBox(width: 8),
        Text(
          labTitle,
          style: TextStyle(
            color: LabColors.softWhite,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        SizedBox(width: 12),
        Text(
          labIdentity,
          key: Key('top-identity'),
          style: TextStyle(color: Color(0xFF8FB4C8), fontSize: 11, letterSpacing: 0.4),
        ),
      ],
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
    return InkWell(
      key: const Key('inspector-toggle'),
      onTap: controller.toggleInspector,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: open ? LabColors.turquoise : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          'Inspection',
          style: TextStyle(
            color: open ? LabColors.softWhite : const Color(0xFFB7C6D4),
            fontSize: compact ? 12 : 14,
            fontWeight: open ? FontWeight.w700 : FontWeight.w500,
          ),
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
    final menu = regime == LabLayoutRegime.narrow || regime == LabLayoutRegime.compact;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: LabColors.canvas,
        border: Border(bottom: BorderSide(color: LabColors.line)),
      ),
      child: SizedBox(
        height: menu ? LabMetrics.workspaceBarHeight : 0,
        child: menu
            ? _NarrowWorkspaceSelector(controller: controller)
            : const SizedBox.shrink(),
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
        padding: const EdgeInsets.symmetric(horizontal: 10),
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
            color: selected ? LabColors.softWhite : const Color(0xFFB7C6D4),
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Secondary route. Present on the bar so Match Builder stays reachable
/// after leaving Simulation. It is not a primary navigation peer.
class _MatchBuilderLink extends StatelessWidget {
  const _MatchBuilderLink({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('workspace-matchBuilder'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          'Match Builder',
          style: TextStyle(
            color: selected ? LabColors.turquoise : const Color(0xFF8AA0B3),
            fontSize: 12,
            fontWeight: FontWeight.w600,
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
    final note = labFooterNote;
    assert(regime.index >= 0);
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
