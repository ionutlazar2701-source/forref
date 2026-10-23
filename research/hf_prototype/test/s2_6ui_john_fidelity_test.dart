import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hf_prototype/research_app.dart';
import 'package:hf_v2/hf_v2.dart';
import 'package:watch_reference_ui/watch_reference_ui.dart';

import 'lab_support.dart';

/// Structural and capture gate for the John desktop composition.
///
/// Screenshots are Linux widget captures. They are not the Founder Windows gate.
void main() {
  testWidgets('John composition is present at the reference viewport', (tester) async {
    await loadReadableFonts();
    final controller = await pumpLab(tester, size: const Size(1672, 941));
    await controller.operatorLoadScenario(ScenarioId.s21MatchReportOps);
    await tester.pump();

    expect(find.text('FORREF SIMULATOR LAB'), findsOneWidget);
    expect(find.text('RESEARCH / NON-PRODUCTION'), findsOneWidget);
    expect(find.text('SCENARIO CONTROLS'), findsOneWidget);
    expect(find.text('Mobile Session'), findsOneWidget);
    expect(find.text('Watch Session'), findsOneWidget);
    expect(find.text('DEVICE & VIEW CONTROLS'), findsOneWidget);
    expect(find.text('COMMAND LAB'), findsOneWidget);
    expect(find.textContaining('EVENT JOURNAL'), findsOneWidget);
    expect(find.text('MATCH READY'), findsWidgets);
    expect(find.text('Not started'), findsWidgets);
    expect(find.text('LAYOUT NOT FIT FOR THIS PROFILE'), findsNothing);
    expect(find.byKey(const Key('paired-link')), findsOneWidget);
    expect(find.byKey(const Key('mobile-kick-off')), findsOneWidget);
    await captureLab(tester, 's26ui-01-simlab-match-ready');

    await tester.tap(find.byKey(const Key('mobile-kick-off')));
    await tester.pump();
    controller.applyLiveElapsed(const Duration(seconds: 37));
    await tester.pump();
    expect(find.text('FIRST HALF'), findsWidgets);
    expect(find.text('00:37'), findsWidgets);
    expect(find.text('LAYOUT NOT FIT FOR THIS PROFILE'), findsNothing);
    await captureLab(tester, 's26ui-02-first-half');

    await tester.tap(find.byKey(const Key('mobile-goal')));
    await tester.pump();
    await captureLab(tester, 's26ui-03-mobile-goal');
    await tester.tap(find.byKey(const Key('mobile-goal-team-home')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-goal-scorer-p-home-9')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-record-goal')));
    await tester.pump();
    expect(controller.instrument.goals, hasLength(1));

    await tester.tap(find.byType(WatchReferenceApp));
    await tapWatch(tester, 'Capture');
    await tester.pump();
    await tapWatch(tester, 'Goal');
    await tester.pump();
    await captureLab(tester, 's26ui-04-watch-goal');
    await tapWatch(tester, 'Back');
    await tester.pump();

    await tester.tap(find.byKey(const Key('mobile-yellow')));
    await tester.pump();
    await captureLab(tester, 's26ui-05-yellow');
    await tester.tap(find.byKey(const Key('mobile-yellow-team-away')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-yellow-subject-p-away-6')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-record-yellow')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('mobile-yellow')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-yellow-team-away')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-yellow-subject-p-away-6')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-record-yellow')));
    await tester.pump();
    expect(controller.instrument.sendOffs, isEmpty);

    await tester.tap(find.byKey(const Key('mobile-sendoff')));
    await tester.pump();
    await captureLab(tester, 's26ui-06-sendoff');
    await tester.tap(find.byKey(const Key('mobile-record-second-sendoff')));
    await tester.pump();
    expect(controller.instrument.sendOffs, hasLength(1));

    await tester.tap(find.byKey(const Key('mobile-sendoff')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-sendoff-team-home')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('mobile-sendoff-subject-p-home-4')));
    await tester.tap(find.byKey(const Key('mobile-sendoff-subject-p-home-4')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-record-direct-sendoff')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('mobile-substitution')));
    await tester.pump();
    await captureLab(tester, 's26ui-07-substitution');
    await tester.tap(find.byKey(const Key('mobile-sub-team-home')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('mobile-sub-out-p-home-9')));
    await tester.tap(find.byKey(const Key('mobile-sub-out-p-home-9')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('mobile-sub-in-p-home-17')));
    await tester.tap(find.byKey(const Key('mobile-sub-in-p-home-17')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-record-substitution')));
    await tester.pump();
    expect(controller.instrument.substitutions, hasLength(1));

    await tester.tap(find.byKey(const Key('mobile-match-report')));
    await tester.pump();
    await captureLab(tester, 's26ui-08-match-report');
    expect(controller.watchRuntime.watchState.matchReport.entries.length, greaterThanOrEqualTo(5));

    await tester.tap(find.byKey(const Key('toggle-device-frame')));
    await tester.pump();
    await captureLab(tester, 's26ui-09-frame-off');
    await tester.tap(find.byKey(const Key('toggle-device-frame')));
    await tester.pump();

    await selectDevice(tester, 'amazfit-gts4');
    await tester.pump();
    expect(find.text('LAYOUT NOT FIT FOR THIS PROFILE'), findsNothing);
    await captureLab(tester, 's26ui-10-rectangular-watch');

    await selectDevice(tester, 'apple-watch-series9-45');
    await tester.pump();
    await captureLab(tester, 's26ui-11-rectangular-watch-a');

    await selectDevice(tester, 'huawei-watch-gt4-46');
    await tester.pump();
    expect(find.text('LAYOUT NOT FIT FOR THIS PROFILE'), findsNothing);
    await captureLab(tester, 's26ui-12-round-watch');

    await openWorkspace(tester, LabWorkspace.compare);
    await tester.pump();
    await captureLab(tester, 's26ui-13-device-compare');

    await openWorkspace(tester, LabWorkspace.commandLab);
    await tester.pump();
    await captureLab(tester, 's26ui-14-command-lab');

    await openWorkspace(tester, LabWorkspace.focus);
    await tester.pump();
    await captureLab(tester, 's26ui-15-phone-and-shell');
  });

  for (final size in const [Size(1600, 900), Size(1920, 1080), Size(1672, 941)]) {
    testWidgets('John shell lays out at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      final controller = await pumpLab(tester, size: size);
      await controller.operatorLoadScenario(ScenarioId.s21MatchReportOps);
      await tester.pump();
      expect(find.text('SCENARIO CONTROLS'), findsOneWidget);
      expect(find.byKey(const Key('mobile-session')), findsOneWidget);
      expect(find.byType(WatchReferenceApp), findsOneWidget);
      expect(find.text('LAYOUT NOT FIT FOR THIS PROFILE'), findsNothing);
    });
  }
}
