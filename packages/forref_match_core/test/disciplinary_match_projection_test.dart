import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

const _matchId = 'match-disciplinary';
const _ordinaryRules = CompetitionRulesContext(
  rulesetId: 'ifab',
  disciplinarySystem: DisciplinarySystem.ordinaryIfab,
);

void main() {
  final homeSeven = _participant(
    'mpid-home-7',
    ParticipantTeamSide.home,
    const RosterLinkedBinding(rosterParticipantId: 'home-7'),
  );

  test('immutable history and standing sequence share canonical identity', () {
    final records = [
      _registered(1, homeSeven),
      _yellow(
        2,
        'yc-sub',
        homeSeven,
        status: ParticipantStatusAtDetermination.substitute,
        intent: 'intent-sub',
      ),
      _yellow(
        3,
        'yc-field',
        homeSeven,
        status: ParticipantStatusAtDetermination.onFieldPlayer,
        intent: 'intent-field',
      ),
      _yellow(
        4,
        'yc-substituted',
        homeSeven,
        status: ParticipantStatusAtDetermination.substitutedPlayer,
        intent: 'intent-substituted',
      ),
      _yellow(
        5,
        'yc-returned',
        homeSeven,
        status: ParticipantStatusAtDetermination.onFieldPlayer,
        intent: 'intent-returned',
      ),
    ];

    final projection = _project(records);

    expect(projection.historicalCautions, hasLength(4));
    expect(projection.standingCautions, hasLength(4));
    expect(
      projection.standingCautions
          .map((caution) => caution.canonicalParticipantId)
          .toSet(),
      {homeSeven.matchParticipantId},
    );
    expect(
      projection.standingCautions
          .map((caution) => caution.standingOrdinal)
          .toList(),
      [1, 2, 3, 4],
    );
    expect(projection.standingCautions.first.hasPriorStandingCaution, isFalse);
    expect(projection.standingCautions[1].hasPriorStandingCaution, isTrue);
    expect(projection.standingCautions[1].isSecondStandingCaution, isTrue);
    expect(projection.standingCautions.last.hasPriorStandingCaution, isTrue);

    final prior = projection.priorCautionStateFor(
      participantId: homeSeven.matchParticipantId,
      accountingScope: DisciplinaryAccountingScope.match,
    );
    expect(prior.state, PriorCautionState.standing);
    expect(prior.standingCautionCount, 4);
    expect(prior.nextStandingOrdinal, 5);
    expect(prior.nextCautionWouldBeSecond, isFalse);
  });

  test('one standing caution exposes advisory second-caution awareness', () {
    final projection = _project([
      _registered(1, homeSeven),
      _yellow(2, 'yc-1', homeSeven, intent: 'intent-1'),
    ]);

    final prior = projection.priorCautionStateFor(
      participantId: homeSeven.matchParticipantId,
      accountingScope: DisciplinaryAccountingScope.match,
    );
    expect(prior.hasPriorStandingCaution, isTrue);
    expect(prior.standingCautionCount, 1);
    expect(prior.nextCautionWouldBeSecond, isTrue);
    expect(prior.nextStandingOrdinal, 2);
  });

  test('shirt number is not a disciplinary ledger key', () {
    final homeEight = _participant(
      'mpid-home-8',
      ParticipantTeamSide.home,
      const TeamScopedNumberBinding(shirtNumber: 8),
    );
    final awayEight = _participant(
      'mpid-away-8',
      ParticipantTeamSide.away,
      const TeamScopedNumberBinding(shirtNumber: 8),
    );
    final projection = _project([
      _registered(1, homeEight),
      _registered(2, awayEight),
      _yellow(3, 'yc-home', homeEight, intent: 'intent-home'),
      _yellow(4, 'yc-away', awayEight, intent: 'intent-away'),
    ]);

    expect(projection.standingCautions, hasLength(2));
    final home = projection.priorCautionStateFor(
      participantId: homeEight.matchParticipantId,
      accountingScope: DisciplinaryAccountingScope.match,
    );
    final away = projection.priorCautionStateFor(
      participantId: awayEight.matchParticipantId,
      accountingScope: DisciplinaryAccountingScope.match,
    );
    expect(home.standingCautionCount, 1);
    expect(away.standingCautionCount, 1);
    expect(projection.priorCautionState.keys, hasLength(2));
  });

  test('legal supersession preserves history and removes standing effect', () {
    final projection = _project([
      _registered(1, homeSeven),
      _yellow(2, 'yc-1', homeSeven, intent: 'intent-1'),
      _legalSupersession(3, 'supersede-yc', 'yc-1'),
    ]);

    expect(projection.historicalCautions, hasLength(1));
    expect(projection.standingCautions, isEmpty);
    expect(
      projection.historicalCautions.single.standingEffect,
      CautionStandingEffect.legallySuperseded,
    );
    expect(projection.historicalCautions.single.standingOrdinal, isNull);
    expect(
      projection
          .priorCautionStateFor(
            participantId: homeSeven.matchParticipantId,
            accountingScope: DisciplinaryAccountingScope.match,
          )
          .state,
      PriorCautionState.none,
    );
  });

  test('identity reconciliation re-keys history and standing ledger', () {
    final provisional = _participant(
      'mpid-provisional',
      ParticipantTeamSide.home,
      const FreeformDescriptorBinding(descriptor: 'unknown home #7'),
    );
    final canonical = _participant(
      'mpid-canonical',
      ParticipantTeamSide.home,
      const RosterLinkedBinding(rosterParticipantId: 'home-7'),
    );
    final projection = _project([
      _registered(1, provisional),
      _registered(2, canonical),
      _yellow(3, 'yc-old-id', provisional, intent: 'intent-old'),
      _reconciliation(
          4, provisional.matchParticipantId, canonical.matchParticipantId),
    ]);

    expect(projection.historicalCautions.single.recordId, 'yc-old-id');
    expect(
      projection.historicalCautions.single.participantRefAtDetermination,
      provisional,
    );
    expect(
      projection.historicalCautions.single.canonicalParticipantId,
      canonical.matchParticipantId,
    );
    expect(
      projection
          .priorCautionStateFor(
            participantId: canonical.matchParticipantId,
            accountingScope: DisciplinaryAccountingScope.match,
          )
          .standingCautionCount,
      1,
    );
    expect(
      projection
          .priorCautionStateFor(
            participantId: provisional.matchParticipantId,
            accountingScope: DisciplinaryAccountingScope.match,
          )
          .standingCautionCount,
      1,
    );
  });

  test('durably bound provisional identity can carry standing caution', () {
    final provisional = _participant(
      'mpid-provisional',
      ParticipantTeamSide.home,
      const FreeformDescriptorBinding(descriptor: 'unknown home player'),
    );
    final projection = _project([
      _registered(1, provisional),
      _yellow(2, 'yc-provisional', provisional, intent: 'intent-provisional'),
    ]);

    expect(projection.standingCautions, hasLength(1));
    expect(
      projection.standingCautions.single.identityConfidence,
      IdentityConfidence.provisional,
    );
    expect(projection.participantIdentityTrust, ProjectionTrust.trusted);
  });

  test('ambiguous participant identity fails closed', () {
    final first = _participant(
      'mpid-eight-a',
      ParticipantTeamSide.home,
      const TeamScopedNumberBinding(shirtNumber: 8),
    );
    final second = _participant(
      'mpid-eight-b',
      ParticipantTeamSide.home,
      const TeamScopedNumberBinding(shirtNumber: 8),
    );
    final projection = _project([
      _registered(1, first),
      _registered(2, second),
      _yellow(3, 'yc-ambiguous', first, intent: 'intent-ambiguous'),
    ]);

    expect(projection.historicalCautions, hasLength(1));
    expect(projection.standingCautions, isEmpty);
    expect(projection.participantIdentityTrust, ProjectionTrust.incomplete);
    expect(projection.disciplinaryFacetTrust, ProjectionTrust.incomplete);
    expect(
      projection
          .priorCautionStateFor(
            participantId: first.matchParticipantId,
            accountingScope: DisciplinaryAccountingScope.match,
          )
          .state,
      PriorCautionState.unresolved,
    );
  });

  test('conflicted participant identity fails closed', () {
    final a = _participant(
      'mpid-a',
      ParticipantTeamSide.home,
      const RosterLinkedBinding(rosterParticipantId: 'a'),
    );
    final b = _participant(
      'mpid-b',
      ParticipantTeamSide.home,
      const RosterLinkedBinding(rosterParticipantId: 'b'),
    );
    final projection = _project([
      _registered(1, a),
      _registered(2, b),
      _reconciliation(3, a.matchParticipantId, b.matchParticipantId),
      _reconciliation(4, b.matchParticipantId, a.matchParticipantId),
      _yellow(5, 'yc-conflicted', a, intent: 'intent-conflicted'),
    ]);

    expect(projection.standingCautions, isEmpty);
    expect(projection.participantIdentityTrust, ProjectionTrust.conflicted);
    expect(projection.disciplinaryFacetTrust, ProjectionTrust.conflicted);
    expect(
      projection.unresolvedConsequences.singleWhere(
        (item) =>
            item.code ==
            UnresolvedDisciplinaryConsequenceCode.participantIdentityConflicted,
      ),
      isNotNull,
    );
  });

  test('MATCH and SHOOTOUT are separate caution ledgers', () {
    final projection = _project([
      _registered(1, homeSeven),
      _yellow(2, 'yc-match', homeSeven, intent: 'intent-match'),
      _yellow(
        3,
        'yc-shootout',
        homeSeven,
        intent: 'intent-shootout',
        scope: DisciplinaryAccountingScope.shootout,
      ),
    ]);

    expect(projection.standingCautions, hasLength(2));
    expect(
      projection.standingCautions
          .map((caution) => caution.standingOrdinal)
          .toList(),
      [1, 1],
    );
    expect(
      projection
          .priorCautionStateFor(
            participantId: homeSeven.matchParticipantId,
            accountingScope: DisciplinaryAccountingScope.match,
          )
          .standingCautionCount,
      1,
    );
    expect(
      projection
          .priorCautionStateFor(
            participantId: homeSeven.matchParticipantId,
            accountingScope: DisciplinaryAccountingScope.shootout,
          )
          .standingCautionCount,
      1,
    );
  });

  test('unresolved accounting scope remains history but never stands', () {
    final projection = _project([
      _registered(1, homeSeven),
      _yellow(
        2,
        'yc-unresolved-scope',
        homeSeven,
        intent: 'intent-unresolved',
        scope: DisciplinaryAccountingScope.unresolved,
      ),
    ]);

    expect(projection.historicalCautions, hasLength(1));
    expect(projection.standingCautions, isEmpty);
    expect(
      projection.historicalCautions.single.standingEffect,
      CautionStandingEffect.unresolved,
    );
    expect(
      projection.unresolvedConsequences.single.code,
      UnresolvedDisciplinaryConsequenceCode.accountingScopeUnresolved,
    );
  });

  test('unsupported disciplinary system cannot create standing caution', () {
    final projection = _project([
      _registered(1, homeSeven),
      _yellow(
        2,
        'yc-temp-dismissal',
        homeSeven,
        intent: 'intent-temp',
        rules: const CompetitionRulesContext(
          rulesetId: 'youth',
          disciplinarySystem: DisciplinarySystem.temporaryDismissal,
        ),
      ),
    ]);

    expect(projection.historicalCautions, hasLength(1));
    expect(projection.standingCautions, isEmpty);
    expect(
      projection.unresolvedConsequences.single.code,
      UnresolvedDisciplinaryConsequenceCode.disciplinarySystemUnsupported,
    );
  });

  test('unresolved disciplinary system cannot create standing caution', () {
    final projection = _project([
      _registered(1, homeSeven),
      _yellow(
        2,
        'yc-system-unresolved',
        homeSeven,
        intent: 'intent-system-unresolved',
        rules: const CompetitionRulesContext(rulesetId: 'ifab'),
      ),
    ]);

    expect(projection.historicalCautions, hasLength(1));
    expect(projection.standingCautions, isEmpty);
    expect(
      projection.unresolvedConsequences.single.code,
      UnresolvedDisciplinaryConsequenceCode.disciplinarySystemUnresolved,
    );
  });

  test('generic correction does not guess disciplinary legal effect', () {
    final projection = _project([
      _registered(1, homeSeven),
      _yellow(2, 'yc-1', homeSeven, intent: 'intent-1'),
      _correction(3, 'correction-1', 'yc-1'),
    ]);

    expect(projection.historicalCautions, hasLength(1));
    expect(projection.standingCautions, isEmpty);
    expect(
      projection.historicalCautions.single.standingEffect,
      CautionStandingEffect.unresolved,
    );
    expect(
      projection.unresolvedConsequences.single.code,
      UnresolvedDisciplinaryConsequenceCode.correctionLegalEffectUnresolved,
    );
    expect(
      projection
          .priorCautionStateFor(
            participantId: homeSeven.matchParticipantId,
            accountingScope: DisciplinaryAccountingScope.match,
          )
          .state,
      PriorCautionState.unresolved,
    );
  });

  test('contradictory corrections propagate conflicted disciplinary trust', () {
    final projection = _project([
      _registered(1, homeSeven),
      _yellow(2, 'yc-1', homeSeven, intent: 'intent-1'),
      _correction(3, 'correction-a', 'yc-1'),
      _correction(4, 'correction-b', 'yc-1'),
    ]);

    expect(projection.historicalCautions, hasLength(1));
    expect(projection.standingCautions, isEmpty);
    expect(projection.disciplinaryFacetTrust, ProjectionTrust.conflicted);
    expect(projection.participantIdentityTrust, ProjectionTrust.conflicted);
    expect(
      projection.unresolvedConsequences.any(
        (item) =>
            item.code ==
            UnresolvedDisciplinaryConsequenceCode.correctionConflict,
      ),
      isTrue,
    );
    expect(
      projection
          .priorCautionStateFor(
            participantId: homeSeven.matchParticipantId,
            accountingScope: DisciplinaryAccountingScope.match,
          )
          .state,
      PriorCautionState.unresolved,
    );
  });

  test(
      'correction plus legal supersession preserves effect but exposes conflict',
      () {
    final projection = _project([
      _registered(1, homeSeven),
      _yellow(2, 'yc-1', homeSeven, intent: 'intent-1'),
      _correction(3, 'correction-1', 'yc-1'),
      _legalSupersession(4, 'supersede-yc', 'yc-1'),
    ]);

    expect(projection.historicalCautions, hasLength(1));
    expect(projection.standingCautions, isEmpty);
    expect(
      projection.historicalCautions.single.standingEffect,
      CautionStandingEffect.legallySuperseded,
    );
    expect(
      projection.unresolvedConsequences.where(
        (item) =>
            item.code ==
            UnresolvedDisciplinaryConsequenceCode
                .correctionLegalEffectUnresolved,
      ),
      isEmpty,
    );
    expect(
      projection.unresolvedConsequences.any(
        (item) =>
            item.code ==
            UnresolvedDisciplinaryConsequenceCode.correctionConflict,
      ),
      isTrue,
    );
    expect(projection.disciplinaryFacetTrust, ProjectionTrust.conflicted);
    expect(
      projection
          .priorCautionStateFor(
            participantId: homeSeven.matchParticipantId,
            accountingScope: DisciplinaryAccountingScope.match,
          )
          .state,
      PriorCautionState.unresolved,
    );
  });

  test('duplicate capture intent fails closed without deleting history', () {
    final projection = _project([
      _registered(1, homeSeven),
      _yellow(2, 'yc-1', homeSeven, intent: 'same-intent'),
      _yellow(3, 'yc-duplicate', homeSeven, intent: 'same-intent'),
    ]);

    expect(projection.historicalCautions, hasLength(2));
    expect(projection.standingCautions, isEmpty);
    expect(projection.disciplinaryFacetTrust, ProjectionTrust.incomplete);
    expect(
      projection.unresolvedConsequences
          .where(
            (item) =>
                item.code ==
                UnresolvedDisciplinaryConsequenceCode.duplicateCaptureIntent,
          )
          .length,
      2,
    );
  });

  test('same intent with different capture content is conflicted', () {
    final away = _participant(
      'mpid-away-9',
      ParticipantTeamSide.away,
      const RosterLinkedBinding(rosterParticipantId: 'away-9'),
    );
    final projection = _project([
      _registered(1, homeSeven),
      _registered(2, away),
      _yellow(3, 'yc-home', homeSeven, intent: 'same-intent'),
      _yellow(4, 'yc-away', away, intent: 'same-intent'),
    ]);

    expect(projection.historicalCautions, hasLength(2));
    expect(projection.standingCautions, isEmpty);
    expect(projection.disciplinaryFacetTrust, ProjectionTrust.conflicted);
  });

  test('distinct capture intents with identical details remain two cautions',
      () {
    final projection = _project([
      _registered(1, homeSeven),
      _yellow(2, 'yc-1', homeSeven, intent: 'intent-1'),
      _yellow(3, 'yc-2', homeSeven, intent: 'intent-2'),
    ]);

    expect(projection.historicalCautions, hasLength(2));
    expect(projection.standingCautions, hasLength(2));
    expect(projection.standingCautions.last.isSecondStandingCaution, isTrue);
  });

  test('deterministic order ignores list order and recordedAt', () {
    final first = _yellow(
      2,
      'yc-first',
      homeSeven,
      intent: 'intent-first',
      recordedAt: DateTime.utc(2099),
    );
    final second = _yellow(
      3,
      'yc-second',
      homeSeven,
      intent: 'intent-second',
      recordedAt: DateTime.utc(2000),
    );
    final registration = _registered(1, homeSeven);
    final forward = _project([registration, first, second]);
    final reversed = _project([second, first, registration]);

    expect(
      forward.historicalCautions.map((caution) => caution.recordId).toList(),
      ['yc-first', 'yc-second'],
    );
    expect(
      reversed.historicalCautions.map((caution) => caution.recordId).toList(),
      ['yc-first', 'yc-second'],
    );
    expect(
      reversed.standingCautions
          .map((caution) => caution.standingOrdinal)
          .toList(),
      [1, 2],
    );
  });

  test('authority beyond projection boundary leaves consequence unresolved',
      () {
    final projection = _project([
      _registered(1, homeSeven),
      _yellow(
        2,
        'yc-future-generation',
        homeSeven,
        intent: 'intent-future',
        generation: 2,
      ),
    ]);

    expect(projection.historicalCautions, hasLength(1));
    expect(projection.standingCautions, isEmpty);
    expect(projection.disciplinaryFacetTrust, ProjectionTrust.incomplete);
    expect(
      projection.unresolvedConsequences.single.code,
      UnresolvedDisciplinaryConsequenceCode.authorityInvalid,
    );
  });

  test('two principals at one authority generation conflict', () {
    final projection = _project([
      _registered(1, homeSeven),
      _yellow(
        2,
        'yc-ref-a',
        homeSeven,
        intent: 'intent-a',
        principal: 'ref-a',
      ),
      _yellow(
        3,
        'yc-ref-b',
        homeSeven,
        intent: 'intent-b',
        principal: 'ref-b',
      ),
    ]);

    expect(projection.historicalCautions, hasLength(2));
    expect(projection.standingCautions, isEmpty);
    expect(projection.disciplinaryFacetTrust, ProjectionTrust.conflicted);
  });

  test('wrong-kind typed yellow card is unsupported, not historical authority',
      () {
    final projection = _project([
      _registered(1, homeSeven),
      _yellow(
        2,
        'yc-wrong-kind',
        homeSeven,
        intent: 'intent-wrong',
        recordKind: RecordKind.action,
      ),
    ]);

    expect(projection.historicalCautions, isEmpty);
    expect(projection.standingCautions, isEmpty);
    expect(projection.disciplinaryFacetTrust, ProjectionTrust.incomplete);
    expect(
      projection.unresolvedConsequences.single.code,
      UnresolvedDisciplinaryConsequenceCode.unsupportedYellowCardSemantic,
    );
  });

  test(
      'current disciplinary accounting scope uses existing authority projection',
      () {
    final projection = DisciplinaryMatchProjection.derive(
      records: [
        _registered(1, homeSeven),
        _transition(
          2,
          'entered',
          V1SemanticTypeCode.refereeEnteredFieldForMatchStart,
        ),
        _transition(3, 'ended', V1SemanticTypeCode.matchEnded),
      ],
      evaluatedAuthorityGeneration: 1,
      competitionRules: const CompetitionRulesContext(
        rulesetId: 'cup',
        penaltyShootOutAfterMatchEnd: true,
        disciplinarySystem: DisciplinarySystem.ordinaryIfab,
      ),
    );

    expect(
      projection.disciplinaryAccountingScope,
      DisciplinaryAccountingScope.shootout,
    );
  });

  test('missing legal-effect target is explicit and globally unresolved', () {
    final projection = _project([
      _registered(1, homeSeven),
      _legalSupersession(2, 'supersede-missing', 'missing-yc'),
    ]);

    expect(projection.historicalCautions, isEmpty);
    expect(
      projection.unresolvedConsequences.single.code,
      UnresolvedDisciplinaryConsequenceCode.missingLegalEffectTarget,
    );
    expect(
      projection
          .priorCautionStateFor(
            participantId: homeSeven.matchParticipantId,
            accountingScope: DisciplinaryAccountingScope.match,
          )
          .state,
      PriorCautionState.unresolved,
    );
  });

  test('projection collections are immutable', () {
    final projection = _project([
      _registered(1, homeSeven),
      _yellow(2, 'yc-1', homeSeven, intent: 'intent-1'),
    ]);

    expect(
      () => projection.historicalCautions.clear(),
      throwsUnsupportedError,
    );
    expect(() => projection.standingCautions.clear(), throwsUnsupportedError);
    expect(() => projection.priorCautionState.clear(), throwsUnsupportedError);
    expect(
      () => projection.unresolvedConsequences.clear(),
      throwsUnsupportedError,
    );
  });

  test('disciplinary projection adds no dismissal authority or UI', () {
    final source = File('lib/projection/disciplinary_match_projection.dart')
        .readAsStringSync();
    expect(source, isNot(contains('RedCardPayload')));
    expect(source, isNot(contains('RED_CARD')));
    expect(source, isNot(contains('EventType')));
    expect(source, isNot(contains('Widget')));
    expect(source, isNot(contains('package:flutter')));
  });
}

