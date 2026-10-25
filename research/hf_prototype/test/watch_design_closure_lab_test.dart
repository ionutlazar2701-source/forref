import 'package:flutter/material.dart' hide ActivateIntent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hf_prototype/src/device_hero_stage.dart';
import 'package:simulator_presentation/simulator_presentation.dart';
import 'package:watch_reference_ui/watch_reference_ui.dart';

import 'lab_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadReadableFonts);

  testWidgets(
      'the lab completes family, team, and participant without a record',
      (tester) async {
    final controller = await pumpLab(tester);
    final beforeCautions = controller.instrument.cautions.length;
    final beforeGoals = controller.instrument.goals.length;
    final beforeSendOffs = controller.instrument.sendOffs.length;
    final beforeSeconds = controller.instrument.matchElapsedSeconds;
    final active = find.byKey(
      const Key('watch-huawei-watch-gt4-46-active'),
    );

    Finder inWatch(Key key) {
      return find.descendant(of: active, matching: find.byKey(key));
    }

    expect(watchFaceFor(controller.shellProfile!), WatchFaceShape.round);
    expect(find.byKey(const Key('watch-capture-glyph')), findsOneWidget);
    await tester.tap(inWatch(const Key('watch-capture-ring')));
    await tester.pump();
    expect(controller.watchRuntime.watchState.navigation.route,
        WatchRoute.captureMenu);
    expect(controller.instrument.cautions, hasLength(beforeCautions));

    await tester.tap(inWatch(const Key('watch-capture-yellow')));
    await tester.pump();
    expect(inWatch(const Key('watch-design-team')), findsOneWidget);
    expect(controller.watchRuntime.watchState.navigation.route,
        WatchRoute.captureMenu);

    await tester.tap(inWatch(const Key('watch-team-home')));
    await tester.pump();
    expect(inWatch(const Key('watch-participant-p-home-14')), findsOneWidget);
    expect(inWatch(const Key('watch-participant-p-away-14')), findsNothing);

    await tester.tap(inWatch(const Key('watch-participant-back')));
    await tester.pump();
    expect(inWatch(const Key('watch-design-team')), findsOneWidget);

    await tester.tap(inWatch(const Key('watch-team-home')));
    await tester.pump();
    await tester.tap(inWatch(const Key('watch-participant-p-home-14')));
    await tester.pump();

    expect(controller.watchRuntime.watchState.navigation.route,
        WatchRoute.yellowFlow);
    expect(controller.instrument.selectedParticipantId, 'p-home-14');
    expect(controller.instrument.cautions, hasLength(beforeCautions));
    expect(controller.instrument.goals, hasLength(beforeGoals));
    expect(controller.instrument.sendOffs, hasLength(beforeSendOffs));
    expect(controller.instrument.matchElapsedSeconds, beforeSeconds);
    expect(
      controller.watchRuntime.intentTrace.map((entry) => entry.intentName),
      containsAllInOrder(<String>[
        'openRoute:captureMenu',
        'setTeam:home',
        'setTeam:home',
        'selectParticipant:p-home-14',
        'offerYellow',
      ]),
    );
    expect(
      controller.watchRuntime.intentTrace.map((entry) => entry.intentName),
      isNot(contains('activate:yellow')),
    );
  });
}
