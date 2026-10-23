import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../research_app.dart';
import 'command_lab.dart';
import 'compare_workspace.dart';
import 'device_selector.dart';
import 'focus_workspace.dart';
import 'lab_inspector.dart';
import 'lab_top_bar.dart';
import 'match_builder_placeholder.dart';

/// John V1 lab frame: top bar, workspace bar, workspace body, inspector, footer.
///
/// Composition only. Sporting truth lives in the controller's instrument.
class LabScaffold extends StatelessWidget {
  const LabScaffold({super.key, required this.controller});

  final ResearchController controller;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onFocusChange: (focused) {
        if (!focused) controller.focusLost();
      },
      child: RepaintBoundary(
        key: const Key('lab-boundary'),
        child: Scaffold(
          backgroundColor: LabColors.canvas,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final regime = labRegimeFor(constraints.maxWidth);
              return _RegimeGuard(
                regime: regime,
                onRegimeChanged: controller.layoutRegimeChanged,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LabTopBar(controller: controller, regime: regime),
                    WorkspaceBar(controller: controller, regime: regime),
                    Expanded(
                      child: _LabBody(
                        controller: controller,
                        regime: regime,
                        width: constraints.maxWidth,
                      ),
                    ),
                    LabFooter(controller: controller, regime: regime),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Bumps the input epoch when the window crosses a regime boundary.
///
/// A press that started under the previous composition cannot commit.
class _RegimeGuard extends StatefulWidget {
  const _RegimeGuard({
    required this.regime,
    required this.onRegimeChanged,
    required this.child,
  });

  final LabLayoutRegime regime;
  final VoidCallback onRegimeChanged;
  final Widget child;

  @override
  State<_RegimeGuard> createState() => _RegimeGuardState();
}

class _RegimeGuardState extends State<_RegimeGuard> {
  late LabLayoutRegime _last = widget.regime;

  @override
  void didUpdateWidget(_RegimeGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.regime != _last) {
      _last = widget.regime;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onRegimeChanged();
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _LabBody extends StatelessWidget {
  const _LabBody({
    required this.controller,
    required this.regime,
    required this.width,
  });

  final ResearchController controller;
  final LabLayoutRegime regime;
  final double width;

  @override
  Widget build(BuildContext context) {
    final inlineInspector =
        regime == LabLayoutRegime.wide && controller.inspectorOpen;
    final inlineRail = controller.workspace == LabWorkspace.commandLab &&
        (regime == LabLayoutRegime.wide || regime == LabLayoutRegime.desktop);
    final railWidth = regime == LabLayoutRegime.wide
        ? LabMetrics.railWidth
        : LabMetrics.railMinWidth;

    final center = _workspace(context);

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (inlineRail)
          SizedBox(
            width: railWidth,
            child: CommandRail(controller: controller, regime: regime),
          ),
        Expanded(child: center),
        if (inlineInspector)
          SizedBox(
            width: LabMetrics.inspectorWidth,
            child: LabInspector(controller: controller, regime: regime),
          ),
      ],
    );

    final overlayInspector = !inlineInspector && controller.inspectorOpen;
    final overlayRail = controller.workspace == LabWorkspace.commandLab &&
        !inlineRail &&
        controller.commandRailOpen;
    final overlaySelector = controller.deviceSelectorOpen;

    if (!overlayInspector && !overlayRail && !overlaySelector) return row;

    final overlayWidth = width < LabMetrics.compactBreakpoint
        ? (width - 48).clamp(240.0, LabMetrics.inspectorWidth)
        : LabMetrics.inspectorWidth;
    return Stack(
      children: [
        Positioned.fill(child: row),
        if (overlayRail || overlayInspector || overlaySelector)
          Positioned.fill(
            child: GestureDetector(
              key: const Key('lab-scrim'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                controller.setCommandRailOpen(false);
                controller.setDeviceSelectorOpen(false);
                if (overlayInspector) controller.closeInspector();
              },
              child: const ColoredBox(color: Color(0x33071F38)),
            ),
          ),
        if (overlayRail)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: (width - 48).clamp(240.0, LabMetrics.railWidth),
            child: Material(
              elevation: 6,
              color: LabColors.surface,
              child: CommandRail(controller: controller, regime: regime),
            ),
          ),
        if (overlayInspector)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: overlayWidth,
            child: Material(
              elevation: 6,
              color: LabColors.surface,
              child: LabInspector(controller: controller, regime: regime),
            ),
          ),
        if (overlaySelector)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.topCenter,
              child:
                  DeviceSelectorPanel(controller: controller, maxWidth: width),
            ),
          ),
      ],
    );
  }

  Widget _workspace(BuildContext context) {
    return switch (controller.workspace) {
      LabWorkspace.focus =>
        FocusWorkspace(controller: controller, regime: regime),
      LabWorkspace.commandLab =>
        CommandLabWorkspace(controller: controller, regime: regime),
      LabWorkspace.compare =>
        CompareWorkspace(controller: controller, regime: regime),
      LabWorkspace.matchBuilder =>
        MatchBuilderPlaceholder(controller: controller, regime: regime),
    };
  }
}
