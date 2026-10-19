import 'package:hf_v2/hf_v2.dart';
import 'package:test/test.dart';

void main() {
  test('Y2 uncommitted is not two cautions recorded', () {
    final instrument = _load(ScenarioId.s02YellowOnePrior);
    instrument.offerRecordYellow();
    expect(instrument.twoCautionsRecorded, isFalse);
    expect(instrument.yellowOffered, isTrue);
    expect(instrument.commitKind, SystemCommitKind.idle);
  });

  test('Y2 saved is two cautions and not a sending-off', () {
    final instrument = _load(ScenarioId.s05Y2SendOffContinuation);
    _saveYellow(instrument);
    expect(instrument.twoCautionsRecorded, isTrue);
    expect(instrument.sendingOffRecorded, isFalse);
    expect(instrument.sendOffs, isEmpty);
    expect(instrument.sendOffContinuationVisible, isTrue);
    expect(instrument.armedKind, isNull);
  });

  test('send-off requires a separate final action', () {
    final instrument = _load(ScenarioId.s05Y2SendOffContinuation);
    _saveYellow(instrument);
    instrument.accessibilityInvoke(FinalActionKind.recordSecondCautionSendOff);
    instrument.resolveSimulatedCommit();
    expect(instrument.sendingOffRecorded, isTrue);
    expect(instrument.sendOffs.single.pathway, SendOffPathwayLabel.secondCaution);
  });

  test('OUT-only and IN-only and an uncommitted pair are not substitutions', () {
    final instrument = _load(ScenarioId.s11SubstitutionOutFirst);
    instrument.selectOut('p-home-9');
    expect(instrument.substitutionStage, SubstitutionStage.outOnly);
    expect(instrument.substitutionRecorded, isFalse);

    final inFirst = _load(ScenarioId.s12SubstitutionInFirst);
    inFirst.selectIn('p-home-7');
    expect(inFirst.substitutionStage, SubstitutionStage.inOnly);
    expect(inFirst.substitutionRecorded, isFalse);

    final pair = _load(ScenarioId.s14SubstitutionInterruptAfterPair);
    pair.selectOut('p-home-9');
    pair.selectIn('p-home-7');
    expect(pair.substitutionStage, SubstitutionStage.review);
    expect(pair.substitutionRecorded, isFalse);
    pair.interrupt();
    pair.resume();
    expect(pair.outId, 'p-home-9');
    expect(pair.inId, 'p-home-7');
    expect(pair.substitutionRecorded, isFalse);
  });

  test('team change invalidates the subject and shirt numbers stay distinct', () {
    final instrument = _load(ScenarioId.s09Home14ThenAway14);
    expect(instrument.selectedParticipantId, 'p-home-14');
    instrument.setTeam(ResearchTeamSide.away);
    expect(instrument.selectionKind, SubjectSelectionKind.invalidated);
    expect(instrument.selectedParticipantId, isNull);
    instrument.selectParticipant('p-away-14');
    expect(instrument.selectedParticipantId, 'p-away-14');
    expect(instrument.selectedParticipant!.shirtLabel, '14');
    expect(
      instrument.selectedParticipantId,
      isNot('p-home-14'),
    );
  });

  test('participant and official identities stay distinct', () {
    final instrument = _load(ScenarioId.s10SimilarOfficials);
    expect(instrument.selectionKind, SubjectSelectionKind.none);
    instrument.selectOfficial('o-alex-assistant');
    expect(instrument.selectedOfficialId, 'o-alex-assistant');
    expect(instrument.selectedParticipantId, isNull);
    instrument.selectOfficial('o-alex-doctor');
    expect(instrument.selectedOfficialId, 'o-alex-doctor');
    expect(instrument.selectedKind, SubjectKind.official);
  });

  test('MATCH and SHOOTOUT cautions stay separate', () {
    final instrument = _load(ScenarioId.s18MatchToShootout);
    expect(
      instrument.savedCautionCount(
        'p-home-9',
        SubjectKind.participant,
        ResearchScope.match,
      ),
      1,
    );
    instrument.setScope(ResearchScope.shootout);
    expect(instrument.twoCautionsRecorded, isFalse);
    expect(
      instrument.savedCautionCount(
        'p-home-9',
        SubjectKind.participant,
        ResearchScope.shootout,
      ),
      0,
    );
    expect(
      instrument.savedCautionCount(
        'p-home-9',
        SubjectKind.participant,
        ResearchScope.match,
      ),
      1,
    );
  });

  test('save not verified is not not-saved, and interruption creates no authority', () {
    final unknown = _load(ScenarioId.s16SaveNotVerified);
    unknown.offerRecordYellow();
    _tap(unknown, 20, 530);
    unknown.resolveSimulatedCommit();
    expect(unknown.commitKind, SystemCommitKind.saveNotVerified);
    expect(unknown.commitKind, isNot(SystemCommitKind.notSaved));
    expect(unknown.commitKind, isNot(SystemCommitKind.saved));
    expect(unknown.cautions, isEmpty);
    expect(unknown.submitWhileUnverified(), isFalse);
    unknown.acknowledgeUnknownOutcome();
    expect(unknown.cautions, isEmpty);

    final interrupted = _load(ScenarioId.s15InterruptWhileSaving);
    interrupted.offerRecordYellow();
    _tap(interrupted, 20, 530);
    expect(interrupted.commitKind, SystemCommitKind.saving);
    interrupted.interrupt();
    expect(interrupted.commitKind, SystemCommitKind.saveNotVerified);
    expect(interrupted.cautions, isEmpty);
    expect(interrupted.sendingOffRecorded, isFalse);
  });

  test('unavailable and conflicted prior cautions are not verified absence', () {
    final unavailable = _load(ScenarioId.s03YellowPriorUnavailable);
    expect(unavailable.priorCautionLabel, 'Prior caution unavailable');
    expect(unavailable.priorCautionLabel, isNot(contains('Known verified absence')));
    final conflicted = _load(ScenarioId.s04YellowPriorConflicted);
    expect(conflicted.priorCautionLabel, 'Prior caution conflicted');
    expect(conflicted.priorCautionLabel, isNot(contains('Known verified absence')));
  });

  test('direct send-off does not borrow the prior yellow', () {
    final instrument = _load(ScenarioId.s08DirectRedWithPriorYellow);
    instrument.offerDirectSendOff();
    _tap(instrument, 210, 530);
    instrument.resolveSimulatedCommit();
    expect(instrument.sendOffs.single.pathway, SendOffPathwayLabel.direct);
    expect(instrument.cautions, hasLength(1));
  });

  test('status rank never drops a known subject', () {
    final instrument = _load(ScenarioId.vSubstituted);
    final ids = instrument.rankedRoster.map((person) => person.id);
    expect(ids, contains('p-home-subbed'));
    expect(ids, contains('p-home-temp'));
    expect(ids, contains('p-home-unknown'));
    expect(ids, contains('p-home-conflict'));
    expect(
      instrument.rankedRoster.first.presence,
      PresenceRank.onField,
    );
  });

  test('same shirt on one team stays two ids', () {
    final instrument = _load(ScenarioId.vDuplicateShirt);
    instrument.selectParticipant('p-home-7');
    expect(instrument.selectedParticipantId, 'p-home-7');
    final shirts = instrument.roster.where((person) => person.shirtLabel == '7');
    expect(shirts.map((person) => person.id).toSet(), {'p-home-7', 'p-home-7b'});
  });

  test('absent team does not accept a subject', () {
    final instrument = _load(ScenarioId.vTeamAbsent);
    instrument.selectParticipant('p-home-9');
    expect(instrument.selectionKind, SubjectSelectionKind.unresolved);
    expect(instrument.selectedParticipantId, isNull);
  });
}

ResearchInstrument _load(ScenarioId id) {
  return ResearchInstrument()..loadScenario(id);
}

void _tap(ResearchInstrument instrument, double x, double y, {int pointerId = 1}) {
  instrument.pointerDown(pointerId: pointerId, x: x, y: y);
  instrument.pointerUp(pointerId: pointerId, x: x, y: y);
}

void _saveYellow(ResearchInstrument instrument) {
  instrument.offerRecordYellow();
  _tap(instrument, 20, 530);
  instrument.resolveSimulatedCommit();
}
