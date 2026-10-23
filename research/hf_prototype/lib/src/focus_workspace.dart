import 'package:flutter/material.dart';

import '../research_app.dart';
import 'geometry_diagnostic.dart';
import 'john_simulation.dart';

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
    return JohnSimulationBoard(
      controller: controller,
      regime: regime,
      profile: profile,
    );
  }
}
