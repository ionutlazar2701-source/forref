import 'package:flutter/material.dart' hide ActivateIntent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hf_prototype/research_app.dart';
import 'package:hf_v2/hf_v2.dart';
import 'package:simulator_hf_bridge/simulator_hf_bridge.dart';
import 'package:simulator_presentation/simulator_presentation.dart';
import 'package:watch_reference_ui/watch_reference_ui.dart';

import 'lab_support.dart';

Future<void> _pumpWatch(
  WidgetTester tester,
  ResearchController controller,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SizedBox(
        width: 320,
        height: 480,
        child: WatchReferenceApp(
          state: controller.watchRuntime.watchState,
          onIntent: controller.dispatchWatch,
          inputEpoch: controller.inputEpoch,
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<HfPresentationRuntime> _goalRuntime() async {
  final instrument = ResearchInstrument();
  final runtime = HfPresentationRuntime(instrument: instrument);
  runtime.bindMatchLabels(home: 'Home', away: 'Away');
  await runtime.dispatch(
    LoadScenarioIntent(ScenarioId.s20GoalMatchReport.name,
        origin: IntentOrigin.operatorFixture),
  );
  await runtime.dispatch(
    const ArmKickOffIntent(origin: IntentOrigin.operatorFixture),
  );
  await runtime.dispatch(
    const ConfirmKickOffIntent(origin: IntentOrigin.operatorFixture),
  );
  return runtime;
}

Future<void> _recordGoal(
  HfPresentationRuntime runtime, {
  required PresentationTeam team,
  required String scorerId,
  required int clockSeconds,
  required IntentOrigin origin,
}) async {
  await runtime.dispatch(OfferGoalIntent(origin: origin));
  await runtime.dispatch(SetTeamIntent(team, origin: origin));
  await runtime.dispatch(
    AdvanceMatchClockIntent(clockSeconds, origin: IntentOrigin.operatorFixture),
  );
  await runtime.dispatch(SelectParticipantIntent(scorerId, origin: origin));
  await runtime.dispatch(ActivateIntent(PresentationAction.goal, origin: origin));
  await runtime.dispatch(ResolveSimulatedCommitIntent(origin: origin));
}

void main() {
  test('G1 home goal happy path', () async {
    final runtime = await _goalRuntime();
    await _recordGoal(
      runtime,
      team: PresentationTeam.home,
      scorerId: 'p-home-9',
      clockSeconds: 18 * 60 + 27,
      origin: IntentOrigin.watchUi,
    );
    final state = runtime.watchState;
    expect(state.score.homeGoals, 1);
    expect(state.score.awayGoals, 0);
    expect(state.matchReport.entries, hasLength(1));
    expect(state.matchReport.entries.single.participantDisplay, '#9 Popescu');
    expect(state.matchReport.entries.single.matchTimeLabel, '18:27');
  });

  test('G2 away goal after home goal', () async {
    final runtime = await _goalRuntime();
    await _recordGoal(
      runtime,
      team: PresentationTeam.home,
      scorerId: 'p-home-9',
      clockSeconds: 600,
      origin: IntentOrigin.watchUi,
    );
    await _recordGoal(
      runtime,
      team: PresentationTeam.away,
      scorerId: 'p-away-11',
      clockSeconds: 1200,
      origin: IntentOrigin.watchUi,
    );
    expect(runtime.watchState.score.label, '1 – 1');
    expect(runtime.watchState.matchReport.entries, hasLength(2));
    expect(runtime.watchState.matchReport.entries.first.sequence, 1);
    expect(runtime.watchState.matchReport.entries.last.participantDisplay, '#11 Matei Ionescu');
  });

  test('G3 team filter blocks away scorer on home team selection', () async {
    final runtime = await _goalRuntime();
    await runtime.dispatch(const OfferGoalIntent(origin: IntentOrigin.watchUi));
    await runtime.dispatch(
      const SetTeamIntent(PresentationTeam.home, origin: IntentOrigin.watchUi),
    );
    await runtime.dispatch(
      const SelectParticipantIntent('p-away-11', origin: IntentOrigin.watchUi),
    );
    expect(runtime.instrument.selectionKind, SubjectSelectionKind.unresolved);
    expect(runtime.watchState.goalFlow.canRecord, isFalse);
  });

  test('G4 home 14 is distinct from away 14', () async {
    final runtime = await _goalRuntime();
    await _recordGoal(
      runtime,
      team: PresentationTeam.home,
      scorerId: 'p-home-14',
      clockSeconds: 100,
      origin: IntentOrigin.watchUi,
    );
    expect(
      runtime.instrument.goals.single.scorerParticipantId,
      'p-home-14',
    );
  });

  test('G5 frozen match time survives later clock advance before resolve', () async {
    final runtime = await _goalRuntime();
    await runtime.dispatch(const OfferGoalIntent(origin: IntentOrigin.watchUi));
    await runtime.dispatch(
      const SetTeamIntent(PresentationTeam.home, origin: IntentOrigin.watchUi),
    );
    await runtime.dispatch(
      const AdvanceMatchClockIntent(23 * 60 + 41,
          origin: IntentOrigin.operatorFixture),
    );
    await runtime.dispatch(
      const SelectParticipantIntent('p-home-9', origin: IntentOrigin.watchUi),
    );
    await runtime.dispatch(
      const ActivateIntent(PresentationAction.goal, origin: IntentOrigin.watchUi),
    );
    await runtime.dispatch(
      const AdvanceMatchClockIntent(180,
          origin: IntentOrigin.operatorFixture),
    );
    await runtime.dispatch(
      const ResolveSimulatedCommitIntent(origin: IntentOrigin.watchUi),
    );
    expect(runtime.instrument.goals.single.matchTimeLabel, '23:41');
  });

  test('G6 team retarget does not change frozen home goal', () async {
    final runtime = await _goalRuntime();
    await runtime.dispatch(const OfferGoalIntent(origin: IntentOrigin.watchUi));
    await runtime.dispatch(
      const SetTeamIntent(PresentationTeam.home, origin: IntentOrigin.watchUi),
    );
    await runtime.dispatch(
      const SelectParticipantIntent('p-home-9', origin: IntentOrigin.watchUi),
    );
    await runtime.dispatch(
      const ActivateIntent(PresentationAction.goal, origin: IntentOrigin.watchUi),
    );
    await runtime.dispatch(
      const SetTeamIntent(PresentationTeam.away, origin: IntentOrigin.watchUi),
    );
    await runtime.dispatch(
      const ResolveSimulatedCommitIntent(origin: IntentOrigin.watchUi),
    );
    expect(runtime.instrument.goals.single.scoringTeam, ResearchTeamSide.home);
  });

  test('G8 duplicate resolve creates one goal', () async {
    final runtime = await _goalRuntime();
    await runtime.dispatch(const OfferGoalIntent(origin: IntentOrigin.watchUi));
    await runtime.dispatch(
      const SetTeamIntent(PresentationTeam.home, origin: IntentOrigin.watchUi),
    );
    await runtime.dispatch(
      const SelectParticipantIntent('p-home-9', origin: IntentOrigin.watchUi),
    );
    await runtime.dispatch(
      const ActivateIntent(PresentationAction.goal, origin: IntentOrigin.watchUi),
    );
    await runtime.dispatch(
      const ResolveSimulatedCommitIntent(origin: IntentOrigin.watchUi),
    );
    await runtime.dispatch(
      const ResolveSimulatedCommitIntent(origin: IntentOrigin.watchUi),
    );
    expect(runtime.instrument.goals, hasLength(1));
    expect(runtime.watchState.score.homeGoals, 1);
  });

  test('G9 known failure leaves score and report unchanged', () async {
    final runtime = await _goalRuntime();
    runtime.instrument.setScriptedOutcome(
      FinalActionKind.recordGoal,
      SimulatedScriptedOutcome.failure,
    );
    await _recordGoal(
      runtime,
      team: PresentationTeam.home,
      scorerId: 'p-home-9',
      clockSeconds: 60,
      origin: IntentOrigin.watchUi,
    );
    expect(runtime.instrument.goals, isEmpty);
    expect(runtime.watchState.score.homeGoals, 0);
    expect(runtime.watchState.matchReport.entries, isEmpty);
  });

  test('G10 unknown outcome does not establish goal', () async {
    final runtime = await _goalRuntime();
    runtime.instrument.setScriptedOutcome(
      FinalActionKind.recordGoal,
      SimulatedScriptedOutcome.unknown,
    );
    await _recordGoal(
      runtime,
      team: PresentationTeam.home,
      scorerId: 'p-home-9',
      clockSeconds: 60,
      origin: IntentOrigin.watchUi,
    );
    expect(runtime.instrument.goals, isEmpty);
    expect(runtime.watchState.matchReport.entries, isEmpty);
  });

  testWidgets('founder journey live 0-0 through match report', (tester) async {
    final controller = ResearchController();
    await controller.applyResearchFixture(
      ResearchFixture.defaults.copyWith(
        scenarioId: ScenarioId.s20GoalMatchReport,
        homeScore: 0,
        awayScore: 0,
      ),
    );
    await establishFirstHalf(controller);
    await _pumpWatch(tester, controller);
    expect(find.byKey(const Key('watch-score')), findsOneWidget);
    expect(find.text('0 – 0'), findsOneWidget);
    await tester.tap(find.text('Capture'));
    await tester.pump();
    await controller.dispatchWatch(
      const OpenRouteIntent(WatchRoute.captureMenu, origin: IntentOrigin.watchUi),
    );
    await _pumpWatch(tester, controller);
    await tester.tap(find.byKey(const Key('watch-capture-goal')));
    await tester.pump();
    await controller.dispatchWatch(const OfferGoalIntent(origin: IntentOrigin.watchUi));
    await _pumpWatch(tester, controller);
    await tester.tap(find.byKey(const Key('watch-goal-team-home')));
    await tester.pump();
    await controller.dispatchWatch(
      const SetTeamIntent(PresentationTeam.home, origin: IntentOrigin.watchUi),
    );
    await controller.watchRuntime.dispatch(
      const AdvanceMatchClockIntent(90, origin: IntentOrigin.operatorFixture),
    );
    await _pumpWatch(tester, controller);
    await tester.tap(find.byKey(const Key('watch-goal-scorer-p-home-9')));
    await tester.pump();
    await controller.dispatchWatch(
      const SelectParticipantIntent('p-home-9', origin: IntentOrigin.watchUi),
    );
    await _pumpWatch(tester, controller);
    await tester.tap(find.byKey(const Key('watch-record-goal')));
    await tester.pump();
    await controller.dispatchWatch(
      const ActivateIntent(PresentationAction.goal, origin: IntentOrigin.watchUi),
    );
    await _pumpWatch(tester, controller);
    expect(find.text('1 – 0'), findsWidgets);
    await tester.tap(find.text('Match Report'));
    await tester.pump();
    await controller.dispatchWatch(
      const OpenRouteIntent(WatchRoute.matchReport, origin: IntentOrigin.watchUi),
    );
    await _pumpWatch(tester, controller);
    expect(find.byKey(const Key('watch-match-report-entry-1')), findsOneWidget);
    expect(find.textContaining('#9 Popescu'), findsWidgets);
  });

  testWidgets('G11 watch goal visible on mobile score and report', (tester) async {
    final controller = await pumpLab(tester);
    await controller.applyResearchFixture(
      ResearchFixture.defaults.copyWith(scenarioId: ScenarioId.s20GoalMatchReport),
    );
    await establishFirstHalf(controller);
    await tester.pumpAndSettle();
    await controller.dispatchWatch(const OfferGoalIntent(origin: IntentOrigin.watchUi));
    await controller.dispatchWatch(
      const SetTeamIntent(PresentationTeam.home, origin: IntentOrigin.watchUi),
    );
    await controller.dispatchWatch(
      const SelectParticipantIntent('p-home-9', origin: IntentOrigin.watchUi),
    );
    await controller.dispatchWatch(
      const ActivateIntent(PresentationAction.goal, origin: IntentOrigin.watchUi),
    );
    await controller.dispatchWatch(
      const ResolveSimulatedCommitIntent(origin: IntentOrigin.watchUi),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mobile-score')), findsOneWidget);
    expect(find.text('1 – 0'), findsWidgets);
    expect(find.byKey(const Key('mobile-match-report-entry-1')), findsOneWidget);
    expect(controller.paired.lastOrigin?.label, 'WATCH UI');
  });
}
