import 'package:flutter/material.dart' hide ActivateIntent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hf_prototype/research_app.dart';
import 'package:simulator_sandbox/simulator_sandbox.dart';
import 'package:watch_reference_ui/watch_reference_ui.dart';

import 'lab_support.dart';

void main() {
  testWidgets('the lab renders a file-backed sandbox journal', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final report = loadCaptureReportFixture();
    expect(report['successLabel'], sandboxCommittedLabel);
    expect(report['failureLabel'], sandboxFailedLabel);
    expect(report['recordId'], isNotNull);
    expect(report['reopenRecord'], report['recordId']);
    expect(report['projectionIds'], contains(report['recordId']));
    expect(report['database'], contains('match-memory.sqlite'));
    expect(report['database'], isNot(contains(':memory:')));

    final controller = ResearchController();
    await tester.pumpWidget(ResearchApp(controller: controller));
    controller.showJournalSnapshot(
      headline:
          'Event Journal · ${report['successLabel']} · ${report['measurement']}',
      detail: 'record ${report['recordId']} bytes ${report['encodedBytes']} '
          'file ${report['fileBytesBefore']}->${report['fileBytesAfter']}',
      lines: (report['successJournal'] as List).cast<String>(),
    );
    await tester.pump();
    // The snapshot opens the Event Journal inspector. The sandbox label and
    // the record id are inspector content, never watch content.
    expect(controller.inspector, InspectorSection.eventJournal);
    expect(find.byKey(const Key('event-journal')), findsOneWidget);
    expect(find.textContaining(sandboxCommittedLabel), findsWidgets);
    expect(find.textContaining('${report['recordId']}'), findsWidgets);
    expect(find.byKey(const Key('journal-origin-warning')), findsOneWidget);
    expect(controller.watchRuntime.watchState.commit.label,
        isNot(sandboxCommittedLabel));
    expect(
      find.descendant(
        of: find.byType(WatchReferenceApp),
        matching: find.textContaining(sandboxCommittedLabel),
      ),
      findsNothing,
    );
    expect(find.text('RESEARCH WATCH PATH · hf_v2 · NOT SQLITE D1'),
        findsOneWidget);
  });
}

