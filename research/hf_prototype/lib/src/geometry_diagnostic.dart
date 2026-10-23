import 'package:flutter/material.dart';
import 'package:hf_v2/hf_v2.dart';
import 'package:simulator_geometry/simulator_geometry.dart';

import '../research_app.dart';
import 'device_hero_stage.dart';
import 'device_stage.dart';
import 'lab_bridge.dart';
import 'lab_theme.dart';

/// Night I geometry diagnostic. Illustrative profiles, painted sporting
/// targets, calibration probes. Reached from Command Lab → Advanced.
///
/// This is research instrumentation, not the V2 device shell. The Night I
/// safety tests still run against it.
class GeometryDiagnosticStage extends StatelessWidget {
  const GeometryDiagnosticStage({
    super.key,
    required this.controller,
    required this.regime,
  });

  final ResearchController controller;
  final LabLayoutRegime regime;

  @override
  Widget build(BuildContext context) {
    final margin = regime == LabLayoutRegime.narrow
        ? LabMetrics.gutter
        : LabMetrics.pageMargin;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          margin, LabMetrics.tight, margin, LabMetrics.tight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'GEOMETRY DIAGNOSTIC · ADVANCED · illustrative stage, painted targets, not the device shell',
                  style: LabText.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                height: 30,
                child: OutlinedButton(
                  key: const Key('geometry-return'),
                  onPressed: controller.closeGeometryStage,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Return to device shell',
                      style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          Expanded(child: _GeometryStage(controller: controller)),
          OutcomeRibbon(controller: controller),
          _SelectionStrip(controller: controller),
          _LegacyContextStrip(controller: controller),
        ],
      ),
    );
  }
}

class _GeometryStage extends StatelessWidget {
  const _GeometryStage({required this.controller});

  final ResearchController controller;

  @override
  Widget build(BuildContext context) {
    final profile = controller.activeProfile;
    final page = controller.page;
    final continuation = controller.instrument.sendOffContinuationVisible;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: DeviceStage(
        profile: profile,
        placement: controller.activeLayout,
        interactive: true,
        calibration: controller.calibration,
        zoom: controller.zoom,
        host: controller.hostEvidence,
        showYellow: page == ResearchPage.yellow,
        showSendOff: page == ResearchPage.red || continuation,
        showSubstitution: page == ResearchPage.substitution,
        onDeviceDown: (x, y, pointerId, inside) {
          controller.devicePointerDown(
            profileId: profile.profileId,
            pointerId: pointerId,
            deviceX: x,
            deviceY: y,
            inside: inside,
          );
        },
        onDeviceUp: (x, y, pointerId) {
          controller.devicePointerUp(
            profileId: profile.profileId,
            pointerId: pointerId,
            deviceX: x,
            deviceY: y,
          );
        },
        onDeviceCancel: (pointerId) {
          controller.devicePointerCancel(profile.profileId, pointerId);
        },
      ),
    );
  }
}

class _LegacyContextStrip extends StatelessWidget {
  const _LegacyContextStrip({required this.controller});

  final ResearchController controller;

  @override
  Widget build(BuildContext context) {
    final instrument = controller.instrument;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        key: const Key('geometry-context'),
        spacing: 4,
        runSpacing: 2,
        children: [
          for (final page in ResearchPage.values)
            _DiagnosticChip(
                label: page.name, onPressed: () => controller.show(page)),
          _DiagnosticChip(
            label: 'Home',
            onPressed: () {
              instrument.setTeam(ResearchTeamSide.home);
              controller.refresh();
            },
          ),
          _DiagnosticChip(
            label: 'Away',
            onPressed: () {
              instrument.setTeam(ResearchTeamSide.away);
              controller.refresh();
            },
          ),
          _DiagnosticChip(
            label: 'Match scope',
            onPressed: () {
              instrument.setScope(ResearchScope.match);
              controller.refresh();
            },
          ),
          _DiagnosticChip(
            label: 'Shoot-out scope',
            onPressed: () {
              instrument.setScope(ResearchScope.shootout);
              controller.refresh();
            },
          ),
          for (final profile in starterProfiles)
            _DiagnosticChip(
              label: shortProfileLabel(profile),
              onPressed: () => controller.selectProfile(profile.profileId),
            ),
        ],
      ),
    );
  }
}

/// Dense chip for the diagnostic strip. It keeps the stage tall on small
/// windows; it is not a watch control.
class _DiagnosticChip extends StatelessWidget {
  const _DiagnosticChip({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
    );
  }
}

class _SelectionStrip extends StatelessWidget {
  const _SelectionStrip({required this.controller});

  final ResearchController controller;

  @override
  Widget build(BuildContext context) {
    final page = controller.page;
    final instrument = controller.instrument;
    if (page != ResearchPage.substitution &&
        page != ResearchPage.players &&
        page != ResearchPage.officials &&
        page != ResearchPage.red) {
      return const SizedBox(height: 4);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Referee selection — not a final action',
          style: TextStyle(color: LabColors.steel, fontSize: 11),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (page == ResearchPage.red)
                TextButton(
                  onPressed: () {
                    instrument.offerDirectSendOff();
                    controller.refresh();
                  },
                  child: const Text('Direct pathway'),
                ),
              if (page == ResearchPage.substitution)
                for (final person in instrument.rankedRoster) ...[
                  TextButton(
                    onPressed: () {
                      instrument.selectOut(person.id);
                      controller.refresh();
                    },
                    child: Text('Out ${person.id}'),
                  ),
                  TextButton(
                    onPressed: () {
                      instrument.selectIn(person.id);
                      controller.refresh();
                    },
                    child: Text('In ${person.id}'),
                  ),
                ],
              if (page == ResearchPage.officials)
                for (final official in instrument.officials)
                  TextButton(
                    onPressed: () {
                      instrument.selectOfficial(official.id);
                      controller.refresh();
                    },
                    child: Text('${official.name} — ${official.roleLabel}'),
                  ),
              if (page == ResearchPage.players)
                for (final person in instrument.rankedRoster)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '${person.shirtLabel} ${person.name} ${person.presence.name}',
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}
