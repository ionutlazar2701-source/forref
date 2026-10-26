import 'package:flutter/material.dart' hide ActivateIntent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hf_prototype/research_app.dart';
import 'package:simulator_presentation/simulator_presentation.dart';
import 'package:simulator_sandbox/simulator_sandbox.dart';
import 'package:watch_reference_ui/watch_reference_ui.dart';

import 'lab_support.dart';

void main() {
  testWidgets('paired focus shows mobile and watch with shared runtime', (tester) async {
    await pumpLab(tester);
    expect(find.byKey(const Key('paired-focus')), findsOneWidget);
    expect(find.byKey(const Key('mobile-session')), findsOneWidget);
    expect(find.byKey(const Key('paired-link')), findsOneWidget);
    expect(find.byKey(const Key('focus-stage')), findsOneWidget);
    expect(find.byType(WatchReferenceApp), findsOneWidget);
  });

  testWidgets('mobile yellow records MOBILE UI origin', (tester) async {
    final controller = await pumpLab(tester);
    await tester.tap(find.byKey(const Key('mobile-yellow')));
    await tester.pump();
    expect(controller.paired.lastOrigin?.label, 'MOBILE UI');
    expect(controller.watchRuntime.intentTrace.last.origin, IntentOrigin.mobileUi);
    expect(find.textContaining('MOBILE → WATCH'), findsWidgets);
  });

  testWidgets('watch tap records WATCH UI origin', (tester) async {
    final controller = await pumpLab(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(WatchReferenceApp),
        matching: find.byKey(const Key('watch-capture-ring')),
      ),
    );
    await tester.pump();
    expect(controller.paired.lastOrigin?.label, 'WATCH UI');
  });

  test('capture report runs without external dart process', () async {
    final report = await captureReportPayload();
    expect(report['successLabel'], sandboxCommittedLabel);
  });

  testWidgets('match builder loads fixture without Saved state', (tester) async {
    final controller = await pumpLab(tester);
    await openWorkspace(tester, LabWorkspace.matchBuilder);
    await tester.tap(find.byKey(const Key('builder-step-review')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('builder-apply-fixture')));
    await tester.pumpAndSettle();
    expect(controller.workspace, LabWorkspace.matchBuilder);
    expect(find.text('Saved'), findsNothing);
    expect(controller.paired.lastOrigin, SimulatedActionOrigin.systemScenario);
  });
}
