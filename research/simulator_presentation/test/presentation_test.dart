import 'dart:io';

import 'package:simulator_presentation/simulator_presentation.dart';
import 'package:test/test.dart';

void main() {
  test('presentation package does not depend on Flutter, persistence, or the instrument', () {
    final pubspec = File('pubspec.yaml').readAsStringSync().toLowerCase();
    expect(pubspec.contains('sdk: flutter'), isFalse);
    expect(RegExp(r'^dependencies:', multiLine: true).hasMatch(pubspec), isFalse);
    for (final token in [
      'hf_v2',
      'forref_match_core',
      'forref_match_persistence',
      'match_core',
      'firebase',
      'simulator_geometry',
    ]) {
      expect(pubspec, isNot(contains(token)), reason: token);
    }
  });

  test('in-memory runtime records origin and does not invent a save', () async {
    final runtime = InMemoryPresentationRuntime();
    await runtime.dispatch(
      const OpenRouteIntent(WatchRoute.captureMenu, origin: IntentOrigin.watchUi),
    );
    await runtime.dispatch(
      const ActivateIntent(PresentationAction.yellow, origin: IntentOrigin.watchUi),
    );
    expect(runtime.watchState.navigation.route, WatchRoute.captureMenu);
    expect(runtime.watchState.commit.label, ResearchCommitPhrases.idle);
    expect(runtime.watchState.discipline.cautionCount, 0);
    expect(runtime.watchState.discipline.sendOffCount, 0);
    expect(runtime.intentTrace, hasLength(2));
    expect(runtime.intentTrace.first.originLabel, watchUiTraceLabel);
    expect(runtime.intentTrace.last.originLabel, watchUiTraceLabel);
    expect(runtime.watchState.clock.available, isFalse);
    expect(runtime.watchState.score.available, isFalse);
    expect(runtime.watchState.score.homeGoals, isNull);
  });

  test('operator and watch origins stay distinct', () {
    expect(intentOriginLabel(IntentOrigin.operatorFixture), operatorFixtureTraceLabel);
    expect(intentOriginLabel(IntentOrigin.watchUi), watchUiTraceLabel);
  });
}
