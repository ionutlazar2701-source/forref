import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hf_prototype/src/device_hero_stage.dart';
import 'package:hf_prototype/src/device_shell_stage.dart';
import 'package:simulator_geometry/simulator_geometry.dart';
import 'package:simulator_presentation/simulator_presentation.dart';
import 'package:watch_reference_ui/watch_reference_ui.dart';

import 'lab_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadReadableFonts);

  testWidgets('lab layout and frame controls do not write a research record',
      (tester) async {
    final controller = await pumpLab(tester);
    await selectDevice(tester, 'huawei-watch-gt4-46');
    final beforeCautions = controller.instrument.cautions.length;
    final beforeGoals = controller.instrument.goals.length;
    final beforeSeconds = controller.instrument.matchElapsedSeconds;
    final beforeRoute = controller.watchRuntime.watchState.navigation.route;

    await tester.tap(find.byKey(const Key('stage-layout-score-side')));
    await tester.pump();
    expect(controller.watchLiveLayout, WatchLiveLayout.scoreSide);
    expect(controller.instrument.cautions, hasLength(beforeCautions));
    expect(controller.instrument.goals, hasLength(beforeGoals));
    expect(controller.instrument.matchElapsedSeconds, beforeSeconds);
    expect(controller.watchRuntime.watchState.navigation.route, beforeRoute);
    expect(watchFaceFor(controller.shellProfile!), WatchFaceShape.round);

    await tester.tap(find.byKey(const Key('stage-layout-centered')));
    await tester.pump();
    await _shot(tester, 'lab-L-A1-round', 'watch-viewport-huawei-watch-gt4-46');

    await tester.tap(find.byKey(const Key('stage-layout-score-side')));
    await tester.pump();
    await _shot(tester, 'lab-L-C1-round', 'watch-viewport-huawei-watch-gt4-46');

    await selectDevice(tester, 'amazfit-gts4');
    expect(watchFaceFor(controller.shellProfile!), WatchFaceShape.rectangular);
    await tester.tap(find.byKey(const Key('stage-layout-centered')));
    await tester.pump();
    await _shot(tester, 'lab-L-A2-rect', 'watch-viewport-amazfit-gts4');
    await tester.tap(find.byKey(const Key('stage-layout-score-side')));
    await tester.pump();
    await _shot(tester, 'lab-L-C2-rect', 'watch-viewport-amazfit-gts4');

    await controller.dispatchWatch(
      const OpenRouteIntent(WatchRoute.captureMenu, origin: IntentOrigin.watchUi),
    );
    await tester.pump();
    expect(controller.instrument.cautions, hasLength(beforeCautions));
    await _shot(tester, 'lab-C-X-rect', 'watch-viewport-amazfit-gts4');
    await selectDevice(tester, 'huawei-watch-gt4-46');
    await _shot(tester, 'lab-C-R-round', 'watch-viewport-huawei-watch-gt4-46');

    await tester.tap(find.byKey(const Key('stage-frame-team')));
    await tester.pump();
    await _shot(tester, 'lab-T-R-round', 'watch-viewport-huawei-watch-gt4-46');
    expect(find.text('No kit color'), findsOneWidget);
    final traceBefore = controller.watchRuntime.intentTrace.length;
    await tester.tap(find.byKey(const Key('watch-team-home')));
    await tester.pump();
    expect(controller.watchDesignFrame, WatchDesignFrame.participant);
    expect(controller.instrument.cautions, hasLength(beforeCautions));
    expect(controller.instrument.goals, hasLength(beforeGoals));
    expect(
      controller.watchRuntime.intentTrace.last.intentName,
      'setTeam:home',
    );
    expect(controller.watchRuntime.intentTrace.length, traceBefore + 1);

    await _shot(tester, 'lab-P-R-round', 'watch-viewport-huawei-watch-gt4-46');
    await selectDevice(tester, 'amazfit-gts4');
    await tester.tap(find.byKey(const Key('stage-frame-team')));
    await tester.pump();
    await _shot(tester, 'lab-T-X-rect', 'watch-viewport-amazfit-gts4');
    await tester.tap(find.byKey(const Key('stage-frame-participant')));
    await tester.pump();
    await _shot(tester, 'lab-P-X-rect', 'watch-viewport-amazfit-gts4');

    await tester.tap(find.byKey(const Key('stage-beyond')));
    await tester.pump();
    expect(controller.watchBeyondNominal, isTrue);
    expect(controller.instrument.matchElapsedSeconds, beforeSeconds);
    await tester.tap(find.byKey(const Key('stage-frame-flow')));
    await tester.pump();
    await controller.dispatchWatch(
      const OpenRouteIntent(WatchRoute.liveCore, origin: IntentOrigin.watchUi),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('stage-language')));
    await tester.pump();
    expect(find.text('AVERTISMENTE'), findsWidgets);

    expect(controller.instrument.cautions, hasLength(beforeCautions));
    expect(controller.instrument.goals, hasLength(beforeGoals));
  });

  testWidgets('the lab shell shows unavailable score and clock without inventing numerals',
      (tester) async {
    final profile = factualProfileById('huawei-watch-gt4-46');
    expect(profile, isNotNull);
    await tester.binding.setSurfaceSize(const Size(480, 640));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 420,
          height: 560,
          child: DeviceShellStage(
            profile: profile!,
            child: RepaintBoundary(
              key: const Key('shell-shot'),
              child: WatchReferenceApp(
                state: WatchPresentationState.empty,
                onIntent: (_) {},
                face: watchFaceFor(profile),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Clock unavailable'), findsOneWidget);
    expect(find.text('Score unavailable'), findsOneWidget);
    expect(find.text('0 – 0'), findsNothing);
    expect(find.text('00:00'), findsNothing);
    await _shot(tester, 'lab-unknown-score-time', 'shell-shot');
  });

  testWidgets(
      'a shell-hosted presentation fixture is labeled outside the face',
      (tester) async {
    final profile = factualProfileById('huawei-watch-gt4-46');
    expect(profile, isNotNull);
    const quiet = DisciplinePresentation(
      awareness: PriorAwareness.knownNone,
      awarenessLabel: 'Known verified absence',
      cautionCount: 0,
      sendOffCount: 0,
      successorEstablished: false,
      yellowOffered: false,
      directSendOffOffered: false,
    );
    WatchPresentationState live({WatchRoute route = WatchRoute.liveCore}) {
      final base = WatchPresentationState.empty;
      return WatchPresentationState(
        scenarioId: 'fixture',
        profileId: 'huawei-watch-gt4-46',
        header: base.header,
        clock: const ClockPresentation(
          available: true,
          label: '03:24',
          phaseLabel: '2ND HALF',
        ),
        score: const ScorePresentation(
          available: true,
          label: '1 – 0',
          homeGoals: 1,
          awayGoals: 0,
        ),
        selection: base.selection,
        discipline: quiet,
        substitution: base.substitution,
        frozenCommand: null,
        commit: base.commit,
        navigation: NavigationPresentation(route: route, canOpenCapture: true),
        roster: base.roster,
        officials: base.officials,
        recoveryLabel: null,
        lastRejection: null,
        goalFlow: base.goalFlow,
        matchReport: base.matchReport,
        homeTeamLabel: 'Home',
        awayTeamLabel: 'Away',
      );
    }

    Future<void> pump(WatchPresentationState state) {
      return tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 420,
            height: 560,
            child: RepaintBoundary(
              key: const Key('lab-fixture-labeled'),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'SIMULATED PRESENTATION FIXTURE',
                      key: Key('lab-fixture-caption'),
                    ),
                  ),
                  Expanded(
                    child: DeviceShellStage(
                      profile: profile!,
                      child: RepaintBoundary(
                        key: const Key('lab-fixture-face'),
                        child: WatchReferenceApp(
                          state: state,
                          onIntent: (_) {},
                          face: watchFaceFor(profile),
                          showBeyondNominal: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    await tester.binding.setSurfaceSize(const Size(480, 640));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    await pump(live());
    expect(tester.takeException(), isNull);
    expect(find.text('SIMULATED PRESENTATION FIXTURE'), findsOneWidget);
    expect(find.text('03:24'), findsOneWidget);
    expect(find.text('BEYOND 90:00'), findsOneWidget);
    expect(find.text('Prior caution unavailable'), findsNothing);
    expect(find.text('Idle'), findsNothing);
    expect(find.text('Capture'), findsNothing);
    final caption = tester.getRect(find.byKey(const Key('lab-fixture-caption')));
    final face = tester.getRect(find.byKey(const Key('lab-fixture-face')));
    expect(caption.overlaps(face), isFalse);
    await _shot(tester, 'lab-fixture-a1-labeled', 'lab-fixture-labeled');
    await _shot(tester, 'lab-fixture-a1', 'lab-fixture-face');

    await pump(live(route: WatchRoute.captureMenu));
    expect(find.text('Capture Event'), findsNothing);
    expect(find.text('10:09'), findsNothing);
    expect(find.text('Yellow'), findsOneWidget);
    await _shot(tester, 'lab-fixture-capture', 'lab-fixture-face');
  });
}

Future<void> _shot(WidgetTester tester, String name, String key) async {
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(Key(key)));
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('/opt/cursor/artifacts/watch_design/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
}
