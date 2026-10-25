import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_presentation/simulator_presentation.dart';
import 'package:watch_reference_ui/watch_reference_ui.dart';

void main() {
  test(
      'the reference app does not depend on the instrument or production authority',
      () {
    final pubspec = File('pubspec.yaml').readAsStringSync().toLowerCase();
    for (final token in [
      'hf_v2',
      'forref_match_core',
      'forref_match_persistence',
      'match_core',
      'firebase',
      'simulator_geometry',
      'simulator_hf_bridge',
    ]) {
      expect(pubspec, isNot(contains(token)), reason: token);
    }
  });

  testWidgets(
      'capture emits a watch-ui route intent and does not invent a save',
      (tester) async {
    final intents = <WatchIntent>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 280,
          height: 420,
          child: WatchReferenceApp(
            state: WatchPresentationState.empty,
            onIntent: intents.add,
          ),
        ),
      ),
    );
    expect(find.text('Clock unavailable'), findsOneWidget);
    expect(find.text('Score unavailable'), findsOneWidget);
    expect(find.text(ResearchCommitPhrases.idle), findsOneWidget);
    expect(find.text('Capture unavailable'), findsNothing);
    expect(find.byKey(const Key('watch-capture-ring')), findsOneWidget);
    await tester.tap(find.text('Capture'));
    await tester.pump();
    final intent = intents.single as OpenRouteIntent;
    expect(intent.route, WatchRoute.captureMenu);
    expect(intent.origin, IntentOrigin.watchUi);
  });

  testWidgets('a tiny aperture is not fit instead of shrinking the actions',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 80,
            height: 80,
            child: WatchReferenceApp(
              state: WatchPresentationState.empty,
              onIntent: _ignore,
            ),
          ),
        ),
      ),
    );
    expect(find.text('LAYOUT NOT FIT FOR THIS PROFILE'), findsOneWidget);
    expect(find.text('Record yellow'), findsNothing);
  });
}

void _ignore(WatchIntent intent) {}
