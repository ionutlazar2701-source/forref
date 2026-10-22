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
    expect(find.text('Capture'), findsOneWidget);

    await tester.tap(find.text('Capture'));
    await tester.pump();
    await tester.tap(find.text('Yellow'));
    await tester.pump();
    final home14 = find.text('home 14 · p-home-14');
    await tester.ensureVisible(home14);
    await tester.tap(home14);
    await tester.pump();
    final record = find.text('Record yellow');
    await tester.ensureVisible(record);
    await tester.tap(record);
    await tester.pump();

    expect(find.textContaining('Frozen yellow p-home-14'), findsOneWidget);
    expect(controller.instrument.snapshot.sendOffs, isEmpty);
    expect(controller.instrument.snapshot.cautions, isEmpty);

    final resolve = find.text('Resolve simulated outcome');
    await tester.ensureVisible(resolve);
    await tester.tap(resolve);
    await tester.pump();
    expect(find.textContaining('SIMULATED SAVED'), findsWidgets);
    expect(controller.instrument.snapshot.cautions, hasLength(1));
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
    expect(controller.instrument.snapshot.inFlight?.subjectId, 'p-home-14');
    expect(controller.instrument.snapshot.sendOffs, isEmpty);
    controller.instrument.setTeam(ResearchTeamSide.away);
    await tester.pump();
    expect(controller.watchRuntime.watchState.frozenCommand?.subjectId,
        'p-home-14');
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
    await tester.tap(find.text('Capture'));
    await tester.pump();
    await tester.tap(find.text('Sending-off'));
    await tester.pump();
    final second = find.text('Record second-caution send-off');
    await tester.ensureVisible(second);
    await tester.tap(second);
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
    await tester.tap(find.text('Capture'));
    await tester.pump();
    await tester.tap(find.text('Yellow'));
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
    await tester.tap(find.text('Capture'));
    await tester.pump();
    await tester.tap(find.text('Substitution'));
    await tester.pump();
    final out = find.text('OUT 9 · p-home-9');
    final inside = find.text('IN 7 · p-home-7');
    await tester.ensureVisible(out);
    await tester.tap(out);
    await tester.pump();
    await tester.ensureVisible(inside);
    await tester.tap(inside);
    await tester.pump();
    final record = find.text('Record substitution');
    await tester.ensureVisible(record);
    await tester.tap(record);
    await tester.pump();
    expect(controller.instrument.snapshot.inFlight?.outId, 'p-home-9');
    expect(controller.instrument.snapshot.inFlight?.inId, 'p-home-7');
    await controller.watchRuntime.dispatch(
      const SelectInIntent('p-home-12', origin: IntentOrigin.operatorFixture),
    );
    await tester.pump();
    expect(controller.watchRuntime.watchState.frozenCommand?.outId, 'p-home-9');
    expect(controller.watchRuntime.watchState.frozenCommand?.inId, 'p-home-7');
    expect(controller.instrument.snapshot.substitutions, isEmpty);
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
        await tester.startGesture(tester.getCenter(find.text('Capture')));
    await selectDevice(tester, 'huawei-watch-gt4-46');
    await gesture.up();
    await tester.pump();
    expect(controller.watchRuntime.watchState.navigation.route,
        WatchRoute.liveCore);
    expect(controller.instrument.snapshot.cautions, isEmpty);
    expect(controller.watchRuntime.watchState.profileId, 'huawei-watch-gt4-46');
  });
}
