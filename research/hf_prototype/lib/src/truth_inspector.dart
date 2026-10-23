import 'package:flutter/material.dart';
import 'package:hf_v2/hf_v2.dart';

import 'lab_theme.dart';

/// Reads an immutable snapshot. It does not append research records.
///
/// Layers: ESTABLISHED, IN-FLIGHT, VISIBLE, SAFETY. Research runtime only.
class TruthInspector extends StatelessWidget {
  const TruthInspector({
    super.key,
    required this.snapshot,
    this.visibleRoute,
    this.visibleCommitLabel,
    this.lastOrigin,
  });

  final ResearchTruthSnapshot snapshot;
  final String? visibleRoute;
  final String? visibleCommitLabel;
  final String? lastOrigin;

  @override
  Widget build(BuildContext context) {
    final inFlight = snapshot.inFlight;
    final subject = snapshot.selectedSubjectId ?? '-';
    final cautionCount = snapshot.cautions
        .where(
            (item) => item.subjectId == subject && item.scope == snapshot.scope)
        .length;
    final twoCautions = snapshot.cautions
            .where(
              (item) =>
                  item.subjectId == subject &&
                  item.kind == snapshot.selectedSubjectKind &&
                  item.scope == snapshot.scope,
            )
            .length >=
        2;
    final sentOff = snapshot.sendOffs.any(
      (item) => item.subjectId == subject && item.scope == snapshot.scope,
    );
    return SingleChildScrollView(
      key: const Key('truth-inspector'),
      padding: const EdgeInsets.all(LabMetrics.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('WHAT FORREF KNOWS · RESEARCH RUNTIME (hf_v2)',
              style: LabText.label),
          const SizedBox(height: 4),
          const Text(
            'Simulated research truth. Not production Match Memory. Not SQLite D1.',
            style: LabText.caption,
          ),
          _Section(
            title: 'ESTABLISHED',
            lines: [
              snapshot.commitLabel,
              '${snapshot.scope.name} cautions $cautionCount',
              snapshot.sendOffPresence,
              if (twoCautions) 'Two cautions recorded',
              if (sentOff) 'Sending-off recorded',
              snapshot.priorCautionLabel,
              'Cautions ${snapshot.cautions.length}${_cautions()}',
              'Sending-offs ${snapshot.sendOffs.length}${_sendOffs()}',
              'Substitutions ${snapshot.substitutions.length}${_substitutions()}',
            ],
          ),
          _Section(
            title: 'IN-FLIGHT / UNFINISHED',
            lines: [
              inFlight == null
                  ? 'In flight: none'
                  : 'In flight: ${inFlight.kind.name} ${inFlight.subjectId ?? '-'} ${inFlight.scope.name} OUT ${inFlight.outId ?? '-'} IN ${inFlight.inId ?? '-'}',
              if (inFlight != null)
                'Frozen subject kind ${inFlight.subjectKind?.name ?? '-'}',
              'Team ${snapshot.teamContext.name}',
              'Subject ${snapshot.selectionKind.name} $subject',
              'Scope ${snapshot.scope.name}',
              'OUT ${snapshot.outId ?? '-'}',
              'IN ${snapshot.inId ?? '-'}',
              'Pair ${snapshot.substitutionStage.name}',
              snapshot.yellowOffered ? 'Yellow offered' : 'Yellow not offered',
              snapshot.directSendOffOffered
                  ? 'Direct send-off offered'
                  : 'Direct send-off not offered',
            ],
          ),
          _Section(
            title: 'VISIBLE ON DEVICE',
            lines: [
              'Route ${visibleRoute ?? 'unknown'}',
              'Commit label ${visibleCommitLabel ?? snapshot.commitLabel}',
              'Last input ${lastOrigin ?? 'none'}',
              visibleCommitLabel == null ||
                      visibleCommitLabel == snapshot.commitLabel
                  ? 'Presentation matches research snapshot'
                  : 'Presentation differs from research snapshot',
            ],
          ),
          _Section(
            title: 'SAFETY / CONTEXT',
            lines: [
              snapshot.freshInputEligible
                  ? 'Fresh input eligible'
                  : 'Fresh input not eligible',
              'Armed ${snapshot.armedKind?.name ?? 'none'}',
              'Predecessor ${snapshot.predecessorKind?.name ?? 'none'}',
              snapshot.successorEstablished
                  ? 'Successor established'
                  : 'No successor',
              'Active pointers ${snapshot.activePointerCount}',
            ],
          ),
          _Section(
            title: 'SCENARIO CONTEXT',
            lines: [
              snapshot.scenarioId,
              snapshot.pitchTruth,
              snapshot.expectedDigitalTruth,
              'P0: ${snapshot.p0Failure}',
            ],
          ),
        ],
      ),
    );
  }

  String _cautions() {
    if (snapshot.cautions.isEmpty) return '';
    return ': ${snapshot.cautions.map((item) => 'caution ${item.subjectId} ${item.scope.name}').join(', ')}';
  }

  String _sendOffs() {
    if (snapshot.sendOffs.isEmpty) return '';
    return ': ${snapshot.sendOffs.map((item) => 'send-off ${item.subjectId} ${item.pathway.name}').join(', ')}';
  }

  String _substitutions() {
    if (snapshot.substitutions.isEmpty) return '';
    return ': ${snapshot.substitutions.map((item) => 'substitution ${item.outId}>${item.inId}').join(', ')}';
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: LabMetrics.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: LabText.label),
          const SizedBox(height: 4),
          DecoratedBox(
            decoration: BoxDecoration(
              color: LabColors.canvas,
              borderRadius: BorderRadius.circular(LabMetrics.controlRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in lines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text(line, style: LabText.numeric),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
