import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hf_prototype/research_app.dart';
import 'package:hf_v2/hf_v2.dart';
import 'package:simulator_geometry/simulator_geometry.dart';

Future<void> _loadReadableFonts() async {
  const regularPath = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';
  const boldPath = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf';
  if (!File(regularPath).existsSync() || !File(boldPath).existsSync()) {
    return;
  }
  Future<ByteData> bytes(String path) async {
    final data = File(path).readAsBytesSync();
    return ByteData.sublistView(data);
  }

  final regular = FontLoader('Roboto')..addFont(bytes(regularPath));
  await regular.load();
  final bold = FontLoader('Roboto')..addFont(bytes(boldPath));
  await bold.load();
}

void main() {
  testWidgets('capture simulator lab surfaces', (tester) async {
    await _loadReadableFonts();
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final controller = ResearchController();
    await tester.pumpWidget(ResearchApp(controller: controller));
    await tester.pump();
    controller.openGeometryStage();
    await tester.pump();
    await _capture(tester, '01-phone-focus');

    controller.selectProfile(illustrativeRoundWatch.profileId);
    await tester.pump();
    await _capture(tester, '02-round-watch-focus');

    controller.selectProfile(illustrativeRectangularWatch.profileId);
    await tester.pump();
    await _capture(tester, '03-rectangular-watch-focus');

    controller.selectProfile(illustrativePhonePortrait.profileId);
    controller.closeGeometryStage();
    controller.setWorkspace(LabWorkspace.compare);
    await tester.pump();
    await _capture(tester, '04-comparison');

    controller.setWorkspace(LabWorkspace.commandLab);
    controller.openInspector(InspectorSection.truth);
    await tester.pump();
    await _capture(tester, '05-inspection');

    controller.closeInspector();
    controller.setWorkspace(LabWorkspace.focus);
    controller.openGeometryStage();
    controller.load(ScenarioId.s07RapidRepeatAfterY2);
    controller.show(ResearchPage.yellow);
    await tester.pump();
    await tester.tap(find.text('Record yellow'));
    await tester.pump();
    await _capture(tester, '06-y2-send-off-absent');

    controller.setHold(true);
    controller.load(ScenarioId.s09Home14ThenAway14);
    controller.show(ResearchPage.yellow);
    await tester.pump();
    await tester.tap(find.text('Record yellow'));
    await tester.pump();
    await _capture(tester, '07-in-flight-frozen');

    controller.setHold(false);
    controller.load(ScenarioId.s16SaveNotVerified);
    controller.show(ResearchPage.yellow);
    await tester.pump();
    await tester.tap(find.text('Record yellow'));
    await tester.pump();
    await _capture(tester, '08-save-not-verified');

    controller.load(ScenarioId.s01YellowNoPrior);
    controller.setCalibration(CalibrationMode.physical1to1);
    await tester.pump();
    await _capture(tester, '09-physical-size-unknown');

    controller.importProfile(_tinyRound);
    controller.show(ResearchPage.yellow);
    await tester.pump();
    await _capture(tester, '10-layout-not-fit');
  });
}

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('lab-boundary')),
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  final directory = Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}forref-sim-visual',
  );
  directory.createSync(recursive: true);
  final file = File(
    '${directory.path}${Platform.pathSeparator}$name.png',
  );
  file.writeAsBytesSync(bytes!);
}

const _tinyRound = '''
{
  "schemaVersion": 1,
  "profileId": "tiny-round",
  "displayName": "Tiny round",
  "deviceClass": "smartwatch",
  "screenShape": "round",
  "classification": "illustrative",
  "logicalViewport": {"width": 80, "height": 80},
  "rasterDimensions": {"known": false},
  "physicalDisplayDimensionsMm": {"known": false},
  "safeArea": {"kind": "circularInset", "inset": 4},
  "edgeClipping": "circularMask",
  "cornerRadius": 0,
  "inputCapabilities": {
    "touchscreen": "supported",
    "crown": "unknown",
    "physicalButtons": "unknown",
    "rotatingBezel": "unknown",
    "gestureInput": "unknown",
    "accessibilityInvocation": "unknown"
  },
  "typography": {"minimumLogicalSp": 12},
  "provenance": {
    "sourceType": "illustrative",
    "sourceReference": "FORREF research fixture. Dimensions are illustrative, not a measured product.",
    "observedDate": null,
    "measurementMethod": null
  }
}
''';
