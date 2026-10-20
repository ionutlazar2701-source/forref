import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hf_prototype/research_app.dart';

Future<void> _loadReadableFonts() async {
  const regularPath = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';
  const boldPath = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf';
  if (!File(regularPath).existsSync() || !File(boldPath).existsSync()) return;
  Future<ByteData> bytes(String path) async {
    return ByteData.sublistView(File(path).readAsBytesSync());
  }

  final regular = FontLoader('Roboto')..addFont(bytes(regularPath));
  await regular.load();
  final bold = FontLoader('Roboto')..addFont(bytes(boldPath));
  await bold.load();
}

void main() {
  testWidgets('capture sandbox journal evidence', (tester) async {
    await _loadReadableFonts();
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final result = Process.runSync(
      'dart',
      ['run', 'bin/capture_report.dart'],
      workingDirectory: '../simulator_sandbox',
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final report = jsonDecode(result.stdout as String) as Map<String, Object?>;
    final sha = _headSha();
    final stamp =
        'SHA $sha | profileId none | runtime Integration Sandbox | scenario synthetic yellow | fidelity not a device | ${report['measurement']}';
    final controller = ResearchController()..evidenceStamp = stamp;
    await tester.pumpWidget(ResearchApp(controller: controller));

    void show(String headline, String detail, List<String> lines) {
      controller.showJournalSnapshot(headline: headline, detail: detail, lines: lines);
    }

    show(
      'Event Journal · ${report['successLabel']} · ${report['measurement']}',
      'record ${report['recordId']} bytes ${report['encodedBytes']} file ${report['fileBytesBefore']}->${report['fileBytesAfter']} records ${report['recordCount']}',
      (report['successJournal'] as List).cast<String>(),
    );
    await tester.pump();
    await _capture(tester, '12-event-journal-success');
    await _capture(tester, '14-record-readback');
    show(
      'Event Journal · ${report['failureLabel']} · ${report['measurement']}',
      'abort left record ${report['recordId']} in the file',
      (report['failureJournal'] as List).cast<String>(),
    );
    await tester.pump();
    await _capture(tester, '13-event-journal-failure');
    show(
      'Event Journal · reopen ${report['reopenRecord']} · ${report['measurement']}',
      'projection ${report['projectionIds']}',
      [
        'readback ${report['reopenRecord']}',
        'projection ${(report['projectionIds'] as List).join(',')}',
        'database ${report['database']}',
      ],
    );
    await tester.pump();
    await _capture(tester, '15-reopen-rebuild');
  });
}

String _headSha() {
  final git = Process.runSync('git', ['rev-parse', 'HEAD']);
  if (git.exitCode != 0) return 'SHA unavailable';
  return (git.stdout as String).trim();
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('lab-boundary')),
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  final targets = <Directory>[
    Directory('${Directory.systemTemp.path}${Platform.pathSeparator}forref-sim-v2'),
    Directory('/opt/cursor/artifacts'),
  ];
  for (final directory in targets) {
    if (directory.path == '/opt/cursor/artifacts' && !directory.existsSync()) continue;
    directory.createSync(recursive: true);
    File('${directory.path}${Platform.pathSeparator}$name.png').writeAsBytesSync(bytes!);
  }
}
