import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

void main() {
  final projector = DeterministicMatchProjector(ProductionSemanticsResolver());
  const matchId = 'match-1';
  const deviceId = 'dev-a';
  const principalId = 'ref-1';
  final teamA = MatchTeamId('team-alpha');
  final teamB = MatchTeamId('team-beta');
  final personA = MatchParticipantId('person-a');
  final personB = MatchParticipantId('person-b');

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

  ProjectionContext context() => ProjectionContext(
        evaluatedAuthorityGeneration: 1,
        scoreCompletenessProof: proof(),
      );

  AuthorityContext authority({int generation = 1}) => AuthorityContext(
        scope: const MainRefereeScope(),
        principal: AuthorityPrincipal(principalId: principalId),
        generation: AuthorityGeneration(value: generation),
      );

  MatchRecord record({
    required String recordId,
    required int originSequence,
    required RecordKind recordKind,
    required MatchRecordPayload payload,
    List<RecordRelationship> relationships = const [],
    String originDeviceId = deviceId,
    int generation = 1,
    String recordMatchId = matchId,
  }) {
    return MatchRecord(
      recordId: recordId,
      matchId: recordMatchId,
      recordKind: recordKind,
      schemaVersion: 1,
      recordedAt: DateTime.utc(2026, 10, 2, 12, originSequence),
      originDeviceId: originDeviceId,
      originSequence: originSequence,
      authorityContext: authority(generation: generation),
      payload: payload,
      integrity: IntegrityMetadata(evidenceRefs: [recordId]),
      relationships: relationships,
    );
  }

  MatchRecord bootstrap({int sequence = 1}) => record(
        recordId: 'started-$sequence',
        originSequence: sequence,
        recordKind: RecordKind.temporalFact,
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.matchStarted,
        ),
      );

  MatchRecord yellow({
    required String recordId,
    required int originSequence,
    required MatchParticipantId participantId,
    DisciplinaryAccountingScope scope = DisciplinaryAccountingScope.match,
    ParticipantSituation? situation,
    String captureIntentId = 'intent-y',
    int generation = 1,
    String originDeviceId = deviceId,
  }) {
    return record(
      recordId: recordId,
      originSequence: originSequence,
      recordKind: RecordKind.humanDetermination,
      originDeviceId: originDeviceId,
      generation: generation,
      payload: YellowCardPayload(
        participantId: participantId,
        accountingScope: scope,
        captureIntentId: captureIntentId,
        situationAtDetermination: situation,
      ),
    );
  }

  CautionAwareness awareness(
    List<MatchRecord> records, {
    MatchParticipantId? participantId,
    DisciplinaryAccountingScope scope = DisciplinaryAccountingScope.match,
  }) {
    final before = records.length;
    final projection = projector.projectRecords(
      matchId: matchId,
      records: records,
      context: context(),
    );
    final answer = assessCautionAwareness(
      matchId: matchId,
      participantId: participantId ?? personA,
      accountingScope: scope,
      records: records,
      proof: proof(),
      authorityConflict: false,
      correctionConflict: false,
      missingDependency: projection.missingDependencyTargets.isNotEmpty,
      unsupportedSemanticRecordIds: projection.unsupportedSemanticRecordIds,
      missingDependencyTargets: projection.missingDependencyTargets,
    );
    expect(records, hasLength(before));
    return answer;
  }

  test('complete history with no yellow is KnownNo, not a zero count', () {
    final answer = awareness([bootstrap()]);
    expect(answer, isA<KnownNoStandingCaution>());
    expect((answer as KnownNoStandingCaution).historicalYellowRecordIds, isEmpty);
    expect(answer, isNot(isA<KnownStandingCaution>()));
  });

  test('a yellow beside a complete root history stays a KnownScore', () {
    final records = [
      bootstrap(),
      yellow(
        recordId: 'y-1',
        originSequence: 2,
        participantId: personA,
        situation: ParticipantSituation.onField,
      ),
    ];
    final projection = projector.projectRecords(
      matchId: matchId,
      records: records,
      context: context(),
    );
    final score = projection.scoreProjection as KnownScore;
    expect(score.goalsByTeam[teamA], 0);
    expect(score.goalsByTeam[teamB], 0);
    final answer = awareness(records);
    expect(answer, isA<KnownStandingCaution>());
    expect((answer as KnownStandingCaution).standingCount, 1);
    expect(answer.secondCautionSituation, isFalse);
  });

  test('substitute and substituted situations keep the same participant id', () {
    final records = [
      bootstrap(),
      yellow(
        recordId: 'y-sub',
        originSequence: 2,
        participantId: personA,
        situation: ParticipantSituation.substitute,
        captureIntentId: 'intent-sub',
      ),
      yellow(
        recordId: 'y-out',
        originSequence: 3,
        participantId: personA,
        situation: ParticipantSituation.substituted,
        captureIntentId: 'intent-out',
      ),
    ];
    final answer = awareness(records) as KnownStandingCaution;
    expect(answer.standingCount, 2);
    expect(answer.secondCautionSituation, isTrue);
    expect(
      records.where((record) => record.payload is YellowCardPayload),
      hasLength(2),
    );
  });

  test('MATCH and SHOOTOUT ledgers do not share a caution', () {
    final records = [
      bootstrap(),
      yellow(
        recordId: 'y-match',
        originSequence: 2,
        participantId: personA,
        scope: DisciplinaryAccountingScope.match,
      ),
    ];
    expect(
      awareness(records, scope: DisciplinaryAccountingScope.shootout),
      isA<KnownNoStandingCaution>(),
    );
    expect(
      awareness(records, scope: DisciplinaryAccountingScope.match),
      isA<KnownStandingCaution>(),
    );
  });

  test('unresolved scope does not parse as MATCH', () {
    expect(DisciplinaryAccountingScopeWire.parseWire(null), isNull);
    expect(DisciplinaryAccountingScopeWire.parseWire('UNRESOLVED'), isNull);
    expect(DisciplinaryAccountingScopeWire.parseWire(''), isNull);
  });

  test('same intent with a different participant conflicts', () {
    final first = yellow(
      recordId: 'y-1',
      originSequence: 2,
      participantId: personA,
    );
    final admission = evaluateYellowCaptureIntentAdmission(
      key: CaptureIntentKey(
        matchId: matchId,
        authorityScope: const MainRefereeScope(),
        captureIntentId: 'intent-y',
      ),
      requestedMeaning: YellowCaptureIntentMeaning(
        participantId: personB,
        accountingScope: DisciplinaryAccountingScope.match,
        authorityPrincipalId: principalId,
        authorityGeneration: 1,
      ),
      committedForMatch: [bootstrap(), first],
    );
    expect(admission, isA<YellowCaptureIntentConflict>());
  });

  test('same shirt label and different ids do not share cautions', () {
    final records = [
      bootstrap(),
      yellow(recordId: 'y-1', originSequence: 2, participantId: personA),
    ];
    expect(awareness(records, participantId: personB), isA<KnownNoStandingCaution>());
    expect(personA.value, isNot('7'));
    expect(personB.value, isNot('7'));
  });

  test('missing origin sequence is not KnownNo', () {
    final records = [
      bootstrap(),
      yellow(recordId: 'y-3', originSequence: 3, participantId: personA),
    ];
    expect(awareness(records), isA<CautionAwarenessUnavailable>());
  });

  test('withdrawal keeps history and removes standing effect', () {
    final records = [
      bootstrap(),
      yellow(recordId: 'y-1', originSequence: 2, participantId: personA),
      record(
        recordId: 'void-1',
        originSequence: 3,
        recordKind: RecordKind.legalSupersession,
        payload: const LegalSupersessionPayload(),
        relationships: [LegalSupersessionTarget(targetRecordId: 'y-1')],
      ),
    ];
    final answer = awareness(records) as KnownNoStandingCaution;
    expect(answer.historicalYellowRecordIds, ['y-1']);
  });

  test('superseding the yellow correction does not keep the repaired subject', () {
    final records = [
      bootstrap(),
      yellow(recordId: 'y-1', originSequence: 2, participantId: personA),
      record(
        recordId: 'corr-1',
        originSequence: 3,
        recordKind: RecordKind.correction,
        payload: CorrectionPayload(repairedParticipantId: personB),
        relationships: [CorrectionTarget(targetRecordId: 'y-1')],
      ),
      record(
        recordId: 'void-corr',
        originSequence: 4,
        recordKind: RecordKind.legalSupersession,
        payload: const LegalSupersessionPayload(),
        relationships: [LegalSupersessionTarget(targetRecordId: 'corr-1')],
      ),
    ];
    expect(awareness(records, participantId: personB), isA<CautionAwarenessUnavailable>());
    final projection = projector.projectRecords(
      matchId: matchId,
      records: records,
      context: context(),
    );
    expect(projection.scoreProjection, isA<KnownScore>());
  });

  test('an unsuperseded correction moves the standing caution', () {
    final records = [
      bootstrap(),
      yellow(recordId: 'y-1', originSequence: 2, participantId: personA),
      record(
        recordId: 'corr-1',
        originSequence: 3,
        recordKind: RecordKind.correction,
        payload: CorrectionPayload(repairedParticipantId: personB),
        relationships: [CorrectionTarget(targetRecordId: 'y-1')],
      ),
    ];
    expect(awareness(records, participantId: personA), isA<KnownNoStandingCaution>());
    final moved = awareness(records, participantId: personB) as KnownStandingCaution;
    expect(moved.standingCount, 1);
  });

  test('record order does not change the caution answer', () {
    final records = [
      bootstrap(),
      yellow(recordId: 'y-1', originSequence: 2, participantId: personA),
      yellow(
        recordId: 'y-2',
        originSequence: 3,
        participantId: personA,
        captureIntentId: 'intent-y2',
      ),
    ];
    final forward = awareness(records);
    final reverse = awareness(records.reversed.toList());
    expect(forward, isA<KnownStandingCaution>());
    expect(reverse, isA<KnownStandingCaution>());
    expect(
      (forward as KnownStandingCaution).standingCount,
      (reverse as KnownStandingCaution).standingCount,
    );
  });

  test('generation 2 yellow is not a known caution or a known score', () {
    final records = [
      bootstrap(),
      yellow(
        recordId: 'y-gen2',
        originSequence: 2,
        participantId: personA,
        generation: 2,
      ),
    ];
    expect(awareness(records), isA<CautionAwarenessUnavailable>());
    final projection = projector.projectRecords(
      matchId: matchId,
      records: records,
      context: context(),
    );
    expect(projection.scoreProjection, isA<ScoreUnavailable>());
  });

  test('field entry is not match start and is not inferred from it', () {
    final entered = record(
      recordId: 'entered-1',
      originSequence: 1,
      recordKind: RecordKind.temporalFact,
      payload: RefereeEnteredFieldPayload(captureIntentId: 'intent-field'),
    );
    expect(
      entered.payload,
      isA<RefereeEnteredFieldPayload>(),
    );
    final enteredProjection = projector.projectRecords(
      matchId: matchId,
      records: [entered],
      context: context(),
    );
    final enteredTemporal = TemporalMatchProjection.derive(
      projection: enteredProjection,
      records: [entered],
    );
    expect(enteredTemporal.matchStarted, isFalse);

    final started = bootstrap();
    expect(started.payload, isA<TemporalTransitionPayload>());
    expect(
      (started.payload as TemporalTransitionPayload).semanticType,
      V1SemanticTypeCode.matchStarted,
    );
    expect(awareness([started]), isA<KnownNoStandingCaution>());
  });

  test('a caution in another match does not answer this match', () {
    final records = [
      bootstrap(),
      record(
        recordId: 'y-other',
        originSequence: 1,
        recordMatchId: 'match-2',
        recordKind: RecordKind.humanDetermination,
        originDeviceId: 'dev-other',
        payload: YellowCardPayload(
          participantId: personA,
          accountingScope: DisciplinaryAccountingScope.match,
          captureIntentId: 'intent-other',
        ),
      ),
    ];
    expect(awareness(records), isA<KnownNoStandingCaution>());
  });
}
