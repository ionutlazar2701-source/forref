import 'package:hf_v2/hf_v2.dart';
import 'package:test/test.dart';

void main() {
  test('a snapshot copies records and does not create any', () {
    final instrument = ResearchInstrument()..loadScenario(ScenarioId.s01YellowNoPrior);
    final before = instrument.behaviorSignature;
    final snap = instrument.snapshot;
    expect(snap.cautions, isEmpty);
    expect(snap.sendOffPresence, 'SEND_OFF absent');
    expect(() => snap.cautions.add(const SavedCaution(
          subjectId: 'x',
          kind: SubjectKind.participant,
          scope: ResearchScope.match,
        )), throwsUnsupportedError);
    instrument.cautions.add(
      const SavedCaution(
        subjectId: 'p-home-9',
        kind: SubjectKind.participant,
        scope: ResearchScope.match,
      ),
    );
    expect(snap.cautions, isEmpty);
    expect(instrument.cautions, hasLength(1));
    instrument.cautions.clear();
    expect(instrument.behaviorSignature, before);
    final again = instrument.snapshot;
    expect(again.cautions, isEmpty);
    expect(instrument.cautions, isEmpty);
  });

  test('in-flight yellow keeps Home 9 when the unfinished subject changes', () {
    final instrument = ResearchInstrument()
      ..loadScenario(ScenarioId.s09Home14ThenAway14)
      ..offerRecordYellow();
    instrument.pointerDown(pointerId: 1, x: 20, y: 190);
    instrument.pointerUp(pointerId: 1, x: 20, y: 190);
    final during = instrument.snapshot;
    expect(during.commitKind, SystemCommitKind.saving);
    expect(during.inFlight?.subjectId, 'p-home-14');
    expect(during.inFlight?.scope, ResearchScope.match);
    expect(during.cautions, isEmpty);
    instrument.setTeam(ResearchTeamSide.away);
    instrument.selectParticipant('p-away-14');
    expect(instrument.snapshot.inFlight?.subjectId, 'p-home-14');
    expect(instrument.snapshot.selectedSubjectId, 'p-away-14');
    instrument.resolveSimulatedCommit();
    expect(instrument.commitKind, SystemCommitKind.saved);
    expect(instrument.cautions.single.subjectId, 'p-home-14');
    expect(instrument.snapshot.inFlight, isNull);
    expect(
      instrument.log.map((event) => event.kind),
      contains(ResearchLogKind.researchRecordAppended),
    );
  });

  test('in-flight scope and substitution pair stay frozen', () {
    final scope = ResearchInstrument()
      ..loadScenario(ScenarioId.s01YellowNoPrior)
      ..offerRecordYellow();
    scope.pointerDown(pointerId: 1, x: 20, y: 190);
    scope.pointerUp(pointerId: 1, x: 20, y: 190);
    scope.setScope(ResearchScope.shootout);
    expect(scope.snapshot.inFlight?.scope, ResearchScope.match);
    expect(scope.snapshot.scope, ResearchScope.shootout);
    scope.resolveSimulatedCommit();
    expect(
      scope.savedCautionCount('p-home-9', SubjectKind.participant, ResearchScope.match),
      1,
    );
    expect(
      scope.savedCautionCount(
        'p-home-9',
        SubjectKind.participant,
        ResearchScope.shootout,
      ),
      0,
    );

    final pair = ResearchInstrument()..loadScenario(ScenarioId.s11SubstitutionOutFirst);
    pair.selectOut('p-home-9');
    pair.selectIn('p-home-7');
    pair.pointerDown(pointerId: 1, x: 40, y: 260);
    pair.pointerUp(pointerId: 1, x: 40, y: 260);
    pair.selectIn('p-home-14');
    expect(pair.snapshot.inFlight?.outId, 'p-home-9');
    expect(pair.snapshot.inFlight?.inId, 'p-home-7');
    expect(pair.snapshot.inId, 'p-home-14');
    pair.resolveSimulatedCommit();
    expect(pair.substitutions.single.outId, 'p-home-9');
    expect(pair.substitutions.single.inId, 'p-home-7');
  });

  test('unknown outcome is neither saved nor a known failure', () {
    final instrument = ResearchInstrument()
      ..loadScenario(ScenarioId.s16SaveNotVerified)
      ..offerRecordYellow();
    instrument.pointerDown(pointerId: 1, x: 20, y: 190);
    instrument.pointerUp(pointerId: 1, x: 20, y: 190);
    instrument.resolveSimulatedCommit();
    final snap = instrument.snapshot;
    expect(snap.commitKind, SystemCommitKind.saveNotVerified);
    expect(snap.commitLabel, contains('SAVE NOT VERIFIED'));
    expect(snap.commitLabel, isNot(contains('SIMULATED SAVED')));
    expect(snap.commitLabel, isNot(contains('NOT SAVED')));
    expect(snap.cautions, isEmpty);
    expect(
      instrument.log.map((event) => event.kind),
      isNot(contains(ResearchLogKind.researchRecordAppended)),
    );
    expect(snap.freshInputEligible, isFalse);
  });

  test('unavailable history and direct pathway stay distinct on the snapshot', () {
    final unavailable = ResearchInstrument()
      ..loadScenario(ScenarioId.s03YellowPriorUnavailable);
    expect(unavailable.snapshot.priorCaution, PriorCautionKnowledge.unavailable);
    expect(unavailable.snapshot.priorCaution, isNot(PriorCautionKnowledge.knownNone));

    final direct = ResearchInstrument()
      ..loadScenario(ScenarioId.s08DirectRedWithPriorYellow)
      ..offerDirectSendOff();
    direct.pointerDown(pointerId: 1, x: 230, y: 190);
    direct.pointerUp(pointerId: 1, x: 230, y: 190);
    direct.resolveSimulatedCommit();
    expect(direct.sendOffs.single.pathway, SendOffPathwayLabel.direct);
    expect(direct.snapshot.sendOffs.single.pathway, SendOffPathwayLabel.direct);
    expect(direct.cautions, hasLength(1));
  });

  test('two cautions do not append a sending-off', () {
    final instrument = ResearchInstrument()
      ..loadScenario(ScenarioId.s05Y2SendOffContinuation)
      ..offerRecordYellow();
    instrument.pointerDown(pointerId: 1, x: 20, y: 190);
    instrument.pointerUp(pointerId: 1, x: 20, y: 190);
    instrument.resolveSimulatedCommit();
    final snap = instrument.snapshot;
    expect(snap.cautions, hasLength(2));
    expect(snap.sendOffs, isEmpty);
    expect(snap.sendOffPresence, 'SEND_OFF absent');
  });

  test('similar officials stay separate subjects', () {
    final instrument = ResearchInstrument()..loadScenario(ScenarioId.s10SimilarOfficials);
    final officials = instrument.snapshot.officials
        .where((official) => official.name == 'Alex Popescu')
        .toList();
    expect(officials, hasLength(2));
    expect(officials[0].id, isNot(officials[1].id));
    expect(instrument.snapshot.selectedSubjectId, isNull);
  });

  test('log sequence is monotonic and reset starts again at 1', () {
    final instrument = ResearchInstrument()..loadScenario(ScenarioId.s01YellowNoPrior);
    expect(instrument.log.first.sequence, 1);
    for (var i = 0; i < instrument.log.length; i++) {
      expect(instrument.log[i].sequence, i + 1);
    }
    instrument.enterSurface('yellow');
    final last = instrument.log.last.sequence;
    instrument.reset();
    expect(instrument.log.first.sequence, 1);
    expect(instrument.log.last.sequence, lessThan(last));
  });

  test('device change cancels an open pointer and writes nothing', () {
    final instrument = ResearchInstrument()
      ..loadScenario(ScenarioId.s01YellowNoPrior)
      ..offerRecordYellow();
    instrument.pointerDown(pointerId: 7, x: 20, y: 190);
    expect(instrument.snapshot.armedKind, FinalActionKind.recordYellow);
    instrument.cancelOpenInputForDeviceChange('illustrative-round-watch');
    instrument.pointerUp(pointerId: 7, x: 20, y: 190);
    instrument.resolveSimulatedCommit();
    expect(instrument.commitKind, SystemCommitKind.idle);
    expect(instrument.cautions, isEmpty);
    expect(instrument.snapshot.activePointerCount, 0);
    expect(
      instrument.log.map((event) => event.kind),
      contains(ResearchLogKind.activeDeviceChanged),
    );
  });
}
