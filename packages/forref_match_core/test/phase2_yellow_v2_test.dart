import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

void main() {
  const matchId = 'match-1';
  const deviceId = 'dev-a';
  const principalId = 'ref-1';
  final teamA = MatchTeamId('team-alpha');
  final teamB = MatchTeamId('team-beta');
  final person = MatchParticipantId('123');
  final official = MatchTeamOfficialId('123');

  ScoreCompletenessProof proof() => ScoreCompletenessProof(
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
      );

  MatchRecord record({
    required String recordId,
    required int originSequence,
    required RecordKind recordKind,
    required MatchRecordPayload payload,
    List<RecordRelationship> relationships = const [],
    int generation = 1,
    String originDeviceId = deviceId,
  }) {
    return MatchRecord(
      recordId: recordId,
      matchId: matchId,
      recordKind: recordKind,
      schemaVersion: 1,
      recordedAt: DateTime.utc(2026, 10, 2, 12, originSequence),
      originDeviceId: originDeviceId,
      originSequence: originSequence,
      authorityContext: AuthorityContext(
        scope: const MainRefereeScope(),
        principal: const AuthorityPrincipal(principalId: principalId),
        generation: AuthorityGeneration(value: generation),
      ),
      payload: payload,
      integrity: IntegrityMetadata(evidenceRefs: [recordId]),
      relationships: relationships,
    );
  }

  MatchRecord bootstrap() => record(
        recordId: 'started-1',
        originSequence: 1,
        recordKind: RecordKind.temporalFact,
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.matchStarted,
        ),
      );

  CautionAwareness awareness(
    List<MatchRecord> records,
    DisciplinarySubjectRef subject, {
    DisciplinaryAccountingScope scope = DisciplinaryAccountingScope.match,
  }) {
    final before = records.length;
    final answer = assessDisciplinaryAwareness(
      matchId: matchId,
      subject: subject,
      accountingScope: scope,
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

  test('v1 yellow normalizes to a participant subject and stays schema 1', () {
    final yellow = record(
      recordId: 'y-v1',
      originSequence: 2,
      recordKind: RecordKind.humanDetermination,
      payload: YellowCardPayload(
        participantId: person,
        accountingScope: DisciplinaryAccountingScope.match,
        captureIntentId: 'intent-v1',
      ),
    );
    expect(yellow.schemaVersion, 1);
    expect(yellowCardPayloadSchemaVersion(yellow.payload), 1);
    expect(
      subjectOfYellowCard(yellow.payload),
      ParticipantDisciplinarySubject(person),
    );
    final answer = awareness(
      [bootstrap(), yellow],
      ParticipantDisciplinarySubject(person),
    ) as KnownStandingCaution;
    expect(answer.standingCount, 1);
    expect(
      awareness(
        [bootstrap(), yellow],
        TeamOfficialDisciplinarySubject(official),
      ),
      isA<KnownNoStandingCaution>(),
    );
  });

  test('team-official v2 does not leak onto the participant token', () {
    final yellow = record(
      recordId: 'y-v2',
      originSequence: 2,
      recordKind: RecordKind.humanDetermination,
      payload: YellowCardPayloadV2(
        disciplinarySubject: TeamOfficialDisciplinarySubject(official),
        accountingScope: DisciplinaryAccountingScope.match,
        captureIntentId: 'intent-official',
      ),
    );
    expect(yellowCardPayloadSchemaVersion(yellow.payload), 2);
    expect(
      awareness(
        [bootstrap(), yellow],
        TeamOfficialDisciplinarySubject(official),
      ),
      isA<KnownStandingCaution>(),
    );
    expect(
      awareness([bootstrap(), yellow], ParticipantDisciplinarySubject(person)),
      isA<KnownNoStandingCaution>(),
    );
  });

  test('team-official situation is rejected', () {
    expect(
      () => YellowCardPayloadV2(
        disciplinarySubject: TeamOfficialDisciplinarySubject(official),
        accountingScope: DisciplinaryAccountingScope.match,
        captureIntentId: 'intent-official',
        participantSituationAtDetermination: ParticipantSituation.onField,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('same intent across subject categories conflicts', () {
    final first = record(
      recordId: 'y-v1',
      originSequence: 2,
      recordKind: RecordKind.humanDetermination,
      payload: YellowCardPayload(
        participantId: person,
        accountingScope: DisciplinaryAccountingScope.match,
        captureIntentId: 'intent-shared',
      ),
    );
    final admission = evaluateYellowCaptureIntentAdmission(
      key: CaptureIntentKey(
        matchId: matchId,
        authorityScope: MainRefereeScope(),
        captureIntentId: 'intent-shared',
      ),
      requestedMeaning: YellowCaptureIntentMeaning(
        disciplinarySubject: TeamOfficialDisciplinarySubject(official),
        accountingScope: DisciplinaryAccountingScope.match,
        authorityPrincipalId: principalId,
        authorityGeneration: 1,
      ),
      committedForMatch: [bootstrap(), first],
    );
    expect(admission, isA<YellowCaptureIntentConflict>());
  });

  test('same v2 intent and official is idempotent', () {
    final subject = TeamOfficialDisciplinarySubject(official);
    final first = record(
      recordId: 'y-v2',
      originSequence: 2,
      recordKind: RecordKind.humanDetermination,
      payload: YellowCardPayloadV2(
        disciplinarySubject: subject,
        accountingScope: DisciplinaryAccountingScope.shootout,
        captureIntentId: 'intent-official',
      ),
    );
    final admission = evaluateYellowCaptureIntentAdmission(
      key: CaptureIntentKey(
        matchId: matchId,
        authorityScope: MainRefereeScope(),
        captureIntentId: 'intent-official',
      ),
      requestedMeaning: YellowCaptureIntentMeaning(
        disciplinarySubject: subject,
        accountingScope: DisciplinaryAccountingScope.shootout,
        authorityPrincipalId: principalId,
        authorityGeneration: 1,
      ),
      committedForMatch: [first],
    );
    expect(admission, isA<YellowCaptureIntentIdempotent>());
  });

  test('MATCH and SHOOTOUT stay separate for an official', () {
    final subject = TeamOfficialDisciplinarySubject(official);
    final records = [
      bootstrap(),
      record(
        recordId: 'y-v2',
        originSequence: 2,
        recordKind: RecordKind.humanDetermination,
        payload: YellowCardPayloadV2(
          disciplinarySubject: subject,
          accountingScope: DisciplinaryAccountingScope.match,
          captureIntentId: 'intent-official',
        ),
      ),
    ];
    expect(
      awareness(records, subject, scope: DisciplinaryAccountingScope.shootout),
      isA<KnownNoStandingCaution>(),
    );
    expect(awareness(records, subject), isA<KnownStandingCaution>());
  });

  test('v2 correction moves the official subject without rewriting history', () {
    final other = MatchTeamOfficialId('official-b');
    final records = [
      bootstrap(),
      record(
        recordId: 'y-v2',
        originSequence: 2,
        recordKind: RecordKind.humanDetermination,
        payload: YellowCardPayloadV2(
          disciplinarySubject: TeamOfficialDisciplinarySubject(official),
          accountingScope: DisciplinaryAccountingScope.match,
          captureIntentId: 'intent-official',
        ),
      ),
      record(
        recordId: 'corr-1',
        originSequence: 3,
        recordKind: RecordKind.correction,
        payload: CorrectionPayload(
          repairedDisciplinarySubject:
              TeamOfficialDisciplinarySubject(other),
        ),
        relationships: [CorrectionTarget(targetRecordId: 'y-v2')],
      ),
    ];
    expect(
      (records[1].payload as YellowCardPayloadV2).disciplinarySubject,
      TeamOfficialDisciplinarySubject(official),
    );
    expect(
      awareness(records, TeamOfficialDisciplinarySubject(official)),
      isA<KnownNoStandingCaution>(),
    );
    final moved = awareness(
      records,
      TeamOfficialDisciplinarySubject(other),
    ) as KnownStandingCaution;
    expect(moved.standingCount, 1);
    expect(moved.historicalYellowRecordIds, ['y-v2']);
  });

  test('generation other than 1 makes official awareness unavailable', () {
    final records = [
      bootstrap(),
      record(
        recordId: 'y-v2',
        originSequence: 2,
        recordKind: RecordKind.humanDetermination,
        generation: 2,
        payload: YellowCardPayloadV2(
          disciplinarySubject: TeamOfficialDisciplinarySubject(official),
          accountingScope: DisciplinaryAccountingScope.match,
          captureIntentId: 'intent-official',
        ),
      ),
    ];
    expect(
      awareness(records, TeamOfficialDisciplinarySubject(official)),
      isA<CautionAwarenessUnavailable>(),
    );
  });

  test('missing team binding is not a trusted official caution', () {
    final assessment = assessTeamOfficialTeamBinding(
      matchId: matchId,
      teamOfficialId: official,
      bindings: const [],
    );
    expect(assessment, isA<MissingTeamOfficialBinding>());
  });
}