DisciplinaryMatchProjection _project(List<MatchRecord> records) {
  return DisciplinaryMatchProjection.derive(
    records: records,
    evaluatedAuthorityGeneration: 1,
  );
}

ParticipantRef _participant(
  String id,
  ParticipantTeamSide side,
  ParticipantBinding binding,
) {
  return ParticipantRef(
    matchParticipantId: MatchParticipantId(id),
    teamSide: side,
    binding: binding,
  );
}

MatchRecord _registered(int sequence, ParticipantRef participant) {
  return _record(
    sequence,
    'register-${participant.matchParticipantId.value}',
    RecordKind.action,
    ParticipantRegisteredPayload(
      matchParticipantId: participant.matchParticipantId,
      teamSide: participant.teamSide,
      binding: participant.binding,
    ),
  );
}

MatchRecord _yellow(
  int sequence,
  String recordId,
  ParticipantRef participant, {
  required String intent,
  ParticipantStatusAtDetermination status =
      ParticipantStatusAtDetermination.onFieldPlayer,
  DisciplinaryAccountingScope scope = DisciplinaryAccountingScope.match,
  CompetitionRulesContext rules = _ordinaryRules,
  int generation = 1,
  String principal = 'ref-main',
  DateTime? recordedAt,
  RecordKind recordKind = RecordKind.humanDetermination,
}) {
  return _record(
    sequence,
    recordId,
    recordKind,
    YellowCardPayload(
      participantRef: participant,
      participantStatusAtDetermination: status,
      disciplinaryAccountingScope: scope,
      captureIntentId: intent,
      competitionRulesContext: rules,
    ),
    authority: AuthorityContext(
      scope: const MainRefereeScope(),
      principal: AuthorityPrincipal(principalId: principal),
      activeCaptureDevice: const ActiveCaptureDevice(deviceId: 'device-a'),
      generation: AuthorityGeneration(value: generation),
    ),
    recordedAt: recordedAt,
  );
}

