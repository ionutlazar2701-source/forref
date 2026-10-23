import 'package:flutter/material.dart' hide ActivateIntent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hf_prototype/research_app.dart';
import 'package:hf_v2/hf_v2.dart';
import 'package:simulator_presentation/simulator_presentation.dart';
import 'package:watch_reference_ui/watch_reference_ui.dart';

import 'lab_support.dart';

void main() {
  testWidgets('the watch reference app runs inside the selected shell',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final controller = ResearchController();
    await tester.pumpWidget(ResearchApp(controller: controller));
    await selectDevice(tester, 'amazfit-gts4');
    expect(find.text('DIAGNOSTIC VIEWPORT'), findsNothing);
    expect(find.byType(WatchReferenceApp), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(WatchReferenceApp),
        matching: find.text('Capture'),
      ),
      findsOneWidget,
    );

    await tapWatch(tester, 'Capture');
    await tester.pump();
    await tapWatch(tester, 'Yellow');
    await tester.pump();
    await syncWatchYellowFlow(controller);
    await tester.pump();
    await controller.dispatchWatch(
      const SelectParticipantIntent('p-home-14', origin: IntentOrigin.watchUi),
    );
    await tester.pump();
    controller.focusLost();
    await tester.pump();
    await controller.dispatchWatch(
      const ActivateIntent(PresentationAction.yellow,
          origin: IntentOrigin.watchUi),
    );
    await tester.pump();

    expect(controller.instrument.cautions.single.subjectId, 'p-home-14');
    expect(controller.instrument.snapshot.sendOffs, isEmpty);
    expect(controller.instrument.snapshot.cautions, hasLength(1));
    expect(find.textContaining('SIMULATED SAVED'), findsWidgets);
    expect(controller.instrument.snapshot.sendOffs, isEmpty);
    expect(find.textContaining('ACTUAL WATCH UI INTERACTION'), findsWidgets);

    await selectDevice(tester, 'apple-watch-series9-45');
    expect(controller.instrument.snapshot.cautions, hasLength(1));
    expect(
        controller.watchRuntime.watchState.profileId, 'apple-watch-series9-45');
    expect(find.byType(WatchReferenceApp), findsOneWidget);
  });

  testWidgets('operator fixture yellow is labeled separately from the watch ui',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final controller = ResearchController();
    await tester.pumpWidget(ResearchApp(controller: controller));
    await selectDevice(tester, 'huawei-watch-gt4-46');
    await openWorkspace(tester, LabWorkspace.commandLab);
    await tester.tap(find.text('Operator fixture: yellow Home 14'));
    await tester.pump();
    final trace =
        tester.widget<Text>(find.byKey(const Key('intent-origin-trace')));
    expect(trace.data, contains('OPERATOR FIXTURE ACTION'));
    expect(trace.data, isNot(contains('ACTUAL WATCH UI INTERACTION')));
    expect(controller.watchRuntime.intentTrace.last.origin,
        IntentOrigin.operatorFixture);
    expect(controller.instrument.cautions.single.subjectId, 'p-home-14');
    expect(controller.instrument.snapshot.inFlight, isNull);
    expect(controller.instrument.snapshot.sendOffs, isEmpty);
    controller.instrument.setTeam(ResearchTeamSide.away);
    await tester.pump();
    expect(controller.instrument.cautions.single.subjectId, 'p-home-14');
  });

  testWidgets(
      'second-caution send-off from the watch does not fire before a successor',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final controller = ResearchController();
    await tester.pumpWidget(ResearchApp(controller: controller));
    await selectDevice(tester, 'amazfit-gts4');
    await controller.dispatchWatch(
      const OpenRouteIntent(WatchRoute.sendOffFlow,
          origin: IntentOrigin.watchUi),
    );
    await tester.pump();
    controller.focusLost();
    await controller.dispatchWatch(
      const ActivateIntent(PresentationAction.secondCautionSendOff,
          origin: IntentOrigin.watchUi),
    );
    await tester.pump();
    expect(controller.instrument.snapshot.sendOffs, isEmpty);
    expect(controller.instrument.snapshot.inFlight, isNull);
  });

  testWidgets('focus loss during the yellow press does not record it',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final controller = ResearchController();
    await tester.pumpWidget(ResearchApp(controller: controller));
    await selectDevice(tester, 'garmin-approach-s60');
    await tapWatch(tester, 'Capture');
    await tester.pump();
    await tapWatch(tester, 'Yellow');
    await tester.pump();
    final record = find.text('Record yellow');
    await tester.ensureVisible(record);
    final gesture = await tester.startGesture(tester.getCenter(record));
    controller.focusLost();
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(controller.instrument.snapshot.cautions, isEmpty);
    expect(controller.instrument.snapshot.inFlight, isNull);
  });

  testWidgets('a frozen substitution pair does not follow a later in-selection',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final controller = ResearchController();
    await tester.pumpWidget(ResearchApp(controller: controller));
    await selectDevice(tester, 'amazfit-gts4');
    await tapWatch(tester, 'Capture');
    await tester.pump();
    await controller.dispatchWatch(
      const OpenRouteIntent(WatchRoute.substitutionFlow,
          origin: IntentOrigin.watchUi),
    );
    await tester.pump();
    await controller.dispatchWatch(
      const SetTeamIntent(PresentationTeam.home, origin: IntentOrigin.watchUi),
    );
    await tester.pump();
    await controller.dispatchWatch(
      const SelectOutIntent('p-home-9', origin: IntentOrigin.watchUi),
    );
    await tester.pump();
    await controller.dispatchWatch(
      const SelectInIntent('p-home-7', origin: IntentOrigin.watchUi),
    );
    await tester.pump();
    controller.focusLost();
    await controller.dispatchWatch(
      const ActivateIntent(PresentationAction.substitution,
          origin: IntentOrigin.watchUi),
    );
    await tester.pump();
    expect(controller.instrument.substitutions.single.outId, 'p-home-9');
    expect(controller.instrument.substitutions.single.inId, 'p-home-7');
    await controller.watchRuntime.dispatch(
      const SelectInIntent('p-home-12', origin: IntentOrigin.operatorFixture),
    );
    await tester.pump();
    expect(controller.instrument.substitutions.single.outId, 'p-home-9');
    expect(controller.instrument.substitutions.single.inId, 'p-home-7');
    expect(controller.watchRuntime.watchState.frozenCommand, isNull);
  });

  testWidgets('a device change during a press does not commit', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final controller = ResearchController();
    await tester.pumpWidget(ResearchApp(controller: controller));
    await selectDevice(tester, 'amazfit-gts4');
    final gesture =
        await tester.startGesture(
          tester.getCenter(
            find.descendant(
              of: find.byType(WatchReferenceApp),
              matching: find.text('Capture'),
            ),
          ),
        );
    await selectDevice(tester, 'huawei-watch-gt4-46');
    await gesture.up();
    await tester.pump();
    expect(controller.watchRuntime.watchState.navigation.route,
        WatchRoute.liveCore);
    expect(controller.instrument.snapshot.cautions, isEmpty);
    expect(controller.watchRuntime.watchState.profileId, 'huawei-watch-gt4-46');
  });
}
