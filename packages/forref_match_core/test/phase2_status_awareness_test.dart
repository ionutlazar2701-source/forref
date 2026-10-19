import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

void main() {
  const matchId = 'match-1';
  final teamA = MatchTeamId('team-alpha');
  final teamB = MatchTeamId('team-beta');
  final player = MatchParticipantId('123');
  final official = MatchTeamOfficialId('123');

  ScoreCompletenessProof proof() => ScoreCompletenessProof(
        matchAuthorityMode: MatchAuthorityMode.matchMemory,
        teamBindings: [
          MatchTeamBinding(matchId: matchId, teamId: teamA),
          MatchTeamBinding(matchId: matchId, teamId: teamB),
        ],
        generationOneRoot: const GenerationOneAuthorityRoot(
          matchId: matchId,
          principalId: 'ref-1',
          deviceId: 'dev-a',
        ),
      );

  MatchRecord record({
    required String recordId,
    required int originSequence,
    required RecordKind recordKind,
    required MatchRecordPayload payload,
  }) {
    return MatchRecord(
      recordId: recordId,
      matchId: matchId,
      recordKind: recordKind,
      schemaVersion: 1,
      recordedAt: DateTime.utc(2026, 10, 2, 12, originSequence),
      originDeviceId: 'dev-a',
      originSequence: originSequence,
      authorityContext: const AuthorityContext(
        scope: MainRefereeScope(),
        principal: AuthorityPrincipal(principalId: 'ref-1'),
        generation: AuthorityGeneration(value: 1),
      ),
      payload: payload,
      integrity: IntegrityMetadata(evidenceRefs: [recordId]),
    );
  }

  CautionAwareness awareness(
    List<MatchRecord> records,
    DisciplinarySubjectRef subject,
  ) {
    final before = records.length;
    final answer = assessDisciplinaryAwareness(
      matchId: matchId,
      subject: subject,
      accountingScope: DisciplinaryAccountingScope.match,
      records: records,
      proof: proof(),
      authorityConflict: false,
      correctionConflict: false,
      missingDependency: false,
      unsupportedSemanticRecordIds: const [],
      missingDependencyTargets: const [],
    );
    expect(records, hasLength(before));
    return answer;
  }

  test('the score adapter and the shared proof agree', () {
    final records = [
      record(
        recordId: 'started-1',
        originSequence: 1,
        recordKind: RecordKind.temporalFact,
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.matchStarted,
        ),
      ),
    ];
    final score = validateScoreCompletenessProof(
      matchId: matchId,
      sortedRecords: records,
      proof: proof(),
      scoreAuthorityConflict: false,
      scoreCorrectionConflict: false,
      scoreMissingDependency: false,
      unsupportedSemanticRecordIds: const [],
      missingDependencyTargets: const [],
    );
    final history = validateAuthoritativeHistoryCompleteness(
      matchId: matchId,
      sortedRecords: records,
      evidence: proof(),
      authorityConflict: false,
      correctionConflict: false,
      missingDependency: false,
      unsupportedSemanticRecordIds: const [],
      missingDependencyTargets: const [],
    );
    expect(score.ready, history.ready);
    expect(score.conflicted, history.conflicted);
    expect(history.ready, isTrue);
  });

  test('substitution does not reset a standing caution', () {
    final records = [
      record(
        recordId: 'started-1',
        originSequence: 1,
        recordKind: RecordKind.temporalFact,
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.matchStarted,
        ),
      ),
      record(
        recordId: 'y-1',
        originSequence: 2,
        recordKind: RecordKind.humanDetermination,
        payload: YellowCardPayload(
          participantId: player,
          accountingScope: DisciplinaryAccountingScope.match,
          captureIntentId: 'intent-y',
          situationAtDetermination: ParticipantSituation.substitute,
        ),
      ),
      record(
        recordId: 'sub-1',
        originSequence: 3,
        recordKind: RecordKind.humanDetermination,
        payload: SubstitutionPayload(
          outgoingParticipantId: MatchParticipantId('other'),
          incomingParticipantId: player,
          teamId: teamA,
          captureIntentId: 'intent-sub',
        ),
      ),
    ];
    final status = projectParticipantStatus(
      recordsById: {for (final item in records) item.recordId: item},
    ) as ProjectedParticipantStatus;
    expect(status.statusByParticipant[player], ParticipantSituation.onField);
    final answer = awareness(
      records,
      ParticipantDisciplinarySubject(player),
    ) as KnownStandingCaution;
    expect(answer.standingCount, 1);
    expect(answer.historicalYellowRecordIds, ['y-1']);
    final projection = DeterministicMatchProjector(ProductionSemanticsResolver())
        .projectRecords(
      matchId: matchId,
      records: records,
      context: ProjectionContext(
        evaluatedAuthorityGeneration: 1,
        scoreCompletenessProof: proof(),
      ),
    );
    expect(projection.scoreProjection, isA<KnownScore>());
  });

  test('team-official known none requires the shared proof', () {
    final records = [
      record(
        recordId: 'started-1',
        originSequence: 1,
        recordKind: RecordKind.temporalFact,
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.matchStarted,
        ),
      ),
    ];
    expect(
      awareness(records, TeamOfficialDisciplinarySubject(official)),
      isA<KnownNoStandingCaution>(),
    );
    final missing = assessDisciplinaryAwareness(
      matchId: matchId,
      subject: TeamOfficialDisciplinarySubject(official),
      accountingScope: DisciplinaryAccountingScope.match,
      records: records,
      proof: null,
      authorityConflict: false,
      correctionConflict: false,
      missingDependency: false,
      unsupportedSemanticRecordIds: const [],
      missingDependencyTargets: const [],
    );
    expect(missing, isA<CautionAwarenessUnavailable>());
    expect(missing, isNot(isA<KnownNoStandingCaution>()));
  });

  test('participant and official tokens do not share a caution after status change', () {
    final records = [
      record(
        recordId: 'started-1',
        originSequence: 1,
        recordKind: RecordKind.temporalFact,
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.matchStarted,
        ),
      ),
      record(
        recordId: 'y-off',
        originSequence: 2,
        recordKind: RecordKind.humanDetermination,
        payload: YellowCardPayloadV2(
          disciplinarySubject: TeamOfficialDisciplinarySubject(official),
          accountingScope: DisciplinaryAccountingScope.match,
          captureIntentId: 'intent-off',
        ),
      ),
    ];
    expect(
      awareness(records, TeamOfficialDisciplinarySubject(official)),
      isA<KnownStandingCaution>(),
    );
    expect(
      awareness(records, ParticipantDisciplinarySubject(player)),
      isA<KnownNoStandingCaution>(),
    );
  });
}
