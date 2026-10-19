import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

/// New attacks against fa4a797. These are not the WAVE 1-SR probes.
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
    int? generation = 1,
    String principal = principalId,
    String recordMatchId = matchId,
    List<RecordRelationship> relationships = const [],
    AuthorityScope? scope,
  }) {
    return MatchRecord(
      recordId: recordId,
      matchId: recordMatchId,
      recordKind: recordKind,
      schemaVersion: 1,
      recordedAt: DateTime.utc(2026, 10, 2, 12, originSequence),
      originDeviceId: originDevice,
      originSequence: originSequence,
      authorityContext: AuthorityContext(
        scope: scope ?? MainRefereeScope(),
        principal: AuthorityPrincipal(principalId: principal),
        activeCaptureDevice: ActiveCaptureDevice(deviceId: originDevice),
        generation:
            generation == null ? null : AuthorityGeneration(value: generation),
      ),
      relationships: relationships,
      payload: payload,
      integrity: const IntegrityMetadata(evidenceRefs: ['ev']),
    );
  }

  MatchRecord started({int originSequence = 1, String originDevice = rootDevice}) {
    return record(
      recordId: 'started-$originDevice-$originSequence',
      recordKind: RecordKind.temporalFact,
      originSequence: originSequence,
      originDevice: originDevice,
      payload: TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.matchStarted,
      ),
    );
  }

  MatchRecord goal({
    required String recordId,
    required String captureIntentId,
    required MatchTeamId team,
    required int originSequence,
    int? generation = 1,
    String originDevice = rootDevice,
    String principal = principalId,
    AuthorityScope? scope,
    String recordMatchId = matchId,
  }) {
    return record(
      recordId: recordId,
      recordKind: RecordKind.humanDetermination,
      originSequence: originSequence,
      originDevice: originDevice,
      generation: generation,
      principal: principal,
      scope: scope,
      recordMatchId: recordMatchId,
      payload: GoalPayload(
        scoringTeamId: team,
        captureIntentId: captureIntentId,
      ),
    );
  }

  ScoreProjection project(List<MatchRecord> records) {
    return projector
        .projectRecords(
          matchId: matchId,
          records: records,
          context: ProjectionContext(
            evaluatedAuthorityGeneration: 1,
            scoreCompletenessProof: proof,
          ),
        )
        .scoreProjection;
  }

  test('root sequence gap 1,3 is ScoreUnavailable and not a numeral', () {
    final records = [
      started(),
      goal(
        recordId: 'goal-gap',
        captureIntentId: 'intent-gap',
        team: teamA,
        originSequence: 3,
      ),
    ];
    expect(records.map((item) => item.originSequence).toSet(), {1, 3});
    expect(records.map((item) => item.originDeviceId).toSet(), {rootDevice});
    final score = project(records);
    expect(score, isA<ScoreUnavailable>(), reason: _describe(score));
    expect(score, isNot(KnownScore({teamA: 1, teamB: 0})));
    expect(score, isNot(KnownScore({teamA: 0, teamB: 0})));
  });

  test('root history that starts at sequence 2 is ScoreUnavailable', () {
    final score = project([
      record(
        recordId: 'started-2',
        recordKind: RecordKind.temporalFact,
        originSequence: 2,
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.matchStarted,
        ),
      ),
      goal(
        recordId: 'goal-3',
        captureIntentId: 'intent-3',
        team: teamA,
        originSequence: 3,
      ),
    ]);
    expect(score, isA<ScoreUnavailable>(), reason: _describe(score));
  });

  test('duplicate sequence numbers do not fill a later root gap', () {
    final score = project([
      started(),
      record(
        recordId: 'started-1b',
        recordKind: RecordKind.temporalFact,
        originSequence: 1,
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.periodStarted,
          period: const PeriodIdentity(index: 1),
        ),
      ),
      goal(
        recordId: 'goal-4',
        captureIntentId: 'intent-4',
        team: teamA,
        originSequence: 4,
      ),
    ]);
    expect(score, isA<ScoreUnavailable>(), reason: _describe(score));
  });

  test('contiguous foreign origin beside a root goal is not KnownScore 1-0', () {
    final score = project([
      started(),
      goal(
        recordId: 'goal-root',
        captureIntentId: 'intent-root',
        team: teamA,
        originSequence: 2,
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
        recordId: 'other-2',
        recordKind: RecordKind.temporalFact,
        originSequence: 2,
        originDevice: otherDevice,
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.periodEnded,
          period: const PeriodIdentity(index: 1),
        ),
      ),
    ]);
    expect(score, isA<ScoreUnavailable>(), reason: _describe(score));
    expect(score, isNot(KnownScore({teamA: 1, teamB: 0})));
    expect(score, isNot(KnownScore({teamA: 0, teamB: 0})));
  });

  test('foreign-only contiguous history is not KnownScore 0-0', () {
    final score = project([
      record(
        recordId: 'other-1',
        recordKind: RecordKind.temporalFact,
        originSequence: 1,
        originDevice: otherDevice,
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.matchStarted,
        ),
      ),
      record(
        recordId: 'other-2',
        recordKind: RecordKind.temporalFact,
        originSequence: 2,
        originDevice: otherDevice,
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.periodStarted,
          period: const PeriodIdentity(index: 1),
        ),
      ),
    ]);
    expect(score, isA<ScoreUnavailable>(), reason: _describe(score));
    expect(score, isNot(isA<KnownScore>()));
  });

  test('complete root goal history is still KnownScore 1-0', () {
    final score = project([
      started(),
      goal(
        recordId: 'goal-1',
        captureIntentId: 'intent-1',
        team: teamA,
        originSequence: 2,
      ),
    ]);
    expect(score, isA<KnownScore>(), reason: _describe(score));
    final known = score as KnownScore;
    expect(known.goalsByTeam[teamA], 1);
    expect(known.goalsByTeam[teamB], 0);
  });

  test('generation-2 goal beside a generation-1 goal is not a numeral', () {
    final score = project([
      started(),
      goal(
        recordId: 'goal-gen1',
        captureIntentId: 'intent-gen1',
        team: teamA,
        originSequence: 2,
      ),
      goal(
        recordId: 'goal-gen2',
        captureIntentId: 'intent-gen2',
        team: teamA,
        originSequence: 3,
        generation: 2,
      ),
    ]);
    expect(score, isA<ScoreUnavailable>(), reason: _describe(score));
    expect(score, isNot(KnownScore({teamA: 1, teamB: 0})));
    expect(score, isNot(KnownScore({teamA: 2, teamB: 0})));
    expect(score, isNot(KnownScore({teamA: 0, teamB: 0})));
  });

  test('a goal with no authority generation is not KnownScore', () {
    final score = project([
      started(),
      goal(
        recordId: 'goal-null-gen',
        captureIntentId: 'intent-null',
        team: teamB,
        originSequence: 2,
        generation: null,
      ),
    ]);
    expect(score, isNot(isA<KnownScore>()), reason: _describe(score));
  });

  test('same record id cannot hide a generation-2 goal behind a generation-1 copy', () {
    final score = project([
      started(),
      goal(
        recordId: 'goal-same',
        captureIntentId: 'intent-same',
        team: teamA,
        originSequence: 2,
      ),
      goal(
        recordId: 'goal-same',
        captureIntentId: 'intent-same',
        team: teamA,
        originSequence: 3,
        generation: 2,
      ),
    ]);
    expect(score, isNot(isA<KnownScore>()), reason: _describe(score));
  });

  test('effective supersession of a goal correction is ScoreUnavailable', () {
    final records = [
      started(),
      goal(
        recordId: 'goal-1',
        captureIntentId: 'intent-1',
        team: teamA,
        originSequence: 2,
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
    ];
    for (final order in _permutations(records)) {
      final score = project(order);
      expect(score, isA<ScoreUnavailable>(), reason: _describe(score));
      expect(score, isNot(KnownScore({teamA: 0, teamB: 1})));
      expect(score, isNot(KnownScore({teamA: 1, teamB: 0})));
    }

    final forward = {
      for (final item in records) item.recordId: item,
    };
    final backward = {
      for (final item in records.reversed) item.recordId: item,
    };
    expect(
      resolveEffectiveGoals(recordsById: forward),
      isA<EffectiveGoalUnavailable>(),
    );
    expect(
      resolveEffectiveGoals(recordsById: backward),
      isA<EffectiveGoalUnavailable>(),
    );
  });

  test('superseding one goal correction makes a second goal unavailable too', () {
    final score = project([
      started(),
      goal(
        recordId: 'goal-1',
        captureIntentId: 'intent-1',
        team: teamA,
        originSequence: 2,
      ),
      goal(
        recordId: 'goal-2',
        captureIntentId: 'intent-2',
        team: teamA,
        originSequence: 3,
      ),
      record(
        recordId: 'corr-1',
        recordKind: RecordKind.correction,
        originSequence: 4,
        relationships: const [CorrectionTarget(targetRecordId: 'goal-1')],
        payload: CorrectionPayload(repairedScoringTeamId: teamB),
      ),
      record(
        recordId: 'ss-corr',
        recordKind: RecordKind.legalSupersession,
        originSequence: 5,
        relationships: const [
          LegalSupersessionTarget(targetRecordId: 'corr-1'),
        ],
        payload: const LegalSupersessionPayload(),
      ),
    ]);
    expect(score, isA<ScoreUnavailable>(), reason: _describe(score));
    expect(score, isNot(KnownScore({teamA: 1, teamB: 1})));
    expect(score, isNot(KnownScore({teamA: 2, teamB: 0})));
    expect(score, isNot(KnownScore({teamA: 1, teamB: 0})));
  });

  test('reversal of a correction supersession restores the repaired team', () {
    final records = [
      started(),
      goal(
        recordId: 'goal-1',
        captureIntentId: 'intent-1',
        team: teamA,
        originSequence: 2,
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
      record(
        recordId: 'ss-restore',
        recordKind: RecordKind.legalSupersession,
        originSequence: 5,
        relationships: const [
          LegalSupersessionTarget(targetRecordId: 'ss-corr'),
        ],
        payload: const LegalSupersessionPayload(),
      ),
    ];
    final canonical = project(records);
    expect(canonical, isA<KnownScore>(), reason: _describe(canonical));
    final known = canonical as KnownScore;
    expect(known.goalsByTeam[teamB], 1, reason: _describe(canonical));
    expect(known.goalsByTeam[teamA], 0, reason: _describe(canonical));
    for (final order in _permutations(records)) {
      expect(project(order), canonical);
    }
  });

  test('direct goal supersession removes the goal and reversal restores it', () {
    final base = [
      started(),
      goal(
        recordId: 'goal-1',
        captureIntentId: 'intent-1',
        team: teamA,
        originSequence: 2,
      ),
      record(
        recordId: 'ss-goal',
        recordKind: RecordKind.legalSupersession,
        originSequence: 3,
        relationships: const [
          LegalSupersessionTarget(targetRecordId: 'goal-1'),
        ],
        payload: const LegalSupersessionPayload(),
      ),
    ];
    for (final order in _permutations(base)) {
      final removed = project(order);
      expect(removed, isA<KnownScore>(), reason: _describe(removed));
      expect((removed as KnownScore).goalsByTeam[teamA], 0);
      expect(removed.goalsByTeam[teamB], 0);
    }

    final restoredRecords = [
      ...base,
      record(
        recordId: 'a-restore',
        recordKind: RecordKind.legalSupersession,
        originSequence: 4,
        relationships: const [
          LegalSupersessionTarget(targetRecordId: 'ss-goal'),
        ],
        payload: const LegalSupersessionPayload(),
      ),
    ];
    expect('a-restore'.compareTo('ss-goal'), lessThan(0));
    for (final order in _permutations(restoredRecords)) {
      final restored = project(order);
      expect(restored, isA<KnownScore>(), reason: _describe(restored));
      expect((restored as KnownScore).goalsByTeam[teamA], 1);
      expect(restored.goalsByTeam[teamB], 0);
    }
  });

  test('an unsuperseded correction still changes the scoring team', () {
    final records = [
      started(),
      goal(
        recordId: 'goal-1',
        captureIntentId: 'intent-1',
        team: teamA,
        originSequence: 2,
      ),
      record(
        recordId: 'corr-1',
        recordKind: RecordKind.correction,
        originSequence: 3,
        relationships: const [CorrectionTarget(targetRecordId: 'goal-1')],
        payload: CorrectionPayload(repairedScoringTeamId: teamB),
      ),
    ];
    for (final order in _permutations(records)) {
      final score = project(order);
      expect(score, isA<KnownScore>(), reason: _describe(score));
      final known = score as KnownScore;
      expect(known.goalsByTeam[teamB], 1);
      expect(known.goalsByTeam[teamA], 0);
    }
  });

  test('separately constructed scopes do not split one intent or accept another team', () {
    final firstScope = MainRefereeScope();
    final secondScope = MainRefereeScope();
    expect(identical(firstScope, secondScope), isFalse);

    final accepted = <MatchRecord>[
      goal(
        recordId: 'goal-1',
        captureIntentId: 'intent-split',
        team: teamA,
        originSequence: 2,
        scope: firstScope,
      ),
    ];
    final sameMeaning = evaluateCaptureIntentAdmission(
      key: CaptureIntentKey(
        matchId: matchId,
        authorityScope: secondScope,
        captureIntentId: 'intent-split',
      ),
      requestedMeaning: CaptureIntentMeaning(
        semanticType: V1SemanticTypeCode.goal,
        authorityPrincipalId: principalId,
        authorityGeneration: 1,
        scoringTeamId: teamA,
      ),
      committedForMatch: accepted,
    );
    expect(sameMeaning, isA<CaptureIntentIdempotent>());
    if (sameMeaning is CaptureIntentFirstAdmission) {
      accepted.add(
        goal(
          recordId: 'goal-2',
          captureIntentId: 'intent-split',
          team: teamA,
          originSequence: 3,
          scope: MainRefereeScope(),
        ),
      );
    }

    final otherTeam = evaluateCaptureIntentAdmission(
      key: CaptureIntentKey(
        matchId: matchId,
        authorityScope: MainRefereeScope(),
        captureIntentId: 'intent-split',
      ),
      requestedMeaning: CaptureIntentMeaning(
        semanticType: V1SemanticTypeCode.goal,
        authorityPrincipalId: principalId,
        authorityGeneration: 1,
        scoringTeamId: teamB,
      ),
      committedForMatch: accepted,
    );
    expect(otherTeam, isA<CaptureIntentConflict>());
    if (otherTeam is CaptureIntentFirstAdmission) {
      accepted.add(
        goal(
          recordId: 'goal-3',
          captureIntentId: 'intent-split',
          team: teamB,
          originSequence: 4,
          scope: v1AuthorityScope,
        ),
      );
    }
    expect(accepted.where((item) => item.payload is GoalPayload), hasLength(1));
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

List<List<T>> _permutations<T>(List<T> items) {
  if (items.length <= 1) return [List<T>.from(items)];
  final out = <List<T>>[];
  for (var index = 0; index < items.length; index++) {
    final rest = [...items]..removeAt(index);
    for (final tail in _permutations(rest)) {
      out.add([items[index], ...tail]);
    }
  }
  return out;
}
