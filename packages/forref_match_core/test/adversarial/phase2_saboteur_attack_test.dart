import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

void main() {
  const matchId = 'match-1';
  const otherMatchId = 'match-2';
  const deviceId = 'dev-a';
  const principalId = 'ref-1';
  final teamA = MatchTeamId('team-alpha');
  final teamB = MatchTeamId('team-beta');
  final token = '123';
  final person = MatchParticipantId(token);
  final official = MatchTeamOfficialId(token);
  final participant = ParticipantDisciplinarySubject(person);
  final officialSubject = TeamOfficialDisciplinarySubject(official);

  ScoreCompletenessProof proof({
    String rootMatchId = matchId,
    List<MatchTeamBinding>? teamBindings,
    MatchAuthorityMode mode = MatchAuthorityMode.matchMemory,
  }) {
    return ScoreCompletenessProof(
      matchAuthorityMode: mode,
      teamBindings: teamBindings ??
          [
            MatchTeamBinding(matchId: matchId, teamId: teamA),
            MatchTeamBinding(matchId: matchId, teamId: teamB),
          ],
      generationOneRoot: GenerationOneAuthorityRoot(
        matchId: rootMatchId,
        principalId: principalId,
        deviceId: deviceId,
      ),
    );
  }

  MatchRecord record({
    required String recordId,
    required int originSequence,
    required RecordKind recordKind,
    required MatchRecordPayload payload,
    String recordMatchId = matchId,
    List<RecordRelationship> relationships = const [],
    int? generation = 1,
    String originDeviceId = deviceId,
    List<String>? evidenceRefs,
  }) {
    return MatchRecord(
      recordId: recordId,
      matchId: recordMatchId,
      recordKind: recordKind,
      schemaVersion: 1,
      recordedAt: DateTime.utc(2026, 10, 2, 12, originSequence),
      originDeviceId: originDeviceId,
      originSequence: originSequence,
      authorityContext: AuthorityContext(
        scope: const MainRefereeScope(),
        principal: const AuthorityPrincipal(principalId: principalId),
        generation:
            generation == null ? null : AuthorityGeneration(value: generation),
      ),
      payload: payload,
      integrity: IntegrityMetadata(evidenceRefs: evidenceRefs ?? [recordId]),
      relationships: relationships,
    );
  }

  MatchRecord bootstrap(
      {int originSequence = 1, String recordMatchId = matchId}) {
    return record(
      recordId: 'started-$recordMatchId',
      originSequence: originSequence,
      recordKind: RecordKind.temporalFact,
      recordMatchId: recordMatchId,
      payload: TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.matchStarted,
      ),
    );
  }

  MatchRecord yellow({
    required String recordId,
    required int originSequence,
    DisciplinarySubjectRef? subject,
    DisciplinaryAccountingScope scope = DisciplinaryAccountingScope.match,
    String intent = 'intent-y',
    String recordMatchId = matchId,
    int? generation = 1,
    String originDeviceId = deviceId,
    ParticipantSituation? situation,
  }) {
    final chosen = subject ?? participant;
    final payload = chosen is TeamOfficialDisciplinarySubject
        ? YellowCardPayloadV2(
            disciplinarySubject: chosen,
            accountingScope: scope,
            captureIntentId: intent,
          )
        : YellowCardPayload(
            participantId:
                (chosen as ParticipantDisciplinarySubject).participantId,
            accountingScope: scope,
            captureIntentId: intent,
            situationAtDetermination: situation,
          );
    return record(
      recordId: recordId,
      originSequence: originSequence,
      recordKind: RecordKind.humanDetermination,
      recordMatchId: recordMatchId,
      generation: generation,
      originDeviceId: originDeviceId,
      payload: payload,
    );
  }

  MatchRecord sendOff({
    required String recordId,
    required int originSequence,
    required DisciplinarySubjectRef subject,
    required SendOffPathway pathway,
    String? first,
    String? second,
    DisciplinaryAccountingScope scope = DisciplinaryAccountingScope.match,
    String intent = 'intent-send',
    String recordMatchId = matchId,
    int? generation = 1,
    List<RecordRelationship>? relationships,
  }) {
    return record(
      recordId: recordId,
      originSequence: originSequence,
      recordKind: RecordKind.humanDetermination,
      recordMatchId: recordMatchId,
      generation: generation,
      relationships: relationships ??
          (pathway == SendOffPathway.direct
              ? const []
              : [
                  CausalDependency(targetRecordId: first!),
                  CausalDependency(targetRecordId: second!),
                ]),
      payload: SendOffPayload(
        disciplinarySubject: subject,
        disciplinaryScope: scope,
        pathway: pathway,
        captureIntentId: intent,
        firstStandingCautionRecordId: first,
        secondCautionRecordId: second,
      ),
    );
  }

  CautionAwareness awareness(
    List<MatchRecord> records,
    DisciplinarySubjectRef subject, {
    DisciplinaryAccountingScope scope = DisciplinaryAccountingScope.match,
    ScoreCompletenessProof? completeness,
    String assessedMatchId = matchId,
    bool useProof = true,
  }) {
    final before = [
      for (final item in records)
        '${item.recordId}:${item.payload.runtimeType}',
    ];
    final answer = assessDisciplinaryAwareness(
      matchId: assessedMatchId,
      subject: subject,
      accountingScope: scope,
      records: records,
      proof: useProof ? (completeness ?? proof()) : null,
      authorityConflict: false,
      correctionConflict: false,
      missingDependency: false,
      unsupportedSemanticRecordIds: const [],
      missingDependencyTargets: const [],
    );
    expect(
      [
        for (final item in records)
          '${item.recordId}:${item.payload.runtimeType}',
      ],
      before,
    );
    expect(records.where((item) => item.payload is SendOffPayload).length,
        before.where((item) => item.contains('SendOffPayload')).length);
    return answer;
  }

  EffectiveSendOffSet resolveSendOffs(List<MatchRecord> records) {
    final resolution = resolveEffectiveSendOffs(
      recordsById: {for (final item in records) item.recordId: item},
    );
    expect(resolution, isA<EffectiveSendOffSet>());
    return resolution as EffectiveSendOffSet;
  }

  void expectHistory(List<MatchRecord> records, {required bool ready}) {
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
    expect(score.ready, ready);
    expect(history.ready, ready);
    expect(score.conflicted, isFalse);
    expect(history.conflicted, isFalse);
  }

  group('BANK G identity', () {
    test('participant token 123 is not team official 123', () {
      expect(person.value, official.value);
      expect(person, isNot(equals(official)));
      expect(participant.kind, DisciplinarySubjectKind.participant);
      expect(officialSubject.kind, DisciplinarySubjectKind.teamOfficial);
      expect(participant, isNot(officialSubject));
      expect(
        <DisciplinarySubjectRef>{participant, officialSubject, participant},
        hasLength(2),
      );
      expect(
        <Object>{person, official},
        hasLength(2),
      );
      expect(participant.toJson()['subjectKind'], 'PARTICIPANT');
      expect(officialSubject.toJson()['subjectKind'], 'TEAM_OFFICIAL');
      expect(
        DisciplinarySubjectRef.parseJson(participant.toJson()),
        participant,
      );
      expect(
        DisciplinarySubjectRef.parseJson(officialSubject.toJson()),
        officialSubject,
      );
    });

    test('role label map does not fork the official id', () {
      final byRole = <String, MatchTeamOfficialId>{
        'coach': official,
        'fourth official': MatchTeamOfficialId(token),
      };
      expect(byRole['coach'], byRole['fourth official']);
      byRole['manager'] = byRole['coach']!;
      expect(byRole['manager'], official);
      expect(byRole.length, 3);
      expect(<MatchTeamOfficialId>{...byRole.values}, hasLength(1));
      expect(official.value, token);
      expect(official.value.contains('coach'), isFalse);
      expect(official, MatchTeamOfficialId.parseWire(token));
      expect(participant,
          isNot(TeamOfficialDisciplinarySubject(byRole['manager']!)));
    });

    test('match scope does not alias one official token', () {
      final here = MatchScopedTeamOfficialId(
        matchId: matchId,
        teamOfficialId: official,
      );
      final there = MatchScopedTeamOfficialId(
        matchId: otherMatchId,
        teamOfficialId: MatchTeamOfficialId(token),
      );
      expect(here.teamOfficialId, there.teamOfficialId);
      expect(here, isNot(there));
      expect(<MatchScopedTeamOfficialId>{here, there}, hasLength(2));
      expect(MatchScopedTeamOfficialId.fromJson(here.toJson()), here);
      expect(here.toJson().keys, ['matchId', 'teamOfficialId']);

      final assessment = assessTeamOfficialTeamBinding(
        matchId: matchId,
        teamOfficialId: official,
        bindings: [
          TeamOfficialTeamBinding(
            matchId: matchId,
            teamOfficialId: official,
            teamId: teamA,
          ),
          TeamOfficialTeamBinding(
            matchId: otherMatchId,
            teamOfficialId: official,
            teamId: teamB,
          ),
        ],
      );
      expect(assessment, isA<TrustedTeamOfficialBinding>());
      final trusted = assessment as TrustedTeamOfficialBinding;
      expect(trusted.binding.matchId, matchId);
      expect(trusted.binding.teamId, teamA);
      expect(trusted.binding.teamId, isNot(teamB));
    });

    test('two teams for one official are ambiguous and not trusted', () {
      final assessment = assessTeamOfficialTeamBinding(
        matchId: matchId,
        teamOfficialId: official,
        bindings: [
          TeamOfficialTeamBinding(
            matchId: matchId,
            teamOfficialId: official,
            teamId: teamA,
          ),
          TeamOfficialTeamBinding(
            matchId: matchId,
            teamOfficialId: MatchTeamOfficialId(token),
            teamId: teamB,
          ),
        ],
      );
      expect(assessment, isA<AmbiguousTeamOfficialBinding>());
      expect(assessment, isNot(isA<TrustedTeamOfficialBinding>()));
      expect(assessment, isNot(isA<MissingTeamOfficialBinding>()));
    });
  });

  group('BANK B2 yellow', () {
    test('v1 yellow stays a participant subject at schema 1', () {
      final payload = YellowCardPayload(
        participantId: person,
        accountingScope: DisciplinaryAccountingScope.match,
        captureIntentId: 'intent-v1',
      );
      final stored = record(
        recordId: 'y-v1',
        originSequence: 2,
        recordKind: RecordKind.humanDetermination,
        payload: payload,
      );
      expect(stored.schemaVersion, 1);
      expect(payload.participantId, person);
      expect(payload.yellowSchemaVersion, 1);
      expect(yellowCardPayloadSchemaVersion(payload), 1);
      final subject = subjectOfYellowCard(payload);
      expect(subject, participant);
      expect(subject, isA<ParticipantDisciplinarySubject>());
      expect(subject, isNot(isA<TeamOfficialDisciplinarySubject>()));
      expect(subject.kind, DisciplinarySubjectKind.participant);
      expect(subject, isNot(officialSubject));
    });

    test('v2 official yellow keeps match schema 1 and payload schema 2', () {
      final payload = YellowCardPayloadV2(
        disciplinarySubject: officialSubject,
        accountingScope: DisciplinaryAccountingScope.match,
        captureIntentId: 'intent-official',
      );
      final stored = record(
        recordId: 'y-v2',
        originSequence: 2,
        recordKind: RecordKind.humanDetermination,
        payload: payload,
      );
      expect(stored.schemaVersion, 1);
      expect(payload.yellowSchemaVersion, 2);
      expect(yellowCardPayloadSchemaVersion(payload), 2);
      expect(subjectOfYellowCard(payload), officialSubject);
      expect(
        subjectOfYellowCard(payload),
        isNot(participant),
      );
    });

    test('v2 official yellow without a trusted binding is missing', () {
      final absent = assessTeamOfficialTeamBinding(
        matchId: matchId,
        teamOfficialId: official,
        bindings: const [],
      );
      expect(absent, isA<MissingTeamOfficialBinding>());
      expect(absent, isNot(isA<TrustedTeamOfficialBinding>()));

      final otherMatchOnly = assessTeamOfficialTeamBinding(
        matchId: matchId,
        teamOfficialId: official,
        bindings: [
          TeamOfficialTeamBinding(
            matchId: otherMatchId,
            teamOfficialId: official,
            teamId: teamA,
          ),
        ],
      );
      expect(otherMatchOnly, isA<MissingTeamOfficialBinding>());
      expect(otherMatchOnly, isNot(isA<TrustedTeamOfficialBinding>()));
    });

    test('team-official situation is rejected on v2', () {
      expect(
        () => YellowCardPayloadV2(
          disciplinarySubject: officialSubject,
          accountingScope: DisciplinaryAccountingScope.match,
          captureIntentId: 'intent-official',
          participantSituationAtDetermination: ParticipantSituation.onField,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('a yellow meaning cannot be both participant and official', () {
      expect(
        () => YellowCaptureIntentMeaning(
          participantId: person,
          disciplinarySubject: officialSubject,
          accountingScope: DisciplinaryAccountingScope.match,
          authorityPrincipalId: principalId,
          authorityGeneration: 1,
        ),
        throwsArgumentError,
      );
    });

    test('same capture intent participant versus official conflicts', () {
      final committed = yellow(
        recordId: 'y-v1',
        originSequence: 2,
        intent: 'intent-shared',
      );
      final admission = evaluateYellowCaptureIntentAdmission(
        key: CaptureIntentKey(
          matchId: matchId,
          authorityScope: const MainRefereeScope(),
          captureIntentId: 'intent-shared',
        ),
        requestedMeaning: YellowCaptureIntentMeaning(
          disciplinarySubject: officialSubject,
          accountingScope: DisciplinaryAccountingScope.match,
          authorityPrincipalId: principalId,
          authorityGeneration: 1,
        ),
        committedForMatch: [bootstrap(), committed],
      );
      expect(admission, isA<YellowCaptureIntentConflict>());
      expect(
        (admission as YellowCaptureIntentConflict).existingRecordId,
        'y-v1',
      );
    });

    test('same intent with a changed accounting scope conflicts', () {
      final committed = yellow(
        recordId: 'y-v1',
        originSequence: 2,
        intent: 'intent-shared',
      );
      final admission = evaluateYellowCaptureIntentAdmission(
        key: CaptureIntentKey(
          matchId: matchId,
          authorityScope: const MainRefereeScope(),
          captureIntentId: 'intent-shared',
        ),
        requestedMeaning: YellowCaptureIntentMeaning(
          participantId: person,
          accountingScope: DisciplinaryAccountingScope.shootout,
          authorityPrincipalId: principalId,
          authorityGeneration: 1,
        ),
        committedForMatch: [committed],
      );
      expect(admission, isA<YellowCaptureIntentConflict>());
    });

    test('a send-off already bound to the intent conflicts with a yellow', () {
      final committed = sendOff(
        recordId: 'so-1',
        originSequence: 2,
        subject: participant,
        pathway: SendOffPathway.direct,
        intent: 'intent-shared',
      );
      final admission = evaluateYellowCaptureIntentAdmission(
        key: CaptureIntentKey(
          matchId: matchId,
          authorityScope: const MainRefereeScope(),
          captureIntentId: 'intent-shared',
        ),
        requestedMeaning: YellowCaptureIntentMeaning(
          participantId: person,
          accountingScope: DisciplinaryAccountingScope.match,
          authorityPrincipalId: principalId,
          authorityGeneration: 1,
        ),
        committedForMatch: [committed],
      );
      expect(admission, isA<YellowCaptureIntentConflict>());
      expect(
        (admission as YellowCaptureIntentConflict).existingRecordId,
        'so-1',
      );
    });

    test('the same intent in another match does not alias', () {
      final elsewhere = yellow(
        recordId: 'y-other',
        originSequence: 1,
        recordMatchId: otherMatchId,
        intent: 'intent-shared',
        subject: officialSubject,
      );
      final admission = evaluateYellowCaptureIntentAdmission(
        key: CaptureIntentKey(
          matchId: matchId,
          authorityScope: const MainRefereeScope(),
          captureIntentId: 'intent-shared',
        ),
        requestedMeaning: YellowCaptureIntentMeaning(
          participantId: person,
          accountingScope: DisciplinaryAccountingScope.match,
          authorityPrincipalId: principalId,
          authorityGeneration: 1,
        ),
        committedForMatch: [elsewhere],
      );
      expect(admission, isA<YellowCaptureIntentFirstAdmission>());
    });

    test('a MATCH yellow is not a SHOOTOUT caution', () {
      final records = [
        bootstrap(),
        yellow(recordId: 'y-match', originSequence: 2, intent: 'intent-match'),
      ];
      final matchAnswer = awareness(records, participant);
      final shootoutAnswer = awareness(
        records,
        participant,
        scope: DisciplinaryAccountingScope.shootout,
      );
      expect(matchAnswer, isA<KnownStandingCaution>());
      expect(
        (matchAnswer as KnownStandingCaution).standingYellowRecordIds,
        ['y-match'],
      );
      expect(shootoutAnswer, isA<KnownNoStandingCaution>());
      final shootoutNone = shootoutAnswer as KnownNoStandingCaution;
      expect(shootoutNone.historicalYellowRecordIds, isEmpty);
      expect(shootoutNone.activeCautionSurface, isTrue);

      final shootoutOnly = [
        bootstrap(),
        yellow(
          recordId: 'y-pens',
          originSequence: 2,
          intent: 'intent-pens',
          scope: DisciplinaryAccountingScope.shootout,
        ),
      ];
      expect(
        awareness(shootoutOnly, participant),
        isA<KnownNoStandingCaution>(),
      );
      expect(
        awareness(
          shootoutOnly,
          participant,
          scope: DisciplinaryAccountingScope.shootout,
        ),
        isA<KnownStandingCaution>(),
      );
    });

    test('an official yellow does not count as the participant token', () {
      final records = [
        bootstrap(),
        yellow(
          recordId: 'y-off',
          originSequence: 2,
          subject: officialSubject,
          intent: 'intent-official',
        ),
      ];
      expect(records[1].schemaVersion, 1);
      expect(yellowCardPayloadSchemaVersion(records[1].payload), 2);
      final officialAnswer = awareness(records, officialSubject);
      final playerAnswer = awareness(records, participant);
      expect(officialAnswer, isA<KnownStandingCaution>());
      expect(playerAnswer, isA<KnownNoStandingCaution>());
      expect(
        (playerAnswer as KnownNoStandingCaution).historicalYellowRecordIds,
        isEmpty,
      );
    });
  });

  group('BANK D send-off', () {
    test('two yellows create no SEND_OFF and awareness appends none', () {
      final records = [
        bootstrap(),
        yellow(recordId: 'y1', originSequence: 2, intent: 'intent-1'),
        yellow(recordId: 'y2', originSequence: 3, intent: 'intent-2'),
      ];
      final answer = awareness(records, participant) as KnownStandingCaution;
      expect(answer.standingCount, 2);
      expect(answer.secondCautionSituation, isTrue);
      expect(answer.activeCautionSurface, isTrue);
      expect(records.where((item) => item.payload is SendOffPayload), isEmpty);
      expect(resolveSendOffs(records).sendOffs, isEmpty);
    });

    test('direct SEND_OFF has no yellow ids and dependency ready', () {
      final direct = sendOff(
        recordId: 'so-direct',
        originSequence: 1,
        subject: participant,
        pathway: SendOffPathway.direct,
      );
      final payload = direct.payload as SendOffPayload;
      expect(payload.firstStandingCautionRecordId, isNull);
      expect(payload.secondCautionRecordId, isNull);
      expect(payload.pathway, SendOffPathway.direct);
      final resolved = resolveSendOffs([direct]);
      expect(resolved.sendOffs, hasLength(1));
      expect(resolved.sendOffs.single.dependencyStatus,
          SendOffDependencyStatus.ready);
      expect(resolved.sendOffs.single.legallyEffective, isTrue);
    });

    test('a direct SEND_OFF with a causal yellow link is unavailable', () {
      final resolved = resolveSendOffs([
        yellow(recordId: 'y1', originSequence: 1, intent: 'intent-1'),
        sendOff(
          recordId: 'so-linked',
          originSequence: 2,
          subject: participant,
          pathway: SendOffPathway.direct,
          relationships: [const CausalDependency(targetRecordId: 'y1')],
        ),
      ]);
      expect(
        resolved.sendOffs.single.dependencyStatus,
        SendOffDependencyStatus.unavailable,
      );
    });

    test('Y1 equal to Y2 throws', () {
      expect(
        () => SendOffPayload(
          disciplinarySubject: participant,
          disciplinaryScope: DisciplinaryAccountingScope.match,
          pathway: SendOffPathway.secondCaution,
          captureIntentId: 'intent-send',
          firstStandingCautionRecordId: 'y1',
          secondCautionRecordId: 'y1',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('missing Y2 is an unavailable dependency', () {
      final resolved = resolveSendOffs([
        yellow(recordId: 'y1', originSequence: 1, intent: 'intent-1'),
        sendOff(
          recordId: 'so-missing',
          originSequence: 2,
          subject: participant,
          pathway: SendOffPathway.secondCaution,
          first: 'y1',
          second: 'y-missing',
        ),
      ]);
      expect(
        resolved.sendOffs.single.dependencyStatus,
        SendOffDependencyStatus.unavailable,
      );
    });

    test('wrong subject, including the same raw token, is unavailable', () {
      final resolved = resolveSendOffs([
        yellow(
          recordId: 'y1',
          originSequence: 1,
          subject: officialSubject,
          intent: 'intent-1',
        ),
        yellow(
          recordId: 'y2',
          originSequence: 2,
          subject: officialSubject,
          intent: 'intent-2',
        ),
        sendOff(
          recordId: 'so-alias',
          originSequence: 3,
          subject: participant,
          pathway: SendOffPathway.secondCaution,
          first: 'y1',
          second: 'y2',
        ),
      ]);
      expect(resolved.sendOffs.single.subject, participant);
      expect(
        resolved.sendOffs.single.dependencyStatus,
        SendOffDependencyStatus.unavailable,
      );
    });

    test('wrong accounting scope is unavailable', () {
      final resolved = resolveSendOffs([
        yellow(recordId: 'y1', originSequence: 1, intent: 'intent-1'),
        yellow(recordId: 'y2', originSequence: 2, intent: 'intent-2'),
        sendOff(
          recordId: 'so-scope',
          originSequence: 3,
          subject: participant,
          pathway: SendOffPathway.secondCaution,
          scope: DisciplinaryAccountingScope.shootout,
          first: 'y1',
          second: 'y2',
        ),
      ]);
      expect(
        resolved.sendOffs.single.dependencyStatus,
        SendOffDependencyStatus.unavailable,
      );
    });

    test('a non-yellow dependency is unavailable', () {
      final resolved = resolveSendOffs([
        record(
          recordId: 'sub-1',
          originSequence: 1,
          recordKind: RecordKind.humanDetermination,
          payload: SubstitutionPayload(
            outgoingParticipantId: person,
            incomingParticipantId: MatchParticipantId('bench'),
            teamId: teamA,
            captureIntentId: 'intent-sub',
          ),
        ),
        yellow(recordId: 'y2', originSequence: 2, intent: 'intent-2'),
        sendOff(
          recordId: 'so-sub',
          originSequence: 3,
          subject: participant,
          pathway: SendOffPathway.secondCaution,
          first: 'sub-1',
          second: 'y2',
        ),
      ]);
      expect(
        resolved.sendOffs.single.dependencyStatus,
        SendOffDependencyStatus.unavailable,
      );
    });

    test('roles are the named ids, not origin time', () {
      final resolved = resolveSendOffs([
        yellow(recordId: 'y-later-role', originSequence: 1, intent: 'intent-1'),
        yellow(
            recordId: 'y-earlier-role', originSequence: 5, intent: 'intent-2'),
        sendOff(
          recordId: 'so-roles',
          originSequence: 6,
          subject: participant,
          pathway: SendOffPathway.secondCaution,
          first: 'y-earlier-role',
          second: 'y-later-role',
          relationships: [
            const CausalDependency(targetRecordId: 'y-later-role'),
            const CausalDependency(targetRecordId: 'y-earlier-role'),
          ],
        ),
      ]);
      expect(
        resolved.sendOffs.single.dependencyStatus,
        SendOffDependencyStatus.ready,
      );
      expect(resolved.sendOffs.single.pathway, SendOffPathway.secondCaution);
    });

    test('relates-to links do not satisfy second-caution causality', () {
      final resolved = resolveSendOffs([
        yellow(recordId: 'y1', originSequence: 1, intent: 'intent-1'),
        yellow(recordId: 'y2', originSequence: 2, intent: 'intent-2'),
        sendOff(
          recordId: 'so-rel',
          originSequence: 3,
          subject: participant,
          pathway: SendOffPathway.secondCaution,
          first: 'y1',
          second: 'y2',
          relationships: [
            const RelatesTo(targetRecordId: 'y1'),
            const RelatesTo(targetRecordId: 'y2'),
          ],
        ),
      ]);
      expect(
        resolved.sendOffs.single.dependencyStatus,
        SendOffDependencyStatus.unavailable,
      );
    });
  });

  group('BANK E substitution', () {
    final outId = MatchParticipantId('out-1');
    final inId = MatchParticipantId('in-1');

    SubstitutionPayload subPayload({
      MatchParticipantId? outgoing,
      MatchParticipantId? incoming,
      MatchTeamId? team,
      CompetitionRulesContext? rules,
    }) {
      return SubstitutionPayload(
        outgoingParticipantId: outgoing ?? outId,
        incomingParticipantId: incoming ?? inId,
        teamId: team ?? teamA,
        captureIntentId: 'intent-sub',
        competitionRulesContext: rules,
      );
    }

    List<MatchParticipantTeamBinding> bothOn(MatchTeamId team) => [
          MatchParticipantTeamBinding(
            matchId: matchId,
            participantId: outId,
            teamId: team,
          ),
          MatchParticipantTeamBinding(
            matchId: matchId,
            participantId: inId,
            teamId: team,
          ),
        ];

    test('the same incoming and outgoing id throws', () {
      expect(
        () => SubstitutionPayload(
          outgoingParticipantId: person,
          incomingParticipantId: MatchParticipantId(token),
          teamId: teamA,
          captureIntentId: 'intent-sub',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('cross-team substitution is rejected', () {
      final admission = evaluateSubstitutionAdmission(
        matchId: matchId,
        payload: subPayload(),
        bindings: [
          MatchParticipantTeamBinding(
            matchId: matchId,
            participantId: outId,
            teamId: teamA,
          ),
          MatchParticipantTeamBinding(
            matchId: matchId,
            participantId: inId,
            teamId: teamB,
          ),
        ],
      );
      expect(admission, isA<SubstitutionRejected>());
      expect((admission as SubstitutionRejected).reason,
          'cross-team substitution');
    });

    test('a missing binding is rejected', () {
      final missingIncoming = evaluateSubstitutionAdmission(
        matchId: matchId,
        payload: subPayload(),
        bindings: [
          MatchParticipantTeamBinding(
            matchId: matchId,
            participantId: outId,
            teamId: teamA,
          ),
        ],
      );
      expect(missingIncoming, isA<SubstitutionRejected>());
      expect(
        (missingIncoming as SubstitutionRejected).reason,
        'missing team binding',
      );

      final otherMatch = evaluateSubstitutionAdmission(
        matchId: matchId,
        payload: subPayload(),
        bindings: [
          MatchParticipantTeamBinding(
            matchId: otherMatchId,
            participantId: outId,
            teamId: teamA,
          ),
          MatchParticipantTeamBinding(
            matchId: otherMatchId,
            participantId: inId,
            teamId: teamA,
          ),
        ],
      );
      expect(otherMatch, isA<SubstitutionRejected>());
      expect(
          (otherMatch as SubstitutionRejected).reason, 'missing team binding');
    });

    test('an ambiguous binding is rejected', () {
      final admission = evaluateSubstitutionAdmission(
        matchId: matchId,
        payload: subPayload(),
        bindings: [
          ...bothOn(teamA),
          MatchParticipantTeamBinding(
            matchId: matchId,
            participantId: outId,
            teamId: teamB,
          ),
        ],
      );
      expect(admission, isA<SubstitutionRejected>());
      expect(
        (admission as SubstitutionRejected).reason,
        'ambiguous team binding',
      );
    });

    test('matching bindings admit without a competition profile', () {
      final bare = subPayload();
      expect(bare.competitionRulesContext, isNull);
      final admitted = evaluateSubstitutionAdmission(
        matchId: matchId,
        payload: bare,
        bindings: bothOn(teamA),
      );
      expect(admitted, isA<SubstitutionAdmitted>());

      final withRules = evaluateSubstitutionAdmission(
        matchId: matchId,
        payload: subPayload(
          rules: const CompetitionRulesContext(
            rulesetId: 'profile-not-consulted',
            additionalPlayingPhase:
                AdditionalPlayingPhaseDisposition.noneRequired,
            penaltyShootOutAfterMatchEnd: true,
          ),
        ),
        bindings: bothOn(teamA),
      );
      expect(withRules, isA<SubstitutionAdmitted>());
    });

    test('a later return projects the same id on field', () {
      MatchRecord substitution({
        required String recordId,
        required int originSequence,
        required MatchParticipantId outgoing,
        required MatchParticipantId incoming,
      }) {
        return record(
          recordId: recordId,
          originSequence: originSequence,
          recordKind: RecordKind.humanDetermination,
          payload: SubstitutionPayload(
            outgoingParticipantId: outgoing,
            incomingParticipantId: incoming,
            teamId: teamA,
            captureIntentId: 'intent-$recordId',
          ),
        );
      }

      final ordered = [
        substitution(
          recordId: 'sub-out',
          originSequence: 1,
          outgoing: person,
          incoming: inId,
        ),
        substitution(
          recordId: 'sub-back',
          originSequence: 2,
          outgoing: inId,
          incoming: person,
        ),
      ];
      final reversed = [ordered[1], ordered[0]];
      final forward = projectParticipantStatus(
        recordsById: {for (final item in ordered) item.recordId: item},
      ) as ProjectedParticipantStatus;
      final backward = projectParticipantStatus(
        recordsById: {for (final item in reversed) item.recordId: item},
      ) as ProjectedParticipantStatus;
      expect(forward.statusByParticipant[person], ParticipantSituation.onField);
      expect(
          forward.statusByParticipant[inId], ParticipantSituation.substituted);
      expect(
          backward.statusByParticipant[person], ParticipantSituation.onField);
      expect(backward.statusByParticipant, forward.statusByParticipant);
      expect(person, MatchParticipantId(token));
    });

    test('a repair that makes IN and OUT the same id is conflicted', () {
      final records = [
        record(
          recordId: 'sub-1',
          originSequence: 1,
          recordKind: RecordKind.humanDetermination,
          payload: SubstitutionPayload(
            outgoingParticipantId: person,
            incomingParticipantId: inId,
            teamId: teamA,
            captureIntentId: 'intent-sub',
          ),
        ),
        record(
          recordId: 'corr-1',
          originSequence: 2,
          recordKind: RecordKind.correction,
          relationships: [const CorrectionTarget(targetRecordId: 'sub-1')],
          payload: CorrectionPayload(
            repairedIncomingParticipantId: person,
          ),
        ),
      ];
      expect(
        resolveEffectiveSubstitutions(
          recordsById: {for (final item in records) item.recordId: item},
        ),
        isA<EffectiveSubstitutionConflicted>(),
      );
      expect(
        projectParticipantStatus(
          recordsById: {for (final item in records) item.recordId: item},
        ),
        isA<ParticipantStatusConflicted>(),
      );
    });
  });

  group('STATUS-AWARENESS', () {
    test('a null proof is unavailable and not known none', () {
      final quiet = [bootstrap()];
      final withYellow = [
        bootstrap(),
        yellow(recordId: 'y-1', originSequence: 2, intent: 'intent-y'),
      ];
      final none = awareness(quiet, participant, useProof: false);
      final standing = awareness(withYellow, participant, useProof: false);
      expect(none, isA<CautionAwarenessUnavailable>());
      expect(none, isNot(isA<KnownNoStandingCaution>()));
      expect(none, isNot(isA<KnownStandingCaution>()));
      expect(standing, isA<CautionAwarenessUnavailable>());
      expect(standing, isNot(isA<KnownNoStandingCaution>()));
      expect(standing, isNot(isA<KnownStandingCaution>()));
    });

    test('an incomplete proof is not known none', () {
      final quiet = [bootstrap()];
      final oneTeam = awareness(
        quiet,
        participant,
        completeness: proof(
          teamBindings: [
            MatchTeamBinding(matchId: matchId, teamId: teamA),
          ],
        ),
      );
      final legacy = awareness(
        quiet,
        participant,
        completeness: proof(mode: MatchAuthorityMode.legacyOnly),
      );
      final wrongMatch = awareness(
        quiet,
        participant,
        completeness: proof(rootMatchId: otherMatchId),
      );
      final gapped = [
        bootstrap(),
        record(
          recordId: 'goal-gap',
          originSequence: 3,
          recordKind: RecordKind.humanDetermination,
          payload: GoalPayload(
            scoringTeamId: teamA,
            captureIntentId: 'intent-goal',
          ),
        ),
      ];
      final gapAnswer = awareness(gapped, participant);
      for (final answer in [oneTeam, legacy, wrongMatch, gapAnswer]) {
        expect(answer, isA<CautionAwarenessUnavailable>());
        expect(answer, isNot(isA<KnownNoStandingCaution>()));
        expect(answer, isNot(isA<KnownStandingCaution>()));
      }
    });

    test('substitution leaves the standing yellow on the same participant id',
        () {
      final bench = MatchParticipantId('bench-9');
      final records = [
        bootstrap(),
        yellow(
          recordId: 'y-1',
          originSequence: 2,
          intent: 'intent-y',
          situation: ParticipantSituation.onField,
        ),
        record(
          recordId: 'sub-out',
          originSequence: 3,
          recordKind: RecordKind.humanDetermination,
          payload: SubstitutionPayload(
            outgoingParticipantId: person,
            incomingParticipantId: bench,
            teamId: teamA,
            captureIntentId: 'intent-sub-out',
          ),
        ),
        record(
          recordId: 'sub-back',
          originSequence: 4,
          recordKind: RecordKind.humanDetermination,
          payload: SubstitutionPayload(
            outgoingParticipantId: bench,
            incomingParticipantId: person,
            teamId: teamA,
            captureIntentId: 'intent-sub-back',
          ),
        ),
      ];
      final status = projectParticipantStatus(
        recordsById: {for (final item in records) item.recordId: item},
      ) as ProjectedParticipantStatus;
      expect(status.statusByParticipant[person], ParticipantSituation.onField);
      expect(
          status.statusByParticipant[bench], ParticipantSituation.substituted);
      final answer = awareness(records, participant) as KnownStandingCaution;
      expect(answer.standingCount, 1);
      expect(answer.standingYellowRecordIds, ['y-1']);
      expect(answer.historicalYellowRecordIds, ['y-1']);
      expect(answer.activeCautionSurface, isTrue);
      final yellowRecord = records.firstWhere((item) => item.recordId == 'y-1');
      expect(
        (yellowRecord.payload as YellowCardPayload).participantId,
        person,
      );
      expect(
        awareness(records, officialSubject),
        isA<KnownNoStandingCaution>(),
      );
    });
  });

  group('AWARENESS-SENDOFF', () {
    test('explicit SEND_OFF keeps historical yellow ids and drops the surface',
        () {
      final records = [
        bootstrap(),
        yellow(recordId: 'y1', originSequence: 2, intent: 'intent-1'),
        yellow(recordId: 'y2', originSequence: 3, intent: 'intent-2'),
        sendOff(
          recordId: 'so-1',
          originSequence: 4,
          subject: participant,
          pathway: SendOffPathway.secondCaution,
          first: 'y1',
          second: 'y2',
        ),
      ];
      final answer = awareness(records, participant) as KnownStandingCaution;
      expect(answer.historicalYellowRecordIds, ['y1', 'y2']);
      expect(answer.standingYellowRecordIds, ['y1', 'y2']);
      expect(answer.activeCautionSurface, isFalse);
      expect(
        records
            .where((item) => item.payload is YellowCardPayload)
            .map((item) => item.recordId),
        ['y1', 'y2'],
      );
      expect(records.where((item) => item.payload is SendOffPayload),
          hasLength(1));
    });

    test('a voided SEND_OFF does not keep the surface closed', () {
      final records = [
        bootstrap(),
        yellow(recordId: 'y1', originSequence: 2, intent: 'intent-1'),
        sendOff(
          recordId: 'so-1',
          originSequence: 3,
          subject: participant,
          pathway: SendOffPathway.direct,
        ),
        record(
          recordId: 'void-so',
          originSequence: 4,
          recordKind: RecordKind.legalSupersession,
          payload: const LegalSupersessionPayload(),
          relationships: [LegalSupersessionTarget(targetRecordId: 'so-1')],
        ),
      ];
      final answer = awareness(records, participant) as KnownStandingCaution;
      expect(answer.activeCautionSurface, isTrue);
      expect(answer.historicalYellowRecordIds, ['y1']);
      expect(records.where((item) => item.payload is SendOffPayload),
          hasLength(1));
    });

    test('a SHOOTOUT send-off does not close the MATCH caution surface', () {
      final records = [
        bootstrap(),
        yellow(recordId: 'y1', originSequence: 2, intent: 'intent-1'),
        sendOff(
          recordId: 'so-pens',
          originSequence: 3,
          subject: participant,
          pathway: SendOffPathway.direct,
          scope: DisciplinaryAccountingScope.shootout,
        ),
      ];
      final matchAnswer =
          awareness(records, participant) as KnownStandingCaution;
      expect(matchAnswer.activeCautionSurface, isTrue);
      expect(matchAnswer.historicalYellowRecordIds, ['y1']);
      final shootoutAnswer = awareness(
        records,
        participant,
        scope: DisciplinaryAccountingScope.shootout,
      ) as KnownNoStandingCaution;
      expect(shootoutAnswer.activeCautionSurface, isFalse);
      expect(shootoutAnswer.historicalYellowRecordIds, isEmpty);
    });

    test('another match send-off does not close this match caution surface',
        () {
      final records = [
        bootstrap(),
        yellow(recordId: 'y1', originSequence: 2, intent: 'intent-1'),
        sendOff(
          recordId: 'so-other-match',
          originSequence: 1,
          recordMatchId: otherMatchId,
          subject: participant,
          pathway: SendOffPathway.direct,
          intent: 'intent-other-send',
        ),
        yellow(
          recordId: 'y-other-match',
          originSequence: 2,
          recordMatchId: otherMatchId,
          intent: 'intent-other-y',
        ),
      ];
      expectHistory(
        [
          records[0],
          records[1],
        ],
        ready: true,
      );
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
      expect(score.ready, isTrue,
          reason: 'other-match rows must not open a gap');
      final answer = awareness(records, participant) as KnownStandingCaution;
      expect(answer.activeCautionSurface, isTrue);
      expect(answer.historicalYellowRecordIds, ['y1']);
      expect(
          answer.historicalYellowRecordIds, isNot(contains('y-other-match')));
      expect(answer.standingCount, 1);
    });

    test(
        'another match yellows do not close this match surface through SEND_OFF',
        () {
      final records = [
        bootstrap(),
        sendOff(
          recordId: 'so-1',
          originSequence: 2,
          subject: participant,
          pathway: SendOffPathway.secondCaution,
          first: 'y1',
          second: 'y2',
          intent: 'intent-send',
        ),
        yellow(
          recordId: 'y1',
          originSequence: 1,
          recordMatchId: otherMatchId,
          intent: 'intent-1',
        ),
        yellow(
          recordId: 'y2',
          originSequence: 2,
          recordMatchId: otherMatchId,
          intent: 'intent-2',
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
      expect(score.ready, isTrue, reason: 'other-match yellows are not a gap');
      final answer = awareness(records, participant);
      final surface = switch (answer) {
        KnownStandingCaution known => known.activeCautionSurface,
        KnownNoStandingCaution known => known.activeCautionSurface,
        _ => null,
      };
      expect(surface, isNot(false));
      if (answer is KnownStandingCaution || answer is KnownNoStandingCaution) {
        final historical = answer is KnownStandingCaution
            ? answer.historicalYellowRecordIds
            : (answer as KnownNoStandingCaution).historicalYellowRecordIds;
        expect(historical, isNot(contains('y1')));
        expect(historical, isNot(contains('y2')));
      }
    });

    test('an official send-off does not close the participant surface', () {
      final records = [
        bootstrap(),
        yellow(recordId: 'y1', originSequence: 2, intent: 'intent-1'),
        sendOff(
          recordId: 'so-off',
          originSequence: 3,
          subject: officialSubject,
          pathway: SendOffPathway.direct,
          intent: 'intent-official-send',
        ),
      ];
      final player = awareness(records, participant) as KnownStandingCaution;
      expect(player.activeCautionSurface, isTrue);
      expect(player.historicalYellowRecordIds, ['y1']);
      final coach =
          awareness(records, officialSubject) as KnownNoStandingCaution;
      expect(coach.activeCautionSurface, isFalse);
      expect(coach.historicalYellowRecordIds, isEmpty);
    });
  });

  group('CROSS-DOMAIN history', () {
    test('a contiguous generation-1 history is ready on both proofs', () {
      expectHistory([bootstrap()], ready: true);
    });

    test('a foreign origin device makes both proofs not ready', () {
      final records = [
        bootstrap(),
        yellow(
          recordId: 'y-foreign',
          originSequence: 1,
          originDeviceId: 'dev-b',
          intent: 'intent-foreign',
        ),
      ];
      expectHistory(records, ready: false);
      final answer = awareness(records, participant);
      expect(answer, isA<CautionAwarenessUnavailable>());
      expect(answer, isNot(isA<KnownStandingCaution>()));
      expect(answer, isNot(isA<KnownNoStandingCaution>()));
    });

    test('an origin gap makes both proofs not ready', () {
      final records = [
        bootstrap(),
        yellow(recordId: 'y-gap', originSequence: 3, intent: 'intent-gap'),
      ];
      expectHistory(records, ready: false);
      expect(
        awareness(records, participant),
        isA<CautionAwarenessUnavailable>(),
      );
    });

    test('generation other than 1 makes both proofs not ready', () {
      final cases = <List<MatchRecord>>[
        [
          bootstrap(),
          record(
            recordId: 'goal-g2',
            originSequence: 2,
            recordKind: RecordKind.humanDetermination,
            generation: 2,
            payload: GoalPayload(
              scoringTeamId: teamA,
              captureIntentId: 'intent-goal',
            ),
          ),
        ],
        [
          bootstrap(),
          yellow(
            recordId: 'y-g2',
            originSequence: 2,
            generation: 2,
            intent: 'intent-g2',
          ),
        ],
        [
          bootstrap(),
          yellow(
            recordId: 'y-null-gen',
            originSequence: 2,
            generation: null,
            intent: 'intent-null-gen',
          ),
        ],
        [
          bootstrap(),
          sendOff(
            recordId: 'so-g2',
            originSequence: 2,
            subject: participant,
            pathway: SendOffPathway.direct,
            generation: 2,
            intent: 'intent-so-g2',
          ),
        ],
        [
          bootstrap(),
          record(
            recordId: 'sub-g2',
            originSequence: 2,
            recordKind: RecordKind.humanDetermination,
            generation: 2,
            payload: SubstitutionPayload(
              outgoingParticipantId: person,
              incomingParticipantId: MatchParticipantId('bench'),
              teamId: teamA,
              captureIntentId: 'intent-sub-g2',
            ),
          ),
        ],
        [
          bootstrap(),
          record(
            recordId: 'enter-g2',
            originSequence: 2,
            recordKind: RecordKind.temporalFact,
            generation: 2,
            payload: RefereeEnteredFieldPayload(
              captureIntentId: 'intent-enter-g2',
            ),
          ),
        ],
      ];
      for (final records in cases) {
        expectHistory(records, ready: false);
      }
    });
  });
}
