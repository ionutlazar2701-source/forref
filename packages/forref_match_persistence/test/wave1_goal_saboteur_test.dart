import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:test/test.dart';

/// Store-level attacks: one capture intent must not become two goals, and a
/// different scoring team for that intent must not append.
void main() {
  late Directory temp;
  final projector = DeterministicMatchProjector(ProductionSemanticsResolver());

  const matchId = 'match-1';
  const deviceId = 'dev-a';
  const otherDeviceId = 'dev-b';
  const principalId = 'ref-1';
  final teamA = MatchTeamId('team-alpha');
  final teamB = MatchTeamId('team-beta');

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('wave1_goal_saboteur_');
  });

  tearDown(() async {
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  CaptureIntentKey keyFor(String captureIntentId) => CaptureIntentKey(
        matchId: matchId,
        authorityScope: v1AuthorityScope,
        captureIntentId: captureIntentId,
      );

  CaptureIntentMeaning meaningFor(MatchTeamId team) => CaptureIntentMeaning(
        semanticType: V1SemanticTypeCode.goal,
        authorityPrincipalId: principalId,
        authorityGeneration: 1,
        scoringTeamId: team,
      );

  Future<List<MatchRecord>> reopen(File file) async {
    final store = SqliteDurableMatchStore.open(file);
    try {
      return await store.readCommittedForMatch(matchId);
    } finally {
      await store.close();
    }
  }

  KnownScore projectScore(List<MatchRecord> records) {
    final projection = projector.projectRecords(
      matchId: matchId,
      records: records,
      context: ProjectionContext(
        evaluatedAuthorityGeneration: 1,
        scoreCompletenessProof: ScoreCompletenessProof(
          matchAuthorityMode: MatchAuthorityMode.matchMemory,
          teamBindings: [
            MatchTeamBinding(matchId: matchId, teamId: teamA),
            MatchTeamBinding(matchId: matchId, teamId: teamB),
          ],
          generationOneRoot: const GenerationOneAuthorityRoot(
            matchId: matchId,
            principalId: principalId,
            deviceId: deviceId,
          ),
        ),
      ),
    );
    expect(projection.scoreProjection, isA<KnownScore>());
    return projection.scoreProjection as KnownScore;
  }

  test('one capture intent cannot become two goals', () async {
    final file = File('${temp.path}/one-intent.sqlite');
    final store = SqliteDurableMatchStore.open(file);
    try {
      expect(
        await store.commitGenerationOneAuthorityRoot(
          const GenerationOneAuthorityRoot(
            matchId: matchId,
            principalId: principalId,
            deviceId: deviceId,
          ),
        ),
        isA<GenerationOneRootCommitSuccess>(),
      );
      final first = await store.commit(
        _goal(
          recordId: 'goal-1',
          captureIntentId: 'intent-1',
          scoringTeam: teamA,
        ),
      );
      expect(first, isA<DurableCommitSuccess>());

      final committed = await store.readCommittedForMatch(matchId);
      final decision = evaluateCaptureIntentAdmission(
        key: keyFor('intent-1'),
        requestedMeaning: meaningFor(teamA),
        committedForMatch: committed,
      );
      expect(decision, isA<CaptureIntentIdempotent>());
      expect(
        (decision as CaptureIntentIdempotent).existingRecordId,
        'goal-1',
      );

      final otherDevice = await store.commit(
        _goal(
          recordId: 'goal-2',
          captureIntentId: 'intent-1',
          scoringTeam: teamA,
          originDeviceId: otherDeviceId,
        ),
      );
      expect(otherDevice, isA<DurableCommitSuccess>());
      expect(
        (otherDevice as DurableCommitSuccess).committedRecordId,
        'goal-1',
      );

      final nextSlot = await store.commit(
        _goal(
          recordId: 'goal-3',
          captureIntentId: 'intent-1',
          scoringTeam: teamA,
          originSequence: 2,
        ),
      );
      expect(nextSlot, isA<DurableCommitSuccess>());
      expect((nextSlot as DurableCommitSuccess).committedRecordId, 'goal-1');
      expect(await store.readCommittedForMatch(matchId), hasLength(1));
      expect(store.captureIntentAdmissionCount(matchId: matchId), 1);
    } finally {
      await store.close();
    }

    final durable = await reopen(file);
    expect(durable.map((item) => item.recordId), ['goal-1']);
    final score = projectScore(durable);
    expect(score.goalsByTeam[teamA], 1);
    expect(score.goalsByTeam[teamB], 0);
  });

  test(
    'concurrent store connections cannot persist two goals for one capture intent',
    () async {
      final file = File('${temp.path}/race.sqlite');
      final left = SqliteDurableMatchStore.open(file);
      final right = SqliteDurableMatchStore.open(file);
      try {
        expect(
          await left.commitGenerationOneAuthorityRoot(
            const GenerationOneAuthorityRoot(
              matchId: matchId,
              principalId: principalId,
              deviceId: deviceId,
            ),
          ),
          isA<GenerationOneRootCommitSuccess>(),
        );
        final results = await Future.wait([
          left.commit(
            _goal(
              recordId: 'goal-a',
              captureIntentId: 'intent-race',
              scoringTeam: teamA,
            ),
          ),
          right.commit(
            _goal(
              recordId: 'goal-b',
              captureIntentId: 'intent-race',
              scoringTeam: teamA,
              originDeviceId: otherDeviceId,
            ),
          ),
        ]);
        expect(results.whereType<DurableCommitSuccess>(), isNotEmpty);
      } finally {
        await left.close();
        await right.close();
      }

      final durable = await reopen(file);
      final goals = [
        for (final item in durable)
          if (item.payload is GoalPayload) item,
      ];
      expect(goals, hasLength(1));
      final score = projectScore(goals);
      expect(score.goalsByTeam[teamA], 1);
      expect(score.goalsByTeam[teamB], 0);
    },
  );

  test(
    'same intent with a different scoring team is a conflict and does not append',
    () async {
      final file = File('${temp.path}/conflict.sqlite');
      final store = SqliteDurableMatchStore.open(file);
      try {
        expect(
          await store.commitGenerationOneAuthorityRoot(
            const GenerationOneAuthorityRoot(
              matchId: matchId,
              principalId: principalId,
              deviceId: deviceId,
            ),
          ),
          isA<GenerationOneRootCommitSuccess>(),
        );
        expect(
          await store.commit(
            _goal(
              recordId: 'goal-1',
              captureIntentId: 'intent-1',
              scoringTeam: teamA,
            ),
          ),
          isA<DurableCommitSuccess>(),
        );

        final committed = await store.readCommittedForMatch(matchId);
        final decision = evaluateCaptureIntentAdmission(
          key: keyFor('intent-1'),
          requestedMeaning: meaningFor(teamB),
          committedForMatch: committed,
        );
        expect(decision, isA<CaptureIntentConflict>());

        final outcome = await store.commit(
          _goal(
            recordId: 'goal-2',
            captureIntentId: 'intent-1',
            scoringTeam: teamB,
            originDeviceId: otherDeviceId,
            originSequence: 1,
          ),
        );
        expect(outcome, isA<DurableCommitFailure>());
        expect(
          (outcome as DurableCommitFailure).reason,
          contains('idempotency conflict'),
        );
        expect(await store.getById('goal-2'), isNull);
        expect(await store.readCommittedForMatch(matchId), hasLength(1));
        expect(store.captureIntentAdmissionCount(matchId: matchId), 1);
      } finally {
        await store.close();
      }

      final durable = await reopen(file);
      expect(durable.map((item) => item.recordId), ['goal-1']);
      final score = projectScore(durable);
      expect(score.goalsByTeam[teamA], 1);
      expect(score.goalsByTeam[teamB], 0);
    },
  );
}

MatchRecord _goal({
  required String recordId,
  required String captureIntentId,
  required MatchTeamId scoringTeam,
  String originDeviceId = 'dev-a',
  int originSequence = 1,
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: 'match-1',
    recordKind: RecordKind.humanDetermination,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 2, 12, originSequence),
    originDeviceId: originDeviceId,
    originSequence: originSequence,
    payload: GoalPayload(
      scoringTeamId: scoringTeam,
      captureIntentId: captureIntentId,
    ),
    integrity: const IntegrityMetadata(evidenceRefs: ['evidence-1']),
    authorityContext: AuthorityContext(
      scope: v1AuthorityScope,
      principal: const AuthorityPrincipal(principalId: 'ref-1'),
      activeCaptureDevice: ActiveCaptureDevice(deviceId: originDeviceId),
      generation: const AuthorityGeneration(value: 1),
    ),
  );
}
