import 'package:hf_v2/hf_v2.dart';
import 'package:test/test.dart';

void main() {
  test('semantic replay uses the instrument and matches a manual yellow', () {
    final manual = ResearchInstrument()
      ..loadScenario(ScenarioId.s01YellowNoPrior)
      ..offerRecordYellow();
    manual.pointerDown(pointerId: 1, x: 20, y: 190);
    manual.pointerUp(pointerId: 1, x: 20, y: 190);
    manual.resolveSimulatedCommit();

    final replayed = replaySemanticSteps(
      scenario: ScenarioId.s01YellowNoPrior,
      steps: const [
        SemanticOpStep(SemanticOp.offerYellow),
        SemanticOpStep(SemanticOp.tap, x: 20, y: 190),
        SemanticOpStep(SemanticOp.resolve),
      ],
    );
    expect(replayed.cautions, hasLength(1));
    expect(replayed.cautions.single.subjectId, manual.cautions.single.subjectId);
    expect(replayed.commitKind, SystemCommitKind.saved);
    expect(replayed.sendOffs, isEmpty);
    expect(replayed.behaviorSignature, manual.behaviorSignature);
  });

  test('pointer replay refuses a different profile and writes nothing', () {
    final instrument = ResearchInstrument()
      ..loadScenario(ScenarioId.s01YellowNoPrior)
      ..offerRecordYellow();
    const trace = PointerTrace(
      profileId: 'illustrative-round-watch',
      layoutPolicyVersion: 1,
      events: [
        PointerTraceEvent.down(pointerId: 1, x: 20, y: 190),
        PointerTraceEvent.up(pointerId: 1, x: 20, y: 190),
      ],
    );
    final refused = replayPointerTrace(
      instrument: instrument,
      trace: trace,
      activeProfileId: 'illustrative-phone-portrait',
      activeLayoutPolicyVersion: 1,
    );
    expect(refused.refusal, PointerReplayRefusal.profileMismatch);
    instrument.resolveSimulatedCommit();
    expect(instrument.cautions, isEmpty);
    expect(instrument.commitKind, SystemCommitKind.idle);
  });

  test('pointer replay on the same profile still goes through the instrument', () {
    final instrument = ResearchInstrument()
      ..loadScenario(ScenarioId.s01YellowNoPrior)
      ..offerRecordYellow();
    final applied = replayPointerTrace(
      instrument: instrument,
      trace: const PointerTrace(
        profileId: 'illustrative-phone-portrait',
        layoutPolicyVersion: 1,
        events: [
          PointerTraceEvent.down(pointerId: 1, x: 20, y: 190),
          PointerTraceEvent.up(pointerId: 1, x: 20, y: 190),
        ],
      ),
      activeProfileId: 'illustrative-phone-portrait',
      activeLayoutPolicyVersion: 1,
    );
    expect(applied.refusal, PointerReplayRefusal.none);
    expect(instrument.cautions, isEmpty);
    expect(instrument.commitKind, SystemCommitKind.saving);
    instrument.resolveSimulatedCommit();
    expect(instrument.cautions, hasLength(1));
  });

  test('a layout version mismatch refuses the pointer trace', () {
    final instrument = ResearchInstrument()
      ..loadScenario(ScenarioId.s07RapidRepeatAfterY2)
      ..offerRecordYellow();
    final refused = replayPointerTrace(
      instrument: instrument,
      trace: const PointerTrace(
        profileId: 'illustrative-phone-portrait',
        layoutPolicyVersion: 1,
        events: [
          PointerTraceEvent.down(pointerId: 1, x: 20, y: 190),
          PointerTraceEvent.up(pointerId: 1, x: 20, y: 190),
        ],
      ),
      activeProfileId: 'illustrative-phone-portrait',
      activeLayoutPolicyVersion: 2,
    );
    expect(refused.refusal, PointerReplayRefusal.layoutMismatch);
    instrument.resolveSimulatedCommit();
    expect(instrument.cautions, hasLength(1));
    expect(instrument.sendOffs, isEmpty);
  });
}
