import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

/// Independent night-program attacks against production SHA
/// f0f5e968925921139e41da06a9a384cc2078ba78.
///
/// Expectations are the fail-closed contract. A red test is evidence.
/// This file does not repair production code.
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
        generationOneRoot: const GenerationOneAuthorityRoot(
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
        principal: const AuthorityPrincipal(principalId: principalId),
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

  MatchRecord bootstrap({int sequence = 1, String recordId = 'started-1'}) =>
      record(
        recordId: recordId,
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
  }) {
    return record(
      recordId: recordId,
      originSequence: originSequence,
      recordKind: RecordKind.humanDetermination,
      generation: generation,
      payload: YellowCardPayload(
        participantId: participantId,
        accountingScope: scope,
        captureIntentId: captureIntentId,
        situationAtDetermination: situation,
      ),
    );
  }

  MatchProjectionState project(List<MatchRecord> records) {
    return projector.projectRecords(
      matchId: matchId,
      records: records,
      context: context(),
    );
  }

  CautionAwareness awareness(
    List<MatchRecord> records, {
    MatchParticipantId? participantId,
    DisciplinaryAccountingScope scope = DisciplinaryAccountingScope.match,
    ScoreCompletenessProof? completeness,
    bool useProof = true,
    bool authorityConflict = false,
    bool correctionConflict = false,
    List<String>? unsupportedSemanticRecordIds,
    List<String>? missingDependencyTargets,
  }) {
    final projection = project(records);
    return assessCautionAwareness(
      matchId: matchId,
      participantId: participantId ?? personA,
      accountingScope: scope,
      records: records,
      proof: useProof ? (completeness ?? proof()) : null,
      authorityConflict: authorityConflict,
      correctionConflict: correctionConflict,
      missingDependency: projection.missingDependencyTargets.isNotEmpty,
      unsupportedSemanticRecordIds:
          unsupportedSemanticRecordIds ?? projection.unsupportedSemanticRecordIds,
      missingDependencyTargets:
          missingDependencyTargets ?? projection.missingDependencyTargets,
    );
  }

  String fingerprint(List<MatchRecord> records) => records
      .map(
        (item) =>
            '${item.recordId}|${item.originSequence}|${item.originDeviceId}|'
            '${item.matchId}|${item.payload.runtimeType}',
      )
      .join(',');

  KnownScore knownScore(List<MatchRecord> records) {
    final score = project(records).scoreProjection;
    expect(score, isA<KnownScore>(), reason: '${score.runtimeType}');
    return score as KnownScore;
  }

  group('BANK A', () {
    test('same shirt-looking label is not identity', () {
      final shirt = MatchParticipantId('7');
      final padded = MatchParticipantId('7 ');
      final zeroPadded = MatchParticipantId('07');
      final fullwidth = MatchParticipantId('７');
      final otherPlayer = MatchParticipantId('person-wearing-7');

      expect(shirt, isNot(padded));
      expect(shirt, isNot(zeroPadded));
      expect(shirt, isNot(fullwidth));
      expect(shirt, isNot(otherPlayer));
      expect(padded, isNot(zeroPadded));
      expect(
        <MatchParticipantId>{shirt, padded, zeroPadded, fullwidth, shirt},
        hasLength(4),
      );
      expect(shirt.wireValue, '7');
      expect(MatchParticipantId.parseWire(shirt.wireValue), shirt);
      expect(personA.value, isNot('7'));
      expect(personB.value, isNot('7'));
      expect(personA, isNot(personB));
    });

    test('empty MatchParticipantId throws', () {
      expect(() => MatchParticipantId(''), throwsArgumentError);
      expect(() => MatchParticipantId.parseWire(''), throwsArgumentError);
      expect(
        () => MatchScopedParticipantId.fromJson(const {
          'matchId': 'match-1',
          'participantId': '',
        }),
        throwsArgumentError,
      );
      expect(
        () => MatchScopedParticipantId(
          matchId: '',
          participantId: personA,
        ),
        throwsArgumentError,
      );
    });

    test('same token in two match ids is not one scoped identity', () {
      final token = MatchParticipantId('7');
      final home = MatchScopedParticipantId(
        matchId: 'match-1',
        participantId: token,
      );
      final away = MatchScopedParticipantId(
        matchId: 'match-2',
        participantId: token,
      );
      final replay = MatchScopedParticipantId.fromJson(home.toJson());

      expect(home.participantId, away.participantId);
      expect(home, isNot(away));
      expect(home == away, isFalse);
      expect(<MatchScopedParticipantId>{home, away, replay}, hasLength(2));
      expect(replay, home);
      expect(replay, isNot(away));
    });

    test('changing ParticipantSituation does not change participant equality', () {
      final id = MatchParticipantId('person-a');
      final onField = YellowCardPayload(
        participantId: id,
        accountingScope: DisciplinaryAccountingScope.match,
        captureIntentId: 'intent-on',
        situationAtDetermination: ParticipantSituation.onField,
      );
      final substituted = YellowCardPayload(
        participantId: id,
        accountingScope: DisciplinaryAccountingScope.match,
        captureIntentId: 'intent-off',
        situationAtDetermination: ParticipantSituation.substituted,
      );
      final substitute = YellowCardPayload(
        participantId: MatchParticipantId('person-a'),
        accountingScope: DisciplinaryAccountingScope.match,
        captureIntentId: 'intent-bench',
        situationAtDetermination: ParticipantSituation.substitute,
      );

      expect(onField.situationAtDetermination, isNot(substituted.situationAtDetermination));
      expect(onField.participantId, substituted.participantId);
      expect(onField.participantId, substitute.participantId);
      expect(onField.participantId, id);
      expect(onField.participantId.hashCode, id.hashCode);
      expect(
        <MatchParticipantId>{
          onField.participantId,
          substituted.participantId,
          substitute.participantId,
        },
        hasLength(1),
      );
      expect(ParticipantSituation.values, hasLength(4));
    });
  });

  group('BANK B', () {
    test('two standing yellows do not become SEND_OFF, RED, or SECOND_YELLOW', () {
      final records = [
        bootstrap(),
        yellow(
          recordId: 'y-1',
          originSequence: 2,
          participantId: personA,
          situation: ParticipantSituation.onField,
          captureIntentId: 'intent-y1',
        ),
        yellow(
          recordId: 'y-2',
          originSequence: 3,
          participantId: personA,
          situation: ParticipantSituation.substituted,
          captureIntentId: 'intent-y2',
        ),
      ];
      final beforeIds = records.map((item) => item.recordId).toList();
      final beforeLength = records.length;
      final projection = project(records);
      final answer = awareness(records);

      expect(records, hasLength(beforeLength));
      expect(records.map((item) => item.recordId).toList(), beforeIds);
      expect(answer, isA<KnownStandingCaution>());
      final standing = answer as KnownStandingCaution;
      expect(standing.standingCount, 2);
      expect(standing.standingYellowRecordIds, hasLength(2));
      expect(standing.secondCautionSituation, isTrue);
      expect(projection.committedRecordIds, beforeIds);
      expect(projection.scoreProjection, isA<KnownScore>());

      const forbidden = {
        'RED',
        'SECOND_YELLOW',
        'RED_CARD',
        'SECOND_YELLOW_CARD',
      };
      expect(
        V1SemanticTypeCodeWire.parseWire('SEND_OFF'),
        V1SemanticTypeCode.sendOff,
      );
      expect(V1SemanticTypeCodeWire.parseWire('RED'), isNull);
      expect(V1SemanticTypeCodeWire.parseWire('SECOND_YELLOW'), isNull);
      expect(V1SemanticTypeCodeWire.parseWire('YELLOW_CARD'), V1SemanticTypeCode.yellowCard);
      for (final code in V1SemanticTypeCode.values) {
        expect(forbidden.contains(code.wireValue), isFalse);
      }
      for (final item in records) {
        final payload = item.payload;
        if (payload is V1SemanticPayload) {
          expect(forbidden.contains(payload.semanticType.wireValue), isFalse);
        }
        final typeName = payload.runtimeType.toString().toUpperCase();
        expect(typeName.contains('SEND'), isFalse);
        expect(typeName.contains('RED'), isFalse);
      }
      expect(
        records.where((item) => item.payload is YellowCardPayload),
        hasLength(2),
      );
    });

    test('goal-bound capture intent conflicts with a yellow admission', () {
      const sharedIntent = 'intent-shared';
      final records = [
        record(
          recordId: 'g-other',
          originSequence: 1,
          recordMatchId: 'match-2',
          recordKind: RecordKind.humanDetermination,
          payload: GoalPayload(
            scoringTeamId: teamA,
            captureIntentId: sharedIntent,
          ),
        ),
        bootstrap(),
        record(
          recordId: 'g-1',
          originSequence: 2,
          recordKind: RecordKind.humanDetermination,
          payload: GoalPayload(
            scoringTeamId: teamB,
            captureIntentId: sharedIntent,
          ),
        ),
      ];
      final before = fingerprint(records);
      final admission = evaluateYellowCaptureIntentAdmission(
        key: CaptureIntentKey(
          matchId: matchId,
          authorityScope: const MainRefereeScope(),
          captureIntentId: sharedIntent,
        ),
        requestedMeaning: YellowCaptureIntentMeaning(
          participantId: personA,
          accountingScope: DisciplinaryAccountingScope.match,
          authorityPrincipalId: principalId,
          authorityGeneration: 1,
        ),
        committedForMatch: records,
      );

      expect(admission, isA<YellowCaptureIntentConflict>());
      expect(admission, isNot(isA<YellowCaptureIntentFirstAdmission>()));
      expect(admission, isNot(isA<YellowCaptureIntentIdempotent>()));
      expect(
        (admission as YellowCaptureIntentConflict).existingRecordId,
        'g-1',
      );
      expect(fingerprint(records), before);
      expect(records, hasLength(3));
    });
  });

  group('BANK C', () {
    test('missing origin sequence 2 is unavailable, not KnownNo', () {
      final records = [
        bootstrap(),
        yellow(
          recordId: 'y-3',
          originSequence: 3,
          participantId: personA,
        ),
      ];
      final answer = awareness(records);
      expect(answer, isA<CautionAwarenessUnavailable>());
      expect(answer, isNot(isA<KnownNoStandingCaution>()));
      expect(answer, isNot(isA<KnownStandingCaution>()));
      expect(project(records).scoreProjection, isA<ScoreUnavailable>());
    });

    test('MATCH yellow is KnownNo in the SHOOTOUT scope', () {
      final records = [
        bootstrap(),
        yellow(
          recordId: 'y-match',
          originSequence: 2,
          participantId: personA,
          scope: DisciplinaryAccountingScope.match,
        ),
      ];
      final shootout = awareness(
        records,
        scope: DisciplinaryAccountingScope.shootout,
      );
      final match = awareness(records);

      expect(shootout, isA<KnownNoStandingCaution>());
      expect(
        (shootout as KnownNoStandingCaution).historicalYellowRecordIds,
        isEmpty,
      );
      expect(shootout, isNot(isA<KnownStandingCaution>()));
      expect(match, isA<KnownStandingCaution>());
      expect((match as KnownStandingCaution).standingCount, 1);
      expect(match.secondCautionSituation, isFalse);
    });

    test('legal supersession keeps the yellow id and drops standing effect', () {
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
      final ids = records.map((item) => item.recordId).toList();
      final answer = awareness(records);

      expect(answer, isA<KnownNoStandingCaution>());
      expect(answer, isNot(isA<KnownStandingCaution>()));
      expect(
        (answer as KnownNoStandingCaution).historicalYellowRecordIds,
        ['y-1'],
      );
      expect(records.map((item) => item.recordId).toList(), ids);
      expect(records.where((item) => item.recordId == 'y-1'), hasLength(1));
    });

    test('superseding a participant repair is unavailable for the repaired id', () {
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
      final repaired = awareness(records, participantId: personB);
      expect(repaired, isA<CautionAwarenessUnavailable>());
      expect(repaired, isNot(isA<KnownStandingCaution>()));
      expect(repaired, isNot(isA<KnownNoStandingCaution>()));
      expect(project(records).scoreProjection, isA<KnownScore>());
    });

    test('generation-2 yellow is not a known caution or a known score', () {
      final records = [
        bootstrap(),
        yellow(
          recordId: 'y-gen2',
          originSequence: 2,
          participantId: personA,
          generation: 2,
        ),
      ];
      final answer = awareness(records);
      expect(answer, isA<CautionAwarenessUnavailable>());
      expect(answer, isNot(isA<KnownStandingCaution>()));
      expect(answer, isNot(isA<KnownNoStandingCaution>()));
      expect(project(records).scoreProjection, isA<ScoreUnavailable>());
    });

    test('assessCautionAwareness does not append records', () {
      final records = List<MatchRecord>.unmodifiable([
        bootstrap(),
        yellow(
          recordId: 'y-1',
          originSequence: 2,
          participantId: personA,
          captureIntentId: 'intent-y1',
        ),
        yellow(
          recordId: 'y-2',
          originSequence: 3,
          participantId: personA,
          captureIntentId: 'intent-y2',
        ),
      ]);
      final before = fingerprint(records);
      final beforeIds = records.map((item) => item.recordId).toList();
      final first = awareness(records) as KnownStandingCaution;
      final second = awareness(records) as KnownStandingCaution;

      expect(records, hasLength(3));
      expect(records.map((item) => item.recordId).toList(), beforeIds);
      expect(fingerprint(records), before);
      expect(first.standingCount, second.standingCount);
      expect(first.standingYellowRecordIds, second.standingYellowRecordIds);
    });

    test('permuting record order does not change standingCount', () {
      final records = [
        bootstrap(),
        yellow(
          recordId: 'y-1',
          originSequence: 2,
          participantId: personA,
          captureIntentId: 'intent-y1',
        ),
        yellow(
          recordId: 'y-2',
          originSequence: 3,
          participantId: personA,
          captureIntentId: 'intent-y2',
        ),
      ];
      final counts = <int>[];
      final standingSets = <String>[];
      for (final order in _permutations(records)) {
        final answer = awareness(order);
        expect(answer, isA<KnownStandingCaution>());
        final standing = answer as KnownStandingCaution;
        counts.add(standing.standingCount);
        standingSets.add(standing.standingYellowRecordIds.join(','));
        expect(order, hasLength(3));
      }
      expect(counts, hasLength(6));
      expect(counts.toSet(), {2});
      expect(standingSets.toSet(), hasLength(1));
    });

    test('KnownNo requires a satisfied completeness proof', () {
      final records = [
        bootstrap(),
        yellow(recordId: 'y-1', originSequence: 2, participantId: personA),
      ];
      final missingProof = awareness(records, useProof: false);
      expect(missingProof, isA<CautionAwarenessUnavailable>());
      expect(missingProof, isNot(isA<KnownStandingCaution>()));
      expect(missingProof, isNot(isA<KnownNoStandingCaution>()));

      final conflicted = awareness(records, correctionConflict: true);
      expect(conflicted, isA<CautionAwarenessConflicted>());
      expect(conflicted, isNot(isA<KnownStandingCaution>()));

      final authority = awareness(records, authorityConflict: true);
      expect(authority, isA<CautionAwarenessConflicted>());
      expect(authority, isNot(isA<KnownNoStandingCaution>()));

      final unsupported = awareness(
        records,
        unsupportedSemanticRecordIds: const ['started-1'],
      );
      expect(unsupported, isA<CautionAwarenessUnavailable>());
      expect(unsupported, isNot(isA<KnownStandingCaution>()));
    });
  });

  group('BANK D', () {
    test('RED wires stay unregistered after SEND_OFF exists', () {
      expect(
        V1SemanticTypeCodeWire.parseWire('SEND_OFF'),
        V1SemanticTypeCode.sendOff,
      );
      expect(V1SemanticTypeCodeWire.parseWire('RED'), isNull);
      expect(V1SemanticTypeCodeWire.parseWire('SECOND_YELLOW'), isNull);
      expect(V1SemanticTypeCodeWire.parseWire('RED_CARD'), isNull);
      expect(V1SemanticTypeCodeWire.parseWire('send_off'), isNull);
      for (final code in V1SemanticTypeCode.values) {
        expect(code.wireValue, isNot('RED'));
        expect(code.wireValue, isNot('SECOND_YELLOW'));
      }
    });
  });

  group('BANK E', () {
    test('SUBSTITUTION cannot be parsed', () {
      expect(V1SemanticTypeCodeWire.parseWire('SUBSTITUTION'), isNull);
      expect(V1SemanticTypeCodeWire.parseWire('SUBSTITUTE'), isNull);
      expect(V1SemanticTypeCodeWire.parseWire('SUBSTITUTED'), isNull);
      expect(V1SemanticTypeCodeWire.parseWire('COMPLETED_SUBSTITUTION'), isNull);
      for (final code in V1SemanticTypeCode.values) {
        expect(code.wireValue, isNot('SUBSTITUTION'));
      }
      expect(
        V1SemanticTypeCodeWire.parseWire(ParticipantSituation.substitute.name),
        isNull,
      );
      expect(
        V1SemanticTypeCodeWire.parseWire(ParticipantSituation.substituted.name),
        isNull,
      );
    });
  });

  group('BANK F', () {
    test('field entry alone does not start the match', () {
      final entered = record(
        recordId: 'entered-1',
        originSequence: 1,
        recordKind: RecordKind.temporalFact,
        payload: RefereeEnteredFieldPayload(captureIntentId: 'intent-field'),
      );
      expect(entered.payload, isA<RefereeEnteredFieldPayload>());
      expect(entered.payload, isNot(isA<TemporalTransitionPayload>()));
      expect(
        (entered.payload as RefereeEnteredFieldPayload).semanticType,
        V1SemanticTypeCode.refereeEnteredFieldForMatchStart,
      );
      expect(
        (entered.payload as RefereeEnteredFieldPayload).semanticType.wireValue,
        'REFEREE_ENTERED_FIELD_FOR_MATCH_START',
      );
      expect(
        () => TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.refereeEnteredFieldForMatchStart,
        ),
        throwsA(isA<AssertionError>()),
      );

      final temporal = TemporalMatchProjection.derive(
        projection: project([entered]),
        records: [entered],
      );
      expect(temporal.matchStarted, isFalse);
      expect(temporal.activePeriod, isNull);
    });

    test('MATCH_STARTED is a temporal transition, not field entry', () {
      final started = bootstrap();
      expect(started.payload, isA<TemporalTransitionPayload>());
      expect(started.payload, isNot(isA<RefereeEnteredFieldPayload>()));
      expect(
        (started.payload as TemporalTransitionPayload).semanticType,
        V1SemanticTypeCode.matchStarted,
      );
      expect(
        (started.payload as TemporalTransitionPayload).semanticType.wireValue,
        'MATCH_STARTED',
      );

      final temporal = TemporalMatchProjection.derive(
        projection: project([started]),
        records: [started],
      );
      expect(temporal.matchStarted, isTrue);
    });
  });

  group('BRIDGE identity-yellow-awareness', () {
    test('root history is 0-0 and KnownNo, then one yellow stays 0-0', () {
      final root = [bootstrap()];
      final rootScore = knownScore(root);
      expect(rootScore.goalsByTeam[teamA], 0);
      expect(rootScore.goalsByTeam[teamB], 0);
      expect(rootScore.goalsByTeam, hasLength(2));
      final rootCaution = awareness(root);
      expect(rootCaution, isA<KnownNoStandingCaution>());
      expect(
        (rootCaution as KnownNoStandingCaution).historicalYellowRecordIds,
        isEmpty,
      );

      final withYellow = [
        ...root,
        yellow(
          recordId: 'y-1',
          originSequence: 2,
          participantId: personA,
          situation: ParticipantSituation.onField,
        ),
      ];
      final yellowScore = knownScore(withYellow);
      expect(yellowScore.goalsByTeam[teamA], 0);
      expect(yellowScore.goalsByTeam[teamB], 0);
      expect(yellowScore.goalsByTeam, hasLength(2));
      final caution = awareness(withYellow);
      expect(caution, isA<KnownStandingCaution>());
      expect((caution as KnownStandingCaution).standingCount, 1);
      expect(caution.secondCautionSituation, isFalse);
      expect(caution.standingYellowRecordIds, ['y-1']);
    });

    test('shirt-looking tokens do not share a caution', () {
      final seven = MatchParticipantId('7');
      final zeroSeven = MatchParticipantId('07');
      expect(seven, isNot(zeroSeven));
      final records = [
        bootstrap(),
        yellow(recordId: 'y-7', originSequence: 2, participantId: seven),
      ];
      final holder = awareness(records, participantId: seven);
      final lookalike = awareness(records, participantId: zeroSeven);
      expect(holder, isA<KnownStandingCaution>());
      expect((holder as KnownStandingCaution).standingCount, 1);
      expect(lookalike, isA<KnownNoStandingCaution>());
      expect(lookalike, isNot(isA<KnownStandingCaution>()));
    });

    test('situation change does not move the caution onto another id', () {
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
      expect(awareness(records, participantId: personB), isA<KnownNoStandingCaution>());
      expect(
        records
            .where((item) => item.payload is YellowCardPayload)
            .map((item) => (item.payload as YellowCardPayload).participantId)
            .toSet(),
        {personA},
      );
    });
  });

  group('BRIDGE lifecycle', () {
    test('field entry does not start the match or invent a caution', () {
      final entered = record(
        recordId: 'entered-1',
        originSequence: 2,
        recordKind: RecordKind.temporalFact,
        payload: RefereeEnteredFieldPayload(captureIntentId: 'intent-field'),
      );
      final records = [bootstrap(), entered];
      final temporal = TemporalMatchProjection.derive(
        projection: project(records),
        records: records,
      );
      final score = knownScore(records);

      expect(temporal.matchStarted, isTrue);
      expect(entered.payload, isNot(isA<TemporalTransitionPayload>()));
      expect(score.goalsByTeam[teamA], 0);
      expect(score.goalsByTeam[teamB], 0);
      expect(awareness(records), isA<KnownNoStandingCaution>());
      expect(project(records).committedRecordIds, ['started-1', 'entered-1']);
    });

    test('field entry alone stays before match start on the lifecycle bridge', () {
      final entered = record(
        recordId: 'entered-1',
        originSequence: 1,
        recordKind: RecordKind.temporalFact,
        payload: RefereeEnteredFieldPayload(captureIntentId: 'intent-field'),
      );
      final temporal = TemporalMatchProjection.derive(
        projection: project([entered]),
        records: [entered],
      );
      expect(temporal.matchStarted, isFalse);
      expect(entered.payload, isA<RefereeEnteredFieldPayload>());
      expect(bootstrap().payload, isNot(isA<RefereeEnteredFieldPayload>()));
    });
  });
}

List<List<T>> _permutations<T>(List<T> items) {
  if (items.length <= 1) return [List<T>.of(items)];
  final result = <List<T>>[];
  for (var index = 0; index < items.length; index++) {
    final rest = [...items]..removeAt(index);
    for (final tail in _permutations(rest)) {
      result.add([items[index], ...tail]);
    }
  }
  return result;
}
