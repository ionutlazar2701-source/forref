import 'package:flutter/material.dart' hide ActivateIntent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hf_v2/hf_v2.dart';
import 'package:simulator_presentation/simulator_presentation.dart';

import 'lab_support.dart';

void main() {
  testWidgets('founder first-half journey records real football time',
      (tester) async {
    await loadReadableFonts();
    final controller = await pumpLab(tester);
    await controller.operatorLoadScenario(ScenarioId.s21MatchReportOps);
    await tester.pump();

    expect(controller.instrument.lifecycle, ResearchMatchLifecycle.matchNotStarted);
    expect(find.text('MATCH READY'), findsWidgets);
    expect(find.byKey(const Key('mobile-kick-off')), findsOneWidget);
    expect(find.text('00:00'), findsNothing);
    expect(tester.widget<FilledButton>(find.byKey(const Key('mobile-goal'))).onPressed,
        isNull);
    expect(controller.instrument.goals, isEmpty);
    await captureLab(tester, 's26a-01-match-ready');

    await tester.tap(find.byKey(const Key('mobile-kick-off')));
    await tester.pump();
    expect(controller.instrument.lifecycle, ResearchMatchLifecycle.firstHalfRunning);
    expect(find.text('FIRST HALF'), findsWidgets);
    expect(find.text('00:00'), findsWidgets);
    expect(controller.instrument.kickOffOriginTrace, mobileUiTraceLabel);
    await captureLab(tester, 's26a-02-kickoff');
    await captureLab(tester, 's26a-03-first-half-zero');

    controller.applyLiveElapsed(const Duration(seconds: 37));
    await tester.pump();
    expect(find.text('00:37'), findsWidgets);
    expect(find.byKey(const Key('watch-clock')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('mobile-clock'))).data,
      tester.widget<Text>(find.byKey(const Key('watch-clock'))).data,
    );
    await captureLab(tester, 's26a-04-running-time');

    await tester.tap(find.byKey(const Key('mobile-goal')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-goal-team-home')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-goal-scorer-p-home-9')));
    await tester.pump();
    expect(find.text('00:37'), findsWidgets);
    await captureLab(tester, 's26a-05-goal-review');
    await tester.tap(find.byKey(const Key('mobile-record-goal')));
    await tester.pump();

    expect(controller.instrument.commitLabel, ResearchCommitPhrases.simulatedSaved);
    expect(controller.watchRuntime.watchState.score.label, '1 – 0');
    expect(controller.instrument.goals.single.matchTimeLabel, '00:37');
    expect(controller.instrument.goals.single.occurrence?.period,
        ResearchOccurrencePeriod.firstHalf);
    expect(find.text('Resolve simulated outcome'), findsNothing);
    await captureLab(tester, 's26a-06-live-score');
    await captureLab(tester, 's26a-07-goal-row');

    controller.applyLiveElapsed(const Duration(seconds: 35));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-yellow')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-yellow-team-away')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-yellow-subject-p-away-6')));
    await tester.pump();
    expect(find.text('01:12'), findsWidgets);
    await captureLab(tester, 's26a-08-yellow-review');
    await tester.tap(find.byKey(const Key('mobile-record-yellow')));
    await tester.pump();

    expect(controller.instrument.cautions.single.matchTimeLabel, '01:12');
    expect(controller.instrument.cautions.single.occurrence?.elapsedSeconds, 72);
    expect(controller.watchRuntime.watchState.score.label, '1 – 0');
    expect(controller.instrument.sendOffs, isEmpty);
    await tester.tap(find.byKey(const Key('mobile-match-report')));
    await tester.pump();
    final labels = controller.watchRuntime.watchState.matchReport.entries
        .map((entry) => entry.matchTimeLabel)
        .toList();
    expect(labels, ['00:37', '01:12']);
    controller.applyLiveElapsed(const Duration(seconds: 48));
    await tester.pump();
    expect(
      controller.watchRuntime.watchState.matchReport.entries
          .map((entry) => entry.matchTimeLabel)
          .toList(),
      ['00:37', '01:12'],
    );
    expect(find.textContaining('00:37 GOAL'), findsWidgets);
    expect(find.textContaining('01:12 YELLOW'), findsWidgets);
    await captureLab(tester, 's26a-09-match-report');
    await selectDevice(tester, 'amazfit-gts4');
    expect(find.text('02:00'), findsWidgets);
    expect(find.textContaining('00:37 GOAL'), findsWidgets);
    expect(find.textContaining('01:12 YELLOW'), findsWidgets);
    await captureLab(tester, 's26a-10-paired-running-time');
  });

  testWidgets('visible clock advances after kick-off without the operator intent',
      (tester) async {
    final controller = await pumpLab(tester);
    controller.forceLiveClockInTest = true;
    try {
      await controller.operatorLoadScenario(ScenarioId.s21MatchReportOps);
      await tester.pump();
      await tester.tap(find.byKey(const Key('mobile-kick-off')));
      await tester.pump();
      expect(find.text('00:00'), findsWidgets);
      await tester.pump(const Duration(seconds: 1));
      expect(controller.instrument.matchElapsedSeconds, 1);
      expect(find.text('00:01'), findsWidgets);
      await tester.pump(const Duration(seconds: 1));
      expect(controller.instrument.matchElapsedSeconds, 2);
      expect(find.text('00:02'), findsWidgets);
      expect(find.text('00:00'), findsNothing);
    } finally {
      controller.stopFootballTicker();
    }
  });

  testWidgets('a second kick-off does not reset the running clock', (tester) async {
    final controller = await pumpLab(tester);
    await controller.operatorLoadScenario(ScenarioId.s21MatchReportOps);
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-kick-off')));
    await tester.pump();
    controller.applyLiveElapsed(const Duration(seconds: 9));
    await tester.pump();
    expect(find.byKey(const Key('mobile-kick-off')), findsNothing);
    expect(controller.instrument.matchElapsedSeconds, 9);
    await controller.dispatchMobile(
      const ArmKickOffIntent(origin: IntentOrigin.mobileUi),
    );
    await controller.dispatchMobile(
      const ConfirmKickOffIntent(origin: IntentOrigin.mobileUi),
    );
    await tester.pump();
    expect(controller.instrument.matchElapsedSeconds, 9);
    expect(controller.instrument.goals, isEmpty);
  });

  testWidgets('watch kick-off starts the clock the mobile surface shows',
      (tester) async {
    final controller = await pumpLab(tester);
    await selectDevice(tester, 'amazfit-gts4');
    await controller.operatorLoadScenario(ScenarioId.s21MatchReportOps);
    await tester.pump();
    final kickOff = find.byKey(const Key('watch-kick-off'));
    await tester.ensureVisible(kickOff);
    await tester.tap(kickOff);
    await tester.pump();
    expect(controller.instrument.lifecycle, ResearchMatchLifecycle.firstHalfRunning);
    expect(controller.instrument.kickOffOriginTrace, watchUiTraceLabel);
    expect(find.text('00:00'), findsWidgets);
    controller.applyLiveElapsed(const Duration(seconds: 4));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('mobile-clock'))).data, '00:04');
    expect(tester.widget<Text>(find.byKey(const Key('watch-clock'))).data, '00:04');
  });
}
