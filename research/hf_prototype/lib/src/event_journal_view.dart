import 'package:flutter/material.dart';
import 'package:simulator_sandbox/simulator_sandbox.dart';

import '../research_app.dart';
import 'lab_theme.dart';

const notObservedLabel = 'NOT OBSERVED';
const observedLabel = 'OBSERVED';
const observedFailedLabel = 'OBSERVED · FAILED';

/// One causal stage derived only from observed journal entries.
final class CausalStage {
  const CausalStage({
    required this.kind,
    required this.entries,
  });

  final JournalEventKind kind;
  final List<JournalEntry> entries;

  bool get observed => entries.isNotEmpty;

  /// A failure is also an observation. It is never painted as success.
  bool get failed {
    if (!observed) return false;
    final detail = entries.last.detail;
    return switch (kind) {
      JournalEventKind.commitReturned =>
        detail.startsWith('DurableCommitFailure'),
      JournalEventKind.recordReadBack => detail.startsWith('missing'),
      JournalEventKind.projectionRebuilt => detail.startsWith('record absent'),
      JournalEventKind.presentationUpdated => detail == sandboxFailedLabel,
      JournalEventKind.captureAdmissionStarted => detail.contains('Conflict'),
      _ => false,
    };
  }

  String get statusLabel {
    if (!observed) return notObservedLabel;
    return failed ? observedFailedLabel : observedLabel;
  }
}

String causalStageTitle(JournalEventKind kind) => switch (kind) {
      JournalEventKind.intentReceived => '1. Intent received',
      JournalEventKind.commandFrozen => '2. Command frozen',
      JournalEventKind.captureAdmissionStarted =>
        '3. Capture admission started',
      JournalEventKind.commitRequested => '4. Commit requested',
      JournalEventKind.commitReturned => '5. Commit returned',
      JournalEventKind.recordReadBack => '6. Record read back',
      JournalEventKind.projectionRebuilt => '7. Projection rebuilt',
      JournalEventKind.presentationUpdated => '8. Presentation updated',
    };

/// Builds the eight stages from live entries or from a seeded snapshot of
/// "sequence kind detail" lines. Nothing is synthesized.
List<CausalStage> causalStagesFrom(List<JournalEntry> entries) {
  return [
    for (final kind in JournalEventKind.values)
      CausalStage(
        kind: kind,
        entries: [
          for (final entry in entries)
            if (entry.kind == kind) entry
        ],
      ),
  ];
}

List<JournalEntry> parseJournalLines(List<String> lines) {
  final entries = <JournalEntry>[];
  for (final line in lines) {
    final parts = line.split(' ');
    if (parts.length < 2) continue;
    final sequence = int.tryParse(parts[0]);
    JournalEventKind? kind;
    for (final candidate in JournalEventKind.values) {
      if (candidate.name == parts[1]) kind = candidate;
    }
    if (sequence == null || kind == null) continue;
    entries.add(
      JournalEntry(
          sequence: sequence, kind: kind, detail: parts.skip(2).join(' ')),
    );
  }
  return entries;
}

/// Event Journal inspector section.
///
/// Observer-only. The sandbox path and the research watch path are shown as
/// two separate origins. A watch tap never appears as a sandbox stage.
class EventJournalView extends StatelessWidget {
  const EventJournalView({super.key, required this.controller});

  final ResearchController controller;

