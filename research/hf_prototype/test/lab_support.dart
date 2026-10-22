import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hf_prototype/research_app.dart';

/// Wide enough for the inline inspector and the inline Command Lab rail.
const wideLab = Size(1600, 1000);

/// Desktop regime: inline rail, overlay inspector.
const desktopLab = Size(1280, 900);

Future<ResearchController> pumpLab(
  WidgetTester tester, {
  ResearchController? controller,
  Size size = wideLab,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
  final lab = controller ?? ResearchController();
  await tester.pumpWidget(ResearchApp(controller: lab));
  await tester.pump();
  return lab;
}

/// Selects a factual device through the top-bar selector, as the Founder would.
Future<void> selectDevice(WidgetTester tester, String profileId) async {
  await tester.tap(find.byKey(const Key('device-summary')));
  await tester.pump();
  await tester.tap(find.byKey(Key('device-card-$profileId')));
  await tester.pump();
}

Future<void> openWorkspace(WidgetTester tester, LabWorkspace workspace) async {
  await tester.tap(find.byKey(Key('workspace-${workspace.name}')));
  await tester.pump();
}

Future<void> openInspectorTab(
    WidgetTester tester, InspectorSection section) async {
  if (find.byKey(const Key('lab-inspector')).evaluate().isEmpty) {
    await tester.tap(find.byKey(const Key('inspector-toggle')));
    await tester.pump();
  }
  await tester.tap(find.byKey(Key('inspector-tab-${section.name}')));
  await tester.pump();
}

Finder inTruthInspector(Finder matching) => find.descendant(
    of: find.byKey(const Key('truth-inspector')), matching: matching);

Future<void> loadReadableFonts() async {
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

String headSha() {
  final result = Process.runSync('git', ['rev-parse', 'HEAD']);
  if (result.exitCode != 0) return 'SHA unavailable';
  return (result.stdout as String).trim();
}

/// Writes the lab boundary to the temp evidence folder and, when it exists,
/// to the cloud artifacts folder. Returns the temp path.
Future<String> captureLab(
  WidgetTester tester,
  String name, {
  Key boundaryKey = const Key('lab-boundary'),
  String folder = 'forref-sim-v2',
}) async {
  await tester.pump();
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  final targets = <Directory>[
    Directory('${Directory.systemTemp.path}${Platform.pathSeparator}$folder'),
    Directory('/opt/cursor/artifacts'),
  ];
  String? first;
  for (final directory in targets) {
    if (directory.path == '/opt/cursor/artifacts' && !directory.existsSync())
      continue;
    directory.createSync(recursive: true);
    final file = File('${directory.path}${Platform.pathSeparator}$name.png');
    file.writeAsBytesSync(bytes!);
    first ??= file.path;
  }
  return first!;
}
