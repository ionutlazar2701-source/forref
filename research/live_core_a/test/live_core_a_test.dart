import 'dart:convert';
import 'dart:io';

import 'package:live_core_a/live_core_a.dart';
import 'package:test/test.dart';

void main() {
  group('completeness', () {
    test('rejects missing confidence on critical tasks', () {
      for (final task in criticalTasks) {
        final record = _minimalCompleteExceptConfidence(task);
        expect(
          record.completenessVerdict,
          CompletenessVerdict.incompleteMissingConfidence,
        );
      }
    });

    test('non-critical score-adjacent timeOnly may omit confidence', () {
      final record = _minimalCompleteExceptConfidence(TrialTask.timeOnly);
      record.recordEvent(
        TelemetryEvent.factAnswered,
        DateTime.utc(2026, 1, 1, 12, 0, 5),
      );
      expect(record.completenessVerdict, CompletenessVerdict.complete);
    });
  });

  group('score grading', () {
    test('wrong-team attribution fails despite matching goals', () {
      final home = OpaqueTeamId('team_alpha');
      final away = OpaqueTeamId('team_beta');
      final expected = ExpectedScore(
        fact: ScoreFact(
          homeGoals: 2,
          awayGoals: 1,
          homeTeamId: home,
          awayTeamId: away,
        ),
      );
      final answer = ScoreFact(
        homeGoals: 2,
        awayGoals: 1,
        homeTeamId: away,
        awayTeamId: home,
      );
      expect(
        gradeScoreAnswer(expected: expected, answer: answer),
        ScoreAnswerVerdict.wrongTeamAttribution,
      );
    });
  });

  group('order generator', () {
    test('seed stability', () {
      const seed = 424242;
      final a = generateCounterbalancedOrder(seed: seed);
      final b = generateCounterbalancedOrder(seed: seed);
      expect(a, b);
    });

    test('does not embed expected answers in order records', () {
      final order = generateCounterbalancedOrder(seed: 99);
      final payload = exportOrderPlan(seed: 99, order: order);
      expect(orderPayloadEmbedsExpectedAnswer(payload), isFalse);
      for (final entry in order) {
        final json = entry.toJson();
        expect(orderPayloadEmbedsExpectedAnswer(json), isFalse);
        expect(json.keys, isNot(contains('expectedScore')));
      }
    });
  });

  group('export', () {
    test('round-trip JSON', () async {
      final harness = CentralInstrumentAHarness(orderSeed: 7);
      final session = harness.newSession(sessionId: 'sess_opaque_001');
      final dir = await Directory.systemTemp.createTemp('live_core_a_rt');
      final file = await exportSessionJson(session: session, directory: dir);
      final parsed = parseSessionJson(await file.readAsString());
      expect(parsed.sessionId, session.sessionId);
      expect(parsed.orderSeed, session.orderSeed);
      expect(parsed.participantOpaqueIds, session.participantOpaqueIds);
      expect(parsed.trials, isEmpty);

      final reencoded = const JsonEncoder.withIndent('  ')
          .convert(parsed.toJson());
      final parsedAgain = parseSessionJson(reencoded);
      expect(parsedAgain.sessionId, parsed.sessionId);
      expect(parsedAgain.orderSeed, parsed.orderSeed);
    });

    test('empty participant list does not invent results', () {
      final session = ResearchSession(
        sessionId: 'empty_participants',
        orderSeed: 1,
        participantOpaqueIds: [],
      );
      expect(session.recordedTrialsOnly, isEmpty);
      final json = session.toJson();
      expect(json['trials'], isEmpty);
      expect(json['participantOpaqueIds'], isEmpty);
    });
  });

  group('cautions / 002D', () {
    test('not formal-002d-scorable when recall unavailable', () {
      final record = TrialRecord(
        task: TrialTask.cautions,
        condition: 'C01',
      );
      expect(record.recallInstrument, RecallInstrumentStatus.unavailable);
      expect(record.formal002dScorable, isFalse);
      final json = record.toJson();
      expect(json['formal002dScorable'], isFalse);
      expect(json['recallInstrument'], 'unavailable');
    });
  });

  group('telemetry names', () {
    test('exact event name set', () {
      expect(TelemetryEvent.all, [
        'trial_started',
        'stimulus_presented',
        'wrist_glance_started',
        'answer_or_action_requested',
        'target_touch',
        'destination_opened',
        'fact_answered',
        'confidence_recorded',
        'return_requested',
        'live_reacquired',
        'trial_completed',
      ]);
    });
  });
}

TrialRecord _minimalCompleteExceptConfidence(TrialTask task) {
  final t0 = DateTime.utc(2026, 1, 1, 12);
  final record = TrialRecord(task: task, condition: 'C00');
  record.recordEvent(TelemetryEvent.trialStarted, t0);
  record.recordEvent(TelemetryEvent.stimulusPresented, t0.add(const Duration(seconds: 1)));
  record.recordEvent(TelemetryEvent.wristGlanceStarted, t0.add(const Duration(seconds: 2)));
  record.recordEvent(
    TelemetryEvent.answerOrActionRequested,
    t0.add(const Duration(seconds: 3)),
  );
  if (task == TrialTask.capture || task == TrialTask.cautions) {
    record.recordEvent(TelemetryEvent.targetTouch, t0.add(const Duration(seconds: 4)));
    record.recordEvent(TelemetryEvent.destinationOpened, t0.add(const Duration(seconds: 5)));
    record.recordEvent(TelemetryEvent.returnRequested, t0.add(const Duration(seconds: 6)));
    record.recordEvent(TelemetryEvent.liveReacquired, t0.add(const Duration(seconds: 7)));
  }
  if (task == TrialTask.timeOnly ||
      task == TrialTask.phaseOnly ||
      task == TrialTask.scoreOnly ||
      task == TrialTask.timeAndScore ||
      task == TrialTask.boundaryTime) {
    record.recordEvent(TelemetryEvent.factAnswered, t0.add(const Duration(seconds: 8)));
  }
  record.recordEvent(TelemetryEvent.trialCompleted, t0.add(const Duration(seconds: 9)));
  return record;
}
