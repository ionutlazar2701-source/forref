import 'package:flutter/material.dart';
import 'package:simulator_geometry/simulator_geometry.dart';

import '../research_app.dart';
import 'device_facts.dart';
import 'device_hero_stage.dart';
import 'geometry_diagnostic.dart';
import 'mobile_session_surface.dart';
import 'paired_link_panel.dart';

/// Focus: paired Mobile Session + Watch Session with a conceptual link.
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
    final stacked = regime == LabLayoutRegime.narrow;
    return Padding(
      key: const Key('paired-focus'),
      padding: EdgeInsets.fromLTRB(
          margin, LabMetrics.gutter, margin, LabMetrics.tight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkspaceHeader(
            title: 'Paired Session Focus',
            subtitle: LabWorkspace.focus.question,
            trailing: regime == LabLayoutRegime.narrow
                ? null
                : ContextChip(text: deviceDisplayName(profile)),
          ),
          const SizedBox(height: LabMetrics.tight),
          Expanded(
            child: stacked ? _stacked(profile) : _row(profile),
          ),
          OutcomeRibbon(controller: controller),
          const SizedBox(height: LabMetrics.tight),
          StageFooter(controller: controller, profile: profile, regime: regime),
        ],
      ),
    );
  }

  Widget _row(DeviceProfileV2 profile) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: MobileSessionSurface(
            controller: controller,
            compact: regime == LabLayoutRegime.compact,
          ),
        ),
        const SizedBox(width: LabMetrics.tight),
        SizedBox(
          width: regime == LabLayoutRegime.wide ? 200 : 160,
          child: PairedLinkPanel(controller: controller),
        ),
        const SizedBox(width: LabMetrics.tight),
        Expanded(
          flex: 4,
          child: DeviceHeroStage(
            key: const Key('focus-stage'),
            controller: controller,
            profile: profile,
            zoom: controller.stageZoom,
            overline: 'WATCH SESSION · REFERENCE UI',
          ),
        ),
      ],
    );
  }

  Widget _stacked(DeviceProfileV2 profile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final watchHeight = (constraints.maxHeight - 260).clamp(280.0, 520.0);
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 160,
                child:
                    MobileSessionSurface(controller: controller, compact: true),
              ),
              const SizedBox(height: LabMetrics.tight),
              SizedBox(
                  height: 64,
                  child: PairedLinkPanel(controller: controller)),
              const SizedBox(height: LabMetrics.tight),
              SizedBox(
                height: watchHeight,
                child: DeviceHeroStage(
                  key: const Key('focus-stage'),
                  controller: controller,
                  profile: profile,
                  zoom: controller.stageZoom,
                  overline: 'WATCH SESSION · REFERENCE UI',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
