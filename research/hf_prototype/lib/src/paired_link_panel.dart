import 'package:flutter/material.dart';

import '../research_app.dart';
import 'lab_theme.dart';
/// Conceptual link between mobile and watch research surfaces.
class PairedLinkPanel extends StatelessWidget {
  const PairedLinkPanel({super.key, required this.controller});

  final ResearchController controller;

  @override
  Widget build(BuildContext context) {
    final paired = controller.paired;
    final origin = paired.lastOrigin;
    return Material(
      key: const Key('paired-link'),
      color: LabColors.softWhite,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: LabColors.line),
          borderRadius: BorderRadius.circular(LabMetrics.controlRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: LabMetrics.tight, vertical: 6),
          child: SingleChildScrollView(
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.devices, color: LabColors.navy, size: 18),
              const SizedBox(height: 6),
              const Text('Devices', style: LabText.caption, textAlign: TextAlign.center),
              Text(
                paired.connection == SimulatedConnectionState.pairActive
                    ? 'Synchronized'
                    : 'SIMULATED DISCONNECT',
                style: LabText.bodyStrong,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: Color(0xFF26C0CA),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.link, color: Colors.white, size: 26),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Live session', style: LabText.caption, textAlign: TextAlign.center),
              Text(
                paired.fixture.scenarioId.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: LabText.bodyStrong,
              ),
              const SizedBox(height: 8),
              const Text('● Events', style: LabText.caption, textAlign: TextAlign.center),
              const Text('● Match time', style: LabText.caption, textAlign: TextAlign.center),
              const Text('● Score', style: LabText.caption, textAlign: TextAlign.center),
              const Text('● Cautions', style: LabText.caption, textAlign: TextAlign.center),
              const Text('● Substitutions', style: LabText.caption, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                paired.propagationNote,
                style: LabText.caption,
                textAlign: TextAlign.center,
              ),
              if (origin != null) ...[
                const SizedBox(height: 12),
                Text('LAST ACTION ORIGIN', style: LabText.caption, textAlign: TextAlign.center),
                Text(origin.label, style: LabText.bodyStrong, textAlign: TextAlign.center),
                if (paired.lastIntentName != null)
                  Text(paired.lastIntentName!, style: LabText.caption, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 12),
              Text(
                'SIMULATED · NOT PRODUCTION SYNC',
                style: LabText.caption.copyWith(color: LabColors.steel),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
