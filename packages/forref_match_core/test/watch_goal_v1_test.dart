import 'dart:convert';
import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

void main() {
  test('the watch goal envelope is the Dart GOAL interpretation', () {
    final fixture = jsonDecode(
      File('test/fixtures/watch_goal_v1.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final envelope = WatchGoalEnvelope(
      matchId: 'match-watch-001',
      recordId: 'goal-home-1',
      captureIntentId: 'intent-home-1',
      scoringTeamId: 'team-alpha-001',
      principalId: 'referee-001',
      writerDeviceId: '6f1e2d3c-4b5a-4678-9abc-def012345678',
      originSequence: 1,
    );
    expect(envelope.canonical, fixture['canonical']);
    expect(envelope.contentHash, fixture['contentHash']);
    expect(envelope.recordKind, RecordKind.humanDetermination);
    expect(envelope.goalPayload.semanticType, V1SemanticTypeCode.goal);
    expect(envelope.goalPayload.semanticType.wireValue, 'GOAL');
    expect(envelope.goalPayload.scoringTeamId.value, 'team-alpha-001');
    expect(envelope.goalPayload.captureIntentId, 'intent-home-1');
    expect(parseWatchGoalV1(envelope.canonical)?.contentHash,
        fixture['contentHash']);
    expect(envelope.canonical.contains('HOME'), isFalse);
    expect(watchGoalLocalRecordLabel, 'LOCAL RECORD VERIFIED — D1 UNCERTIFIED');
  });
}
