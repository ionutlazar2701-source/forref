import 'dart:io';

import 'package:hf_v2/hf_v2.dart';
import 'package:simulator_geometry/simulator_geometry.dart';
import 'package:simulator_hf_bridge/simulator_hf_bridge.dart';
import 'package:simulator_presentation/simulator_presentation.dart';
import 'package:test/test.dart';

void main() {
  test('bridge does not depend on Flutter, production authority, or legacy match core', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final token in [
      'flutter',
      'forref_match_core',
      'forref_match_persistence',
      'match_core',
      'firebase',
    ]) {
      expect(pubspec.toLowerCase(), isNot(contains(token)), reason: token);
    }
    final hf = File('../hf_v2/pubspec.yaml').readAsStringSync();
    expect(hf, isNot(contains('simulator_presentation')));
    expect(hf, isNot(contains('simulator_geometry')));
  });

  test('binding a profile does not append a research record', () {
    final runtime = HfPresentationRuntime();
    final before = runtime.instrument.snapshot.cautions.length;
    runtime.bindProfile(amazfitGts4);
    expect(runtime.viewport?.profileId, 'amazfit-gts4');
    expect(runtime.viewport?.safeAreaKnown, isFalse);
    expect(runtime.watchState.profileId, 'amazfit-gts4');
    expect(runtime.watchState.discipline.cautionCount, before);
    expect(runtime.watchState.clock.available, isFalse);
    expect(runtime.watchState.score.homeGoals, isNull);
    expect(runtime.instrument.productionMatchMemoryWrites, isFalse);
  });

  test('yellow resolve does not create a send-off', () async {
    final runtime = HfPresentationRuntime();
    await runtime.dispatch(
      const SelectParticipantIntent('p-home-14', origin: IntentOrigin.watchUi),
    );
    await runtime.dispatch(const OfferYellowIntent(origin: IntentOrigin.watchUi));
    await runtime.dispatch(
      const ActivateIntent(PresentationAction.yellow, origin: IntentOrigin.watchUi),
    );
    expect(runtime.watchState.frozenCommand?.subjectId, 'p-home-14');
    expect(runtime.watchState.frozenCommand?.action, PresentationAction.yellow);
    expect(runtime.watchState.commit.label, ResearchCommitPhrases.saving);
    await runtime.dispatch(
      const ResolveSimulatedCommitIntent(origin: IntentOrigin.watchUi),
    );
    expect(runtime.watchState.commit.label, ResearchCommitPhrases.simulatedSaved);
    expect(runtime.watchState.discipline.cautionCount, 1);
    expect(runtime.watchState.discipline.sendOffCount, 0);
    expect(runtime.instrument.snapshot.sendOffs, isEmpty);
  });

  test('an in-flight home 14 command stays home 14 when away is selected', () async {
    final runtime = HfPresentationRuntime();
    await runtime.dispatch(
      const SelectParticipantIntent('p-home-14', origin: IntentOrigin.watchUi),
    );
    await runtime.dispatch(const OfferYellowIntent(origin: IntentOrigin.watchUi));
    await runtime.dispatch(
      const ActivateIntent(PresentationAction.yellow, origin: IntentOrigin.watchUi),
    );
    await runtime.dispatch(
      const SetTeamIntent(PresentationTeam.away, origin: IntentOrigin.operatorFixture),
    );
    expect(runtime.watchState.frozenCommand?.subjectId, 'p-home-14');
    expect(runtime.watchState.header.teamContext, PresentationTeamContext.away);
    expect(runtime.watchState.discipline.cautionCount, 0);
    expect(runtime.intentTrace.last.originLabel, operatorFixtureTraceLabel);
  });

  test('an in-flight match command stays match when shootout is selected', () async {
    final runtime = HfPresentationRuntime();
    await runtime.dispatch(
      const SelectParticipantIntent('p-home-9', origin: IntentOrigin.watchUi),
    );
    await runtime.dispatch(const OfferYellowIntent(origin: IntentOrigin.watchUi));
    await runtime.dispatch(
      const ActivateIntent(PresentationAction.yellow, origin: IntentOrigin.watchUi),
    );
    await runtime.dispatch(
      const SetScopeIntent(PresentationScope.shootout, origin: IntentOrigin.operatorFixture),
    );
    expect(runtime.watchState.frozenCommand?.scope, PresentationScope.match);
    expect(runtime.watchState.header.scope, PresentationScope.shootout);
    expect(runtime.watchState.discipline.sendOffCount, 0);
  });

  test('an in-flight substitution pair stays frozen when in changes', () async {
    final runtime = HfPresentationRuntime();
    await runtime.dispatch(
      const SelectOutIntent('p-home-9', origin: IntentOrigin.watchUi),
    );
    await runtime.dispatch(
      const SelectInIntent('p-home-7', origin: IntentOrigin.watchUi),
    );
    await runtime.dispatch(
      const ActivateIntent(
        PresentationAction.substitution,
        origin: IntentOrigin.watchUi,
      ),
    );
    await runtime.dispatch(
      const SelectInIntent('p-home-12', origin: IntentOrigin.operatorFixture),
    );
    expect(runtime.watchState.frozenCommand?.outId, 'p-home-9');
    expect(runtime.watchState.frozenCommand?.inId, 'p-home-7');
    expect(runtime.instrument.snapshot.substitutions, isEmpty);
  });

  test('second-caution send-off is refused before a successor exists', () async {
    final runtime = HfPresentationRuntime();
    await runtime.dispatch(
      const ActivateIntent(
        PresentationAction.secondCautionSendOff,
        origin: IntentOrigin.watchUi,
      ),
    );
    expect(runtime.watchState.frozenCommand, isNull);
    expect(runtime.watchState.discipline.sendOffCount, 0);
    expect(runtime.instrument.snapshot.commitKind, SystemCommitKind.idle);
  });

  test('unavailable prior caution is not projected as known none', () async {
    final runtime = HfPresentationRuntime();
    await runtime.dispatch(
      const LoadScenarioIntent('s03YellowPriorUnavailable', origin: IntentOrigin.operatorFixture),
    );
    expect(runtime.watchState.discipline.awareness, PriorAwareness.unavailable);
    expect(runtime.watchState.discipline.awareness, isNot(PriorAwareness.knownNone));
    expect(runtime.watchState.discipline.awarenessLabel, contains('unavailable'));
  });

  test('shirt labels are not the participant identity', () async {
    final runtime = HfPresentationRuntime();
    final home = runtime.watchState.roster.where((person) => person.id == 'p-home-14').single;
    final away = runtime.watchState.roster.where((person) => person.id == 'p-away-14').single;
    expect(home.shirtLabel, '14');
    expect(away.shirtLabel, '14');
    expect(home.id, isNot(away.id));
  });
}
