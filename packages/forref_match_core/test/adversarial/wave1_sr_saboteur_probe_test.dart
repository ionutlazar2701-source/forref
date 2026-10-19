import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

/// Faithful WAVE 1-SR reproductions. Each expectation is the contract.
/// Production projection at 4e5fa663414b317f9bdfc05ccd7735bb07a71e90 fails them.
void main() {
  final projector = DeterministicMatchProjector(ProductionSemanticsResolver());
  const matchId = 'match-1';
  const rootDevice = 'dev-root';
  const otherDevice = 'dev-other';
  const principalId = 'ref-1';
  final teamA = MatchTeamId('team-alpha');
  final teamB = MatchTeamId('team-beta');

  final proof = ScoreCompletenessProof(
    matchAuthorityMode: MatchAuthorityMode.matchMemory,
    teamBindings: [
      MatchTeamBinding(matchId: matchId, teamId: teamA),
      MatchTeamBinding(matchId: matchId, teamId: teamB),
    ],
    generationOneRoot: const GenerationOneAuthorityRoot(
      matchId: matchId,
      principalId: principalId,
      deviceId: rootDevice,
    ),
  );

  MatchRecord record({
    required String recordId,
    required RecordKind recordKind,
    required int originSequence,
    required MatchRecordPayload payload,
    String originDevice = rootDevice,
    int generation = 1,
    List<RecordRelationship> relationships = const [],
  }) {
    return MatchRecord(
      recordId: recordId,
      matchId: matchId,
      recordKind: recordKind,
      schemaVersion: 1,
      recordedAt: DateTime.utc(2026, 10, 2, 12, originSequence),
      originDeviceId: originDevice,
      originSequence: originSequence,
      authorityContext: AuthorityContext(
        scope: const MainRefereeScope(),
        principal: const AuthorityPrincipal(principalId: principalId),
        activeCaptureDevice: ActiveCaptureDevice(deviceId: originDevice),
        generation: AuthorityGeneration(value: generation),
      ),
      relationships: relationships,
      payload: payload,
      integrity: const IntegrityMetadata(evidenceRefs: ['ev']),
    );
  }

  MatchProjectionState project(List<MatchRecord> records) {
    return projector.projectRecords(
      matchId: matchId,
      records: records,
      context: ProjectionContext(
        evaluatedAuthorityGeneration: 1,
        scoreCompletenessProof: proof,
      ),
    );
  }

  test('a sequence gap on a non-root origin does not yield KnownScore 0-0', () {
    final records = [
      record(
        recordId: 'started-1',
        recordKind: RecordKind.temporalFact,
        originSequence: 1,
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.matchStarted,
        ),
      ),
      record(
        recordId: 'other-1',
        recordKind: RecordKind.temporalFact,
        originSequence: 1,
        originDevice: otherDevice,
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.periodStarted,
          period: const PeriodIdentity(index: 1),
        ),
      ),
      record(
        recordId: 'other-3',
        recordKind: RecordKind.temporalFact,
        originSequence: 3,
        originDevice: otherDevice,
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.periodEnded,
          period: const PeriodIdentity(index: 1),
        ),
      ),
    ];
    final score = project(records).scoreProjection;
    expect(score, isA<ScoreUnavailable>(), reason: _describe(score));
    expect(score, isNot(KnownScore({teamA: 0, teamB: 0})));
  });

  test('a generation-2 goal is not included in KnownScore', () {
    final score = project([
      record(
        recordId: 'started-1',
        recordKind: RecordKind.temporalFact,
        originSequence: 1,
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.matchStarted,
        ),
      ),
      record(
        recordId: 'goal-gen2',
        recordKind: RecordKind.humanDetermination,
        originSequence: 2,
        generation: 2,
        payload: GoalPayload(
          scoringTeamId: teamA,
          captureIntentId: 'intent-gen2',
        ),
      ),
    ]).scoreProjection;
    expect(score, isNot(isA<KnownScore>()), reason: _describe(score));
  });

  test('superseding the correction that repaired a goal does not keep that team', () {
    final score = project([
      record(
        recordId: 'started-1',
        recordKind: RecordKind.temporalFact,
        originSequence: 1,
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.matchStarted,
        ),
      ),
      record(
        recordId: 'goal-1',
        recordKind: RecordKind.humanDetermination,
        originSequence: 2,
        payload: GoalPayload(
          scoringTeamId: teamA,
          captureIntentId: 'intent-1',
        ),
      ),
      record(
        recordId: 'corr-1',
        recordKind: RecordKind.correction,
        originSequence: 3,
        relationships: const [CorrectionTarget(targetRecordId: 'goal-1')],
        payload: CorrectionPayload(repairedScoringTeamId: teamB),
      ),
      record(
        recordId: 'ss-corr',
        recordKind: RecordKind.legalSupersession,
        originSequence: 4,
        relationships: const [
          LegalSupersessionTarget(targetRecordId: 'corr-1'),
        ],
        payload: const LegalSupersessionPayload(),
      ),
    ]).scoreProjection;
    if (score is KnownScore) {
      expect(score.goalsByTeam[teamB], 0, reason: _describe(score));
      expect(score.goalsByTeam[teamA], 1, reason: _describe(score));
    } else {
      expect(
        score,
        anyOf(isA<ScoreUnavailable>(), isA<ScoreConflicted>()),
        reason: _describe(score),
      );
    }
  });
}

String _describe(ScoreProjection score) {
  if (score is KnownScore) {
    final pairs = score.goalsByTeam.entries
        .map((entry) => '${entry.key.value}=${entry.value}')
        .join(',');
    return 'KnownScore($pairs)';
  }
  return score.runtimeType.toString();
}
