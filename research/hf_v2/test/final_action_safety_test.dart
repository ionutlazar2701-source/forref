import 'package:hf_v2/hf_v2.dart';
import 'package:test/test.dart';

void main() {
  test('A rapid double tap at the yellow position records yellow only', () {
    final instrument = _ready();
    _tap(instrument, 20, 530);
    instrument.resolveSimulatedCommit();
    _tap(instrument, 20, 530, pointerId: 2);
    instrument.resolveSimulatedCommit();
    expect(instrument.twoCautionsRecorded, isTrue);
    expect(instrument.sendOffs, isEmpty);
  });

  test('B pointer down, held commit, release does not send off', () {
    final instrument = _ready();
    instrument.pointerDown(pointerId: 1, x: 20, y: 530);
    instrument.commitCapturedActionWhileHeld(1);
    instrument.resolveSimulatedCommit();
    expect(instrument.twoCautionsRecorded, isTrue);
    instrument.pointerUp(pointerId: 1, x: 20, y: 530);
    instrument.resolveSimulatedCommit();
    expect(instrument.sendOffs, isEmpty);
  });

  test('C delayed release does not activate the successor', () {
    final instrument = _ready();
    instrument.pointerDown(pointerId: 1, x: 20, y: 530);
    instrument.commitCapturedActionWhileHeld(1);
    instrument.resolveSimulatedCommit();
    instrument.pointerUp(pointerId: 1, x: 80, y: 540);
    expect(instrument.sendOffs, isEmpty);
  });

  test('D press, transition, release does not activate the successor', () {
    final instrument = _ready();
    instrument.pointerDown(pointerId: 1, x: 20, y: 530);
    instrument.commitCapturedActionWhileHeld(1);
    instrument.resolveSimulatedCommit();
    expect(instrument.sendOffContinuationVisible, isTrue);
    expect(instrument.armedKind, isNull);
    instrument.pointerUp(pointerId: 1, x: 210, y: 530);
    expect(instrument.sendOffs, isEmpty);
  });

  test('E a second tap on the old yellow location is not a send-off', () {
    final instrument = _ready();
    _tap(instrument, 30, 540);
    instrument.resolveSimulatedCommit();
    _tap(instrument, 30, 540, pointerId: 2);
    expect(instrument.lastActivated, FinalActionKind.recordYellow);
    expect(instrument.sendOffs, isEmpty);
  });

  test('F a carried second pointer does not activate send-off', () {
    final instrument = _ready();
    instrument.pointerDown(pointerId: 1, x: 20, y: 530);
    instrument.pointerDown(pointerId: 2, x: 220, y: 530);
    instrument.commitCapturedActionWhileHeld(1);
    instrument.resolveSimulatedCommit();
    instrument.pointerDown(pointerId: 3, x: 220, y: 530);
    instrument.pointerUp(pointerId: 3, x: 220, y: 530);
    instrument.pointerUp(pointerId: 2, x: 220, y: 530);
    instrument.pointerUp(pointerId: 1, x: 20, y: 530);
    instrument.resolveSimulatedCommit();
    expect(instrument.twoCautionsRecorded, isTrue);
    expect(instrument.sendOffs, isEmpty);
  });

  test('G focus loss does not activate a new authority action', () {
    final instrument = _ready();
    instrument.pointerDown(pointerId: 1, x: 20, y: 530);
    instrument.focusLost();
    instrument.pointerUp(pointerId: 1, x: 20, y: 530);
    expect(instrument.commitKind, SystemCommitKind.idle);
    expect(instrument.cautions, hasLength(1));
    expect(instrument.sendOffs, isEmpty);
  });

  test('H relayout does not fire a stale successor target', () {
    final instrument = _ready();
    instrument.pointerDown(pointerId: 1, x: 20, y: 530);
    instrument.relayout(
      const ResearchLayout(
        yellow: ResearchRect(16, 520, 140, 48),
        sendOff: ResearchRect(16, 520, 140, 48),
        substitution: ResearchRect(16, 440, 200, 48),
        roster: ResearchRect(16, 120, 320, 280),
      ),
    );
    instrument.pointerUp(pointerId: 1, x: 20, y: 530);
    instrument.resolveSimulatedCommit();
    expect(instrument.twoCautionsRecorded, isTrue);
    expect(instrument.sendOffs, isEmpty);
    instrument.pointerDown(pointerId: 2, x: 20, y: 530);
    instrument.pointerUp(pointerId: 2, x: 20, y: 530);
    expect(instrument.sendOffs, isEmpty);
  });

  test('I accessibility invokes each authority action on its own', () {
    final instrument = _ready();
    instrument.accessibilityInvoke(FinalActionKind.recordSecondCautionSendOff);
    expect(instrument.sendOffs, isEmpty);
    instrument.accessibilityInvoke(FinalActionKind.recordYellow);
    instrument.resolveSimulatedCommit();
    expect(instrument.sendOffs, isEmpty);
    instrument.accessibilityInvoke(FinalActionKind.recordSecondCautionSendOff);
    instrument.resolveSimulatedCommit();
    expect(instrument.sendOffs, hasLength(1));
  });

  test('subject selection does not record a yellow', () {
    final instrument = _ready();
    instrument.selectParticipant('p-home-7');
    expect(instrument.commitKind, SystemCommitKind.idle);
    expect(instrument.cautions, hasLength(1));
  });

  test('direct red selection does not carry into send-off', () {
    final instrument = ResearchInstrument()
      ..loadScenario(ScenarioId.s08DirectRedWithPriorYellow);
    instrument.selectParticipant('p-home-9');
    expect(instrument.sendOffs, isEmpty);
    instrument.offerDirectSendOff();
    instrument.pointerDown(pointerId: 1, x: 210, y: 530);
    instrument.focusLost();
    instrument.pointerUp(pointerId: 1, x: 210, y: 530);
    expect(instrument.sendOffs, isEmpty);
  });

  test('the second substitution selection does not record it', () {
    final instrument = ResearchInstrument()
      ..loadScenario(ScenarioId.s11SubstitutionOutFirst);
    instrument.selectOut('p-home-9');
    instrument.pointerDown(pointerId: 1, x: 40, y: 200);
    instrument.selectIn('p-home-7');
    instrument.pointerUp(pointerId: 1, x: 40, y: 200);
    expect(instrument.substitutionStage, SubstitutionStage.review);
    expect(instrument.substitutionRecorded, isFalse);
    expect(instrument.outId, 'p-home-9');
    expect(instrument.inId, 'p-home-7');
  });

  test('becoming visible does not activate send-off', () {
    final instrument = _ready();
    _tap(instrument, 20, 530);
    instrument.resolveSimulatedCommit();
    expect(instrument.sendOffContinuationVisible, isTrue);
    expect(instrument.armedKind, isNull);
    expect(instrument.sendingOffRecorded, isFalse);
  });

  test('phone research regions do not stack yellow and send-off', () {
    expect(
      ResearchLayout.phone.yellow.overlaps(ResearchLayout.phone.sendOff),
      isFalse,
    );
  });
}

ResearchInstrument _ready() {
  return ResearchInstrument()
    ..loadScenario(ScenarioId.s07RapidRepeatAfterY2)
    ..offerRecordYellow();
}

void _tap(ResearchInstrument instrument, double x, double y, {int pointerId = 1}) {
  instrument.pointerDown(pointerId: pointerId, x: x, y: y);
  instrument.pointerUp(pointerId: pointerId, x: x, y: y);
}
