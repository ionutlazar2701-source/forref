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

Future<HfPresentationRuntime> _opsRuntime({
  ScenarioId scenario = ScenarioId.s21MatchReportOps,
}) async {
  final instrument = ResearchInstrument();
  final runtime = HfPresentationRuntime(instrument: instrument);
  runtime.bindMatchLabels(home: 'HOME', away: 'AWAY');
  await runtime.dispatch(
    LoadScenarioIntent(scenario.name, origin: IntentOrigin.operatorFixture),
  );
  if (runtime.instrument.lifecycle == ResearchMatchLifecycle.matchNotStarted) {
    await runtime.dispatch(
      const ArmKickOffIntent(origin: IntentOrigin.operatorFixture),
    );
    await runtime.dispatch(
      const ConfirmKickOffIntent(origin: IntentOrigin.operatorFixture),
    );
  }
  return runtime;
}

Future<void> _setClock(
  HfPresentationRuntime runtime,
  int targetElapsedSeconds,
) async {
  final delta = targetElapsedSeconds - runtime.instrument.matchElapsedSeconds;
  if (delta <= 0) return;
  await runtime.dispatch(
    AdvanceMatchClockIntent(delta, origin: IntentOrigin.operatorFixture),
  );
}

Future<void> _recordYellow(
  HfPresentationRuntime runtime, {
  required PresentationTeam team,
  required String subjectId,
  required int clockSeconds,
  required IntentOrigin origin,
  bool resolve = true,
}) async {
  await runtime.dispatch(OfferYellowIntent(origin: origin));
  await runtime.dispatch(SetTeamIntent(team, origin: origin));
  await _setClock(runtime, clockSeconds);
  await runtime.dispatch(SelectParticipantIntent(subjectId, origin: origin));
  await runtime.dispatch(
    ActivateIntent(PresentationAction.yellow, origin: origin),
  );
  if (resolve) {
    await runtime.dispatch(ResolveSimulatedCommitIntent(origin: origin));
  }
}

Future<void> _recordDirectSendOff(
  HfPresentationRuntime runtime, {
  required PresentationTeam team,
  required String subjectId,
  required int clockSeconds,
  required IntentOrigin origin,
  bool resolve = true,
}) async {
  await runtime.dispatch(
    const OpenRouteIntent(WatchRoute.sendOffFlow, origin: IntentOrigin.watchUi),
  );
  await runtime.dispatch(SetTeamIntent(team, origin: origin));
  await runtime.dispatch(OfferDirectSendOffIntent(origin: origin));
  await _setClock(runtime, clockSeconds);
  await runtime.dispatch(SelectParticipantIntent(subjectId, origin: origin));
  await runtime.dispatch(
    ActivateIntent(PresentationAction.directSendOff, origin: origin),
  );
  if (resolve) {
    await runtime.dispatch(ResolveSimulatedCommitIntent(origin: origin));
  }
}

Future<void> _recordSecondCautionSendOff(
  HfPresentationRuntime runtime, {
  required PresentationTeam team,
  required String subjectId,
  required int clockSeconds,
  required IntentOrigin origin,
  bool resolve = true,
}) async {
  await runtime.dispatch(
    const OpenRouteIntent(WatchRoute.sendOffFlow, origin: IntentOrigin.watchUi),
  );
  await runtime.dispatch(SetTeamIntent(team, origin: origin));
  await _setClock(runtime, clockSeconds);
  await runtime.dispatch(SelectParticipantIntent(subjectId, origin: origin));
  await runtime.dispatch(
    ActivateIntent(
      PresentationAction.secondCautionSendOff,
      origin: origin,
    ),
  );
  if (resolve) {
    await runtime.dispatch(ResolveSimulatedCommitIntent(origin: origin));
  }
}

