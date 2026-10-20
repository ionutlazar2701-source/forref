import 'package:flutter/material.dart';
import 'package:hf_v2/hf_v2.dart';

import 'lab_theme.dart';

/// Reads an immutable snapshot. It does not append research records.
class TruthInspector extends StatelessWidget {
  const TruthInspector({super.key, required this.snapshot});

  final ResearchTruthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final inFlight = snapshot.inFlight;
    return ListView(
      key: const Key('truth-inspector'),
      padding: const EdgeInsets.all(12),
      children: [
        _section('PITCH TRUTH', snapshot.pitchTruth),
        _section('SIMULATED DIGITAL TRUTH', _digital()),
        _section('UNFINISHED INTENT', _unfinished()),
        _section('IN-FLIGHT COMMAND', _inFlight(inFlight)),
        _section('COMMIT STATE', snapshot.commitLabel),
        _section('SAFETY STATE', _safety()),
        _section(
          'SCENARIO CONTEXT',
          '${snapshot.scenarioId}\n${snapshot.expectedDigitalTruth}\nP0: ${snapshot.p0Failure}',
        ),
      ],
    );
  }

  String _digital() {
    final cautions = snapshot.cautions
        .map((item) => 'caution ${item.subjectId} ${item.scope.name}')
        .join(', ');
    final sendOffs = snapshot.sendOffs
        .map((item) => 'send-off ${item.subjectId} ${item.pathway.name}')
        .join(', ');
    final substitutions = snapshot.substitutions
        .map((item) => 'substitution ${item.outId}>${item.inId}')
        .join(', ');
    return [
      snapshot.sendOffPresence,
      'Cautions ${snapshot.cautions.length}${cautions.isEmpty ? '' : ': $cautions'}',
      'Sending-offs ${snapshot.sendOffs.length}${sendOffs.isEmpty ? '' : ': $sendOffs'}',
      'Substitutions ${snapshot.substitutions.length}${substitutions.isEmpty ? '' : ': $substitutions'}',
      snapshot.priorCautionLabel,
    ].join('\n');
  }

  String _unfinished() {
    return [
      'Team ${snapshot.teamContext.name}',
      'Subject ${snapshot.selectionKind.name} ${snapshot.selectedSubjectId ?? '-'}',
      'Scope ${snapshot.scope.name}',
      'OUT ${snapshot.outId ?? '-'}',
      'IN ${snapshot.inId ?? '-'}',
      'Pair ${snapshot.substitutionStage.name}',
    ].join('\n');
  }

  String _inFlight(ActivatedCommandSnapshot? command) {
    if (command == null) return 'None';
    return [
      command.kind.name,
      'subject ${command.subjectId ?? '-'}',
      'kind ${command.subjectKind?.name ?? '-'}',
      'scope ${command.scope.name}',
      'OUT ${command.outId ?? '-'}',
      'IN ${command.inId ?? '-'}',
    ].join('\n');
  }

  String _safety() {
    return [
      snapshot.freshInputEligible ? 'Fresh input eligible' : 'Fresh input not eligible',
      'Armed ${snapshot.armedKind?.name ?? 'none'}',
      'Predecessor ${snapshot.predecessorKind?.name ?? 'none'}',
      snapshot.successorEstablished ? 'Successor established' : 'No successor',
      'Active pointers ${snapshot.activePointerCount}',
    ].join('\n');
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: LabColors.navy,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(body, style: const TextStyle(color: LabColors.navy, fontSize: 12)),
        ],
      ),
    );
  }
}
