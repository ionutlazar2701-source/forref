import 'package:flutter/material.dart' hide ActivateIntent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hf_v2/hf_v2.dart';
import 'package:simulator_presentation/simulator_presentation.dart';

import 'lab_support.dart';

Future<void> _clock(dynamic controller, WidgetTester tester, int elapsed) async {
  final delta = elapsed - (controller.instrument.matchElapsedSeconds as int);
  if (delta <= 0) return;
  await controller.watchRuntime.dispatch(
    AdvanceMatchClockIntent(delta, origin: IntentOrigin.operatorFixture),
  );
  await tester.pump();
}

void main() {
  testWidgets('mobile Record Yellow establishes without a resolve tap',
      (tester) async {
    await loadReadableFonts();
    final controller = await pumpLab(tester);
    await controller.operatorLoadScenario(ScenarioId.s21MatchReportOps);
    await establishFirstHalf(controller);
    await _clock(controller, tester, 26 * 60 + 3);
    await tester.tap(find.byKey(const Key('mobile-yellow')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-yellow-team-away')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-yellow-subject-p-away-6')));
    await tester.pump();
    await captureLab(tester, 's25r-fix-01-yellow-review');
    await tester.tap(find.byKey(const Key('mobile-record-yellow')));
    await tester.pump();

    expect(controller.instrument.commitLabel, ResearchCommitPhrases.simulatedSaved);
    expect(controller.instrument.cautions, hasLength(1));
    expect(controller.instrument.cautions.single.subjectId, 'p-away-6');
    expect(controller.instrument.cautions.single.matchTimeLabel, '26:03');
    expect(controller.instrument.sendOffs, isEmpty);
    final entry = controller.watchRuntime.watchState.matchReport.entries.single;
    expect(entry.kind, MatchReportEntryKind.yellow);
    expect(entry.participantDisplay, '#6 Ionescu');
    expect(entry.teamLabel, 'Away');
    expect(find.text('Resolve simulated outcome'), findsNothing);
    await captureLab(tester, 's25r-fix-02-yellow-saved');
  });

  testWidgets('second Yellow does not create a send-off', (tester) async {
    final controller = await pumpLab(tester);
    await controller.operatorLoadScenario(ScenarioId.s21MatchReportOps);
    await establishFirstHalf(controller);
    await tester.pump();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const Key('mobile-yellow')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('mobile-yellow-team-away')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('mobile-yellow-subject-p-away-6')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('mobile-record-yellow')));
      await tester.pump();
    }
    expect(controller.instrument.cautions, hasLength(2));
    expect(controller.instrument.sendOffs, isEmpty);
    expect(
      controller.watchRuntime.watchState.matchReport.entries
          .where((entry) => entry.kind == MatchReportEntryKind.yellow),
      hasLength(2),
    );
    expect(
      controller.watchRuntime.watchState.matchReport.entries
          .where((entry) => entry.kind == MatchReportEntryKind.secondCautionSendOff),
      isEmpty,
    );
    await loadReadableFonts();
    await captureLab(tester, 's25r-fix-03-second-yellow-no-sendoff');
  });

  testWidgets('second-caution send-off is a fresh successful record', (tester) async {
    final controller = await pumpLab(tester);
    await controller.operatorLoadScenario(ScenarioId.s21MatchReportOps);
    await establishFirstHalf(controller);
    await tester.pump();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const Key('mobile-yellow')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('mobile-yellow-team-away')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('mobile-yellow-subject-p-away-6')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('mobile-record-yellow')));
      await tester.pump();
    }
    expect(controller.instrument.sendOffs, isEmpty);
    await tester.tap(find.byKey(const Key('mobile-sendoff')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-sendoff-team-away')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-sendoff-subject-p-away-6')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-record-second-sendoff')));
    await tester.pump();
    expect(controller.instrument.commitLabel, ResearchCommitPhrases.simulatedSaved);
    expect(controller.instrument.sendOffs, hasLength(1));
    expect(controller.instrument.sendOffs.single.pathway, SendOffPathwayLabel.secondCaution);
    expect(controller.instrument.cautions, hasLength(2));
    expect(
      controller.watchRuntime.watchState.matchReport.entries
          .where((entry) => entry.kind == MatchReportEntryKind.secondCautionSendOff),
      hasLength(1),
    );
    await loadReadableFonts();
    await captureLab(tester, 's25r-fix-04-second-caution-saved');
  });

  testWidgets('direct send-off records as direct', (tester) async {
    final controller = await pumpLab(tester);
    await controller.operatorLoadScenario(ScenarioId.s21MatchReportOps);
    await establishFirstHalf(controller);
    await _clock(controller, tester, 77 * 60 + 5);
    await tester.tap(find.byKey(const Key('mobile-sendoff')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-sendoff-team-home')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-sendoff-subject-p-home-4')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-record-direct-sendoff')));
    await tester.pump();
    expect(controller.instrument.sendOffs.single.pathway, SendOffPathwayLabel.direct);
    expect(controller.instrument.sendOffs.single.subjectId, 'p-home-4');
    expect(controller.instrument.sendOffs.single.matchTimeLabel, '77:05');
    expect(
      controller.watchRuntime.watchState.matchReport.entries.single.kind,
      MatchReportEntryKind.directSendOff,
    );
    await loadReadableFonts();
    await captureLab(tester, 's25r-fix-05-direct-saved');
  });

  testWidgets('substitution records the frozen pair', (tester) async {
    final controller = await pumpLab(tester);
    await controller.operatorLoadScenario(ScenarioId.s21MatchReportOps);
    await establishFirstHalf(controller);
    await _clock(controller, tester, 44 * 60 + 3);
    await tester.tap(find.byKey(const Key('mobile-substitution')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-sub-team-home')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-sub-out-p-home-9')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-sub-in-p-home-17')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-record-substitution')));
    await tester.pump();
    expect(controller.instrument.substitutions, hasLength(1));
    expect(controller.instrument.substitutions.single.outId, 'p-home-9');
    expect(controller.instrument.substitutions.single.inId, 'p-home-17');
    expect(controller.instrument.substitutions.single.matchTimeLabel, '44:03');
    final entry = controller.watchRuntime.watchState.matchReport.entries.single;
    expect(entry.kind, MatchReportEntryKind.substitution);
    expect(entry.details, contains('#9 Popescu'));
    expect(entry.details, contains('#17 Marin'));
    await loadReadableFonts();
    await captureLab(tester, 's25r-fix-06-substitution-saved');
  });

  testWidgets('home 14 yellow is not away 14', (tester) async {
    final controller = await pumpLab(tester);
    await controller.operatorLoadScenario(ScenarioId.s21MatchReportOps);
    await establishFirstHalf(controller);
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-yellow')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-yellow-team-home')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-yellow-subject-p-home-14')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-record-yellow')));
    await tester.pump();
    expect(controller.instrument.cautions.single.subjectId, 'p-home-14');
  });

  testWidgets('a repeated yellow activation does not duplicate the caution',
      (tester) async {
    final controller = await pumpLab(tester);
    await controller.operatorLoadScenario(ScenarioId.s21MatchReportOps);
    await establishFirstHalf(controller);
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-yellow')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-yellow-team-away')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-yellow-subject-p-away-6')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-record-yellow')));
    await tester.pump();
    await controller.dispatchMobile(
      const ActivateIntent(PresentationAction.yellow, origin: IntentOrigin.mobileUi),
    );
    await tester.pump();
    expect(controller.instrument.cautions, hasLength(1));
  });

  testWidgets('scripted failures stay unresolved until explicit resolve',
      (tester) async {
    final controller = await pumpLab(tester);
    await controller.operatorLoadScenario(ScenarioId.s21MatchReportOps);
    await establishFirstHalf(controller);
    controller.instrument.setScriptedOutcome(
      FinalActionKind.recordYellow,
      SimulatedScriptedOutcome.failure,
    );
    controller.instrument.setScriptedOutcome(
      FinalActionKind.recordDirectSendOff,
      SimulatedScriptedOutcome.failure,
    );
    controller.instrument.setScriptedOutcome(
      FinalActionKind.recordSubstitution,
      SimulatedScriptedOutcome.failure,
    );
    controller.setHold(true);
    await tester.pump();

    await tester.tap(find.byKey(const Key('mobile-yellow')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-yellow-team-away')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-yellow-subject-p-away-6')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-record-yellow')));
    await tester.pump();
    expect(controller.instrument.commitKind, SystemCommitKind.saving);
    expect(controller.instrument.cautions, isEmpty);
    await controller.dispatchMobile(
      const ResolveSimulatedCommitIntent(origin: IntentOrigin.mobileUi),
    );
    await tester.pump();
    expect(controller.instrument.commitLabel, ResearchCommitPhrases.notSaved);
    expect(controller.watchRuntime.watchState.matchReport.entries, isEmpty);

    await tester.ensureVisible(find.byKey(const Key('mobile-sendoff')));
    await tester.tap(find.byKey(const Key('mobile-sendoff')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('mobile-sendoff-team-home')));
    await tester.tap(find.byKey(const Key('mobile-sendoff-team-home')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('mobile-sendoff-subject-p-home-4')));
    await tester.tap(find.byKey(const Key('mobile-sendoff-subject-p-home-4')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('mobile-record-direct-sendoff')));
    await tester.tap(find.byKey(const Key('mobile-record-direct-sendoff')));
    await tester.pump();
    expect(controller.instrument.commitKind, SystemCommitKind.saving);
    expect(controller.instrument.sendOffs, isEmpty);
    await controller.dispatchMobile(
      const ResolveSimulatedCommitIntent(origin: IntentOrigin.mobileUi),
    );
    await tester.pump();
    expect(controller.instrument.commitLabel, ResearchCommitPhrases.notSaved);
    expect(controller.instrument.sendOffs, isEmpty);
    expect(controller.watchRuntime.watchState.matchReport.entries, isEmpty);

    await tester.ensureVisible(find.byKey(const Key('mobile-substitution')));
    await tester.tap(find.byKey(const Key('mobile-substitution')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('mobile-sub-team-home')));
    await tester.tap(find.byKey(const Key('mobile-sub-team-home')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('mobile-sub-out-p-home-9')));
    await tester.tap(find.byKey(const Key('mobile-sub-out-p-home-9')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('mobile-sub-in-p-home-17')));
    await tester.tap(find.byKey(const Key('mobile-sub-in-p-home-17')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('mobile-record-substitution')));
    await tester.tap(find.byKey(const Key('mobile-record-substitution')));
    await tester.pump();
    expect(controller.instrument.commitKind, SystemCommitKind.saving);
    expect(controller.instrument.substitutions, isEmpty);
    await controller.dispatchMobile(
      const ResolveSimulatedCommitIntent(origin: IntentOrigin.mobileUi),
    );
    await tester.pump();
    expect(controller.instrument.commitLabel, ResearchCommitPhrases.notSaved);
    expect(controller.watchRuntime.watchState.matchReport.entries, isEmpty);
  });

  testWidgets('scripted unknown outcomes are not established', (tester) async {
    final controller = await pumpLab(tester);
    await controller.operatorLoadScenario(ScenarioId.s21MatchReportOps);
    await establishFirstHalf(controller);
    controller.instrument.setScriptedOutcome(
      FinalActionKind.recordYellow,
      SimulatedScriptedOutcome.unknown,
    );
    controller.instrument.setScriptedOutcome(
      FinalActionKind.recordDirectSendOff,
      SimulatedScriptedOutcome.unknown,
    );
    controller.instrument.setScriptedOutcome(
      FinalActionKind.recordSubstitution,
      SimulatedScriptedOutcome.unknown,
    );
    controller.setHold(true);
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-yellow')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-yellow-team-home')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-yellow-subject-p-home-9')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-record-yellow')));
    await tester.pump();
    expect(controller.instrument.commitKind, SystemCommitKind.saving);
    await controller.dispatchMobile(
      const ResolveSimulatedCommitIntent(origin: IntentOrigin.mobileUi),
    );
    await tester.pump();
    expect(controller.instrument.commitLabel, ResearchCommitPhrases.saveNotVerified);
    expect(controller.instrument.cautions, isEmpty);
    expect(controller.watchRuntime.watchState.matchReport.entries, isEmpty);
    await controller.dispatchMobile(
      const AcknowledgeUnknownIntent(origin: IntentOrigin.mobileUi),
    );
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('mobile-sendoff')));
    await tester.tap(find.byKey(const Key('mobile-sendoff')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('mobile-sendoff-team-home')));
    await tester.tap(find.byKey(const Key('mobile-sendoff-team-home')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('mobile-sendoff-subject-p-home-4')));
    await tester.tap(find.byKey(const Key('mobile-sendoff-subject-p-home-4')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('mobile-record-direct-sendoff')));
    await tester.tap(find.byKey(const Key('mobile-record-direct-sendoff')));
    await tester.pump();
    expect(controller.instrument.commitKind, SystemCommitKind.saving);
    await controller.dispatchMobile(
      const ResolveSimulatedCommitIntent(origin: IntentOrigin.mobileUi),
    );
    await tester.pump();
    expect(controller.instrument.commitLabel, ResearchCommitPhrases.saveNotVerified);
    expect(controller.instrument.sendOffs, isEmpty);
    await controller.dispatchMobile(
      const AcknowledgeUnknownIntent(origin: IntentOrigin.mobileUi),
    );
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('mobile-substitution')));
    await tester.tap(find.byKey(const Key('mobile-substitution')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('mobile-sub-team-home')));
    await tester.tap(find.byKey(const Key('mobile-sub-team-home')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('mobile-sub-out-p-home-9')));
    await tester.tap(find.byKey(const Key('mobile-sub-out-p-home-9')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('mobile-sub-in-p-home-17')));
    await tester.tap(find.byKey(const Key('mobile-sub-in-p-home-17')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('mobile-record-substitution')));
    await tester.tap(find.byKey(const Key('mobile-record-substitution')));
    await tester.pump();
    expect(controller.instrument.commitKind, SystemCommitKind.saving);
    await controller.dispatchMobile(
      const ResolveSimulatedCommitIntent(origin: IntentOrigin.mobileUi),
    );
    await tester.pump();
    expect(controller.instrument.commitLabel, ResearchCommitPhrases.saveNotVerified);
    expect(controller.instrument.substitutions, isEmpty);
    expect(controller.watchRuntime.watchState.matchReport.entries, isEmpty);
  });

  testWidgets('combined founder journey builds one chronological report',
      (tester) async {
    await loadReadableFonts();
    final controller = await pumpLab(tester);
    await controller.operatorLoadScenario(ScenarioId.s21MatchReportOps);
    await establishFirstHalf(controller);
    await tester.pump();

    Future<void> tapKey(Key key) async {
      final target = find.byKey(key);
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pump();
    }

    Future<void> goal(PresentationTeam team, String id, int elapsed) async {
      await _clock(controller, tester, elapsed);
      await tapKey(const Key('mobile-goal'));
      await tapKey(Key(
        team == PresentationTeam.home
            ? 'mobile-goal-team-home'
            : 'mobile-goal-team-away',
      ));
      await tapKey(Key('mobile-goal-scorer-$id'));
      await tapKey(const Key('mobile-record-goal'));
    }

    Future<void> yellow(int elapsed) async {
      await _clock(controller, tester, elapsed);
      await tapKey(const Key('mobile-yellow'));
      await tapKey(const Key('mobile-yellow-team-away'));
      await tapKey(const Key('mobile-yellow-subject-p-away-6'));
      await tapKey(const Key('mobile-record-yellow'));
    }

    await goal(PresentationTeam.away, 'p-away-11', 12 * 60 + 14);
    expect(controller.watchRuntime.watchState.score.label, '0 – 1');
    await goal(PresentationTeam.home, 'p-home-9', 18 * 60 + 27);
    expect(controller.watchRuntime.watchState.score.label, '1 – 1');
    await yellow(26 * 60 + 3);
    await _clock(controller, tester, 44 * 60 + 3);
    await tapKey(const Key('mobile-substitution'));
    await tapKey(const Key('mobile-sub-team-home'));
    await tapKey(const Key('mobile-sub-out-p-home-9'));
    await tapKey(const Key('mobile-sub-in-p-home-17'));
    await tapKey(const Key('mobile-record-substitution'));
    await yellow(58 * 60 + 11);
    expect(controller.instrument.sendOffs, isEmpty);
    await _clock(controller, tester, 73 * 60 + 12);
    await tapKey(const Key('mobile-sendoff'));
    await tapKey(const Key('mobile-sendoff-team-away'));
    await tapKey(const Key('mobile-sendoff-subject-p-away-6'));
    await tapKey(const Key('mobile-record-second-sendoff'));
    await _clock(controller, tester, 82 * 60 + 33);
    await tapKey(const Key('mobile-sendoff'));
    await tapKey(const Key('mobile-sendoff-team-home'));
    await tapKey(const Key('mobile-sendoff-subject-p-home-4'));
    await tapKey(const Key('mobile-record-direct-sendoff'));

    final kinds = controller.watchRuntime.watchState.matchReport.entries
        .map((entry) => entry.kind)
        .toList();
    expect(kinds, [
      MatchReportEntryKind.goal,
      MatchReportEntryKind.goal,
      MatchReportEntryKind.yellow,
      MatchReportEntryKind.substitution,
      MatchReportEntryKind.yellow,
      MatchReportEntryKind.secondCautionSendOff,
      MatchReportEntryKind.directSendOff,
    ]);
    expect(controller.watchRuntime.watchState.score.label, '1 – 1');
    await tester.tap(find.byKey(const Key('mobile-match-report')));
    await tester.pump();
    expect(find.textContaining('SEND-OFF · DIRECT'), findsWidgets);
    expect(find.textContaining('SEND-OFF · SECOND CAUTION'), findsWidgets);
    expect(find.textContaining('SUBSTITUTION'), findsWidgets);
    await captureLab(tester, 's25r-fix-07-mobile-report');
    await selectDevice(tester, 'amazfit-gts4');
    expect(find.textContaining('SEND-OFF · DIRECT'), findsWidgets);
    expect(controller.watchRuntime.watchState.profileId, 'amazfit-gts4');
    await captureLab(tester, 's25r-fix-08-watch-report');
  });
}