Future<void> _recordSubstitution(
  HfPresentationRuntime runtime, {
  required PresentationTeam team,
  required String outId,
  required String inId,
  required int clockSeconds,
  required IntentOrigin origin,
  bool resolve = true,
}) async {
  await runtime.dispatch(
    const OpenRouteIntent(
      WatchRoute.substitutionFlow,
      origin: IntentOrigin.watchUi,
    ),
  );
  await runtime.dispatch(SetTeamIntent(team, origin: origin));
  await _setClock(runtime, clockSeconds);
  await runtime.dispatch(SelectOutIntent(outId, origin: origin));
  await runtime.dispatch(SelectInIntent(inId, origin: origin));
  await runtime.dispatch(
    ActivateIntent(PresentationAction.substitution, origin: origin),
  );
  if (resolve) {
    await runtime.dispatch(ResolveSimulatedCommitIntent(origin: origin));
  }
}

void main() {
  group('yellow match report', () {
    test('Y1 participant known-none success', () async {
      final runtime = await _opsRuntime();
      await _recordYellow(
        runtime,
        team: PresentationTeam.away,
        subjectId: 'p-away-6',
        clockSeconds: 31 * 60 + 14,
        origin: IntentOrigin.watchUi,
      );
      final entry = runtime.watchState.matchReport.entries.single;
      expect(entry.kind, MatchReportEntryKind.yellow);
      expect(entry.matchTimeLabel, '31:14');
      expect(entry.participantDisplay, '#6 Ionescu');
    });

    test('Y2 standing prior caution', () async {
      final runtime = HfPresentationRuntime(
        instrument: ResearchInstrument()..loadScenario(ScenarioId.s02YellowOnePrior),
      );
      runtime.bindMatchLabels(home: 'HOME', away: 'AWAY');
      await _recordYellow(
        runtime,
        team: PresentationTeam.home,
        subjectId: 'p-home-9',
        clockSeconds: 600,
        origin: IntentOrigin.watchUi,
      );
      expect(runtime.instrument.cautions, hasLength(2));
      expect(runtime.watchState.discipline.awareness,
          PriorAwareness.knownStanding);
    });

    test('Y3 second yellow does not auto send-off', () async {
      final runtime = await _opsRuntime();
      await _recordYellow(
        runtime,
        team: PresentationTeam.away,
        subjectId: 'p-away-6',
        clockSeconds: 100,
        origin: IntentOrigin.watchUi,
      );
      await _recordYellow(
        runtime,
        team: PresentationTeam.away,
        subjectId: 'p-away-6',
        clockSeconds: 200,
        origin: IntentOrigin.watchUi,
      );
      expect(runtime.instrument.sendOffs, isEmpty);
      expect(runtime.instrument.successorEstablished, isTrue);
      expect(
        runtime.watchState.matchReport.entries
            .where((e) => e.kind == MatchReportEntryKind.yellow),
        hasLength(2),
      );
    });

    test('Y4 separate second-caution send-off after two yellows', () async {
      final runtime = await _opsRuntime();
      await _recordYellow(
        runtime,
        team: PresentationTeam.away,
        subjectId: 'p-away-6',
        clockSeconds: 58 * 60 + 11,
        origin: IntentOrigin.watchUi,
      );
      await _recordYellow(
        runtime,
        team: PresentationTeam.away,
        subjectId: 'p-away-6',
        clockSeconds: 73 * 60 + 4,
        origin: IntentOrigin.watchUi,
      );
      await _recordSecondCautionSendOff(
        runtime,
        team: PresentationTeam.away,
        subjectId: 'p-away-6',
        clockSeconds: 73 * 60 + 12,
        origin: IntentOrigin.watchUi,
      );
      expect(runtime.instrument.sendOffs.single.pathway,
          SendOffPathwayLabel.secondCaution);
      final kinds = runtime.watchState.matchReport.entries
          .map((e) => e.kind)
          .toList();
      expect(kinds, contains(MatchReportEntryKind.secondCautionSendOff));
      expect(
        kinds.where((k) => k == MatchReportEntryKind.yellow).length,
        2,
      );
    });

    test('Y5 prior unavailable', () async {
      final runtime = HfPresentationRuntime(
        instrument: ResearchInstrument()
          ..loadScenario(ScenarioId.s03YellowPriorUnavailable),
      );
      runtime.bindMatchLabels(home: 'HOME', away: 'AWAY');
      expect(runtime.watchState.discipline.awareness,
          PriorAwareness.unavailable);
      await _recordYellow(
        runtime,
        team: PresentationTeam.home,
        subjectId: 'p-home-9',
        clockSeconds: 120,
        origin: IntentOrigin.watchUi,
      );
      expect(runtime.watchState.matchReport.entries, hasLength(1));
    });

    test('Y6 prior conflicted', () async {
      final runtime = HfPresentationRuntime(
        instrument: ResearchInstrument()
          ..loadScenario(ScenarioId.s04YellowPriorConflicted),
      );
      runtime.bindMatchLabels(home: 'HOME', away: 'AWAY');
      expect(
        runtime.watchState.discipline.awareness,
        PriorAwareness.conflicted,
      );
    });

    test('Y7 home 14 distinct from away 14', () async {
      final runtime = await _opsRuntime();
      await _recordYellow(
        runtime,
        team: PresentationTeam.home,
        subjectId: 'p-home-14',
        clockSeconds: 90,
        origin: IntentOrigin.watchUi,
      );
      expect(runtime.instrument.cautions.single.subjectId, 'p-home-14');
    });

    test('Y8 official yellow when supported', () async {
      final runtime = HfPresentationRuntime(
        instrument: ResearchInstrument()
          ..loadScenario(ScenarioId.s10SimilarOfficials),
      );
      runtime.bindMatchLabels(home: 'HOME', away: 'AWAY');
      await runtime.dispatch(
        const OfferYellowIntent(origin: IntentOrigin.watchUi),
      );
      await runtime.dispatch(
        const SetTeamIntent(PresentationTeam.home, origin: IntentOrigin.watchUi),
      );
      await _setClock(runtime, 300);
      final officialId = runtime.instrument.officials.first.id;
      await runtime.dispatch(
        SelectOfficialIntent(officialId, origin: IntentOrigin.watchUi),
      );
      await runtime.dispatch(
        const ActivateIntent(
          PresentationAction.yellow,
          origin: IntentOrigin.watchUi,
        ),
      );
      await runtime.dispatch(
        const ResolveSimulatedCommitIntent(origin: IntentOrigin.watchUi),
      );
      expect(runtime.instrument.cautions.single.kind, SubjectKind.official);
      expect(runtime.watchState.matchReport.entries, hasLength(1));
    });

    test('Y9 known failure no report entry', () async {
      final runtime = await _opsRuntime();
      runtime.instrument.setScriptedOutcome(
        FinalActionKind.recordYellow,
        SimulatedScriptedOutcome.failure,
      );
      await _recordYellow(
        runtime,
        team: PresentationTeam.away,
        subjectId: 'p-away-6',
        clockSeconds: 60,
        origin: IntentOrigin.watchUi,
      );
      expect(runtime.watchState.matchReport.entries, isEmpty);
    });

    test('Y10 unknown no established yellow in report', () async {
      final runtime = await _opsRuntime();
      runtime.instrument.setScriptedOutcome(
        FinalActionKind.recordYellow,
        SimulatedScriptedOutcome.unknown,
      );
      await _recordYellow(
        runtime,
        team: PresentationTeam.away,
        subjectId: 'p-away-6',
        clockSeconds: 60,
        origin: IntentOrigin.watchUi,
      );
      expect(runtime.watchState.matchReport.entries, isEmpty);
    });

    test('Y11 time freezes at activation', () async {
      final runtime = await _opsRuntime();
      await runtime.dispatch(
        const OfferYellowIntent(origin: IntentOrigin.watchUi),
      );
      await runtime.dispatch(
        const SetTeamIntent(PresentationTeam.away, origin: IntentOrigin.watchUi),
      );
      await _setClock(runtime, 31 * 60 + 14);
      await runtime.dispatch(
        const SelectParticipantIntent('p-away-6',
            origin: IntentOrigin.watchUi),
      );
      await runtime.dispatch(
        const ActivateIntent(
          PresentationAction.yellow,
          origin: IntentOrigin.watchUi,
        ),
      );
      await _setClock(runtime, 9999);
      await runtime.dispatch(
        const ResolveSimulatedCommitIntent(origin: IntentOrigin.watchUi),
      );
      expect(runtime.instrument.cautions.single.matchTimeLabel, '31:14');
    });

    test('Y12 subject retarget after activation does not alter frozen yellow',
        () async {
      final runtime = await _opsRuntime();
      await runtime.dispatch(
        const OfferYellowIntent(origin: IntentOrigin.watchUi),
      );
      await runtime.dispatch(
        const SetTeamIntent(PresentationTeam.home, origin: IntentOrigin.watchUi),
      );
      await runtime.dispatch(
        const SelectParticipantIntent('p-home-9', origin: IntentOrigin.watchUi),
      );
      await runtime.dispatch(
        const ActivateIntent(
          PresentationAction.yellow,
          origin: IntentOrigin.watchUi,
        ),
      );
      await runtime.dispatch(
        const SelectParticipantIntent('p-home-14',
            origin: IntentOrigin.watchUi),
      );
      await runtime.dispatch(
        const ResolveSimulatedCommitIntent(origin: IntentOrigin.watchUi),
      );
      expect(runtime.instrument.cautions.single.subjectId, 'p-home-9');
    });
  });

  group('direct send-off match report', () {
    test('R1 happy path', () async {
      final runtime = await _opsRuntime();
      await _recordDirectSendOff(
        runtime,
        team: PresentationTeam.home,
        subjectId: 'p-home-4',
        clockSeconds: 77 * 60 + 5,
        origin: IntentOrigin.watchUi,
      );
      final entry = runtime.watchState.matchReport.entries.single;
      expect(entry.kind, MatchReportEntryKind.directSendOff);
      expect(entry.matchTimeLabel, '77:05');
    });

    test('R2 frozen subject', () async {
      final runtime = await _opsRuntime();
      await runtime.dispatch(
        const OpenRouteIntent(WatchRoute.sendOffFlow,
            origin: IntentOrigin.watchUi),
      );
      await runtime.dispatch(
        const SetTeamIntent(PresentationTeam.home, origin: IntentOrigin.watchUi),
      );
      await runtime.dispatch(
        const OfferDirectSendOffIntent(origin: IntentOrigin.watchUi),
      );
      await runtime.dispatch(
        const SelectParticipantIntent('p-home-4', origin: IntentOrigin.watchUi),
      );
      await runtime.dispatch(
        const ActivateIntent(
          PresentationAction.directSendOff,
          origin: IntentOrigin.watchUi,
        ),
      );
      expect(runtime.instrument.sendOffs.single.subjectId, 'p-home-4');
      expect(runtime.instrument.snapshot.inFlight, isNull);
    });

    test('R3 team retarget cannot alter frozen result', () async {
      final runtime = await _opsRuntime();
      await runtime.dispatch(
        const OpenRouteIntent(WatchRoute.sendOffFlow,
            origin: IntentOrigin.watchUi),
      );
      await runtime.dispatch(
        const SetTeamIntent(PresentationTeam.home, origin: IntentOrigin.watchUi),
      );
      await runtime.dispatch(
        const OfferDirectSendOffIntent(origin: IntentOrigin.watchUi),
      );
      await runtime.dispatch(
        const SelectParticipantIntent('p-home-4', origin: IntentOrigin.watchUi),
      );
      await runtime.dispatch(
        const ActivateIntent(
          PresentationAction.directSendOff,
          origin: IntentOrigin.watchUi,
        ),
      );
      await runtime.dispatch(
        const SetTeamIntent(PresentationTeam.away, origin: IntentOrigin.watchUi),
      );
      await runtime.dispatch(
        const ResolveSimulatedCommitIntent(origin: IntentOrigin.watchUi),
      );
      expect(runtime.instrument.sendOffs.single.subjectId, 'p-home-4');
    });

    test('R5 match time freezes', () async {
      final runtime = await _opsRuntime();
      await runtime.dispatch(
        const OpenRouteIntent(WatchRoute.sendOffFlow,
            origin: IntentOrigin.watchUi),
      );
      await runtime.dispatch(
        const SetTeamIntent(PresentationTeam.home, origin: IntentOrigin.watchUi),
      );
      await runtime.dispatch(
        const OfferDirectSendOffIntent(origin: IntentOrigin.watchUi),
      );
      await _setClock(runtime, 77 * 60 + 5);
      await runtime.dispatch(
        const SelectParticipantIntent('p-home-4', origin: IntentOrigin.watchUi),
      );
      await runtime.dispatch(
        const ActivateIntent(
          PresentationAction.directSendOff,
          origin: IntentOrigin.watchUi,
        ),
      );
      await _setClock(runtime, 5000);
      await runtime.dispatch(
        const ResolveSimulatedCommitIntent(origin: IntentOrigin.watchUi),
      );
      expect(runtime.instrument.sendOffs.single.matchTimeLabel, '77:05');
    });

    test('R6 known failure no report', () async {
      final runtime = await _opsRuntime();
      runtime.instrument.setScriptedOutcome(
        FinalActionKind.recordDirectSendOff,
        SimulatedScriptedOutcome.failure,
      );
      await _recordDirectSendOff(
        runtime,
        team: PresentationTeam.home,
        subjectId: 'p-home-4',
        clockSeconds: 100,
        origin: IntentOrigin.watchUi,
      );
      expect(runtime.watchState.matchReport.entries, isEmpty);
    });

    test('R8 exactly one report entry on success', () async {
      final runtime = await _opsRuntime();
      await _recordDirectSendOff(
        runtime,
        team: PresentationTeam.home,
        subjectId: 'p-home-4',
        clockSeconds: 100,
        origin: IntentOrigin.watchUi,
      );
      expect(runtime.watchState.matchReport.entries, hasLength(1));
    });
  });

  group('second-caution send-off', () {
    test('S1 two cautions no auto send-off', () async {
      final runtime = await _opsRuntime();
      await _recordYellow(
        runtime,
        team: PresentationTeam.away,
        subjectId: 'p-away-6',
        clockSeconds: 100,
        origin: IntentOrigin.watchUi,
      );
      await _recordYellow(
        runtime,
        team: PresentationTeam.away,
        subjectId: 'p-away-6',
        clockSeconds: 200,
        origin: IntentOrigin.watchUi,
      );
      expect(runtime.instrument.sendOffs, isEmpty);
    });

    test('S5 pathway stored as second caution', () async {
      final runtime = await _opsRuntime();
      await _recordYellow(
        runtime,
        team: PresentationTeam.away,
        subjectId: 'p-away-6',
        clockSeconds: 100,
        origin: IntentOrigin.watchUi,
      );
      await _recordYellow(
        runtime,
        team: PresentationTeam.away,
        subjectId: 'p-away-6',
        clockSeconds: 200,
        origin: IntentOrigin.watchUi,
      );
      await _recordSecondCautionSendOff(
        runtime,
        team: PresentationTeam.away,
        subjectId: 'p-away-6',
        clockSeconds: 210,
        origin: IntentOrigin.watchUi,
      );
      expect(runtime.instrument.sendOffs.single.pathway,
          SendOffPathwayLabel.secondCaution);
    });

    test('S7 send-off failure leaves second yellow intact', () async {
      final runtime = await _opsRuntime();
      await _recordYellow(
        runtime,
        team: PresentationTeam.away,
        subjectId: 'p-away-6',
        clockSeconds: 100,
        origin: IntentOrigin.watchUi,
      );
      await _recordYellow(
        runtime,
        team: PresentationTeam.away,
        subjectId: 'p-away-6',
        clockSeconds: 200,
        origin: IntentOrigin.watchUi,
      );
      runtime.instrument.setScriptedOutcome(
        FinalActionKind.recordSecondCautionSendOff,
        SimulatedScriptedOutcome.failure,
      );
      await _recordSecondCautionSendOff(
        runtime,
        team: PresentationTeam.away,
        subjectId: 'p-away-6',
        clockSeconds: 210,
        origin: IntentOrigin.watchUi,
      );
      expect(runtime.instrument.cautions, hasLength(2));
      expect(runtime.instrument.sendOffs, isEmpty);
    });
  });

  group('substitution match report', () {
    test('SUB1 home out/in happy path', () async {
      final runtime = await _opsRuntime();
      await _recordSubstitution(
        runtime,
        team: PresentationTeam.home,
        outId: 'p-home-9',
        inId: 'p-home-17',
        clockSeconds: 44 * 60 + 3,
        origin: IntentOrigin.watchUi,
      );
      final entry = runtime.watchState.matchReport.entries.single;
      expect(entry.kind, MatchReportEntryKind.substitution);
      expect(entry.matchTimeLabel, '44:03');
      expect(entry.details, contains('Popescu'));
      expect(entry.details, contains('Marin'));
    });

    test('SUB5 out equals in rejected', () async {
      final runtime = await _opsRuntime();
      await runtime.dispatch(
        const OpenRouteIntent(WatchRoute.substitutionFlow,
            origin: IntentOrigin.watchUi),
      );
      await runtime.dispatch(
        const SetTeamIntent(PresentationTeam.home, origin: IntentOrigin.watchUi),
      );
      await runtime.dispatch(
        const SelectOutIntent('p-home-9', origin: IntentOrigin.watchUi),
      );
      await runtime.dispatch(
        const SelectInIntent('p-home-9', origin: IntentOrigin.watchUi),
      );
      expect(runtime.instrument.substitutionStage, isNot(SubstitutionStage.review));
    });

    test('SUB8 match time freezes', () async {
      final runtime = await _opsRuntime();
      await runtime.dispatch(
        const OpenRouteIntent(WatchRoute.substitutionFlow,
            origin: IntentOrigin.watchUi),
      );
      await runtime.dispatch(
        const SetTeamIntent(PresentationTeam.home, origin: IntentOrigin.watchUi),
      );
      await _setClock(runtime, 44 * 60 + 3);
      await runtime.dispatch(
        const SelectOutIntent('p-home-9', origin: IntentOrigin.watchUi),
      );
      await runtime.dispatch(
        const SelectInIntent('p-home-17', origin: IntentOrigin.watchUi),
      );
      await runtime.dispatch(
        const ActivateIntent(
          PresentationAction.substitution,
          origin: IntentOrigin.watchUi,
        ),
      );
      await _setClock(runtime, 9999);
      await runtime.dispatch(
        const ResolveSimulatedCommitIntent(origin: IntentOrigin.watchUi),
      );
      expect(runtime.instrument.substitutions.single.matchTimeLabel, '44:03');
    });

    test('SUB9 known failure no report', () async {
      final runtime = await _opsRuntime();
      runtime.instrument.setScriptedOutcome(
        FinalActionKind.recordSubstitution,
        SimulatedScriptedOutcome.failure,
      );
      await _recordSubstitution(
        runtime,
        team: PresentationTeam.home,
        outId: 'p-home-9',
        inId: 'p-home-17',
        clockSeconds: 100,
        origin: IntentOrigin.watchUi,
      );
      expect(runtime.watchState.matchReport.entries, isEmpty);
    });
  });

  test('combined chronological match report integration', () async {
    final runtime = await _opsRuntime();
    await _recordGoal(
      runtime,
      team: PresentationTeam.home,
      scorerId: 'p-home-9',
      clockSeconds: 12 * 60 + 14,
      origin: IntentOrigin.watchUi,
    );
    await _recordYellow(
      runtime,
      team: PresentationTeam.away,
      subjectId: 'p-away-6',
      clockSeconds: 26 * 60 + 3,
      origin: IntentOrigin.watchUi,
    );
    await _recordSubstitution(
      runtime,
      team: PresentationTeam.home,
      outId: 'p-home-9',
      inId: 'p-home-17',
      clockSeconds: 42 * 60 + 50,
      origin: IntentOrigin.watchUi,
    );
    await _recordYellow(
      runtime,
      team: PresentationTeam.away,
      subjectId: 'p-away-6',
      clockSeconds: 58 * 60 + 11,
      origin: IntentOrigin.watchUi,
    );
    await _recordYellow(
      runtime,
      team: PresentationTeam.away,
      subjectId: 'p-away-6',
      clockSeconds: 73 * 60 + 4,
      origin: IntentOrigin.watchUi,
    );
    await _recordSecondCautionSendOff(
      runtime,
      team: PresentationTeam.away,
      subjectId: 'p-away-6',
      clockSeconds: 73 * 60 + 12,
      origin: IntentOrigin.watchUi,
    );
    await _recordDirectSendOff(
      runtime,
      team: PresentationTeam.home,
      subjectId: 'p-home-4',
      clockSeconds: 82 * 60 + 33,
      origin: IntentOrigin.watchUi,
    );
    final entries = runtime.watchState.matchReport.entries;
    expect(entries, hasLength(7));
    expect(runtime.watchState.score.label, '1 – 0');
    expect(entries.first.kind, MatchReportEntryKind.goal);
    expect(entries.last.kind, MatchReportEntryKind.directSendOff);
    for (var i = 1; i < entries.length; i++) {
      expect(entries[i].sequence, greaterThan(entries[i - 1].sequence));
    }
  });

  test('report pollution does not establish entries', () async {
    final runtime = await _opsRuntime();
    await runtime.dispatch(
      const OfferYellowIntent(origin: IntentOrigin.watchUi),
    );
    await runtime.dispatch(
      const SetTeamIntent(PresentationTeam.home, origin: IntentOrigin.watchUi),
    );
    await runtime.dispatch(
      const SelectParticipantIntent('p-home-9', origin: IntentOrigin.watchUi),
    );
    await runtime.dispatch(
      const OpenRouteIntent(WatchRoute.sendOffFlow,
          origin: IntentOrigin.watchUi),
    );
    expect(runtime.watchState.matchReport.entries, isEmpty);
  });

  test('SUB11 mobile sees watch substitution', () async {
    final runtime = await _opsRuntime();
    await _recordSubstitution(
      runtime,
      team: PresentationTeam.home,
      outId: 'p-home-9',
      inId: 'p-home-17',
      clockSeconds: 100,
      origin: IntentOrigin.mobileUi,
    );
    expect(runtime.watchState.matchReport.entries, hasLength(1));
    expect(runtime.intentTrace.last.origin, IntentOrigin.mobileUi);
  });

  testWidgets('founder combined referee journey through watch UI', (tester) async {
    final controller = ResearchController();
    await controller.applyResearchFixture(
      ResearchFixture.defaults.copyWith(
        scenarioId: ScenarioId.s21MatchReportOps,
        homeScore: 0,
        awayScore: 0,
      ),
    );
    await establishFirstHalf(controller);
    await _pumpWatch(tester, controller);

    Future<void> advance(int seconds) async {
      await controller.watchRuntime.dispatch(
        AdvanceMatchClockIntent(seconds, origin: IntentOrigin.operatorFixture),
      );
      await _pumpWatch(tester, controller);
    }

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
    await _pumpWatch(tester, controller);
    await advance(12 * 60 + 14);
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

    await tester.tap(find.text('Capture'));
    await tester.pump();
    await controller.dispatchWatch(
      const OpenRouteIntent(WatchRoute.captureMenu, origin: IntentOrigin.watchUi),
    );
    await _pumpWatch(tester, controller);
    await tapWatch(tester, 'Yellow');
    await tester.pump();
    await controller.dispatchWatch(
      const OfferYellowIntent(origin: IntentOrigin.watchUi),
    );
    await _pumpWatch(tester, controller);
    await tester.tap(find.byKey(const Key('watch-yellow-team-away')));
    await tester.pump();
    await controller.dispatchWatch(
      const SetTeamIntent(PresentationTeam.away, origin: IntentOrigin.watchUi),
    );
    await advance(26 * 60 + 3 - (12 * 60 + 14));
    await tapWatchYellowSubject(tester, 'p-away-6');
    await tester.pump();
    await controller.dispatchWatch(
      const SelectParticipantIntent('p-away-6', origin: IntentOrigin.watchUi),
    );
    await tester.tap(find.byKey(const Key('watch-record-yellow')));
    await tester.pump();
    await controller.dispatchWatch(
      const ActivateIntent(PresentationAction.yellow, origin: IntentOrigin.watchUi),
    );
    await _pumpWatch(tester, controller);

    await tester.tap(find.text('Capture'));
    await tester.pump();
    await controller.dispatchWatch(
      const OpenRouteIntent(WatchRoute.captureMenu, origin: IntentOrigin.watchUi),
    );
    await _pumpWatch(tester, controller);
    await tester.tap(find.byKey(const Key('watch-capture-sub')));
    await tester.pump();
    await controller.dispatchWatch(
      const OpenRouteIntent(WatchRoute.substitutionFlow,
          origin: IntentOrigin.watchUi),
    );
    await _pumpWatch(tester, controller);
    await tester.tap(find.byKey(const Key('watch-sub-team-home')));
    await tester.pump();
    await controller.dispatchWatch(
      const SetTeamIntent(PresentationTeam.home, origin: IntentOrigin.watchUi),
    );
    await advance(42 * 60 + 50 - (26 * 60 + 3));
    await tester.tap(find.byKey(const Key('watch-sub-out-p-home-9')));
    await tester.pump();
    await controller.dispatchWatch(
      const SelectOutIntent('p-home-9', origin: IntentOrigin.watchUi),
    );
    await tester.tap(find.byKey(const Key('watch-sub-in-p-home-17')));
    await tester.pump();
    await controller.dispatchWatch(
      const SelectInIntent('p-home-17', origin: IntentOrigin.watchUi),
    );
    await tester.tap(find.byKey(const Key('watch-record-substitution')));
    await tester.pump();
    await controller.dispatchWatch(
      const ActivateIntent(PresentationAction.substitution,
          origin: IntentOrigin.watchUi),
    );
    await _pumpWatch(tester, controller);

    await tester.tap(find.text('Match Report'));
    await tester.pump();
    await controller.dispatchWatch(
      const OpenRouteIntent(WatchRoute.matchReport, origin: IntentOrigin.watchUi),
    );
    await _pumpWatch(tester, controller);
    expect(find.textContaining('GOAL'), findsWidgets);
    expect(find.textContaining('YELLOW'), findsWidgets);
    expect(find.textContaining('SUBSTITUTION'), findsWidgets);
    expect(controller.watchRuntime.watchState.matchReport.entries.length,
        greaterThanOrEqualTo(3));
  });
}