MatchRecord _legalSupersession(
  int sequence,
  String recordId,
  String targetRecordId,
) {
  return _record(
    sequence,
    recordId,
    RecordKind.legalSupersession,
    const LegalSupersessionPayload(),
    relationships: [LegalSupersessionTarget(targetRecordId: targetRecordId)],
    authority: _authority,
  );
}

MatchRecord _correction(
  int sequence,
  String recordId,
  String targetRecordId,
) {
  return _record(
    sequence,
    recordId,
    RecordKind.correction,
    const CorrectionPayload(),
    relationships: [CorrectionTarget(targetRecordId: targetRecordId)],
    authority: _authority,
  );
}

MatchRecord _reconciliation(
  int sequence,
  MatchParticipantId from,
  MatchParticipantId to,
) {
  return _record(
    sequence,
    'reconcile-${from.value}-${to.value}',
    RecordKind.action,
    ParticipantIdentityReconciliationPayload(
      fromParticipantId: from,
      toParticipantId: to,
    ),
  );
}

MatchRecord _transition(
  int sequence,
  String recordId,
  V1SemanticTypeCode type,
) {
  return _record(
    sequence,
    recordId,
    RecordKind.temporalFact,
    TemporalTransitionPayload(semanticType: type),
    authority: _authority,
  );
}

const _authority = AuthorityContext(
  scope: MainRefereeScope(),
  principal: AuthorityPrincipal(principalId: 'ref-main'),
  activeCaptureDevice: ActiveCaptureDevice(deviceId: 'device-a'),
  generation: AuthorityGeneration(value: 1),
);

MatchRecord _record(
  int sequence,
  String recordId,
  RecordKind recordKind,
  MatchRecordPayload payload, {
  List<RecordRelationship> relationships = const [],
  AuthorityContext? authority,
  DateTime? recordedAt,
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: _matchId,
    recordKind: recordKind,
    schemaVersion: 1,
    recordedAt: recordedAt ?? DateTime.utc(2026, 10, 6, 12, 0, sequence),
    originDeviceId: 'device-a',
    originSequence: sequence,
    payload: payload,
    integrity: const IntegrityMetadata(),
    authorityContext: authority,
    relationships: relationships,
  );
}
