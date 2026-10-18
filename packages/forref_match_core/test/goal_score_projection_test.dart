import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

void main() {
  final resolver = ProductionSemanticsResolver();
  final projector = DeterministicMatchProjector(resolver);

  const matchId = 'match-1';
  const deviceId = 'dev-a';
  const principalId = 'ref-1';
  final teamA = MatchTeamId('team-alpha');
  final teamB = MatchTeamId('team-beta');

  ScoreCompletenessProof proof() => ScoreCompletenessProof(
        matchAuthorityMode: MatchAuthorityMode.matchMemory,
        teamBindings: [
          MatchTeamBinding(matchId: matchId, teamId: teamA),
          MatchTeamBinding(matchId: matchId, teamId: teamB),
        ],
        generationOneRoot: GenerationOneAuthorityRoot(
          matchId: matchId,
          principalId: principalId,
          deviceId: deviceId,
        ),
        integrityAccepted: true,
      );

  ProjectionContext context({ScoreCompletenessProof? scoreProof}) =>
      ProjectionContext(
        evaluatedAuthorityGeneration: 1,
        scoreCompletenessProof: scoreProof,
      );

  AuthorityContext authority() => AuthorityContext(
        scope: const MainRefereeScope(),
        principal: AuthorityPrincipal(principalId: principalId),
        activeCaptureDevice: ActiveCaptureDevice(deviceId: deviceId),
        generation: const AuthorityGeneration(value: 1),
      );

  MatchRecord bootstrap() {
    final started = MatchRecord(
      recordId: 'started-1',
      matchId: matchId,
      recordKind: RecordKind.temporalFact,
      schemaVersion: 1,
      recordedAt: DateTime.utc(2026, 10, 2, 12),
      originDeviceId: deviceId,
      originSequence: 1,
      authorityContext: authority(),
      payload: TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.matchStarted,
      ),
      integrity: const IntegrityMetadata(evidenceRefs: ['ev-1']),
    );
    return started;
  }

  MatchRecord goalRecord({
    required String recordId,
    required String captureIntentId,
    required MatchTeamId scoringTeam,
    int originSequence = 2,
    TemporalContext? temporalContext,
  }) {
    return MatchRecord(
      recordId: recordId,
      matchId: matchId,
      recordKind: RecordKind.humanDetermination,
      schemaVersion: 1,
      recordedAt: DateTime.utc(2026, 10, 2, 12, originSequence),
      originDeviceId: deviceId,
      originSequence: originSequence,
      authorityContext: authority(),
      temporalContext: temporalContext,
      payload: GoalPayload(
        scoringTeamId: scoringTeam,
        captureIntentId: captureIntentId,
      ),
      integrity: const IntegrityMetadata(evidenceRefs: ['ev-goal']),
    );
  }

  group('Goal score projection', () {
    test('empty history is ScoreUnavailable', () {
      final projection = projector.projectRecords(
        matchId: matchId,
        records: const [],
        context: context(scoreProof: proof()),
      );
      expect(projection.scoreProjection, isA<ScoreUnavailable>());
      expect(projection.trustFor(ProjectionFacet.score), ProjectionTrust.untrusted);
    });

    test('valid proof with zero effective goals is KnownScore 0-0', () {
      final projection = projector.projectRecords(
        matchId: matchId,
        records: [bootstrap()],
        context: context(scoreProof: proof()),
      );
      expect(projection.scoreProjection, isA<KnownScore>());
      final known = projection.scoreProjection as KnownScore;
      expect(known.goalsByTeam[teamA], 0);
      expect(known.goalsByTeam[teamB], 0);
      expect(projection.trustFor(ProjectionFacet.score), ProjectionTrust.trusted);
    });

    test('idempotent same intent vs conflict on different team', () {
      final key = CaptureIntentKey(
        matchId: matchId,
        authorityScope: const MainRefereeScope(),
        captureIntentId: 'intent-1',
      );
      final meaningA = CaptureIntentMeaning(
        semanticType: V1SemanticTypeCode.goal,
        authorityPrincipalId: principalId,
        authorityGeneration: 1,
        scoringTeamId: teamA,
      );
      final meaningB = CaptureIntentMeaning(
        semanticType: V1SemanticTypeCode.goal,
        authorityPrincipalId: principalId,
        authorityGeneration: 1,
        scoringTeamId: teamB,
      );
      final committed = [
        goalRecord(
          recordId: 'goal-1',
          captureIntentId: 'intent-1',
          scoringTeam: teamA,
        ),
      ];
      expect(
        evaluateCaptureIntentAdmission(
          key: key,
          requestedMeaning: meaningA,
          committedForMatch: committed,
        ),
        isA<CaptureIntentIdempotent>(),
      );
      expect(
        evaluateCaptureIntentAdmission(
          key: key,
          requestedMeaning: meaningB,
          committedForMatch: committed,
        ),
        isA<CaptureIntentConflict>(),
      );
    });

    test('missing correction target yields unavailable score', () {
      final goal = goalRecord(
        recordId: 'goal-1',
        captureIntentId: 'intent-1',
        scoringTeam: teamA,
      );
      final orphanCorrection = MatchRecord(
        recordId: 'corr-1',
        matchId: matchId,
        recordKind: RecordKind.correction,
        schemaVersion: 1,
        recordedAt: DateTime.utc(2026, 10, 2, 12, 3),
        originDeviceId: deviceId,
        originSequence: 3,
        authorityContext: authority(),
        relationships: const [CorrectionTarget(targetRecordId: 'missing-goal')],
        payload: CorrectionPayload(repairedScoringTeamId: teamB),
        integrity: const IntegrityMetadata(evidenceRefs: ['ev-c']),
      );
      final projection = projector.projectRecords(
        matchId: matchId,
        records: [bootstrap(), goal, orphanCorrection],
        context: context(scoreProof: proof()),
      );
      expect(projection.scoreProjection, isA<ScoreUnavailable>());
    });

    test('competing corrections yield conflicted score', () {
      final goal = goalRecord(
        recordId: 'goal-1',
        captureIntentId: 'intent-1',
        scoringTeam: teamA,
      );
      MatchRecord correction(String id, int seq, MatchTeamId team) =>
          MatchRecord(
            recordId: id,
            matchId: matchId,
            recordKind: RecordKind.correction,
            schemaVersion: 1,
            recordedAt: DateTime.utc(2026, 10, 2, 12, seq),
            originDeviceId: deviceId,
            originSequence: seq,
            authorityContext: authority(),
            relationships: const [CorrectionTarget(targetRecordId: 'goal-1')],
            payload: CorrectionPayload(repairedScoringTeamId: team),
            integrity: const IntegrityMetadata(evidenceRefs: ['ev-c']),
          );
      final projection = projector.projectRecords(
        matchId: matchId,
        records: [
          bootstrap(),
          goal,
          correction('corr-a', 3, teamA),
          correction('corr-b', 4, teamB),
        ],
        context: context(scoreProof: proof()),
      );
      expect(projection.scoreProjection, isA<ScoreConflicted>());
    });

    test('supersession removes goal; reversal restores same goal id', () {
      final goal = goalRecord(
        recordId: 'goal-1',
        captureIntentId: 'intent-1',
        scoringTeam: teamA,
      );
      final supersedeGoal = MatchRecord(
        recordId: 'ls-1',
        matchId: matchId,
        recordKind: RecordKind.legalSupersession,
        schemaVersion: 1,
        recordedAt: DateTime.utc(2026, 10, 2, 12, 3),
        originDeviceId: deviceId,
        originSequence: 3,
        authorityContext: authority(),
        relationships: const [LegalSupersessionTarget(targetRecordId: 'goal-1')],
        payload: const LegalSupersessionPayload(),
        integrity: const IntegrityMetadata(evidenceRefs: ['ev-ls']),
      );
      final withoutGoal = projector.projectRecords(
        matchId: matchId,
        records: [bootstrap(), goal, supersedeGoal],
        context: context(scoreProof: proof()),
      );
      expect(withoutGoal.scoreProjection, isA<KnownScore>());
      expect((withoutGoal.scoreProjection as KnownScore).goalsByTeam[teamA], 0);

      final reverse = MatchRecord(
        recordId: 'ls-2',
        matchId: matchId,
        recordKind: RecordKind.legalSupersession,
        schemaVersion: 1,
        recordedAt: DateTime.utc(2026, 10, 2, 12, 4),
        originDeviceId: deviceId,
        originSequence: 4,
        authorityContext: authority(),
        relationships: const [LegalSupersessionTarget(targetRecordId: 'ls-1')],
        payload: const LegalSupersessionPayload(),
        integrity: const IntegrityMetadata(evidenceRefs: ['ev-ls2']),
      );
      final restored = projector.projectRecords(
        matchId: matchId,
        records: [bootstrap(), goal, supersedeGoal, reverse],
        context: context(scoreProof: proof()),
      );
      expect(restored.scoreProjection, isA<KnownScore>());
      expect((restored.scoreProjection as KnownScore).goalsByTeam[teamA], 1);
    });

    test('cycle yields unavailable score, not a numeral', () {
      final lsA = MatchRecord(
        recordId: 'ls-a',
        matchId: matchId,
        recordKind: RecordKind.legalSupersession,
        schemaVersion: 1,
        recordedAt: DateTime.utc(2026, 10, 2, 12, 2),
        originDeviceId: deviceId,
        originSequence: 2,
        authorityContext: authority(),
        relationships: const [LegalSupersessionTarget(targetRecordId: 'ls-b')],
        payload: const LegalSupersessionPayload(),
        integrity: const IntegrityMetadata(evidenceRefs: ['ev-a']),
      );
      final lsB = MatchRecord(
        recordId: 'ls-b',
        matchId: matchId,
        recordKind: RecordKind.legalSupersession,
        schemaVersion: 1,
        recordedAt: DateTime.utc(2026, 10, 2, 12, 3),
        originDeviceId: deviceId,
        originSequence: 3,
        authorityContext: authority(),
        relationships: const [LegalSupersessionTarget(targetRecordId: 'ls-a')],
        payload: const LegalSupersessionPayload(),
        integrity: const IntegrityMetadata(evidenceRefs: ['ev-b']),
      );
      final projection = projector.projectRecords(
        matchId: matchId,
        records: [bootstrap(), lsA, lsB],
        context: context(scoreProof: proof()),
      );
      expect(projection.scoreProjection, isA<ScoreUnavailable>());
      expect(projection.trustFor(ProjectionFacet.score), isNot(ProjectionTrust.trusted));
    });

    test('permuting record order does not change effective goals', () {
      final goal = goalRecord(
        recordId: 'goal-1',
        captureIntentId: 'intent-1',
        scoringTeam: teamA,
        originSequence: 2,
      );
      final records = [bootstrap(), goal];
      final forward = projector.projectRecords(
        matchId: matchId,
        records: records,
        context: context(scoreProof: proof()),
      );
      final reversed = projector.projectRecords(
        matchId: matchId,
        records: records.reversed.toList(),
        context: context(scoreProof: proof()),
      );
      expect(forward.scoreProjection, reversed.scoreProjection);
    });

    test('temporal context absent still allows goal to count with proof', () {
      final goal = goalRecord(
        recordId: 'goal-1',
        captureIntentId: 'intent-1',
        scoringTeam: teamA,
        temporalContext: null,
      );
      final projection = projector.projectRecords(
        matchId: matchId,
        records: [bootstrap(), goal],
        context: context(scoreProof: proof()),
      );
      expect(projection.scoreProjection, isA<KnownScore>());
      expect((projection.scoreProjection as KnownScore).goalsByTeam[teamA], 1);
    });
  });
}
