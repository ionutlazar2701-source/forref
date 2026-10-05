import 'dart:convert';
import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:referee_phone/infrastructure/competition_rules/match_competition_rules_store.dart';
import 'package:referee_phone/infrastructure/competition_rules/phone_match_capture_context.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/infrastructure/temporal/phone_temporal_evidence_store.dart';
import 'package:referee_phone/match_application/authoritative_capture_command.dart';
import 'package:referee_phone/match_application/kick_off_authority.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('goal_cutover_');
  });

  tearDown(() async {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('a goal commits during active period 1 under MAIN_REFEREE', () async {
    final opened = await _open(temp);
    await _kickOff(opened);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();

    final result = await _commitGoal(opened, GoalScoringSide.home);

    expect(result, isA<DurableCommitSuccess>());
    final records = await _records(opened.composition);
    expect(records, hasLength(3));
    final goal = records.last;
    expect(goal.recordKind, RecordKind.action);
    expect(goal.originSequence, 3);
    expect(goal.originDeviceId, identity.originDeviceId);
    expect((goal.payload as GoalPayload).scoringSide, GoalScoringSide.home);
    expect((goal.payload as GoalPayload).period, const PeriodIdentity(index: 1));
    expect((goal.payload as GoalPayload).playerId, isNull);
    expect((goal.payload as GoalPayload).playerNumber, isNull);
    expect(goal.authorityContext!.scope, isA<MainRefereeScope>());
    expect(
      goal.authorityContext!.principal!.principalId,
      identity.authorityPrincipalId,
    );
    expect(
      goal.authorityContext!.generation!.value,
      PhoneCaptureIdentity.initialAuthorityGeneration,
    );
    expect(goal.relationships.single, isA<CausalDependency>());
    expect(
      (goal.relationships.single as CausalDependency).targetRecordId,
      records[1].recordId,
    );
  });

  test('a goal cannot commit before an active period and consumes no sequence', () async {
    final opened = await _open(temp);

    final blocked = await _commitGoal(opened, GoalScoringSide.home);

    expect(blocked, isA<DurableCommitFailure>());
    expect(
      (blocked as DurableCommitFailure).reason,
      'GOAL requires one active period',
    );
    expect(await _records(opened.composition), isEmpty);

    await _kickOff(opened);
    final records = await _records(opened.composition);
    expect(records.map((record) => record.originSequence), [1, 2]);
  });

  test('a goal cannot commit after a valid MATCH_ENDED', () async {
    final opened = await _open(temp);
    final ended = await _bothPeriodsEnded(opened);
    await _saveRules(opened, _noneRequired);
    final before = await _records(opened.composition);
    expect(
      await _endMatch(opened, periodEndedRecordId: ended.finalPeriodEndId),
      isA<DurableCommitSuccess>(),
    );
    final afterEnd = await _records(opened.composition);

    final blocked = await _commitGoal(opened, GoalScoringSide.away);

    expect(blocked, isA<DurableCommitFailure>());
    expect(
      (blocked as DurableCommitFailure).reason,
      'GOAL requires a match that has not normally ended',
    );
    expect(await _records(opened.composition), hasLength(afterEnd.length));
    expect(before.length, lessThan(afterEnd.length));
    expect(
      afterEnd.where(_isGoal),
      isEmpty,
    );
  });

  test('an abandoned match rejects a goal without a new record', () async {
    final opened = await _open(temp);
    await _kickOff(opened);
    expect(
      await opened.composition.boundary.captureAndCommit(
        AuthoritativeCaptureCommand(
          context: await _context(opened),
          recordKind: RecordKind.temporalFact,
          payload: TemporalTransitionPayload(
            semanticType: V1SemanticTypeCode.matchAbandoned,
          ),
          integrity: const IntegrityMetadata(),
        ),
      ),
      isA<DurableCommitSuccess>(),
    );
    final before = await _records(opened.composition);

    final blocked = await _commitGoal(opened, GoalScoringSide.home);

    expect(
      (blocked as DurableCommitFailure).reason,
      'GOAL requires a match that has not been abandoned',
    );
    expect(await _records(opened.composition), hasLength(before.length));
  });

  test('the next origin sequence is allocated only for an admitted goal', () async {
    final opened = await _open(temp);
    await _kickOff(opened);

    final first = await _commitGoal(opened, GoalScoringSide.home);
    final second = await _commitGoal(opened, GoalScoringSide.away);
    final records = await _records(opened.composition);

    expect(first, isA<DurableCommitSuccess>());
    expect(second, isA<DurableCommitSuccess>());
    expect(records.map((record) => record.originSequence), [1, 2, 3, 4]);
    expect(records[2].recordKind, RecordKind.action);
    expect(records[3].recordKind, RecordKind.action);
  });

  test('invalid capture authority fails closed and consumes no sequence', () async {
    final opened = await _open(temp);
    await _kickOff(opened);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final before = await _records(opened.composition);

    final emptyPrincipal = await opened.composition.boundary.commitGoal(
      CaptureContext(
        matchId: 'match-1',
        originDeviceId: identity.originDeviceId,
        authorityScope: v1AuthorityScope,
        authorityPrincipalId: '',
        authorityGeneration: 1,
        projectionAuthorityGeneration: 1,
      ),
      scoringSide: GoalScoringSide.home,
      temporalContext: const TemporalContext(evidenceIds: []),
    );
    final foreignGeneration = await opened.composition.boundary.commitGoal(
      CaptureContext(
        matchId: 'match-1',
        originDeviceId: identity.originDeviceId,
        authorityScope: v1AuthorityScope,
        authorityPrincipalId: identity.authorityPrincipalId,
        authorityGeneration: 2,
        projectionAuthorityGeneration: 1,
      ),
      scoringSide: GoalScoringSide.home,
      temporalContext: const TemporalContext(evidenceIds: []),
    );

    expect(
      (emptyPrincipal as DurableCommitFailure).reason,
      'GOAL requires an authority principal',
    );
    expect(
      (foreignGeneration as DurableCommitFailure).reason,
      'GOAL capture authority generation does not match',
    );
    expect(await _records(opened.composition), hasLength(before.length));
  });

  test('eight monotonic minutes do not become 00:00 from a zero legacy clock', () async {
    final clock = ManualContinuityClock();
    final opened = await _open(temp, clock: clock);
    clock.elapsed = Duration.zero;
    clock.now = DateTime.utc(2099);
    final periodEvidence = await _kickOff(opened);
    clock.elapsed = const Duration(minutes: 8);
    clock.now = DateTime.utc(1970);
    final goalEvidence = await opened.evidence.captureAnchor();

    final result = await opened.composition.boundary.commitGoal(
      await _context(opened),
      scoringSide: GoalScoringSide.home,
      temporalContext: TemporalContext(
        evidenceIds: [goalEvidence.evidenceId],
        domainClockPolicyVersion: PhoneCaptureIdentity.domainClockContract.value,
      ),
    );

    expect(result, isA<DurableCommitSuccess>());
    final records = await _records(opened.composition);
    final projection = deriveGoalMatchProjection(
      records: records,
      recordedEvidence: [periodEvidence, goalEvidence],
    );
    final reading = projection.history.single.temporal;
    expect(reading.exactElapsed, const Duration(minutes: 8));
    expect(reading.exactElapsed, isNot(Duration.zero));
    expect(reading.continuity, TemporalContinuityStatus.exactContinuity);
    expect(projection.homeScore, 1);
    expect(projection.awayScore, 0);
    expect(records.last.recordedAt, isNot(DateTime.utc(1970)));
  });

  test('unresolved goal evidence stays uncertain instead of 00:00', () async {
    final opened = await _open(temp);
    await _kickOff(opened);

    final result = await opened.composition.boundary.commitGoal(
      await _context(opened),
      scoringSide: GoalScoringSide.away,
      temporalContext: const TemporalContext(evidenceIds: ['missing-sample']),
    );

    expect(result, isA<DurableCommitSuccess>());
    final projection = deriveGoalMatchProjection(
      records: await _records(opened.composition),
      recordedEvidence: const [],
    );
    expect(projection.history.single.temporal, GoalTemporalReading.uncertain);
    expect(projection.history.single.temporal.exactElapsed, isNull);
    expect(projection.history.single.temporal.exactElapsed, isNot(Duration.zero));
    expect(projection.awayScore, 1);
    expect(projection.homeScore, 0);
  });

  test('ambiguous temporal lineage fails closed and consumes no sequence', () async {
    final opened = await _open(temp);
    await _kickOff(opened);
    final records = await _records(opened.composition);
    final matchStart = records.first;
    expect(
      await opened.composition.boundary.captureAndCommit(
        AuthoritativeCaptureCommand(
          context: await _context(opened),
          recordKind: RecordKind.temporalFact,
          payload: TemporalTransitionPayload(
            semanticType: V1SemanticTypeCode.periodStarted,
            period: const PeriodIdentity(index: 1),
          ),
          integrity: const IntegrityMetadata(),
          relationships: [
            CausalDependency(targetRecordId: matchStart.recordId),
          ],
        ),
      ),
      isA<DurableCommitSuccess>(),
    );
    final before = await _records(opened.composition);

    final blocked = await _commitGoal(opened, GoalScoringSide.home);

    expect(
      (blocked as DurableCommitFailure).reason,
      'GOAL has ambiguous temporal lineage',
    );
    final after = await _records(opened.composition);
    expect(after, hasLength(before.length));
    expect(after.map((record) => record.originSequence), [1, 2, 3]);
  });

  test('home and away goals rebuild the same score after reopen', () async {
    final clock = ManualContinuityClock();
    final opened = await _open(temp, clock: clock);
    final periodEvidence = await _kickOff(opened);
    clock.elapsed = const Duration(minutes: 3);
    final homeEvidence = await opened.evidence.captureAnchor();
    expect(
      await opened.composition.boundary.commitGoal(
        await _context(opened),
        scoringSide: GoalScoringSide.home,
        playerNumber: '9',
        temporalContext: TemporalContext(
          evidenceIds: [homeEvidence.evidenceId],
          domainClockPolicyVersion:
              PhoneCaptureIdentity.domainClockContract.value,
        ),
      ),
      isA<DurableCommitSuccess>(),
    );
    clock.elapsed = const Duration(minutes: 11);
    final awayEvidence = await opened.evidence.captureAnchor();
    expect(
      await opened.composition.boundary.commitGoal(
        await _context(opened),
        scoringSide: GoalScoringSide.away,
        temporalContext: TemporalContext(
          evidenceIds: [awayEvidence.evidenceId],
          domainClockPolicyVersion:
              PhoneCaptureIdentity.domainClockContract.value,
        ),
      ),
      isA<DurableCommitSuccess>(),
    );
    final evidence = [periodEvidence, homeEvidence, awayEvidence];
    final before = deriveGoalMatchProjection(
      records: await _records(opened.composition),
      recordedEvidence: evidence,
    );
    await opened.composition.close();
    opened.closed = true;

    final reopened = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(reopened.close);
    final after = deriveGoalMatchProjection(
      records: await _records(reopened),
      recordedEvidence: evidence,
    );

    expect(after, before);
    expect(after.homeScore, 1);
    expect(after.awayScore, 1);
    expect(after.history.map((goal) => goal.scoringSide), [
      GoalScoringSide.home,
      GoalScoringSide.away,
    ]);
    expect(after.history.first.playerNumber, '9');
    expect(after.history.first.temporal.exactElapsed, const Duration(minutes: 3));
    expect(after.history.last.temporal.exactElapsed, const Duration(minutes: 11));
    expect(after.history.map((goal) => goal.originSequence), [3, 4]);
  });

  test('goal memory stores no mutable score and no legacy match database', () async {
    final opened = await _open(temp);
    await _kickOff(opened);
    expect(
      await _commitGoal(opened, GoalScoringSide.home),
      isA<DurableCommitSuccess>(),
    );
    final records = await _records(opened.composition);
    final goal = records.last;
    final stored = jsonEncode(encodeMatchRecordForStorage(goal));

    expect(opened.composition.boundary.durableStore.tableNames(), [
      'committed_match_records',
    ]);
    expect(stored, isNot(contains('scoreHome')));
    expect(stored, isNot(contains('scoreAway')));
    expect(stored, isNot(contains('homeScore')));
    expect(stored, isNot(contains('awayScore')));
    expect(stored, isNot(contains('elapsedSeconds')));
    expect(stored, contains('GOAL'));
    expect(stored, contains('HOME'));
    final files = temp.listSync(recursive: true).whereType<File>();
    expect(
      files.where((file) => file.path.endsWith('.sqlite')).map((file) => file.uri.pathSegments.last),
      ['match_memory.sqlite'],
    );
    expect(records.where(_isGoal), hasLength(1));
  });

  test('commitGoal does not write legacy match authority', () {
    final boundary = File(
      'lib/match_application/match_application_boundary.dart',
    ).readAsStringSync();
    final command = RegExp(
      r'Future<DurableCommitResult> commitGoal[\s\S]*?\n  \}\r?\n',
    ).firstMatch(boundary)!.group(0)!;
    final page = File(
      'lib/features/live_match/live_match_page.dart',
    ).readAsStringSync();

    expect(command, contains('assessGoalAdmission'));
    expect(command, contains('commitAtNextOriginSequence'));
    expect(command, isNot(contains('captureAndCommit')));
    expect(command, isNot(contains('package:match_core')));
    expect(command, isNot(contains('scoreHome')));
    expect(command, isNot(contains('LocalMatchDatabase')));
    expect(command, isNot(contains('elapsedSeconds')));
    expect(page, isNot(contains('commitGoal')));
  });
}

const _noneRequired = CompetitionRulesContext(
  rulesetId: 'ifab',
  additionalPlayingPhase: AdditionalPlayingPhaseDisposition.noneRequired,
);

final class _Opened {
  _Opened({
    required this.composition,
    required this.capture,
    required this.evidence,
    required this.rulesStore,
  });

  final MatchApplicationComposition composition;
  final PhoneMatchCaptureContext capture;
  final PhoneTemporalEvidenceStore evidence;
  final MatchCompetitionRulesStore rulesStore;
  bool closed = false;
}

Future<_Opened> _open(Directory temp, {ManualContinuityClock? clock}) async {
  final evidence = PhoneTemporalEvidenceStore(
    storageRoot: temp,
    clock: clock ?? ManualContinuityClock(),
  );
  final composition = await MatchApplicationComposition.open(storageRoot: temp);
  final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
  final rulesStore = MatchCompetitionRulesStore(temp);
  await rulesStore.ensureForMatch('match-1');
  final opened = _Opened(
    composition: composition,
    capture: PhoneMatchCaptureContext(
      identity: identity,
      rulesStore: rulesStore,
    ),
    evidence: evidence,
    rulesStore: rulesStore,
  );
  addTearDown(() async {
    if (!opened.closed) await composition.close();
  });
  return opened;
}

Future<void> _saveRules(_Opened opened, CompetitionRulesContext rules) {
  return opened.rulesStore.saveForMatch('match-1', rules);
}

Future<CaptureContext> _context(_Opened opened) {
  return opened.capture.captureContextFor('match-1');
}

Future<TemporalEvidence> _kickOff(_Opened opened) async {
  final captured = await opened.evidence.captureAnchor();
  final result = await opened.composition.boundary.commitKickOff(
    await _context(opened),
    period: const PeriodIdentity(index: 1),
    periodAnchor: () async => TemporalContext(
      evidenceIds: [captured.evidenceId],
      domainClockPolicyVersion: PhoneCaptureIdentity.domainClockContract.value,
    ),
  );
  expect(result, isA<KickOffAuthorityCommitted>());
  return captured;
}

Future<DurableCommitResult> _commitGoal(
  _Opened opened,
  GoalScoringSide side,
) async {
  final captured = await opened.evidence.captureAnchor();
  return opened.composition.boundary.commitGoal(
    await _context(opened),
    scoringSide: side,
    temporalContext: TemporalContext(
      evidenceIds: [captured.evidenceId],
      domainClockPolicyVersion: PhoneCaptureIdentity.domainClockContract.value,
    ),
  );
}

Future<_EndedPeriods> _bothPeriodsEnded(_Opened opened) async {
  await _kickOff(opened);
  final records = await _records(opened.composition);
  final periodOneId = records[1].recordId;
  final periodOne = await _endPeriod(
    opened,
    period: const PeriodIdentity(index: 1),
    periodStartedRecordId: periodOneId,
  );
  final periodOneEndId = (periodOne as DurableCommitSuccess).committedRecordId;
  final started = await _startPeriod2(opened, periodOneEndId);
  final periodTwoId = (started as DurableCommitSuccess).committedRecordId;
  final periodTwo = await _endPeriod(
    opened,
    period: const PeriodIdentity(index: 2),
    periodStartedRecordId: periodTwoId,
  );
  return _EndedPeriods(
    finalPeriodEndId: (periodTwo as DurableCommitSuccess).committedRecordId,
  );
}

Future<DurableCommitResult> _endPeriod(
  _Opened opened, {
  required PeriodIdentity period,
  required String periodStartedRecordId,
}) async {
  final captured = await opened.evidence.captureAnchor();
  return opened.composition.boundary.commitPeriodEnded(
    await _context(opened),
    period: period,
    periodStartedRecordId: periodStartedRecordId,
    temporalContext: TemporalContext(
      evidenceIds: [captured.evidenceId],
      domainClockPolicyVersion: PhoneCaptureIdentity.domainClockContract.value,
    ),
  );
}

Future<DurableCommitResult> _startPeriod2(
  _Opened opened,
  String periodEndedRecordId,
) async {
  final captured = await opened.evidence.captureAnchor();
  return opened.composition.boundary.commitNextPeriodStarted(
    await _context(opened),
    period: const PeriodIdentity(index: 2),
    periodEndedRecordId: periodEndedRecordId,
    temporalContext: TemporalContext(
      evidenceIds: [captured.evidenceId],
      domainClockPolicyVersion: PhoneCaptureIdentity.domainClockContract.value,
    ),
  );
}

Future<DurableCommitResult> _endMatch(
  _Opened opened, {
  required String periodEndedRecordId,
}) async {
  return opened.composition.boundary.commitMatchEnded(
    await _context(opened),
    periodEndedRecordId: periodEndedRecordId,
  );
}

Future<List<MatchRecord>> _records(MatchApplicationComposition composition) {
  return composition.boundary.durableStore.readCommittedForMatch('match-1');
}

bool _isGoal(MatchRecord record) => record.payload is GoalPayload;

final class _EndedPeriods {
  const _EndedPeriods({required this.finalPeriodEndId});

  final String finalPeriodEndId;
}

final class ManualContinuityClock implements MonotonicContinuityClock {
  @override
  String get continuityDomainId => 'domain-live';

  Duration elapsed = Duration.zero;
  DateTime now = DateTime.utc(2026, 10, 5, 12);

  @override
  Duration get monotonicElapsed => elapsed;

  @override
  DateTime get chronology => now;
}
