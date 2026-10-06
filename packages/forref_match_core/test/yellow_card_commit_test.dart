import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:test/test.dart';

const _matchId = 'match-yc';

void main() {
  late Directory temp;
  late File databaseFile;
  late SqliteDurableMatchStore store;
  late YellowCardCommitter committer;
  late AuthoritativeRecordBuilder builder;

  final homePlayer = ParticipantRef(
    matchParticipantId: MatchParticipantId('mpid-home-7'),
    teamSide: ParticipantTeamSide.home,
    binding: const RosterLinkedBinding(rosterParticipantId: 'home-7'),
  );

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('yellow_card_commit_');
    databaseFile = File('${temp.path}/memory.sqlite');
    store = SqliteDurableMatchStore.open(databaseFile);
    builder = AuthoritativeRecordBuilder(
      identityGenerator: _SequentialIds(),
    );
    committer = YellowCardCommitter(
      originCommit: store,
      memory: store,
      recordBuilder: builder,
    );
  });

  tearDown(() async {
    try {
      await store.close();
    } on Object {
      // Recovery tests close the store before reopening the same file.
    }
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<List<MatchRecord>> records() => store.readCommittedForMatch(_matchId);

  Future<void> append(
    RecordKind kind,
    MatchRecordPayload payload, {
    CaptureContext? context,
  }) async {
    final result = await store.commitAtNextOriginSequence(
      builder.build(
        context: context ?? _context(),
        recordKind: kind,
        payload: payload,
        integrity: const IntegrityMetadata(),
      ),
    );
    expect(result, isA<DurableCommitSuccess>());
  }

  Future<void> enteredField() {
    return append(
      RecordKind.temporalFact,
      TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.refereeEnteredFieldForMatchStart,
      ),
    );
  }

  Future<void> leftField() {
    return append(
      RecordKind.temporalFact,
      TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.refereeLeftFieldAfterMatch,
      ),
    );
  }

  Future<void> matchStarted() {
    return append(
      RecordKind.temporalFact,
      TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.matchStarted,
      ),
    );
  }

  Future<void> matchEnded() {
    return append(
      RecordKind.temporalFact,
      TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.matchEnded,
      ),
    );
  }

  Future<void> register(ParticipantRef ref) {
    return append(
      RecordKind.action,
      ParticipantRegisteredPayload(
        matchParticipantId: ref.matchParticipantId,
        teamSide: ref.teamSide,
        binding: ref.binding,
      ),
    );
  }

  Future<void> ready({ParticipantRef? participant}) async {
    await enteredField();
    await register(participant ?? homePlayer);
  }

  CommitYellowCardCommand command({
    ParticipantRef? participant,
    String intent = 'intent-yc-1',
    DisciplinaryAccountingScope scope = DisciplinaryAccountingScope.match,
    ParticipantStatusAtDetermination status =
        ParticipantStatusAtDetermination.onFieldPlayer,
    String? reason,
    TemporalContext? temporal,
    CaptureContext? context,
    DateTime? recordedAt,
  }) {
    return CommitYellowCardCommand(
      context: context ?? _context(),
      participantRef: participant ?? homePlayer,
      participantStatusAtDetermination: status,
      disciplinaryAccountingScope: scope,
      captureIntentId: intent,
      reason: reason,
      temporalContext: temporal,
      recordedAt: recordedAt,
    );
  }

  List<MatchRecord> yellowsOf(List<MatchRecord> committed) {
    return [
      for (final record in committed)
        if (record.payload is YellowCardPayload) record,
    ];
  }

  test('valid administered caution under ordinary IFAB commits', () async {
    await ready();
    final result = await committer.commitYellowCard(command());
    expect(result, isA<YellowCardSaved>());
    expect(result.ackEligible, isTrue);
    final saved = result as YellowCardSaved;
    expect(saved.recoveredExisting, isFalse);
    expect(yellowsOf(await records()), hasLength(1));
    expect(saved.record.originSequence, 3);
  });

  test('result is typed YELLOW_CARD / HUMAN_DETERMINATION', () async {
    await ready();
    final saved =
        await committer.commitYellowCard(command()) as YellowCardSaved;
    expect(saved.record.recordKind, RecordKind.humanDetermination);
    final payload = saved.record.payload as YellowCardPayload;
    expect(payload.semanticType, V1SemanticTypeCode.yellowCard);
    expect(payload.semanticType.wireValue, 'YELLOW_CARD');
    expect(
      payload.competitionRulesContext?.disciplinarySystem,
      DisciplinarySystem.ordinaryIfab,
    );
  });

  test('MAIN_REFEREE authority required', () async {
    await ready();
    final saved =
        await committer.commitYellowCard(command()) as YellowCardSaved;
    expect(saved.record.authorityContext?.scope, isA<MainRefereeScope>());
    expect(saved.record.authorityContext?.generation?.value, 1);
    expect(saved.record.authorityContext?.principal?.principalId, 'ref-main');

    final emptyPrincipal = await committer.commitYellowCard(
      command(
        intent: 'intent-empty-principal',
        context: _context(principal: ' '),
      ),
    );
    expect(emptyPrincipal, isA<YellowCardCommitRejected>());
    expect(
      (emptyPrincipal as YellowCardCommitRejected).failure,
      YellowCardCommitFailure.authorityInvalid,
    );
    expect(emptyPrincipal.ackEligible, isFalse);

    await append(
      RecordKind.temporalFact,
      TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.matchStarted,
      ),
      context: _context(generation: 2),
    );
    final stale = await committer.commitYellowCard(
      command(intent: 'intent-stale-generation'),
    );
    expect(
      (stale as YellowCardCommitRejected).failure,
      YellowCardCommitFailure.authorityInvalid,
    );

    final mismatched = await committer.commitYellowCard(
      command(
        intent: 'intent-generation-mismatch',
        context: _context(generation: 2, projectionGeneration: 1),
      ),
    );
    expect(
      (mismatched as YellowCardCommitRejected).failure,
      YellowCardCommitFailure.authorityInvalid,
    );

    final source =
        File('lib/capture/yellow_card_commit.dart').readAsStringSync();
    expect(source, contains('is! MainRefereeScope'));
    expect(yellowsOf(await records()), hasLength(1));
  });

  test('card authority before field-entry boundary rejects', () async {
    await register(homePlayer);
    final before = await records();
    final result = await committer.commitYellowCard(command());
    expect(
      (result as YellowCardCommitRejected).failure,
      YellowCardCommitFailure.cardAuthorityClosedOrNotOpen,
    );
    expect(result.ackEligible, isFalse);
    expect(await records(), hasLength(before.length));
    expect(yellowsOf(await records()), isEmpty);
  });

  test('card authority after field-entry and before kick-off allows', () async {
    await ready();
    final result = await committer.commitYellowCard(command());
    expect(result, isA<YellowCardSaved>());
    final committed = await records();
    expect(
      committed.where((record) {
        final payload = record.payload;
        return payload is TemporalTransitionPayload &&
            payload.semanticType == V1SemanticTypeCode.matchStarted;
      }),
      isEmpty,
    );
  });

  test('MATCH_STARTED is not required', () async {
    await ready();
    expect(await committer.commitYellowCard(command()), isA<YellowCardSaved>());
    expect(
      (await records()).where((record) {
        final payload = record.payload;
        return payload is TemporalTransitionPayload &&
            payload.semanticType == V1SemanticTypeCode.matchStarted;
      }),
      isEmpty,
    );
  });

  test('MATCH_ENDED alone does not block capture', () async {
    await ready();
    await matchEnded();
    final result = await committer.commitYellowCard(command());
    expect(result, isA<YellowCardSaved>());
    final payload =
        (result as YellowCardSaved).record.payload as YellowCardPayload;
    expect(
        payload.disciplinaryAccountingScope, DisciplinaryAccountingScope.match);
  });

  test('REFEREE_LEFT_FIELD_AFTER_MATCH blocks capture', () async {
    await ready();
    await matchStarted();
    await matchEnded();
    await leftField();
    final before = (await records()).length;
    final result = await committer.commitYellowCard(command());
    expect(
      (result as YellowCardCommitRejected).failure,
      YellowCardCommitFailure.cardAuthorityClosedOrNotOpen,
    );
    expect((await records()).length, before);
    expect(yellowsOf(await records()), isEmpty);
  });

  test('resolved participant identity allows', () async {
    await ready();
    final saved =
        await committer.commitYellowCard(command()) as YellowCardSaved;
    final payload = saved.record.payload as YellowCardPayload;
    expect(payload.participantRef, homePlayer);
    final projection =
        ParticipantIdentityProjection.derive(records: await records());
    expect(
      projection.confidenceFor(homePlayer.matchParticipantId),
      IdentityConfidence.resolved,
    );
  });

  test('ambiguous participant identity rejects', () async {
    await enteredField();
    final first = ParticipantRef(
      matchParticipantId: MatchParticipantId('mpid-home-8-a'),
      teamSide: ParticipantTeamSide.home,
      binding: const TeamScopedNumberBinding(shirtNumber: 8),
    );
    final second = ParticipantRef(
      matchParticipantId: MatchParticipantId('mpid-home-8-b'),
      teamSide: ParticipantTeamSide.home,
      binding: const TeamScopedNumberBinding(shirtNumber: 8),
    );
    await register(first);
    await register(second);
    final result =
        await committer.commitYellowCard(command(participant: first));
    expect(
      (result as YellowCardCommitRejected).failure,
      YellowCardCommitFailure.participantIdentityUnresolvedOrConflicted,
    );
    expect(yellowsOf(await records()), isEmpty);
  });

  test('conflicted participant identity rejects', () async {
    await enteredField();
    final a = ParticipantRef(
      matchParticipantId: MatchParticipantId('mpid-a'),
      teamSide: ParticipantTeamSide.home,
      binding: const TeamScopedNumberBinding(shirtNumber: 3),
    );
    final b = MatchParticipantId('mpid-b');
    final c = MatchParticipantId('mpid-c');
    await register(a);
    await register(
      ParticipantRef(
        matchParticipantId: b,
        teamSide: ParticipantTeamSide.home,
        binding: const TeamScopedNumberBinding(shirtNumber: 4),
      ),
    );
    await register(
      ParticipantRef(
        matchParticipantId: c,
        teamSide: ParticipantTeamSide.home,
        binding: const TeamScopedNumberBinding(shirtNumber: 5),
      ),
    );
    await append(
      RecordKind.action,
      ParticipantIdentityReconciliationPayload(
        fromParticipantId: a.matchParticipantId,
        toParticipantId: b,
      ),
    );
    await append(
      RecordKind.action,
      ParticipantIdentityReconciliationPayload(
        fromParticipantId: b,
        toParticipantId: c,
      ),
    );
    await append(
      RecordKind.action,
      ParticipantIdentityReconciliationPayload(
        fromParticipantId: c,
        toParticipantId: a.matchParticipantId,
      ),
    );
    final projection =
        ParticipantIdentityProjection.derive(records: await records());
    expect(
      projection.confidenceFor(a.matchParticipantId),
      IdentityConfidence.conflicted,
    );
    final result = await committer.commitYellowCard(command(participant: a));
    expect(
      (result as YellowCardCommitRejected).failure,
      YellowCardCommitFailure.participantIdentityUnresolvedOrConflicted,
    );
    expect(yellowsOf(await records()), isEmpty);
    expect(
      (await records()).where(
        (record) => record.payload is ParticipantIdentityReconciliationPayload,
      ),
      hasLength(3),
    );
  });

  test('durable provisional identity follows frozen admission rule', () async {
    await enteredField();
    final provisional = ParticipantRef(
      matchParticipantId: MatchParticipantId('mpid-provisional'),
      teamSide: ParticipantTeamSide.home,
      binding: const FreeformDescriptorBinding(descriptor: 'unknown home #7'),
    );
    await register(provisional);
    final projection =
        ParticipantIdentityProjection.derive(records: await records());
    expect(
      projection.confidenceFor(provisional.matchParticipantId),
      IdentityConfidence.provisional,
    );
    expect(projection[provisional.matchParticipantId]!.registrationRecordId,
        isNotNull);

    final saved = await committer.commitYellowCard(
      command(participant: provisional, intent: 'intent-provisional'),
    ) as YellowCardSaved;
    final payload = saved.record.payload as YellowCardPayload;
    expect(payload.participantRef, provisional);

    final unbound = ParticipantRef(
      matchParticipantId: MatchParticipantId('mpid-empty-provisional'),
      teamSide: ParticipantTeamSide.away,
      binding: const FreeformDescriptorBinding(descriptor: '   '),
    );
    await register(unbound);
    final rejected = await committer.commitYellowCard(
      command(participant: unbound, intent: 'intent-unbound'),
    );
    expect(
      (rejected as YellowCardCommitRejected).failure,
      YellowCardCommitFailure.participantIdentityUnresolvedOrConflicted,
    );
    expect(yellowsOf(await records()), hasLength(1));
  });

  test('ORDINARY_IFAB allows', () async {
    await ready();
    final saved =
        await committer.commitYellowCard(command()) as YellowCardSaved;
    expect(
      (saved.record.payload as YellowCardPayload)
          .competitionRulesContext
          ?.disciplinarySystem,
      DisciplinarySystem.ordinaryIfab,
    );
  });

  test('TEMPORARY_DISMISSAL rejects', () async {
    await ready();
    final result = await committer.commitYellowCard(
      command(
        context: _context(system: DisciplinarySystem.temporaryDismissal),
      ),
    );
    expect(
      (result as YellowCardCommitRejected).failure,
      YellowCardCommitFailure.unsupportedDisciplinarySystem,
    );
    expect(yellowsOf(await records()), isEmpty);
  });

  test('UNRESOLVED disciplinary system rejects', () async {
    await ready();
    final unresolved = await committer.commitYellowCard(
      command(context: _context(system: DisciplinarySystem.unresolved)),
    );
    expect(
      (unresolved as YellowCardCommitRejected).failure,
      YellowCardCommitFailure.disciplinarySystemUnresolved,
    );

    final missing = await committer.commitYellowCard(
      command(
        context: _context(omitRules: true),
        intent: 'intent-missing-rules',
      ),
    );
    expect(
      (missing as YellowCardCommitRejected).failure,
      YellowCardCommitFailure.disciplinarySystemUnresolved,
    );

    final rulesetOnly = await committer.commitYellowCard(
      command(
        intent: 'intent-ruleset-only',
        context: _context(
          system: DisciplinarySystem.unresolved,
          rulesetId: 'ifab',
        ),
      ),
    );
    expect(
      (rulesetOnly as YellowCardCommitRejected).failure,
      YellowCardCommitFailure.disciplinarySystemUnresolved,
    );
    expect(yellowsOf(await records()), isEmpty);
  });

  test('trusted MATCH accounting scope allows', () async {
    await ready();
    final saved =
        await committer.commitYellowCard(command()) as YellowCardSaved;
    expect(
      (saved.record.payload as YellowCardPayload).disciplinaryAccountingScope,
      DisciplinaryAccountingScope.match,
    );
  });

  test('unresolved accounting scope rejects', () async {
    await ready();
    final before = (await records()).length;
    final result = await committer.commitYellowCard(
      command(scope: DisciplinaryAccountingScope.unresolved),
    );
    expect(
      (result as YellowCardCommitRejected).failure,
      YellowCardCommitFailure.disciplinaryAccountingScopeUnresolved,
    );
    expect((await records()).length, before);
  });

  test('MATCH and SHOOTOUT remain distinct', () async {
    await ready();
    final matchCaution = await committer.commitYellowCard(
      command(intent: 'intent-match'),
    ) as YellowCardSaved;
    await matchEnded();
    final shootoutCaution = await committer.commitYellowCard(
      command(
        intent: 'intent-shootout',
        scope: DisciplinaryAccountingScope.shootout,
        context: _context(shootout: true),
      ),
    ) as YellowCardSaved;

    final matchPayload = matchCaution.record.payload as YellowCardPayload;
    final shootoutPayload = shootoutCaution.record.payload as YellowCardPayload;
    expect(matchPayload.disciplinaryAccountingScope,
        DisciplinaryAccountingScope.match);
    expect(
      shootoutPayload.disciplinaryAccountingScope,
      DisciplinaryAccountingScope.shootout,
    );
    expect(
        matchPayload.captureIntentId, isNot(shootoutPayload.captureIntentId));
    expect(yellowsOf(await records()), hasLength(2));
  });

  test('reason absent still allows commit', () async {
    await ready();
    final saved =
        await committer.commitYellowCard(command()) as YellowCardSaved;
    expect((saved.record.payload as YellowCardPayload).reason, isNull);
    final blank = await committer.commitYellowCard(
      command(intent: 'intent-blank-reason', reason: '   '),
    ) as YellowCardSaved;
    expect((blank.record.payload as YellowCardPayload).reason, isNull);
  });

  test('exact temporal evidence reference remains preserved', () async {
    await ready();
    final exactEvidence = TemporalEvidence(
      evidenceId: 'clock-exact-1',
      capturedAt: DateTime.utc(2026, 10, 6, 18),
      continuityDomainId: 'continuity-a',
      monotonicElapsed: const Duration(minutes: 23, seconds: 17),
    );
    final saved = await committer.commitYellowCard(
      command(
        temporal: TemporalContext(
          evidenceIds: [exactEvidence.evidenceId],
          domainClockPolicyVersion: 'domain-clock-v1',
        ),
      ),
    ) as YellowCardSaved;
    final committed = (await records()).last;
    expect(
      committed.temporalContext?.evidenceIds,
      [exactEvidence.evidenceId],
    );
    expect(
      committed.temporalContext?.domainClockPolicyVersion,
      'domain-clock-v1',
    );
    expect(committed.temporalContext?.explicitUncertainty, isFalse);
    expect(saved.record.recordId, committed.recordId);
  });

  test('continuity-unresolved temporal placement remains explicitly uncertain',
      () async {
    await ready();
    final saved = await committer.commitYellowCard(
      command(
        temporal: const TemporalContext(
          evidenceIds: ['clock-unresolved-1'],
          domainClockPolicyVersion: 'domain-clock-v1',
          explicitUncertainty: true,
        ),
      ),
    ) as YellowCardSaved;
    final committed = (await records()).last;
    expect(committed.recordId, saved.record.recordId);
    expect(committed.temporalContext?.evidenceIds, ['clock-unresolved-1']);
    expect(committed.temporalContext?.explicitUncertainty, isTrue);
    final payload = encodeMatchRecordForStorage(committed)['payload']
        as Map<String, Object?>;
    expect(payload.keys, isNot(contains('minute')));
    expect(payload.keys, isNot(contains('matchMinute')));
    expect(payload.keys, isNot(contains('elapsedSeconds')));
    expect(payload.keys, isNot(contains('playingTime')));
    expect(payload.toString(), isNot(contains('00:00')));
  });

  test('no exact minute is required for yellow card authority', () async {
    await ready();
    final saved =
        await committer.commitYellowCard(command()) as YellowCardSaved;
    final committed = (await records()).last;
    expect(committed.recordId, saved.record.recordId);
    expect(committed.temporalContext?.evidenceIds, isEmpty);
    expect(committed.temporalContext?.explicitUncertainty, isTrue);
    expect(saved.ackEligible, isTrue);
  });

  test('first captureIntentId commit appends exactly one YC', () async {
    await ready();
    expect(await committer.commitYellowCard(command()), isA<YellowCardSaved>());
    expect(yellowsOf(await records()), hasLength(1));
  });

  test('committed intent survives later competition-rules change', () async {
    await ready();
    final first =
        await committer.commitYellowCard(command()) as YellowCardSaved;
    final before = [
      for (final record in await records()) record.originSequence,
    ];
    final retry = await committer.commitYellowCard(
      command(
        context: _context(system: DisciplinarySystem.temporaryDismissal),
      ),
    ) as YellowCardSaved;
    expect(retry.recoveredExisting, isTrue);
    expect(retry.record.recordId, first.record.recordId);
    expect(retry.record.originSequence, first.record.originSequence);
    expect(
      (retry.record.payload as YellowCardPayload)
          .competitionRulesContext
          ?.disciplinarySystem,
      DisciplinarySystem.ordinaryIfab,
    );
    expect(
      [for (final record in await records()) record.originSequence],
      before,
    );
    expect(yellowsOf(await records()), hasLength(1));
  });

  test('committed intent survives later authority-generation change', () async {
    await ready();
    final first =
        await committer.commitYellowCard(command()) as YellowCardSaved;
    final before = [
      for (final record in await records()) record.originSequence,
    ];
    final retry = await committer.commitYellowCard(
      command(context: _context(generation: 2)),
    ) as YellowCardSaved;
    final after = [
      for (final record in await records()) record.originSequence,
    ];
    expect(retry.recoveredExisting, isTrue);
    expect(after, before);
    expect(retry.record.originSequence, first.record.originSequence);
    expect(retry.record.authorityContext?.generation?.value, 1);
  });

  test('committed intent survives later card-authority closure', () async {
    await ready();
    final first =
        await committer.commitYellowCard(command()) as YellowCardSaved;
    await leftField();
    final before = [
      for (final record in await records()) record.originSequence,
    ];
    final retry =
        await committer.commitYellowCard(command()) as YellowCardSaved;
    expect(retry.recoveredExisting, isTrue);
    expect(retry.record.recordId, first.record.recordId);
    expect(retry.record.originSequence, first.record.originSequence);
    expect(
      [for (final record in await records()) record.originSequence],
      before,
    );
    expect(yellowsOf(await records()), hasLength(1));
  });

  test('same intent and different participant is an idempotency conflict',
      () async {
    await enteredField();
    final other = ParticipantRef(
      matchParticipantId: MatchParticipantId('mpid-away-4'),
      teamSide: ParticipantTeamSide.away,
      binding: const RosterLinkedBinding(rosterParticipantId: 'away-4'),
    );
    await register(homePlayer);
    await register(other);
    final first =
        await committer.commitYellowCard(command()) as YellowCardSaved;
    final before = (await records()).length;
    final conflict = await committer.commitYellowCard(
      command(participant: other),
    );
    expect(
      (conflict as YellowCardCommitRejected).failure,
      YellowCardCommitFailure.idempotencyConflict,
    );
    expect(conflict.ackEligible, isFalse);
    expect((await records()).length, before);
    expect(yellowsOf(await records()).single.recordId, first.record.recordId);
  });

  test(
      'same intent and different authoritative payload is an idempotency conflict',
      () async {
    await ready();
    await committer.commitYellowCard(command(reason: 'dissent'));
    final sequences = [
      for (final record in await records()) record.originSequence,
    ];
    final statusConflict = await committer.commitYellowCard(
      command(status: ParticipantStatusAtDetermination.substitute),
    );
    expect(
      (statusConflict as YellowCardCommitRejected).failure,
      YellowCardCommitFailure.idempotencyConflict,
    );
    final scopeConflict = await committer.commitYellowCard(
      command(
        scope: DisciplinaryAccountingScope.shootout,
        context: _context(shootout: true),
      ),
    );
    expect(
      (scopeConflict as YellowCardCommitRejected).failure,
      YellowCardCommitFailure.idempotencyConflict,
    );
    expect(
      [for (final record in await records()) record.originSequence],
      sequences,
    );
    expect(yellowsOf(await records()), hasLength(1));
  });

  test('reason-only retry recovers original immutable enrichment', () async {
    await ready();
    final first = await committer.commitYellowCard(
      command(reason: 'dissent'),
    ) as YellowCardSaved;
    final before = [
      for (final record in await records()) record.originSequence,
    ];

    final changed = await committer.commitYellowCard(
      command(reason: 'unsporting behaviour'),
    ) as YellowCardSaved;
    final removed =
        await committer.commitYellowCard(command()) as YellowCardSaved;

    expect(changed.recoveredExisting, isTrue);
    expect(removed.recoveredExisting, isTrue);
    expect(changed.record.recordId, first.record.recordId);
    expect(removed.record.recordId, first.record.recordId);
    expect(
      (changed.record.payload as YellowCardPayload).reason,
      'dissent',
    );
    expect(
      (removed.record.payload as YellowCardPayload).reason,
      'dissent',
    );
    expect(
      [for (final record in await records()) record.originSequence],
      before,
    );
    expect(yellowsOf(await records()), hasLength(1));
  });

  test(
      'two distinct intents for the same participant and timestamp create two cautions',
      () async {
    await ready();
    final when = DateTime.utc(2026, 10, 6, 18, 4);
    const temporal = TemporalContext(evidenceIds: ['shared-clock']);
    final first = await committer.commitYellowCard(
      command(intent: 'intent-a', recordedAt: when, temporal: temporal),
    ) as YellowCardSaved;
    final second = await committer.commitYellowCard(
      command(intent: 'intent-b', recordedAt: when, temporal: temporal),
    ) as YellowCardSaved;
    expect(first.record.recordId, isNot(second.record.recordId));
    expect(first.record.recordedAt, second.record.recordedAt);
    expect(first.record.temporalContext?.evidenceIds, ['shared-clock']);
    expect(second.record.temporalContext?.evidenceIds, ['shared-clock']);
    expect(yellowsOf(await records()), hasLength(2));
    expect(first.record.originSequence, isNot(second.record.originSequence));
  });

  test('crash reopen retry produces one YC', () async {
    await ready();
    final issued = command();
    final saved = await committer.commitYellowCard(issued) as YellowCardSaved;
    expect(saved.ackEligible, isTrue);
    await store.close();

    final reopened = SqliteDurableMatchStore.open(databaseFile);
    addTearDown(reopened.close);
    final recovered = await YellowCardCommitter(
      originCommit: reopened,
      memory: reopened,
      recordBuilder: AuthoritativeRecordBuilder(
        identityGenerator: _SequentialIds(),
      ),
    ).commitYellowCard(issued) as YellowCardSaved;
    expect(recovered.recoveredExisting, isTrue);
    expect(recovered.record.recordId, saved.record.recordId);
    final yellows = [
      for (final record in await reopened.readCommittedForMatch(_matchId))
        if (record.payload is YellowCardPayload) record,
    ];
    expect(yellows, hasLength(1));
  });

  test('a commit that never succeeded can succeed once on retry', () async {
    await ready();
    store.abortBeforeCommitForTest = () {
      throw StateError('power loss before commit');
    };
    final failed = await committer.commitYellowCard(command());
    expect(failed, isA<YellowCardCommitRejected>());
    expect(
      (failed as YellowCardCommitRejected).failure,
      YellowCardCommitFailure.durableCommitFailure,
    );
    expect(failed.ackEligible, isFalse);
    expect(failed.toString(), isNot(contains('sqlite')));
    expect(yellowsOf(await records()), isEmpty);
    store.abortBeforeCommitForTest = null;
    await store.close();

    final reopened = SqliteDurableMatchStore.open(databaseFile);
    addTearDown(reopened.close);
    final saved = await YellowCardCommitter(
      originCommit: reopened,
      memory: reopened,
      recordBuilder: AuthoritativeRecordBuilder(
        identityGenerator: _SequentialIds(start: 100),
      ),
    ).commitYellowCard(command()) as YellowCardSaved;
    expect(saved.recoveredExisting, isFalse);
    expect(saved.ackEligible, isTrue);
    final yellows = [
      for (final record in await reopened.readCommittedForMatch(_matchId))
        if (record.payload is YellowCardPayload) record,
    ];
    expect(yellows, hasLength(1));
  });

  test('D1 failure produces no Saved result', () async {
    await ready();
    final before = (await records()).map((record) => record.recordId).toList();
    store.abortBeforeCommitForTest = () {
      throw StateError('commit aborted');
    };
    final result = await committer.commitYellowCard(command());
    expect(result, isNot(isA<YellowCardSaved>()));
    expect(result.ackEligible, isFalse);
    expect(
      (result as YellowCardCommitRejected).failure,
      YellowCardCommitFailure.durableCommitFailure,
    );
    expect(
      (await records()).map((record) => record.recordId).toList(),
      before,
    );
  });

  test('failed admission writes nothing', () async {
    await register(homePlayer);
    final before =
        (await records()).map((record) => record.originSequence).toList();
    final result = await committer.commitYellowCard(command());
    expect(result, isA<YellowCardCommitRejected>());
    expect(
      (await records()).map((record) => record.originSequence).toList(),
      before,
    );
    expect(yellowsOf(await records()), isEmpty);
  });

  test('no legacy Yellow event is written by the command', () {
    final source =
        File('lib/capture/yellow_card_commit.dart').readAsStringSync();
    expect(source, isNot(contains('package:match_core')));
    expect(source, isNot(contains('MatchSession')));
    expect(source, isNot(contains('EventType')));
    expect(source, isNot(contains('upsertMatch')));
  });

  test('capture record stores no mutable standing-caution authority', () async {
    await ready();
    final saved =
        await committer.commitYellowCard(command()) as YellowCardSaved;
    final encoded = encodeMatchRecordForStorage(saved.record);
    final payload = encoded['payload'] as Map<String, Object?>;
    expect(payload.keys, isNot(contains('yellowCount')));
    expect(payload.keys, isNot(contains('standingCautions')));
    expect(payload.keys, isNot(contains('priorCautionState')));
    expect(payload.keys, isNot(contains('isSecondYellow')));
    expect(payload.keys, isNot(contains('dismissalRequired')));
  });

  test('no RED_CARD semantic or record is added', () async {
    expect(V1SemanticTypeCodeWire.parseWire('RED_CARD'), isNull);
    await ready();
    final saved =
        await committer.commitYellowCard(command()) as YellowCardSaved;
    expect(
      (saved.record.payload as YellowCardPayload).semanticType,
      isNot(V1SemanticTypeCodeWire.parseWire('RED_CARD')),
    );
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in files) {
      expect(file.readAsStringSync(), isNot(contains('RedCardPayload')));
      expect(file.readAsStringSync(), isNot(contains('RED_CARD')));
    }
  });

  test('bounded yellow card D1 batch reports cloud timing', () async {
    await ready();
    const batch = 32;
    final watch = Stopwatch()..start();
    for (var index = 0; index < batch; index++) {
      final result = await committer.commitYellowCard(
        command(intent: 'intent-batch-$index'),
      );
      expect(result, isA<YellowCardSaved>());
    }
    watch.stop();
    expect(yellowsOf(await records()), hasLength(batch));
    final micros = watch.elapsedMicroseconds;
    final perCommit = micros / batch;
    final report = StringBuffer()
      ..writeln('yellow_card_d1_batch')
      ..writeln('batch=$batch')
      ..writeln('elapsed_us=$micros')
      ..writeln('per_commit_us=${perCommit.toStringAsFixed(1)}')
      ..writeln('cloud_timing_is_not_phone_d1_certification=true');
    // ignore: avoid_print
    print(report.toString());
    final artifactDir = Directory('/opt/cursor/artifacts');
    if (!artifactDir.existsSync()) artifactDir.createSync(recursive: true);
    File('${artifactDir.path}/yellow_card_d1_batch_timing.txt')
        .writeAsStringSync(report.toString());
  });
}

CaptureContext _context({
  DisciplinarySystem system = DisciplinarySystem.ordinaryIfab,
  bool shootout = false,
  int generation = 1,
  int? projectionGeneration,
  String principal = 'ref-main',
  String rulesetId = 'ifab',
  CompetitionRulesContext? rules,
  bool omitRules = false,
}) {
  return CaptureContext(
    matchId: _matchId,
    originDeviceId: 'device-yc',
    authorityScope: const MainRefereeScope(),
    authorityPrincipalId: principal,
    authorityGeneration: generation,
    projectionAuthorityGeneration: projectionGeneration ?? generation,
    activeCaptureDeviceId: 'device-yc',
    domainContractVersion: const DomainContractVersion('domain-clock-v1'),
    competitionRulesContext: omitRules
        ? null
        : rules ??
            CompetitionRulesContext(
              rulesetId: rulesetId,
              disciplinarySystem: system,
              penaltyShootOutAfterMatchEnd: shootout,
            ),
  );
}

final class _SequentialIds implements RecordIdentityGenerator {
  _SequentialIds({int start = 0}) : _next = start;

  int _next;

  @override
  String newRecordId() {
    _next += 1;
    return 'yc-record-$_next';
  }
}
