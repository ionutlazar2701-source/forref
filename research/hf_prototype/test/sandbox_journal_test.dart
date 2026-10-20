import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide ActivateIntent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hf_prototype/research_app.dart';
import 'package:simulator_sandbox/simulator_sandbox.dart';

void main() {
  testWidgets('the lab renders a file-backed sandbox journal', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final report = _captureReport();
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
      headline: 'Event Journal · ${report['successLabel']} · ${report['measurement']}',
      detail: 'record ${report['recordId']} bytes ${report['encodedBytes']} '
          'file ${report['fileBytesBefore']}->${report['fileBytesAfter']}',
      lines: (report['successJournal'] as List).cast<String>(),
    );
    await tester.pump();
    expect(find.textContaining(sandboxCommittedLabel), findsWidgets);
    expect(find.textContaining('${report['recordId']}'), findsWidgets);
  });
}

Map<String, Object?> _captureReport() {
  final result = Process.runSync(
    'dart',
    ['run', 'bin/capture_report.dart'],
    workingDirectory: '../simulator_sandbox',
  );
  expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  return jsonDecode(result.stdout as String) as Map<String, Object?>;
}
