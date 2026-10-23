import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hf_prototype/research_app.dart';
import 'package:simulator_presentation/simulator_presentation.dart';

import 'lab_support.dart';

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
  testWidgets('capture the watch reference app inside the shells',
      (tester) async {
    await _loadReadableFonts();
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final sha = _headSha();
    final controller = ResearchController();
    String stamp(String profileId, String scenario) {
      return 'SHA $sha | profileId $profileId | runtime Research | scenario $scenario | fidelity schematic';
    }

    controller.evidenceStamp = stamp('amazfit-gts4', 's01YellowNoPrior');
    await tester.pumpWidget(ResearchApp(controller: controller));
    await selectDevice(tester, 'amazfit-gts4');
    await _capture(tester, '06-watch-live');

    await tapWatch(tester, 'Capture');
    await tester.pump();
    await tapWatch(tester, 'Yellow');
    await tester.pump();
    await _capture(tester, '07-yellow-flow');

    await controller.dispatchWatch(
      const OpenRouteIntent(WatchRoute.sendOffFlow,
          origin: IntentOrigin.watchUi),
    );
    await tester.pump();
    await _capture(tester, '08-y2-sendoff-separated');

    await controller.dispatchWatch(
      const OpenRouteIntent(WatchRoute.substitutionFlow,
          origin: IntentOrigin.watchUi),
    );
    await tester.pump();
    await _capture(tester, '09-substitution');

    await controller.dispatchWatch(
      const OpenRouteIntent(WatchRoute.yellowFlow,
          origin: IntentOrigin.watchUi),
    );
    await tester.pump();
    final home14 = find.byKey(const Key('watch-yellow-subject-p-home-14'));
    await tester.ensureVisible(home14);
    await tester.tap(home14);
    await tester.pump();
    final record = find.text('Record yellow');
    await tester.ensureVisible(record);
    await tester.tap(record);
    await tester.pump();
    final resolve = find.text('Resolve simulated outcome');
    await tester.ensureVisible(resolve);
    await tester.tap(resolve);
    await tester.pump();
    controller.evidenceStamp =
        stamp('apple-watch-series9-45', 's01YellowNoPrior');
    await selectDevice(tester, 'apple-watch-series9-45');
    await _capture(tester, '10-device-switch-same-state');

    final commands = ResearchController()
      ..evidenceStamp = stamp('huawei-watch-gt4-46', 's01YellowNoPrior');
    await tester.pumpWidget(ResearchApp(controller: commands));
    await selectDevice(tester, 'huawei-watch-gt4-46');
    await openWorkspace(tester, LabWorkspace.commandLab);
    await tester.tap(find.text('Operator fixture: yellow Home 14'));
    await tester.pump();
    await _capture(tester, '11-command-lab');
  });
}

String _headSha() {
  final result = Process.runSync('git', ['rev-parse', 'HEAD']);
  if (result.exitCode != 0) return 'SHA unavailable';
  return (result.stdout as String).trim();
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
    Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}forref-sim-v2'),
    Directory('/opt/cursor/artifacts'),
  ];
  for (final directory in targets) {
    if (directory.path == '/opt/cursor/artifacts' && !directory.existsSync()) {
      continue;
    }
    directory.createSync(recursive: true);
    File('${directory.path}${Platform.pathSeparator}$name.png')
        .writeAsBytesSync(bytes!);
  }
}