  @override
  Widget build(BuildContext context) {
    final live =
        controller.sandboxSession?.journal.entries ?? const <JournalEntry>[];
    final seeded = parseJournalLines(controller.journalLines);
    final entries = live.isNotEmpty ? live : seeded;
    final stages = causalStagesFrom(entries);
    final report = controller.sandboxReport;
    final hasAny = entries.isNotEmpty;
    final headline = controller.journalHeadline ??
        (report != null
            ? report.label
            : (hasAny
                ? 'Sandbox stages observed'
                : 'No sandbox capture observed'));
    final trace = controller.watchRuntime.intentTrace;
    final watchCommit = controller.watchRuntime.watchState.commit.label;

    return SingleChildScrollView(
      key: const Key('event-journal'),
      padding: const EdgeInsets.all(LabMetrics.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('CAUSALITY · INTEGRATION SANDBOX', style: LabText.label),
          const SizedBox(height: 4),
          Text(headline,
              key: const Key('journal-headline'), style: LabText.panelTitle),
          const SizedBox(height: 4),
          Text(
            hasAny
                ? '$sandboxOriginLabel · stages below come from observed JournalEntry records.'
                : 'No INTEGRATION SANDBOX ACTION has run in this session. Every stage is $notObservedLabel.',
            style: LabText.caption,
          ),
          if (controller.journalDetail != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(controller.journalDetail!, style: LabText.caption),
            ),
          const SizedBox(height: LabMetrics.tight),
          _OriginWarning(),
          const SizedBox(height: LabMetrics.tight),
          for (final stage in stages) _StageRow(stage: stage),
          const SizedBox(height: LabMetrics.gutter),
          _ResearchPathCard(
            trace: trace.isEmpty
                ? 'No watch or operator intent yet'
                : '${trace.last.originLabel} · ${trace.last.intentName}',
            commit: watchCommit,
          ),
          const SizedBox(height: LabMetrics.gutter),
          ExpansionTile(
            key: const Key('journal-details'),
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Details · ${report?.measurementLabel ?? sandboxMeasurementLabel}',
              style: LabText.bodyStrong,
            ),
            subtitle: const Text(
              'Desktop timings and file sizes. Not device performance.',
              style: LabText.caption,
            ),
            children: [
              if (report != null) ...[
                _detail('Capture intent', report.captureIntentId),
                _detail('Record id', report.recordId ?? 'none'),
                _detail('Encoded bytes', '${report.encodedBytes}'),
                _detail('Database file',
                    '${report.fileBytesBefore} → ${report.fileBytesAfter} bytes'),
                _detail('Record count', '${report.recordCount}'),
                _detail('Diagnostics', report.commitDiagnostics ?? 'none'),
                _detail('Commit', '${report.commitElapsed.inMicroseconds} µs'),
                _detail(
                    'Readback', '${report.readbackElapsed.inMicroseconds} µs'),
                _detail('Projection',
                    '${report.projectionElapsed.inMicroseconds} µs'),
                _detail('Journal fault', report.journalFault ?? 'none'),
              ],
              if (controller.sandboxSession != null)
                _detail('Database', controller.sandboxSession!.path.file.path),
              if (entries.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 6, bottom: 2),
                  child: Text('RAW JOURNAL', style: LabText.label),
                ),
                for (final entry in entries)
                  Text(
                    '${entry.sequence} ${entry.kind.name} ${entry.detail}',
                    key: Key('journal-raw-${entry.sequence}'),
                    style: const TextStyle(
                        color: LabColors.navy,
                        fontSize: 11,
                        fontFamily: 'monospace'),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: LabText.caption)),
          Expanded(child: Text(value, style: LabText.numeric)),
        ],
      ),
    );
  }
}

class _OriginWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: LabColors.canvas,
        borderRadius: BorderRadius.circular(LabMetrics.controlRadius),
      ),
      child: const Text(
        'Sandbox Yellow is an explicit INTEGRATION SANDBOX ACTION. A Yellow tapped on the '
        'reference watch is an hf_v2 research action and does not reach SQLite. No bridge '
        'between them exists in this build.',
        key: Key('journal-origin-warning'),
        style: LabText.caption,
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.stage});

  final CausalStage stage;

  @override
  Widget build(BuildContext context) {
    final color = !stage.observed
        ? LabColors.unknownFact
        : (stage.failed ? LabColors.failure : LabColors.navy);
    final detail = stage.observed
        ? stage.entries.last.detail
        : 'No journal entry for this stage.';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: stage.observed ? color : Colors.transparent,
                border: Border.all(color: color, width: 1.5),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(causalStageTitle(stage.kind),
                          style: LabText.bodyStrong),
                    ),
                    Text(
                      stage.statusLabel,
                      key: Key('stage-${stage.kind.name}'),
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                Text(
                  detail,
                  style: LabText.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResearchPathCard extends StatelessWidget {
  const _ResearchPathCard({required this.trace, required this.commit});

  final String trace;
  final String commit;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('journal-research-path'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: LabColors.line),
        borderRadius: BorderRadius.circular(LabMetrics.controlRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RESEARCH WATCH PATH · hf_v2 · NOT SQLITE D1',
              style: LabText.label),
          const SizedBox(height: 4),
          Text(trace, style: LabText.caption),
          Text(commit,
              key: const Key('journal-research-commit'),
              style: LabText.bodyStrong),
        ],
      ),
    );
  }
}
