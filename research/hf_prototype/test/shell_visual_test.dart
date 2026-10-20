import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hf_prototype/src/device_shell_stage.dart';
import 'package:simulator_geometry/simulator_geometry.dart';

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
  testWidgets('capture schematic seed shells', (tester) async {
    await _loadReadableFonts();
    await tester.binding.setSurfaceSize(const Size(900, 1100));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final sha = _headSha();
    final shots = [
      ('01-amazfit-gts4-shell', amazfitGts4),
      ('02-huawei-gt4-shell', huaweiWatchGt446),
      ('03-apple-watch-series9-shell', appleWatchSeries945),
      ('04-garmin-s60-shell', garminApproachS60),
      ('05-display-aperture-inspection', huaweiWatchGt446),
    ];
    for (final shot in shots) {
      final inspection = shot.$1.startsWith('05');
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: const Key('shell-boundary'),
            child: ColoredBox(
              color: const Color(0xFFF8FAFC),
              child: SizedBox(
                width: 900,
                height: 1100,
                child: DeviceShellStage(
                  profile: shot.$2,
                  stamp: inspection
                      ? 'SHA $sha | runtime Research | scenario none | fidelity schematic | aperture inspection'
                      : 'SHA $sha | runtime Research | scenario none | fidelity schematic',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await _capture(tester, shot.$1);
    }
  });
}

String _headSha() {
  final result = Process.runSync('git', ['rev-parse', 'HEAD']);
  if (result.exitCode != 0) return 'SHA unavailable';
  return (result.stdout as String).trim();
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('shell-boundary')),
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
