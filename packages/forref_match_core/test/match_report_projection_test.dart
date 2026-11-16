import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

void main() {
  const matchId = 'match-1';
  const deviceId = 'dev-a';
  const principalId = 'ref-1';
  final teamA = MatchTeamId('team-alpha');
  final teamB = MatchTeamId('team-beta');
  final player = MatchParticipantId('person-a');
  final incoming = MatchParticipantId('person-b');

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

  ProjectionContext context({ScoreCompletenessProof? scoreProof}) =>
      ProjectionContext(
        evaluatedAuthorityGeneration: 1,
        scoreCompletenessProof: scoreProof,
      );

  AuthorityContext authority() => AuthorityContext(
        scope: const MainRefereeScope(),
        principal: const AuthorityPrincipal(principalId: principalId),
        generation: const AuthorityGeneration(value: 1),
      );

  MatchRecord record({
    required String recordId,
    required int originSequence,
    required RecordKind recordKind,
    required MatchRecordPayload payload,
    List<RecordRelationship> relationships = const [],
    DateTime? recordedAt,
  }) {
    return MatchRecord(
      recordId: recordId,
      matchId: matchId,
      recordKind: recordKind,
      schemaVersion: 1,
      recordedAt: recordedAt ?? DateTime.utc(2026, 10, 2, 12, originSequence),
      originDeviceId: deviceId,
      originSequence: originSequence,
      authorityContext: authority(),
      payload: payload,
      integrity: IntegrityMetadata(evidenceRefs: [recordId]),
      relationships: relationships,
    );
  }

  List<MatchRecord> kickOff() => [
        record(
          recordId: 'started',
          originSequence: 1,
          recordKind: RecordKind.temporalFact,
          payload: TemporalTransitionPayload(
            semanticType: V1SemanticTypeCode.matchStarted,
          ),
        ),
        record(
          recordId: 'period-1',
          originSequence: 2,
          recordKind: RecordKind.temporalFact,
          payload: TemporalTransitionPayload(
            semanticType: V1SemanticTypeCode.periodStarted,
            period: const PeriodIdentity(index: 1),
          ),
          relationships: const [CausalDependency(targetRecordId: 'started')],
        ),
      ];

  test('known events keep an unavailable minute and a proven score', () {
    final records = [
      ...kickOff(),
      record(
        recordId: 'goal-1',
        originSequence: 3,
        recordKind: RecordKind.humanDetermination,
        payload: GoalPayload(
          scoringTeamId: teamA,
          captureIntentId: 'intent-goal',
        ),
      ),
      record(
        recordId: 'yellow-1',
        originSequence: 4,
        recordKind: RecordKind.humanDetermination,
        payload: YellowCardPayload(
          participantId: player,
          accountingScope: DisciplinaryAccountingScope.match,
          captureIntentId: 'intent-yellow',
        ),
      ),
      record(
        recordId: 'sub-1',
        originSequence: 5,
        recordKind: RecordKind.humanDetermination,
        payload: SubstitutionPayload(
          outgoingParticipantId: player,
          incomingParticipantId: incoming,
          teamId: teamA,
          captureIntentId: 'intent-sub',
        ),
      ),
      record(
        recordId: 'off-1',
        originSequence: 6,
        recordKind: RecordKind.humanDetermination,
        payload: SendOffPayload(
          disciplinarySubject: ParticipantDisciplinarySubject(incoming),
          disciplinaryScope: DisciplinaryAccountingScope.match,
          pathway: SendOffPathway.direct,
          captureIntentId: 'intent-off',
        ),
      ),
    ];

    final report = projectMatchReport(
      matchId: matchId,
      records: records.reversed.toList(),
      context: context(scoreProof: proof()),
    );
    final again = projectMatchReport(
      matchId: matchId,
      records: [
        for (final item in records)
          MatchRecord(
            recordId: item.recordId,
            matchId: item.matchId,
            recordKind: item.recordKind,
            schemaVersion: item.schemaVersion,
            recordedAt: item.recordedAt.add(const Duration(hours: 5)),
            originDeviceId: item.originDeviceId,
            originSequence: item.originSequence,
            authorityContext: item.authorityContext,
            payload: item.payload,
            integrity: item.integrity,
            relationships: item.relationships,
          ),
      ],
      context: context(scoreProof: proof()),
    );

    expect(report, again);
    expect(report.readiness, MatchReportReadiness.readable);
    expect(report.score, isA<KnownScore>());
    expect((report.score as KnownScore).goalsByTeam[teamA], 1);
    expect((report.score as KnownScore).goalsByTeam[teamB], 0);
    expect(
      report.facet(MatchReportFacetId.score).classification,
      MatchReportClassification.known,
    );
    expect(
      report.facet(MatchReportFacetId.temporal).classification,
      MatchReportClassification.known,
    );
    expect(report.temporal.matchStarted, isTrue);
    expect(report.temporal.activePeriod, const PeriodIdentity(index: 1));
    expect(
      report.entries.map((entry) => entry.kind).toList(),
      [
        MatchReportEntryKind.temporal,
        MatchReportEntryKind.temporal,
        MatchReportEntryKind.goal,
        MatchReportEntryKind.yellow,
        MatchReportEntryKind.substitution,
        MatchReportEntryKind.sendOff,
      ],
    );
    for (final entry in report.entries) {
      expect(entry.timeFact, MatchReportTimeFact.exactMatchTimeUnavailable);
      expect(entry.classification, MatchReportClassification.known);
    }
    final sendOff = report.entries.whereType<SendOffReportEntry>().single;
    expect(sendOff.pathway, SendOffPathway.direct);
    expect(sendOff.legallyEffective, isTrue);
    expect(sendOff.dependencyStatus, SendOffDependencyStatus.ready);
  });

  test('a goal without completeness proof does not become a score', () {
    final report = projectMatchReport(
      matchId: matchId,
      records: [
        ...kickOff(),
        record(
          recordId: 'goal-1',
          originSequence: 3,
          recordKind: RecordKind.humanDetermination,
          payload: GoalPayload(
            scoringTeamId: teamA,
            captureIntentId: 'intent-goal',
          ),
        ),
      ],
      context: context(),
    );
    expect(report.score, isA<ScoreUnavailable>());
    expect(
      report.facet(MatchReportFacetId.score).classification,
      MatchReportClassification.unavailable,
    );
    expect(report.entries.whereType<GoalReportEntry>(), hasLength(1));
  });

  test('an unsupported payload is not reported as a goal', () {
    final report = projectMatchReport(
      matchId: matchId,
      records: [
        record(
          recordId: 'blob-1',
          originSequence: 1,
          recordKind: RecordKind.occurrence,
          payload: StructuredPayload(const {'event': 'goal', 'minute': 12}),
        ),
      ],
      context: context(scoreProof: proof()),
    );
    expect(report.entries.whereType<GoalReportEntry>(), isEmpty);
    expect(report.unsupportedRecordIds, ['blob-1']);
    expect(report.score, isA<ScoreUnavailable>());
  });

  test('a broken correction chain stays unavailable', () {
    final report = projectMatchReport(
      matchId: matchId,
      records: [
        ...kickOff(),
        record(
          recordId: 'goal-1',
          originSequence: 3,
          recordKind: RecordKind.humanDetermination,
          payload: GoalPayload(
            scoringTeamId: teamA,
            captureIntentId: 'intent-goal',
          ),
        ),
        record(
          recordId: 'corr-1',
          originSequence: 4,
          recordKind: RecordKind.correction,
          payload: CorrectionPayload(repairedScoringTeamId: teamB),
          relationships: const [
            CorrectionTarget(targetRecordId: 'missing-goal'),
          ],
        ),
      ],
      context: context(scoreProof: proof()),
    );
    expect(report.entries.whereType<GoalReportEntry>(), isEmpty);
    expect(
      report.facet(MatchReportFacetId.goal).classification,
      MatchReportClassification.unavailable,
    );
    expect(report.score, isA<ScoreUnavailable>());
  });

  test('competing goal corrections are a conflict, not a chosen score', () {
    final report = projectMatchReport(
      matchId: matchId,
      records: [
        ...kickOff(),
        record(
          recordId: 'goal-1',
          originSequence: 3,
          recordKind: RecordKind.humanDetermination,
          payload: GoalPayload(
            scoringTeamId: teamA,
            captureIntentId: 'intent-goal',
          ),
        ),
        record(
          recordId: 'corr-a',
          originSequence: 4,
          recordKind: RecordKind.correction,
          payload: CorrectionPayload(repairedScoringTeamId: teamA),
          relationships: const [CorrectionTarget(targetRecordId: 'goal-1')],
        ),
        record(
          recordId: 'corr-b',
          originSequence: 5,
          recordKind: RecordKind.correction,
          payload: CorrectionPayload(repairedScoringTeamId: teamB),
          relationships: const [CorrectionTarget(targetRecordId: 'goal-1')],
        ),
      ],
      context: context(scoreProof: proof()),
    );
    expect(report.entries.whereType<GoalReportEntry>(), isEmpty);
    expect(
      report.facet(MatchReportFacetId.goal).classification,
      MatchReportClassification.conflict,
    );
    expect(report.score, isA<ScoreConflicted>());
    expect(
      report.facet(MatchReportFacetId.score).classification,
      MatchReportClassification.conflict,
    );
  });

  test('a second-caution send-off without its Yellows stays unavailable', () {
    final report = projectMatchReport(
      matchId: matchId,
      records: [
        record(
          recordId: 'off-1',
          originSequence: 1,
          recordKind: RecordKind.humanDetermination,
          payload: SendOffPayload(
            disciplinarySubject: ParticipantDisciplinarySubject(player),
            disciplinaryScope: DisciplinaryAccountingScope.match,
            pathway: SendOffPathway.secondCaution,
            captureIntentId: 'intent-off',
            firstStandingCautionRecordId: 'yellow-1',
            secondCautionRecordId: 'yellow-2',
          ),
          relationships: const [
            CausalDependency(targetRecordId: 'yellow-1'),
            CausalDependency(targetRecordId: 'yellow-2'),
          ],
        ),
      ],
      context: context(),
    );
    final sendOff = report.entries.whereType<SendOffReportEntry>().single;
    expect(sendOff.classification, MatchReportClassification.unavailable);
    expect(sendOff.dependencyStatus, SendOffDependencyStatus.unavailable);
    expect(
      report.facet(MatchReportFacetId.sendOff).classification,
      MatchReportClassification.unavailable,
    );
  });
}
