import 'package:flutter/material.dart';

import '../research_app.dart';
import 'device_facts.dart';
import 'device_hero_stage.dart';
import 'geometry_diagnostic.dart';

/// Focus: one large device, the live reference app inside it, nothing else
/// competing for attention.
class FocusWorkspace extends StatelessWidget {
  const FocusWorkspace(
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
            title: 'Device Focus',
            subtitle: LabWorkspace.focus.question,
            trailing: regime == LabLayoutRegime.narrow
                ? null
                : ContextChip(text: deviceDisplayName(profile)),
          ),
          const SizedBox(height: LabMetrics.tight),
          Expanded(
            child: DeviceHeroStage(
              key: const Key('focus-stage'),
              controller: controller,
              profile: profile,
              zoom: controller.stageZoom,
              overline: 'ACTIVE REFERENCE UI',
            ),
          ),
          OutcomeRibbon(controller: controller),
          const SizedBox(height: LabMetrics.tight),
          StageFooter(controller: controller, profile: profile, regime: regime),
        ],
      ),
    );
  }
}
