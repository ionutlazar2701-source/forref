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

  test('goal-only numerals match the local test fixture and stay KnownScore', () {
    final fixture = jsonDecode(
      File('test/fixtures/watch_local_score_v1.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final local = fixture['localTest']! as Map<String, Object?>;
    expect(local['knownScore'], isFalse);
    expect(local['kind'], 'local-test');
    const matchId = 'match-watch-001';
    final home = MatchTeamId('team-alpha-001');
    final away = MatchTeamId('team-beta-001');
    const deviceId = '6f1e2d3c-4b5a-4678-9abc-def012345678';
    const principalId = 'referee-001';
    AuthorityContext authority() => AuthorityContext(
          scope: const MainRefereeScope(),
          principal: AuthorityPrincipal(principalId: principalId),
          activeCaptureDevice: ActiveCaptureDevice(deviceId: deviceId),
          generation: const AuthorityGeneration(value: 1),
        );
    MatchRecord goal({
      required String recordId,
      required String captureIntentId,
      required MatchTeamId team,
      required int sequence,
    }) {
      return MatchRecord(
        recordId: recordId,
        matchId: matchId,
        recordKind: RecordKind.humanDetermination,
        schemaVersion: 1,
        recordedAt: DateTime.utc(2026, 11, 27, 12, sequence),
        originDeviceId: deviceId,
        originSequence: sequence,
        authorityContext: authority(),
        payload: GoalPayload(
          scoringTeamId: team,
          captureIntentId: captureIntentId,
        ),
        integrity: const IntegrityMetadata(evidenceRefs: ['ev-goal']),
      );
    }

    final started = MatchRecord(
      recordId: 'started-1',
      matchId: matchId,
      recordKind: RecordKind.temporalFact,
      schemaVersion: 1,
      recordedAt: DateTime.utc(2026, 11, 27, 12),
      originDeviceId: deviceId,
      originSequence: 1,
      authorityContext: authority(),
      payload: TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.matchStarted,
      ),
      integrity: const IntegrityMetadata(evidenceRefs: ['ev-start']),
    );
    final projection = DeterministicMatchProjector(ProductionSemanticsResolver())
        .projectRecords(
      matchId: matchId,
      records: [
        started,
        goal(
          recordId: 'goal-a',
          captureIntentId: 'intent-a',
          team: home,
          sequence: 2,
        ),
        goal(
          recordId: 'goal-b',
          captureIntentId: 'intent-b',
          team: away,
          sequence: 3,
        ),
      ],
      context: ProjectionContext(
        evaluatedAuthorityGeneration: 1,
        scoreCompletenessProof: ScoreCompletenessProof(
          matchAuthorityMode: MatchAuthorityMode.matchMemory,
          teamBindings: [
            MatchTeamBinding(matchId: matchId, teamId: home),
            MatchTeamBinding(matchId: matchId, teamId: away),
          ],
          generationOneRoot: GenerationOneAuthorityRoot(
            matchId: matchId,
            principalId: principalId,
            deviceId: deviceId,
          ),
        ),
      ),
    );
    final known = projection.scoreProjection;
    expect(known, isA<KnownScore>());
    expect((known as KnownScore).goalsByTeam[home], local['home']);
    expect(known.goalsByTeam[away], local['away']);
  });
}
