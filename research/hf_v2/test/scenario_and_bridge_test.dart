import 'package:hf_v2/hf_v2.dart';
import 'package:test/test.dart';

void main() {
  test('every core scenario and variant loads, resets, and logs', () {
    expect(coreScenarios, hasLength(21));
    for (final id in ScenarioId.values) {
      final instrument = ResearchInstrument()..loadScenario(id);
      expect(instrument.pitchTruth, isNotEmpty);
      expect(instrument.expectedDigitalTruth, isNotEmpty);
      expect(instrument.expectedUnfinishedTruth, isNotEmpty);
      expect(instrument.p0Failure, isNotEmpty);
      final opening = instrument.behaviorSignature;
      instrument.enterSurface('yellow');
      instrument.reset();
      expect(instrument.behaviorSignature, opening);
      expect(instrument.log.map((event) => event.kind),
          contains(ResearchLogKind.scenarioStarted));
      expect(instrument.productionMatchMemoryWrites, isFalse);
      if (id == ScenarioId.s17FinishLaterSimulatedRestart) {
        expect(instrument.simulatedRecoveryDisclaimer, isTrue);
        expect(instrument.recoveryBanner, RecoveryClaim.finishLaterLabel);
        expect(instrument.claimsProductionRecovery, isFalse);
        expect(instrument.commitKind, SystemCommitKind.saveNotVerified);
      }
    }
  });

  test('logging on and off leaves the research behavior unchanged', () {
    final logged = ResearchInstrument(loggingEnabled: true)
      ..loadScenario(ScenarioId.s11SubstitutionOutFirst);
    final quiet = ResearchInstrument(loggingEnabled: false)
      ..loadScenario(ScenarioId.s11SubstitutionOutFirst);
    for (final instrument in [logged, quiet]) {
      instrument.selectOut('p-home-9');
      instrument.selectIn('p-home-7');
      instrument.reorderRoster(['p-home-7', 'p-home-9']);
      instrument.interrupt();
      instrument.resume();
    }
    expect(quiet.log, isEmpty);
    expect(logged.log, isNotEmpty);
    expect(quiet.behaviorSignature, logged.behaviorSignature);
    expect(logged.outId, 'p-home-9');
    expect(logged.inId, 'p-home-7');
  });

  test('a throwing log sink does not change the action', () {
    final instrument = ResearchInstrument(
      sink: (_) => throw StateError('log down'),
    )..loadScenario(ScenarioId.s01YellowNoPrior);
    instrument.offerRecordYellow();
    instrument.pointerDown(pointerId: 1, x: 20, y: 190);
    instrument.pointerUp(pointerId: 1, x: 20, y: 190);
    instrument.resolveSimulatedCommit();
    expect(instrument.commitKind, SystemCommitKind.saved);
    expect(instrument.cautions, hasLength(1));
    expect(instrument.log, isEmpty);
  });

  test('sent-off history remains while the active surface closes', () {
    final instrument = ResearchInstrument()
      ..loadScenario(ScenarioId.s19SentOffHistoricalReview);
    expect(instrument.cautions, hasLength(2));
    expect(instrument.sendingOffRecorded, isTrue);
    expect(instrument.activeCautionSurface, isFalse);
  });

  test('roster reorder does not reverse substitution roles', () {
    final instrument = ResearchInstrument()
      ..loadScenario(ScenarioId.s14SubstitutionInterruptAfterPair);
    instrument.selectOut('p-home-subbed');
    instrument.selectIn('p-home-7');
    instrument.reorderRoster(['p-home-7', 'p-home-subbed', 'p-home-9']);
    instrument.interrupt();
    instrument.resume();
    expect(instrument.outId, 'p-home-subbed');
    expect(instrument.inId, 'p-home-7');
    expect(instrument.substitutionRecorded, isFalse);
  });

  test('known failure is distinct from an unknown outcome', () {
    final instrument = ResearchInstrument()
      ..loadScenario(ScenarioId.s01YellowNoPrior)
      ..setScriptedOutcome(
        FinalActionKind.recordYellow,
        SimulatedScriptedOutcome.failure,
      );
    instrument.offerRecordYellow();
    instrument.pointerDown(pointerId: 1, x: 20, y: 190);
    instrument.pointerUp(pointerId: 1, x: 20, y: 190);
    instrument.resolveSimulatedCommit();
    expect(instrument.commitKind, SystemCommitKind.notSaved);
    expect(instrument.commitLabel, contains('known simulated failure'));
    expect(instrument.cautions, isEmpty);
  });
}
