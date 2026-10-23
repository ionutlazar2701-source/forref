import 'package:flutter/material.dart' hide ActivateIntent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hf_v2/hf_v2.dart';
import 'package:simulator_presentation/simulator_presentation.dart';

import 'lab_support.dart';

/// Founder Windows path: Record Goal must finish without a second resolve tap.
void main() {
  testWidgets('mobile Record Goal on s21 updates score and match report',
      (tester) async {
    await loadReadableFonts();
    final controller = await pumpLab(tester);
    await controller.operatorLoadScenario(ScenarioId.s21MatchReportOps);
    await establishFirstHalf(controller);
    await controller.watchRuntime.dispatch(
      const AdvanceMatchClockIntent(12 * 60 + 14,
          origin: IntentOrigin.operatorFixture),
    );
    await tester.pump();
    expect(find.text('0 – 0'), findsWidgets);
    await captureLab(tester, 's25g-fix-01-live-0-0');

    await tester.tap(find.byKey(const Key('mobile-goal')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-goal-team-away')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-goal-scorer-p-away-11')));
    await tester.pump();
    expect(find.byKey(const Key('mobile-record-goal')), findsOneWidget);
    await captureLab(tester, 's25g-fix-02-away-goal-ready');

    await tester.tap(find.byKey(const Key('mobile-record-goal')));
    await tester.pump();

    expect(controller.instrument.commitKind, SystemCommitKind.saved);
    expect(
      controller.instrument.commitLabel,
      ResearchCommitPhrases.simulatedSaved,
    );
    expect(controller.instrument.goals, hasLength(1));
    expect(controller.instrument.goals.single.scorerParticipantId, 'p-away-11');
    expect(
      controller.instrument.goals.single.scoringTeam,
      ResearchTeamSide.away,
    );
    expect(controller.instrument.goals.single.matchTimeLabel, '12:14');
    expect(controller.watchRuntime.watchState.score.label, '0 – 1');
    expect(controller.watchRuntime.watchState.matchReport.entries, hasLength(1));
    expect(
      controller.watchRuntime.watchState.matchReport.entries.single.kind,
      MatchReportEntryKind.goal,
    );
    expect(find.text('0 – 1'), findsWidgets);
    expect(find.textContaining('#11 Matei Ionescu'), findsWidgets);
    expect(find.text('Resolve simulated outcome'), findsNothing);
    await captureLab(tester, 's25g-fix-03-live-0-1');

    await controller.watchRuntime.dispatch(
      const AdvanceMatchClockIntent(300, origin: IntentOrigin.operatorFixture),
    );
    await tester.pump();
    expect(controller.instrument.goals.single.matchTimeLabel, '12:14');

    await tester.tap(find.byKey(const Key('mobile-goal')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-goal-team-home')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-goal-scorer-p-home-9')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-record-goal')));
    await tester.pump();

    expect(controller.watchRuntime.watchState.score.label, '1 – 1');
    expect(controller.instrument.goals, hasLength(2));
    expect(controller.watchRuntime.watchState.matchReport.entries, hasLength(2));
    expect(find.text('1 – 1'), findsWidgets);
    await captureLab(tester, 's25g-fix-04-live-1-1');

    await tester.tap(find.byKey(const Key('mobile-match-report')));
    await tester.pump();
    expect(find.byKey(const Key('mobile-match-report-entry-1')), findsOneWidget);
    expect(find.byKey(const Key('mobile-match-report-entry-2')), findsOneWidget);
    await captureLab(tester, 's25g-fix-05-match-report');
  });

  testWidgets('a second Record Goal tap does not add another goal', (tester) async {
    final controller = await pumpLab(tester);
    await controller.operatorLoadScenario(ScenarioId.s21MatchReportOps);
    await establishFirstHalf(controller);
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-goal')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-goal-team-away')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-goal-scorer-p-away-11')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-record-goal')));
    await tester.pump();
    expect(controller.instrument.goals, hasLength(1));
    expect(find.byKey(const Key('mobile-record-goal')), findsNothing);
    await controller.dispatchMobile(
      const ActivateIntent(PresentationAction.goal, origin: IntentOrigin.mobileUi),
    );
    await tester.pump();
    expect(controller.instrument.goals, hasLength(1));
    expect(controller.watchRuntime.watchState.score.awayGoals, 1);
  });

  testWidgets('watch Record Goal on a fitting profile needs no resolve tap',
      (tester) async {
    final controller = await pumpLab(tester);
    await selectDevice(tester, 'amazfit-gts4');
    await controller.operatorLoadScenario(ScenarioId.s21MatchReportOps);
    await establishFirstHalf(controller);
    await tester.pump();
    await tapWatch(tester, 'Capture');
    await tester.pump();
    await tapWatch(tester, 'Goal');
    await tester.pump();
    await tester.tap(find.byKey(const Key('watch-goal-team-away')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('watch-goal-scorer-p-away-11')));
    await tester.tap(find.byKey(const Key('watch-goal-scorer-p-away-11')));
    await tester.pump();
    final record = find.byKey(const Key('watch-record-goal'));
    await tester.ensureVisible(record);
    await tester.tap(record);
    await tester.pump();
    expect(controller.instrument.goals, hasLength(1));
    expect(controller.instrument.commitLabel, ResearchCommitPhrases.simulatedSaved);
    expect(controller.watchRuntime.watchState.score.label, '0 – 1');
    expect(find.text('Resolve simulated outcome'), findsNothing);
  });

  testWidgets('scripted goal failure stays unresolved until explicit resolve',
      (tester) async {
    final controller = await pumpLab(tester);
    await controller.operatorLoadScenario(ScenarioId.s21MatchReportOps);
    await establishFirstHalf(controller);
    controller.instrument.setScriptedOutcome(
      FinalActionKind.recordGoal,
      SimulatedScriptedOutcome.failure,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-goal')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-goal-team-away')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-goal-scorer-p-away-11')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-record-goal')));
    await tester.pump();
    expect(controller.instrument.commitKind, SystemCommitKind.saving);
    expect(controller.instrument.goals, isEmpty);
    expect(controller.watchRuntime.watchState.score.label, '0 – 0');
    expect(controller.watchRuntime.watchState.matchReport.entries, isEmpty);

    await controller.dispatchMobile(
      const ResolveSimulatedCommitIntent(origin: IntentOrigin.mobileUi),
    );
    await tester.pump();
    expect(controller.instrument.commitLabel, ResearchCommitPhrases.notSaved);
    expect(controller.instrument.goals, isEmpty);
    expect(controller.watchRuntime.watchState.matchReport.entries, isEmpty);
  });

  testWidgets('scripted unknown goal is not established', (tester) async {
    final controller = await pumpLab(tester);
    await controller.operatorLoadScenario(ScenarioId.s21MatchReportOps);
    await establishFirstHalf(controller);
    controller.instrument.setScriptedOutcome(
      FinalActionKind.recordGoal,
      SimulatedScriptedOutcome.unknown,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-goal')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-goal-team-home')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-goal-scorer-p-home-9')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-record-goal')));
    await tester.pump();
    expect(controller.instrument.commitKind, SystemCommitKind.saving);
    expect(controller.instrument.goals, isEmpty);
    await controller.dispatchWatch(
      const ResolveSimulatedCommitIntent(origin: IntentOrigin.operatorFixture),
    );
    await tester.pump();
    expect(
      controller.instrument.commitLabel,
      ResearchCommitPhrases.saveNotVerified,
    );
    expect(controller.instrument.goals, isEmpty);
    expect(controller.watchRuntime.watchState.score.homeGoals, 0);
    expect(controller.watchRuntime.watchState.matchReport.entries, isEmpty);
  });
}
