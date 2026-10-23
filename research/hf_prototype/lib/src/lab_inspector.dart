import 'package:flutter/material.dart';

import '../research_app.dart';
import 'device_evidence_view.dart';
import 'event_journal_view.dart';
import 'lab_theme.dart';
import 'truth_inspector.dart';

/// Contextual inspector. Closed by default. Reads only.
///
/// Truth comes from the hf_v2 snapshot, Event Journal from observed
/// sandbox entries, Device Evidence from DeviceProfileV2 facts.
class LabInspector extends StatelessWidget {
  const LabInspector(
      {super.key, required this.controller, required this.regime});

  final ResearchController controller;
  final LabLayoutRegime regime;

  @override
  Widget build(BuildContext context) {
    final section = controller.inspector ?? InspectorSection.truth;
    return Material(
      key: const Key('lab-inspector'),
      color: LabColors.surface,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: LabColors.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  LabMetrics.gutter, 12, LabMetrics.tight, 0),
              child: Row(
                children: [
                  const Expanded(
                      child: Text('INSPECTOR', style: LabText.label)),
                  IconButton(
                    key: const Key('inspector-close'),
                    tooltip: 'Close inspector',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close,
                        size: 18, color: LabColors.navy),
                    onPressed: controller.closeInspector,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: LabMetrics.tight),
              child: Row(
                children: [
                  for (final item in InspectorSection.values)
                    Expanded(
                      child: _SectionTab(
                        section: item,
                        selected: item == section,
                        onTap: () => controller.openInspector(item),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: LabColors.line),
            Expanded(child: _body(section)),
          ],
        ),
      ),
    );
  }

  Widget _body(InspectorSection section) {
    switch (section) {
      case InspectorSection.truth:
        final trace = controller.watchRuntime.intentTrace;
        return TruthInspector(
          snapshot: controller.instrument.snapshot,
          visibleRoute:
              controller.watchRuntime.watchState.navigation.route.name,
          visibleCommitLabel: controller.watchRuntime.watchState.commit.label,
          lastOrigin: trace.isEmpty
              ? null
              : '${trace.last.originLabel} · ${trace.last.intentName}',
        );
      case InspectorSection.eventJournal:
        return EventJournalView(controller: controller);
      case InspectorSection.deviceEvidence:
        return DeviceEvidenceView(
          profile:
              controller.deviceShellVisible ? controller.shellProfile : null,
        );
    }
  }
}

class _SectionTab extends StatelessWidget {
  const _SectionTab({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final InspectorSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('inspector-tab-${section.name}'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? LabColors.turquoise : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          section.label,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: selected
              ? LabText.bodyStrong
              : LabText.body.copyWith(color: LabColors.inkMuted),
        ),
      ),
    );
  }
}
