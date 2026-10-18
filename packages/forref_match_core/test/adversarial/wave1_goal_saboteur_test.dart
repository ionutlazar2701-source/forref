import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

/// Attacks on WAVE 1 Goal and Score claims.
///
/// Each test tries to obtain a numeral, a second goal, or a legacy score
/// field that the claim says must not exist.
void main() {
  final resolver = ProductionSemanticsResolver();
  final projector = DeterministicMatchProjector(resolver);

  const matchId = 'match-1';
  const deviceId = 'dev-a';
  const otherDeviceId = 'dev-b';
  const principalId = 'ref-1';
  final teamA = MatchTeamId('team-alpha');
  final teamB = MatchTeamId('team-beta');
  final scope = const MainRefereeScope();

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
      );

  AuthorityContext authority({
    AuthorityScope? authorityScope,
    String captureDeviceId = deviceId,
  }) =>
      AuthorityContext(
        scope: authorityScope ?? scope,
        principal: const AuthorityPrincipal(principalId: principalId),
        activeCaptureDevice: ActiveCaptureDevice(deviceId: captureDeviceId),
        generation: const AuthorityGeneration(value: 1),
      );

  MatchRecord record({
    required String recordId,
    required RecordKind recordKind,
    required int originSequence,
    required MatchRecordPayload payload,
    String originDevice = deviceId,
    AuthorityScope? authorityScope,
    List<RecordRelationship> relationships = const [],
    IntegrityMetadata integrity = const IntegrityMetadata(evidenceRefs: ['ev']),
    DateTime? recordedAt,
  }) {
    return MatchRecord(
      recordId: recordId,
      matchId: matchId,
      recordKind: recordKind,
      schemaVersion: 1,
      recordedAt: recordedAt ?? DateTime.utc(2026, 10, 2, 12, originSequence),
      originDeviceId: originDevice,
      originSequence: originSequence,
      authorityContext: authority(
        authorityScope: authorityScope,
        captureDeviceId: originDevice,
      ),
      relationships: relationships,
      payload: payload,
      integrity: integrity,
    );
  }

  MatchRecord bootstrap({int originSequence = 1}) => record(
        recordId: 'started-1',
        recordKind: RecordKind.temporalFact,
        originSequence: originSequence,
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.matchStarted,
        ),
        integrity: const IntegrityMetadata(evidenceRefs: ['ev-start']),
      );

  MatchRecord goal({
    required String recordId,
    required String captureIntentId,
    required MatchTeamId scoringTeam,
    required int originSequence,
    String originDevice = deviceId,
    AuthorityScope? authorityScope,
    IntegrityMetadata integrity =
        const IntegrityMetadata(evidenceRefs: ['ev-goal']),
    DateTime? recordedAt,
  }) {
    return record(
      recordId: recordId,
      recordKind: RecordKind.humanDetermination,
      originSequence: originSequence,
      originDevice: originDevice,
      authorityScope: authorityScope,
      recordedAt: recordedAt,
      payload: GoalPayload(
        scoringTeamId: scoringTeam,
        captureIntentId: captureIntentId,
      ),
      integrity: integrity,
    );
  }

  MatchProjectionState project(
    List<MatchRecord> records, {
    bool withProof = true,
  }) {
    return projector.projectRecords(
      matchId: matchId,
      records: records,
      context: ProjectionContext(
        evaluatedAuthorityGeneration: 1,
        scoreCompletenessProof: withProof ? proof() : null,
      ),
    );
  }

  KnownScore knownScore(MatchProjectionState projection) {
    expect(projection.scoreProjection, isA<KnownScore>());
    return projection.scoreProjection as KnownScore;
  }

  group('WAVE 1 goal saboteur', () {
    test('empty record list is not KnownScore 0-0', () {
      final zeros = KnownScore({teamA: 0, teamB: 0});
      final withProof = project(const <MatchRecord>[]);
      final withoutProof = project(const <MatchRecord>[], withProof: false);

      for (final projection in [withProof, withoutProof]) {
        expect(projection.scoreProjection, isA<ScoreUnavailable>());
        expect(projection.scoreProjection, isNot(isA<KnownScore>()));
        expect(projection.scoreProjection, isNot(zeros));
      }
    });

    test(
      'caller cannot get KnownScore by passing a proof when any record has empty integrity evidence',
      () {
        final started = bootstrap();
        final period = record(
          recordId: 'period-1',
          recordKind: RecordKind.temporalFact,
          originSequence: 2,
          payload: TemporalTransitionPayload(
            semanticType: V1SemanticTypeCode.periodStarted,
          ),
          integrity: const IntegrityMetadata(evidenceRefs: ['ev-period']),
        );
        final scored = goal(
          recordId: 'goal-1',
          captureIntentId: 'intent-1',
          scoringTeam: teamA,
          originSequence: 3,
        );
        final complete = [started, period, scored];
        final control = knownScore(project(complete));
        expect(control.goalsByTeam[teamA], 1);
        expect(control.goalsByTeam[teamB], 0);

        for (var index = 0; index < complete.length; index++) {
          final attacked = [...complete];
          final blank = attacked[index];
          attacked[index] = record(
            recordId: blank.recordId,
            recordKind: blank.recordKind,
            originSequence: blank.originSequence,
            payload: blank.payload,
            relationships: blank.relationships,
            integrity: const IntegrityMetadata(),
          );
          final projection = project(attacked);
          expect(
            projection.scoreProjection,
            isA<ScoreUnavailable>(),
            reason: 'empty evidence on ${blank.recordId}',
          );
          expect(
            projection.scoreProjection,
            isNot(isA<KnownScore>()),
            reason: 'empty evidence on ${blank.recordId}',
          );
        }
      },
    );

    test('one capture intent cannot become two goals', () {
      final key = CaptureIntentKey(
        matchId: matchId,
        authorityScope: scope,
        captureIntentId: 'intent-1',
      );
      final meaning = CaptureIntentMeaning(
        semanticType: V1SemanticTypeCode.goal,
        authorityPrincipalId: principalId,
        authorityGeneration: 1,
        scoringTeamId: teamA,
      );
      final accepted = <MatchRecord>[
        bootstrap(),
        goal(
          recordId: 'goal-1',
          captureIntentId: 'intent-1',
          scoringTeam: teamA,
          originSequence: 2,
        ),
      ];

      final sameDevice = evaluateCaptureIntentAdmission(
        key: key,
        requestedMeaning: meaning,
        committedForMatch: accepted,
      );
      expect(sameDevice, isA<CaptureIntentIdempotent>());
      expect(
        (sameDevice as CaptureIntentIdempotent).existingRecordId,
        'goal-1',
      );

      final otherDevice = goal(
        recordId: 'goal-2',
        captureIntentId: 'intent-1',
        scoringTeam: teamA,
        originSequence: 1,
        originDevice: otherDeviceId,
      );
      final crossDevice = evaluateCaptureIntentAdmission(
        key: key,
        requestedMeaning: meaning,
        committedForMatch: accepted,
      );
      expect(crossDevice, isNot(isA<CaptureIntentFirstAdmission>()));
      if (crossDevice is CaptureIntentFirstAdmission) {
        accepted.add(otherDevice);
      }

      final goals = accepted.where((item) => item.payload is GoalPayload);
      expect(goals, hasLength(1));
      final score = knownScore(project(accepted));
      expect(score.goalsByTeam[teamA], 1);
      expect(score.goalsByTeam[teamB], 0);
    });

    test(
      'separately constructed MainRefereeScope values cannot split one capture intent into two goals',
      () {
        final recordScope = MainRefereeScope();
        final keyScope = MainRefereeScope();
        expect(recordScope, isA<MainRefereeScope>());
        expect(keyScope, isA<MainRefereeScope>());
        expect(identical(recordScope, keyScope), isFalse);

        final meaning = CaptureIntentMeaning(
          semanticType: V1SemanticTypeCode.goal,
          authorityPrincipalId: principalId,
          authorityGeneration: 1,
          scoringTeamId: teamA,
        );
        final accepted = <MatchRecord>[
          goal(
            recordId: 'goal-1',
            captureIntentId: 'intent-split',
            scoringTeam: teamA,
            originSequence: 2,
            authorityScope: recordScope,
          ),
        ];
        final second = evaluateCaptureIntentAdmission(
          key: CaptureIntentKey(
            matchId: matchId,
            authorityScope: keyScope,
            captureIntentId: 'intent-split',
          ),
          requestedMeaning: meaning,
          committedForMatch: accepted,
        );
        if (second is CaptureIntentFirstAdmission) {
          accepted.add(
            goal(
              recordId: 'goal-2',
              captureIntentId: 'intent-split',
              scoringTeam: teamA,
              originSequence: 3,
              authorityScope: MainRefereeScope(),
            ),
          );
        }

        expect(accepted.where((item) => item.payload is GoalPayload),
            hasLength(1));
        expect(second, isNot(isA<CaptureIntentFirstAdmission>()));
      },
    );

    test(
      'same intent with a different scoring team is a conflict and does not append',
      () {
        final key = CaptureIntentKey(
          matchId: matchId,
          authorityScope: scope,
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
        final accepted = <MatchRecord>[
          bootstrap(),
          goal(
            recordId: 'goal-1',
            captureIntentId: 'intent-1',
            scoringTeam: teamA,
            originSequence: 2,
          ),
        ];
        final before = accepted.length;
        final decision = evaluateCaptureIntentAdmission(
          key: key,
          requestedMeaning: meaningB,
          committedForMatch: accepted,
        );
        expect(decision, isA<CaptureIntentConflict>());
        final conflict = decision as CaptureIntentConflict;
        expect(conflict.existingRecordId, 'goal-1');
        expect(conflict.existingMeaning, meaningA);
        expect(conflict.requestedMeaning, meaningB);
        if (decision is CaptureIntentFirstAdmission) {
          accepted.add(
            goal(
              recordId: 'goal-2',
              captureIntentId: 'intent-1',
              scoringTeam: teamB,
              originSequence: 3,
            ),
          );
        }
        expect(accepted, hasLength(before));
        final score = knownScore(project(accepted));
        expect(score.goalsByTeam[teamA], 1);
        expect(score.goalsByTeam[teamB], 0);
      },
    );

    test(
      'separately constructed MainRefereeScope values still conflict for a different scoring team',
      () {
        final meaningB = CaptureIntentMeaning(
          semanticType: V1SemanticTypeCode.goal,
          authorityPrincipalId: principalId,
          authorityGeneration: 1,
          scoringTeamId: teamB,
        );
        final accepted = <MatchRecord>[
          goal(
            recordId: 'goal-1',
            captureIntentId: 'intent-team',
            scoringTeam: teamA,
            originSequence: 2,
            authorityScope: MainRefereeScope(),
          ),
        ];
        final decision = evaluateCaptureIntentAdmission(
          key: CaptureIntentKey(
            matchId: matchId,
            authorityScope: MainRefereeScope(),
            captureIntentId: 'intent-team',
          ),
          requestedMeaning: meaningB,
          committedForMatch: accepted,
        );
        if (decision is CaptureIntentFirstAdmission) {
          accepted.add(
            goal(
              recordId: 'goal-2',
              captureIntentId: 'intent-team',
              scoringTeam: teamB,
              originSequence: 3,
              authorityScope: MainRefereeScope(),
            ),
          );
        }
        expect(decision, isA<CaptureIntentConflict>());
        expect(accepted.where((item) => item.payload is GoalPayload),
            hasLength(1));
      },
    );

    test(
      'supersession reversal counts the original goal id when the restoring record id sorts first',
      () {
        final scored = goal(
          recordId: 'm-goal-original',
          captureIntentId: 'intent-1',
          scoringTeam: teamA,
          originSequence: 2,
          recordedAt: DateTime.utc(2026, 10, 2, 12, 10),
        );
        final voidGoal = record(
          recordId: 'z-void',
          recordKind: RecordKind.legalSupersession,
          originSequence: 3,
          recordedAt: DateTime.utc(2026, 10, 2, 12, 40),
          relationships: const [
            LegalSupersessionTarget(targetRecordId: 'm-goal-original'),
          ],
          payload: const LegalSupersessionPayload(),
          integrity: const IntegrityMetadata(evidenceRefs: ['ev-void']),
        );
        final restore = record(
          recordId: 'a-restore',
          recordKind: RecordKind.legalSupersession,
          originSequence: 4,
          recordedAt: DateTime.utc(2026, 10, 2, 12, 20),
          relationships: const [
            LegalSupersessionTarget(targetRecordId: 'z-void'),
          ],
          payload: const LegalSupersessionPayload(),
          integrity: const IntegrityMetadata(evidenceRefs: ['ev-restore']),
        );
        expect(restore.recordId.compareTo(voidGoal.recordId), lessThan(0));
        expect(restore.originSequence, greaterThan(voidGoal.originSequence));
        expect(restore.recordedAt.isBefore(voidGoal.recordedAt), isTrue);

        final records = [restore, scored, voidGoal, bootstrap()];
        final byRecordId = [...records]
          ..sort((a, b) => a.recordId.compareTo(b.recordId));
        expect(byRecordId.first.recordId, 'a-restore');
        final resolved = resolveEffectiveGoals(
          recordsById: {for (final item in byRecordId) item.recordId: item},
        );
        expect(resolved, isA<EffectiveGoalSet>());
        final goals = (resolved as EffectiveGoalSet).goals;
        expect(goals, hasLength(1));
        expect(goals.single.goalRecordId, 'm-goal-original');
        expect(goals.single.scoringTeamId, teamA);

        for (final order in [records, records.reversed.toList(), byRecordId]) {
          final score = knownScore(project(order));
          expect(score.goalsByTeam[teamA], 1);
          expect(score.goalsByTeam[teamB], 0);
        }
      },
    );

    test('a correction cycle does not yield a numeral', () {
      final started = bootstrap();
      final scored = goal(
        recordId: 'goal-1',
        captureIntentId: 'intent-1',
        scoringTeam: teamA,
        originSequence: 2,
      );
      final open = knownScore(project([started, scored]));
      expect(open.goalsByTeam[teamA], 1);

      MatchRecord correction({
        required String recordId,
        required String targetId,
        required int originSequence,
        required MatchTeamId repairedTeam,
      }) {
        return record(
          recordId: recordId,
          recordKind: RecordKind.correction,
          originSequence: originSequence,
          relationships: [CorrectionTarget(targetRecordId: targetId)],
          payload: CorrectionPayload(repairedScoringTeamId: repairedTeam),
          integrity: IntegrityMetadata(evidenceRefs: ['ev-$recordId']),
        );
      }

      final cycled = project([
        started,
        scored,
        correction(
          recordId: 'corr-a',
          targetId: 'corr-b',
          originSequence: 3,
          repairedTeam: teamB,
        ),
        correction(
          recordId: 'corr-b',
          targetId: 'corr-c',
          originSequence: 4,
          repairedTeam: teamA,
        ),
        correction(
          recordId: 'corr-c',
          targetId: 'corr-a',
          originSequence: 5,
          repairedTeam: teamB,
        ),
      ]);
      expect(cycled.scoreProjection, isNot(isA<KnownScore>()));
      expect(
        cycled.scoreProjection,
        anyOf(isA<ScoreUnavailable>(), isA<ScoreConflicted>()),
      );

      final selfCycled = project([
        started,
        scored,
        correction(
          recordId: 'corr-self',
          targetId: 'corr-self',
          originSequence: 3,
          repairedTeam: teamB,
        ),
      ]);
      expect(selfCycled.scoreProjection, isNot(isA<KnownScore>()));
    });

    test('permuting record order does not change KnownScore', () {
      final records = [
        bootstrap(),
        goal(
          recordId: 'goal-a',
          captureIntentId: 'intent-a',
          scoringTeam: teamA,
          originSequence: 2,
        ),
        goal(
          recordId: 'goal-b',
          captureIntentId: 'intent-b',
          scoringTeam: teamB,
          originSequence: 3,
        ),
        record(
          recordId: 'corr-a',
          recordKind: RecordKind.correction,
          originSequence: 4,
          relationships: const [CorrectionTarget(targetRecordId: 'goal-a')],
          payload: CorrectionPayload(repairedScoringTeamId: teamB),
          integrity: const IntegrityMetadata(evidenceRefs: ['ev-corr']),
        ),
        record(
          recordId: 'ss-b',
          recordKind: RecordKind.legalSupersession,
          originSequence: 5,
          relationships: const [
            LegalSupersessionTarget(targetRecordId: 'goal-b'),
          ],
          payload: const LegalSupersessionPayload(),
          integrity: const IntegrityMetadata(evidenceRefs: ['ev-ss']),
        ),
      ];
      final orders = _permutations(records);
      expect(orders, hasLength(120));
      final canonical = knownScore(project(records));
      expect(canonical.goalsByTeam[teamA], 0);
      expect(canonical.goalsByTeam[teamB], 1);

      for (final order in orders) {
        expect(
          project(order).scoreProjection,
          canonical,
          reason: order.map((item) => item.recordId).join(','),
        );
      }
    });

    test('missing origin sequence 2 yields ScoreUnavailable', () {
      final records = [
        goal(
          recordId: 'goal-1',
          captureIntentId: 'intent-1',
          scoringTeam: teamA,
          originSequence: 3,
        ),
        bootstrap(),
      ];
      expect(records.map((item) => item.originSequence).toSet(), {1, 3});
      expect(
        records.map((item) => item.originDeviceId).toSet(),
        {deviceId},
      );

      final projection = project(records);
      expect(projection.scoreProjection, isA<ScoreUnavailable>());
      expect(projection.scoreProjection, isNot(isA<KnownScore>()));
      expect(
        projection.scoreProjection,
        isNot(KnownScore({teamA: 1, teamB: 0})),
      );
      expect(
        projection.scoreProjection,
        isNot(KnownScore({teamA: 0, teamB: 0})),
      );
    });

    test(
      'ScoreUnavailable and ScoreConflicted have no homeScore and are not KnownScore',
      () {
        final unavailable = project(const []).scoreProjection;
        expect(unavailable, isA<ScoreUnavailable>());
        expect(unavailable, isNot(isA<KnownScore>()));
        _expectNoLegacyScoreInteger(unavailable);
        _expectNoLegacyScoreInteger(const ScoreUnavailable());

        final conflicted = project([
          bootstrap(),
          goal(
            recordId: 'goal-1',
            captureIntentId: 'intent-1',
            scoringTeam: teamA,
            originSequence: 2,
          ),
          record(
            recordId: 'corr-a',
            recordKind: RecordKind.correction,
            originSequence: 3,
            relationships: const [CorrectionTarget(targetRecordId: 'goal-1')],
            payload: CorrectionPayload(repairedScoringTeamId: teamA),
            integrity: const IntegrityMetadata(evidenceRefs: ['ev-a']),
          ),
          record(
            recordId: 'corr-b',
            recordKind: RecordKind.correction,
            originSequence: 4,
            relationships: const [CorrectionTarget(targetRecordId: 'goal-1')],
            payload: CorrectionPayload(repairedScoringTeamId: teamB),
            integrity: const IntegrityMetadata(evidenceRefs: ['ev-b']),
          ),
        ]).scoreProjection;
        expect(conflicted, isA<ScoreConflicted>());
        expect(conflicted, isNot(isA<KnownScore>()));
        _expectNoLegacyScoreInteger(conflicted);
        _expectNoLegacyScoreInteger(const ScoreConflicted());
      },
    );
  });
}

void _expectNoLegacyScoreInteger(ScoreProjection score) {
  expect(score, isNot(isA<KnownScore>()));
  final dynamic surface = score;
  for (final field in ['homeScore', 'awayScore', 'scoreHome', 'scoreAway']) {
    expect(
      () => _readLegacyField(surface, field),
      throwsNoSuchMethodError,
      reason: '${score.runtimeType}.$field',
    );
  }
}

Object? _readLegacyField(dynamic surface, String field) {
  switch (field) {
    case 'homeScore':
      return surface.homeScore;
    case 'awayScore':
      return surface.awayScore;
    case 'scoreHome':
      return surface.scoreHome;
    case 'scoreAway':
      return surface.scoreAway;
    default:
      throw ArgumentError(field);
  }
}

List<List<T>> _permutations<T>(List<T> items) {
  if (items.isEmpty) return [[]];
  final results = <List<T>>[];
  for (var index = 0; index < items.length; index++) {
    final head = items[index];
    final rest = [...items.sublist(0, index), ...items.sublist(index + 1)];
    for (final tail in _permutations(rest)) {
      results.add([head, ...tail]);
    }
  }
  return results;
}
