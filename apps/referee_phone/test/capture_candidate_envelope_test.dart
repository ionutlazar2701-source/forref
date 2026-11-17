import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('the watch candidate envelope is a wire fixture, not a Match Record', () {
    final file = File('../forref_watch_zepp/test/fixtures/valid_goal_envelope.json');
    final raw = file.readAsStringSync();
    final envelope = jsonDecode(raw) as Map<String, Object?>;
    final payload = envelope['canonicalCandidatePayload'] as Map<String, Object?>;

    expect(envelope['candidateSchemaVersion'], 1);
    expect(envelope['admissionState'], 'VALID_STRUCTURED_CANDIDATE');
    expect(envelope['admissionState'], isNot('DurableCommitSuccess'));
    expect(envelope['matchId'], 'SIM_MATCH_001');
    expect(envelope['captureIntentId'], envelope['candidateId']);
    expect(envelope['localOriginDeviceId'], 'SIM_DEVICE_001');
    expect(envelope['localSequence'], 1);
    expect(envelope['createdUtcDiagnosticOnly'], isNull);
    expect(envelope.containsKey('matchTime'), isFalse);
    expect(payload['kind'], 'GOAL');
    expect(payload['matchTeamId'], 'SIM_TEAM_HOME');
    expect(payload['matchTeamId'], isNot('HOME'));
    expect(payload.containsKey('player'), isFalse);
    expect(raw.contains('Saved'), isFalse);
    expect(raw.contains('DurableCommitSuccess'), isFalse);
  });
}
