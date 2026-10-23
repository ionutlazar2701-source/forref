import 'package:hf_v2/hf_v2.dart';
import 'package:test/test.dart';

void main() {
  ResearchInstrument fresh() {
    return ResearchInstrument()..loadScenario(ScenarioId.s21MatchReportOps);
  }

  void kickOff(ResearchInstrument instrument) {
    instrument.armKickOff();
    expect(
      instrument.confirmKickOff(originTrace: 'MOBILE UI ACTION'),
      isTrue,
    );
  }

  test('T1 s21 starts not started and has no football-time coordinate', () {
    final instrument = fresh();
    expect(instrument.lifecycle, ResearchMatchLifecycle.matchNotStarted);
    expect(instrument.footballTimeActive, isFalse);
    expect(instrument.liveClockArmed, isFalse);
    expect(instrument.kickOffOriginTrace, isNull);
    expect(instrument.snapshot.footballTimeActive, isFalse);
  });

  test('T2 kick-off establishes first half at zero without a second anchor', () {
    final instrument = fresh();
    kickOff(instrument);
    expect(instrument.lifecycle, ResearchMatchLifecycle.firstHalfRunning);
    expect(instrument.footballTimeActive, isTrue);
    expect(instrument.liveClockArmed, isTrue);
    expect(instrument.matchElapsedSeconds, 0);
    expect(instrument.kickOffOriginTrace, 'MOBILE UI ACTION');
    expect(instrument.kickOffEvidenceSequence, isNotNull);
    final anchor = instrument.kickOffEvidenceSequence;
    instrument.noteLiveElapsed(const Duration(seconds: 5));
    instrument.armKickOff();
    expect(instrument.confirmKickOff(originTrace: 'WATCH UI'), isFalse);
    expect(instrument.matchElapsedSeconds, 5);
    expect(instrument.kickOffEvidenceSequence, anchor);
    expect(instrument.kickOffOriginTrace, 'MOBILE UI ACTION');
  });

  test('T5 stale kick-off input does not create an anchor', () {
    final instrument = fresh();
    expect(instrument.confirmKickOff(originTrace: 'residual'), isFalse);
    instrument.armKickOff();
    instrument.focusLost();
    expect(instrument.confirmKickOff(originTrace: 'after-focus'), isFalse);
    instrument.armKickOff();
    instrument.cancelOpenInputForDeviceChange('other-profile');
    expect(instrument.confirmKickOff(originTrace: 'after-device'), isFalse);
    expect(instrument.lifecycle, ResearchMatchLifecycle.matchNotStarted);
    expect(instrument.goals, isEmpty);
  });

  test('advance before kick-off does not invent a football time', () {
    final instrument = fresh();
    instrument.advanceMatchClock(37);
    expect(instrument.footballTimeActive, isFalse);
    expect(instrument.goals, isEmpty);
    kickOff(instrument);
    expect(instrument.matchElapsedSeconds, 0);
  });

  test('A1 goal before kick-off is prohibited and writes no 00:00 row', () {
    final instrument = fresh();
    instrument.offerRecordGoal();
    instrument.setTeam(ResearchTeamSide.home);
    instrument.selectParticipant('p-home-9');
    instrument.accessibilityInvoke(FinalActionKind.recordGoal);
    instrument.resolveSimulatedCommit();
    expect(instrument.goals, isEmpty);
    expect(instrument.lifecycle, ResearchMatchLifecycle.matchNotStarted);
  });

  test('A2 normal substitution before kick-off is prohibited', () {
    final instrument = fresh();
    instrument.setTeam(ResearchTeamSide.home);
    instrument.selectOut('p-home-9');
    instrument.selectIn('p-home-17');
    instrument.accessibilityInvoke(FinalActionKind.recordSubstitution);
    instrument.resolveSimulatedCommit();
    expect(instrument.substitutions, isEmpty);
  });

  test('A3 yellow before kick-off is not admitted', () {
    final instrument = fresh();
    instrument.setTeam(ResearchTeamSide.away);
    instrument.selectParticipant('p-away-6');
    instrument.offerRecordYellow();
    instrument.accessibilityInvoke(FinalActionKind.recordYellow);
    instrument.resolveSimulatedCommit();
    expect(instrument.cautions, isEmpty);
  });

  test('A4 direct send-off before kick-off is not admitted', () {
    final instrument = fresh();
    instrument.setTeam(ResearchTeamSide.home);
    instrument.selectParticipant('p-home-4');
    instrument.offerDirectSendOff();
    instrument.accessibilityInvoke(FinalActionKind.recordDirectSendOff);
    instrument.resolveSimulatedCommit();
    expect(instrument.sendOffs, isEmpty);
  });

  test('A5 second-caution send-off before kick-off is not admitted', () {
    final instrument = fresh();
    instrument.accessibilityInvoke(FinalActionKind.recordSecondCautionSendOff);
    instrument.resolveSimulatedCommit();
    expect(instrument.sendOffs, isEmpty);
    expect(instrument.cautions, isEmpty);
  });

  test('fast goal at displayed 00:00 is admitted after kick-off', () {
    final instrument = fresh();
    kickOff(instrument);
    expect(formatResearchMatchTime(instrument.matchElapsedSeconds), '00:00');
    instrument.offerRecordGoal();
    instrument.setTeam(ResearchTeamSide.home);
    instrument.selectParticipant('p-home-9');
    instrument.accessibilityInvoke(FinalActionKind.recordGoal);
    instrument.resolveSimulatedCommit();
    final goal = instrument.goals.single;
    expect(goal.matchTimeLabel, '00:00');
    expect(goal.occurrence?.period, ResearchOccurrencePeriod.firstHalf);
    expect(goal.occurrence?.elapsedSeconds, 0);
    expect(instrument.sendOffs, isEmpty);
  });

  test('live elapsed freezes goal and yellow times', () {
    final instrument = fresh();
    kickOff(instrument);
    instrument.noteLiveElapsed(const Duration(seconds: 37));
    instrument.offerRecordGoal();
    instrument.setTeam(ResearchTeamSide.home);
    instrument.selectParticipant('p-home-9');
    instrument.accessibilityInvoke(FinalActionKind.recordGoal);
    instrument.resolveSimulatedCommit();
    expect(instrument.goals.single.matchTimeLabel, '00:37');
    expect(instrument.goals.single.occurrence?.elapsedSeconds, 37);
    instrument.noteLiveElapsed(const Duration(seconds: 35));
    expect(instrument.matchElapsedSeconds, 72);
    instrument.setTeam(ResearchTeamSide.away);
    instrument.selectParticipant('p-away-6');
    instrument.offerRecordYellow();
    instrument.accessibilityInvoke(FinalActionKind.recordYellow);
    instrument.resolveSimulatedCommit();
    expect(instrument.cautions.single.matchTimeLabel, '01:12');
    expect(instrument.cautions.single.occurrence?.period,
        ResearchOccurrencePeriod.firstHalf);
    instrument.noteLiveElapsed(const Duration(seconds: 108));
    expect(instrument.matchElapsedSeconds, 180);
    expect(instrument.goals.single.matchTimeLabel, '00:37');
    expect(instrument.cautions.single.matchTimeLabel, '01:12');
    expect(instrument.sendOffs, isEmpty);
  });

  test('noteLiveElapsed does not run before kick-off or move time backwards', () {
    final instrument = fresh();
    expect(instrument.noteLiveElapsed(const Duration(seconds: 3)), isFalse);
    kickOff(instrument);
    expect(instrument.noteLiveElapsed(Duration.zero), isFalse);
    expect(instrument.noteLiveElapsed(const Duration(milliseconds: 400)), isFalse);
    expect(instrument.matchElapsedSeconds, 0);
    expect(instrument.noteLiveElapsed(const Duration(seconds: 2)), isTrue);
    expect(instrument.matchElapsedSeconds, 2);
  });

  test('research fixtures that are already in the first half keep their clock', () {
    final instrument = ResearchInstrument()
      ..loadScenario(ScenarioId.s01YellowNoPrior);
    expect(instrument.lifecycle, ResearchMatchLifecycle.firstHalfRunning);
    expect(instrument.liveClockArmed, isFalse);
    expect(instrument.footballTimeActive, isTrue);
    instrument.advanceMatchClock(15);
    expect(instrument.matchElapsedSeconds, 15);
    expect(instrument.noteLiveElapsed(const Duration(seconds: 5)), isFalse);
    expect(instrument.matchElapsedSeconds, 15);
  });
}
