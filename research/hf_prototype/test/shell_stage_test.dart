import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hf_prototype/src/device_shell_stage.dart';
import 'package:simulator_geometry/simulator_geometry.dart';

void main() {
  testWidgets('diagnostic viewport sits in each seed shell', (tester) async {
    for (final profile in factualSeedProfiles) {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 420,
            height: 640,
            child: DeviceShellStage(
                profile: profile, stamp: 'test', showEvidenceCaption: true),
          ),
        ),
      );
      expect(find.text(profile.identity.profileId), findsOneWidget);
      expect(find.text('DIAGNOSTIC VIEWPORT'), findsOneWidget);
      expect(find.text('SAFE AREA UNKNOWN'), findsOneWidget);
      expect(find.textContaining('not certified'), findsOneWidget);
    }
  });

  testWidgets('a bezel tap does not press the aperture child', (tester) async {
    var pressed = 0;
    final rejected = <ShellSurface>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 640,
            child: DeviceShellStage(
              profile: huaweiWatchGt446,
              onRejected: rejected.add,
              child: Center(
                child: TextButton(
                  onPressed: () => pressed++,
                  child: const Text('INSIDE'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('INSIDE'));
    await tester.pump();
    expect(pressed, 1);
    await tester.tapAt(tester.getTopLeft(find.byKey(const Key('shell-paint'))) +
        const Offset(4, 4));
    await tester.pump();
    expect(pressed, 1);
    expect(rejected, isNotEmpty);
    expect(rejected, isNot(contains(ShellSurface.aperture)));
  });

  testWidgets('switching shell profile cancels an open pointer',
      (tester) async {
    final cancelled = <int>[];
    var profile = huaweiWatchGt446;
    late StateSetter setState;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setter) {
            setState = setter;
            return SizedBox(
              width: 420,
              height: 640,
              child: DeviceShellStage(
                profile: profile,
                onPointerCancel: cancelled.add,
                child: const SizedBox.expand(
                  child: ColoredBox(
                    color: Color(0xFFFFFFFF),
                    child: Center(child: Text('INSIDE')),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('INSIDE')));
    setState(() => profile = appleWatchSeries945);
    await tester.pump();
    expect(cancelled, isNotEmpty);
    await gesture.up();
  });
}
