import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// Store and decoded-history attacks against fa4a797.
void main() {
  late Directory temp;
  final projector = DeterministicMatchProjector(ProductionSemanticsResolver());
  const matchId = 'match-1';
  const rootDevice = 'dev-root';
  const otherDevice = 'dev-other';
  const principalId = 'ref-1';
  final teamA = MatchTeamId('team-alpha');
  final teamB = MatchTeamId('team-beta');

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('wave1_r_attack_');
  });

  tearDown(() async {
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  MatchRecord record({
    required String recordId,
    required RecordKind recordKind,
    required int originSequence,
    required MatchRecordPayload payload,
    String originDevice = rootDevice,
    int? generation = 1,
    String principal = principalId,
    AuthorityScope? scope,
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
        scope: scope ?? const MainRefereeScope(),
        principal: AuthorityPrincipal(principalId: principal),
        activeCaptureDevice: ActiveCaptureDevice(deviceId: originDevice),
        generation:
            generation == null ? null : AuthorityGeneration(value: generation),
      ),
      relationships: relationships,
      payload: payload,
      integrity: const IntegrityMetadata(evidenceRefs: ['evidence-1']),
    );
  }

  MatchRecord started({int originSequence = 1}) {
    return record(
      recordId: 'started-$originSequence',
      recordKind: RecordKind.temporalFact,
      originSequence: originSequence,
      payload: TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.matchStarted,
      ),
    );
  }

  MatchRecord goal({
    required String recordId,
    required String captureIntentId,
    required MatchTeamId team,
    int originSequence = 2,
    int? generation = 1,
    String originDevice = rootDevice,
    String principal = principalId,
    AuthorityScope? scope,
  }) {
    return record(
      recordId: recordId,
      recordKind: RecordKind.humanDetermination,
      originSequence: originSequence,
      originDevice: originDevice,
      generation: generation,
      principal: principal,
      scope: scope,
      payload: GoalPayload(
        scoringTeamId: team,
        captureIntentId: captureIntentId,
      ),
    );
  }

  ScoreProjection scoreOf(List<MatchRecord> records) {
    return projector
        .projectRecords(
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
                deviceId: rootDevice,
              ),
            ),
          ),
        )
        .scoreProjection;
  }

  Future<GenerationOneRootCommitResult> admitRoot(SqliteDurableMatchStore store) {
    return store.commitGenerationOneAuthorityRoot(
      const GenerationOneAuthorityRoot(
        matchId: matchId,
        principalId: principalId,
        deviceId: rootDevice,
      ),
    );
  }

  test('root sequence gap stored beside a goal is not KnownScore', () async {
    final store = SqliteDurableMatchStore.open(File('${temp.path}/gap.sqlite'));
    try {
      expect(await admitRoot(store), isA<GenerationOneRootCommitSuccess>());
      expect(await store.commit(started()), isA<DurableCommitSuccess>());
      expect(
        await store.commit(
          goal(
            recordId: 'goal-gap',
            captureIntentId: 'intent-gap',
            team: teamA,
            originSequence: 3,
          ),
        ),
        isA<DurableCommitSuccess>(),
      );
      final records = await store.readCommittedForMatch(matchId);
      final score = scoreOf(records);
      expect(score, isA<ScoreUnavailable>(), reason: _describe(score));
      expect(score, isNot(KnownScore({teamA: 1, teamB: 0})));
      expect(score, isNot(KnownScore({teamA: 0, teamB: 0})));
    } finally {
      await store.close();
    }
  });

  test('contiguous foreign origin beside a stored root goal is not KnownScore',
      () async {
    final store =
        SqliteDurableMatchStore.open(File('${temp.path}/foreign.sqlite'));
    try {
      expect(await admitRoot(store), isA<GenerationOneRootCommitSuccess>());
      expect(await store.commit(started()), isA<DurableCommitSuccess>());
      expect(
        await store.commit(
          goal(
            recordId: 'goal-root',
            captureIntentId: 'intent-root',
            team: teamA,
          ),
        ),
        isA<DurableCommitSuccess>(),
      );
      expect(
        await store.commit(
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
        ),
        isA<DurableCommitSuccess>(),
      );
      final score = scoreOf(await store.readCommittedForMatch(matchId));
      expect(score, isA<ScoreUnavailable>(), reason: _describe(score));
      expect(score, isNot(KnownScore({teamA: 1, teamB: 0})));
    } finally {
      await store.close();
    }
  });

  test('wrong principal, wrong device, and generation 2 store nothing', () async {
    final store =
        SqliteDurableMatchStore.open(File('${temp.path}/reject.sqlite'));
    try {
      expect(await admitRoot(store), isA<GenerationOneRootCommitSuccess>());
      expect(await store.commit(started()), isA<DurableCommitSuccess>());

      final wrongPrincipal = await store.commit(
        goal(
          recordId: 'goal-principal',
          captureIntentId: 'intent-principal',
          team: teamA,
          originSequence: 2,
          principal: 'ref-other',
        ),
      );
      final wrongDevice = await store.commit(
        goal(
          recordId: 'goal-device',
          captureIntentId: 'intent-device',
          team: teamA,
          originSequence: 2,
          originDevice: otherDevice,
        ),
      );
      final generationTwo = await store.commit(
        goal(
          recordId: 'goal-gen2',
          captureIntentId: 'intent-gen2',
          team: teamA,
          originSequence: 2,
          generation: 2,
        ),
      );
      final nullGeneration = await store.commit(
        goal(
          recordId: 'goal-null',
          captureIntentId: 'intent-null',
          team: teamA,
          originSequence: 2,
          generation: null,
        ),
      );

      expect(wrongPrincipal, isA<DurableCommitFailure>());
      expect(wrongDevice, isA<DurableCommitFailure>());
      expect(generationTwo, isA<DurableCommitFailure>());
      expect(nullGeneration, isA<DurableCommitFailure>());

      final records = await store.readCommittedForMatch(matchId);
      expect(records.map((item) => item.recordId), ['started-1']);
      expect(records.where((item) => item.payload is GoalPayload), isEmpty);
      expect(store.captureIntentAdmissionCount(matchId: matchId), 0);
      expect(await store.getById('goal-principal'), isNull);
      expect(await store.getById('goal-device'), isNull);
      expect(await store.getById('goal-gen2'), isNull);
      expect(await store.getById('goal-null'), isNull);
    } finally {
      await store.close();
    }
  });

  test('commitAtNextOriginSequence rejects bad goals and does not skip a slot',
      () async {
    final store =
        SqliteDurableMatchStore.open(File('${temp.path}/next.sqlite'));
    try {
      expect(await admitRoot(store), isA<GenerationOneRootCommitSuccess>());
      expect(await store.commit(started()), isA<DurableCommitSuccess>());

      Future<DurableCommitResult> propose({
        required String recordId,
        required String captureIntentId,
        required String originDevice,
        required String principal,
        required int generation,
        required AuthorityScope scope,
      }) {
        return store.commitAtNextOriginSequence(
          AuthoritativeRecordCommitRequest(
            recordId: recordId,
            matchId: matchId,
            originDeviceId: originDevice,
            recordKind: RecordKind.humanDetermination,
            schemaVersion: 1,
            recordedAt: DateTime.utc(2026, 10, 2, 12, 2),
            payload: GoalPayload(
              scoringTeamId: teamA,
              captureIntentId: captureIntentId,
            ),
            integrity: const IntegrityMetadata(evidenceRefs: ['evidence-1']),
            authorityContext: AuthorityContext(
              scope: scope,
              principal: AuthorityPrincipal(principalId: principal),
              activeCaptureDevice: ActiveCaptureDevice(deviceId: originDevice),
              generation: AuthorityGeneration(value: generation),
            ),
          ),
        );
      }

      expect(
        await propose(
          recordId: 'goal-gen2',
          captureIntentId: 'intent-gen2',
          originDevice: rootDevice,
          principal: principalId,
          generation: 2,
          scope: MainRefereeScope(),
        ),
        isA<DurableCommitFailure>(),
      );
      expect(
        await propose(
          recordId: 'goal-principal',
          captureIntentId: 'intent-principal',
          originDevice: rootDevice,
          principal: 'ref-other',
          generation: 1,
          scope: const MainRefereeScope(),
        ),
        isA<DurableCommitFailure>(),
      );
      expect(
        await propose(
          recordId: 'goal-device',
          captureIntentId: 'intent-device',
          originDevice: otherDevice,
          principal: principalId,
          generation: 1,
          scope: v1AuthorityScope,
        ),
        isA<DurableCommitFailure>(),
      );

      final admitted = await propose(
        recordId: 'goal-ok',
        captureIntentId: 'intent-ok',
        originDevice: rootDevice,
        principal: principalId,
        generation: 1,
        scope: MainRefereeScope(),
      );
      expect(admitted, isA<DurableCommitSuccess>());
      final records = await store.readCommittedForMatch(matchId);
      final goals = records.where((item) => item.payload is GoalPayload);
      expect(goals.map((item) => item.recordId), ['goal-ok']);
      expect(goals.single.originSequence, 2);
      expect(store.captureIntentAdmissionCount(matchId: matchId), 1);
    } finally {
      await store.close();
    }
  });

  test('same-command generation-1 retry still returns the existing goal', () async {
    final store =
        SqliteDurableMatchStore.open(File('${temp.path}/retry.sqlite'));
    try {
      expect(await admitRoot(store), isA<GenerationOneRootCommitSuccess>());
      final first = await store.commit(
        goal(
          recordId: 'goal-1',
          captureIntentId: 'intent-1',
          team: teamA,
          originSequence: 1,
          scope: const MainRefereeScope(),
        ),
      );
      expect(first, isA<DurableCommitSuccess>());

      final retry = await store.commit(
        goal(
          recordId: 'goal-retry',
          captureIntentId: 'intent-1',
          team: teamA,
          originSequence: 2,
          scope: MainRefereeScope(),
        ),
      );
      expect(retry, isA<DurableCommitSuccess>());
      expect((retry as DurableCommitSuccess).committedRecordId, 'goal-1');
      expect(await store.readCommittedForMatch(matchId), hasLength(1));
      expect(store.captureIntentAdmissionCount(matchId: matchId), 1);
    } finally {
      await store.close();
    }
  });

  test('two MainRefereeScope instances cannot split one intent in the store',
      () async {
    final store =
        SqliteDurableMatchStore.open(File('${temp.path}/scope.sqlite'));
    try {
      expect(await admitRoot(store), isA<GenerationOneRootCommitSuccess>());
      final firstScope = MainRefereeScope();
      final secondScope = MainRefereeScope();
      expect(identical(firstScope, secondScope), isFalse);

      expect(
        await store.commit(
          goal(
            recordId: 'goal-1',
            captureIntentId: 'intent-split',
            team: teamA,
            originSequence: 1,
            scope: firstScope,
          ),
        ),
        isA<DurableCommitSuccess>(),
      );

      final sameTeam = await store.commit(
        goal(
          recordId: 'goal-2',
          captureIntentId: 'intent-split',
          team: teamA,
          originSequence: 2,
          scope: secondScope,
        ),
      );
      expect(sameTeam, isA<DurableCommitSuccess>());
      expect((sameTeam as DurableCommitSuccess).committedRecordId, 'goal-1');

      final otherTeam = await store.commit(
        goal(
          recordId: 'goal-3',
          captureIntentId: 'intent-split',
          team: teamB,
          originSequence: 3,
          scope: MainRefereeScope(),
        ),
      );
      expect(otherTeam, isA<DurableCommitFailure>());
      expect(
        (otherTeam as DurableCommitFailure).reason,
        contains('idempotency conflict'),
      );

      final records = await store.readCommittedForMatch(matchId);
      expect(records.where((item) => item.payload is GoalPayload), hasLength(1));
      expect(store.captureIntentAdmissionCount(matchId: matchId), 1);
      final score = scoreOf(records);
      expect(score, isA<KnownScore>(), reason: _describe(score));
      expect((score as KnownScore).goalsByTeam[teamA], 1);
      expect(score.goalsByTeam[teamB], 0);
    } finally {
      await store.close();
    }
  });

  test('a raw generation-2 goal row beside a valid goal is not KnownScore',
      () async {
    final file = File('${temp.path}/raw-gen2.sqlite');
    final store = SqliteDurableMatchStore.open(file);
    try {
      expect(await admitRoot(store), isA<GenerationOneRootCommitSuccess>());
      expect(await store.commit(started()), isA<DurableCommitSuccess>());
      expect(
        await store.commit(
          goal(
            recordId: 'goal-gen1',
            captureIntentId: 'intent-gen1',
            team: teamA,
          ),
        ),
        isA<DurableCommitSuccess>(),
      );
    } finally {
      await store.close();
    }

    final injected = goal(
      recordId: 'goal-gen2',
      captureIntentId: 'intent-gen2',
      team: teamA,
      originSequence: 3,
      generation: 2,
    );
    final db = sqlite3.open(file.path);
    db.execute(
      '''
      INSERT INTO committed_match_records (
        record_id, match_id, origin_device_id, origin_sequence, record_json
      ) VALUES (?, ?, ?, ?, ?)
      ''',
      [
        injected.recordId,
        injected.matchId,
        injected.originDeviceId,
        injected.originSequence,
        encodeMatchRecordJson(injected),
      ],
    );
    db.close();

    final reopened = SqliteDurableMatchStore.open(file);
    try {
      final records = await reopened.readCommittedForMatch(matchId);
      expect(records.where((item) => item.payload is GoalPayload), hasLength(2));
      expect(
        records
            .where((item) => item.payload is GoalPayload)
            .map((item) => item.authorityContext?.generation?.value)
            .toSet(),
        {1, 2},
      );
      final score = scoreOf(records);
      expect(score, isA<ScoreUnavailable>(), reason: _describe(score));
      expect(score, isNot(KnownScore({teamA: 1, teamB: 0})));
      expect(score, isNot(KnownScore({teamA: 2, teamB: 0})));
      expect(score, isNot(KnownScore({teamA: 0, teamB: 0})));
    } finally {
      await reopened.close();
    }
  });

  test('stored superseded correction is not KnownScore for the repaired team',
      () async {
    final store =
        SqliteDurableMatchStore.open(File('${temp.path}/corr.sqlite'));
    try {
      expect(await admitRoot(store), isA<GenerationOneRootCommitSuccess>());
      expect(await store.commit(started()), isA<DurableCommitSuccess>());
      expect(
        await store.commit(
          goal(
            recordId: 'goal-1',
            captureIntentId: 'intent-1',
            team: teamA,
          ),
        ),
        isA<DurableCommitSuccess>(),
      );
      expect(
        await store.commit(
          record(
            recordId: 'corr-1',
            recordKind: RecordKind.correction,
            originSequence: 3,
            relationships: const [CorrectionTarget(targetRecordId: 'goal-1')],
            payload: CorrectionPayload(repairedScoringTeamId: teamB),
          ),
        ),
        isA<DurableCommitSuccess>(),
      );

      final before = scoreOf(await store.readCommittedForMatch(matchId));
      expect(before, isA<KnownScore>(), reason: _describe(before));
      expect((before as KnownScore).goalsByTeam[teamB], 1);
      expect(before.goalsByTeam[teamA], 0);

      expect(
        await store.commit(
          record(
            recordId: 'ss-corr',
            recordKind: RecordKind.legalSupersession,
            originSequence: 4,
            relationships: const [
              LegalSupersessionTarget(targetRecordId: 'corr-1'),
            ],
            payload: const LegalSupersessionPayload(),
          ),
        ),
        isA<DurableCommitSuccess>(),
      );
      final after = scoreOf(await store.readCommittedForMatch(matchId));
      expect(after, isA<ScoreUnavailable>(), reason: _describe(after));
      expect(after, isNot(KnownScore({teamA: 0, teamB: 1})));

      expect(
        await store.commit(
          record(
            recordId: 'ss-goal',
            recordKind: RecordKind.legalSupersession,
            originSequence: 5,
            relationships: const [
              LegalSupersessionTarget(targetRecordId: 'goal-1'),
            ],
            payload: const LegalSupersessionPayload(),
          ),
        ),
        isA<DurableCommitSuccess>(),
      );
      expect(
        await store.commit(
          record(
            recordId: 'ss-restore-goal',
            recordKind: RecordKind.legalSupersession,
            originSequence: 6,
            relationships: const [
              LegalSupersessionTarget(targetRecordId: 'ss-goal'),
            ],
            payload: const LegalSupersessionPayload(),
          ),
        ),
        isA<DurableCommitSuccess>(),
      );
      final stillUnavailable =
          scoreOf(await store.readCommittedForMatch(matchId));
      expect(
        stillUnavailable,
        isA<ScoreUnavailable>(),
        reason: _describe(stillUnavailable),
      );
    } finally {
      await store.close();
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
