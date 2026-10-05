import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
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
    temp = await Directory.systemTemp.createTemp('match_ended_');
  });

  tearDown(() async {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('eligible NONE_REQUIRED commits one MATCH_ENDED on the final period', () async {
    final opened = await _open(temp);
    final ended = await _bothPeriodsEnded(opened);
    await _saveRules(opened, _noneRequired);
    final before = await _records(opened.composition);
    final committed = await _endMatch(
      opened,
      periodEndedRecordId: ended.finalPeriodEndId,
    );

    expect(committed, isA<DurableCommitSuccess>());
    final records = await _records(opened.composition);
    final matchEnded = records.where(_isMatchEnded).toList();
    expect(matchEnded, hasLength(1));
    expect(records, hasLength(before.length + 1));
    final record = matchEnded.single;
    final payload = record.payload as TemporalTransitionPayload;
    expect(record.recordKind, RecordKind.temporalFact);
    expect(record.schemaVersion, 1);
    expect(payload.semanticType, V1SemanticTypeCode.matchEnded);
    expect(payload.period, isNull);
    expect(payload.competitionRulesContext, _noneRequired);
    expect(record.authorityContext?.scope, v1AuthorityScope);
    expect(
      record.authorityContext?.principal?.principalId,
      opened.capture.identity.authorityPrincipalId,
    );
    expect(record.authorityContext?.generation?.value, 1);
    expect(
      record.relationships.whereType<CausalDependency>().single.targetRecordId,
      ended.finalPeriodEndId,
    );
    expect(record.originSequence, before.map((item) => item.originSequence).reduce((a, b) => a > b ? a : b) + 1);

    final temporal = await _temporal(opened.composition);
    expect(temporal.matchNormallyEnded, isTrue);
    expect(temporal.activePeriod, isNull);
    expect(temporal.formallySuspended, isFalse);
    expect(temporal.intervalActive, isFalse);
  });

  test('no completed playing phase blocks MATCH_ENDED', () async {
    final opened = await _open(temp);
    expect(
      await opened.composition.boundary.captureAndCommit(
        AuthoritativeCaptureCommand(
          context: await _context(opened),
          recordKind: RecordKind.temporalFact,
          payload: TemporalTransitionPayload(
            semanticType: V1SemanticTypeCode.matchStarted,
          ),
          integrity: const IntegrityMetadata(),
        ),
      ),
      isA<DurableCommitSuccess>(),
    );
    final before = await _records(opened.composition);
    await _saveRules(opened, _noneRequired);
    final blocked = await _endMatch(
      opened,
      periodEndedRecordId: before.single.recordId,
    );
    expect(blocked, isA<DurableCommitFailure>());
    expect(
      (blocked as DurableCommitFailure).reason,
      contains('blockedNoCompletedPlayingPhase'),
    );
    expect(await _records(opened.composition), hasLength(before.length));
  });

  test('active period blocks MATCH_ENDED and writes nothing', () async {
    final opened = await _open(temp);
    await _kickOff(opened);
    final before = await _records(opened.composition);
    await _saveRules(opened, _noneRequired);
    final blocked = await _endMatch(
      opened,
      periodEndedRecordId: before.last.recordId,
    );
    expect(blocked, isA<DurableCommitFailure>());
    expect((blocked as DurableCommitFailure).reason, contains('blockedActivePeriod'));
    expect(await _records(opened.composition), hasLength(before.length));
  });

  test('open suspension blocks MATCH_ENDED and writes nothing', () async {
    final opened = await _open(temp);
    final kickOff = await _kickOff(opened);
    await _suspend(opened, kickOff.periodStartedRecordId);
    final before = await _records(opened.composition);
    await _saveRules(opened, _noneRequired);
    final blocked = await _endMatch(
      opened,
      periodEndedRecordId: kickOff.periodStartedRecordId,
    );
    expect(blocked, isA<DurableCommitFailure>());
    expect((blocked as DurableCommitFailure).reason, contains('blockedOpenSuspension'));
    expect(await _records(opened.composition), hasLength(before.length));
  });

  test('additional playing phase required blocks MATCH_ENDED', () async {
    final opened = await _open(temp);
    final ended = await _bothPeriodsEnded(opened);
    final before = await _records(opened.composition);
    await _saveRules(
      opened,
      const CompetitionRulesContext(
        rulesetId: 'ifab',
        additionalPlayingPhase:
            AdditionalPlayingPhaseDisposition.additionalPlayingPhaseRequired,
      ),
    );
    final blocked = await _endMatch(
      opened,
      periodEndedRecordId: ended.finalPeriodEndId,
    );
    expect(blocked, isA<DurableCommitFailure>());
    expect(
      (blocked as DurableCommitFailure).reason,
      contains('blockedAdditionalPlayingPhase'),
    );
    expect(await _records(opened.composition), hasLength(before.length));
  });

  test('unresolved disposition blocks even when both ordinary periods ended', () async {
    final opened = await _open(temp);
    final ended = await _bothPeriodsEnded(opened);
    final before = await _records(opened.composition);
    final blocked = await _endMatch(
      opened,
      periodEndedRecordId: ended.finalPeriodEndId,
    );
    expect(blocked, isA<DurableCommitFailure>());
    expect(
      (blocked as DurableCommitFailure).reason,
      contains('blockedPhaseDispositionUnresolved'),
    );
    expect(await _records(opened.composition), hasLength(before.length));
    expect((await _temporal(opened.composition)).matchNormallyEnded, isFalse);
    expect((await _temporal(opened.composition)).bothOrdinaryPeriodsEnded, isTrue);
  });

  test('MATCH_ABANDONED blocks MATCH_ENDED', () async {
    final opened = await _open(temp);
    final ended = await _bothPeriodsEnded(opened);
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
    await _saveRules(opened, _noneRequired);
    final blocked = await _endMatch(
      opened,
      periodEndedRecordId: ended.finalPeriodEndId,
    );
    expect(blocked, isA<DurableCommitFailure>());
    expect((blocked as DurableCommitFailure).reason, contains('blockedAbandoned'));
    expect(await _records(opened.composition), hasLength(before.length));
  });

  test('an existing MATCH_ENDED blocks a duplicate', () async {
    final opened = await _open(temp);
    final ended = await _bothPeriodsEnded(opened);
    await _saveRules(opened, _noneRequired);
    expect(
      await _endMatch(
        opened,
        periodEndedRecordId: ended.finalPeriodEndId,
      ),
      isA<DurableCommitSuccess>(),
    );
    final before = await _records(opened.composition);
    final duplicate = await _endMatch(
      opened,
      periodEndedRecordId: ended.finalPeriodEndId,
    );
    expect(duplicate, isA<DurableCommitFailure>());
    expect((duplicate as DurableCommitFailure).reason, contains('blockedAlreadyEnded'));
    final records = await _records(opened.composition);
    expect(records, hasLength(before.length));
    expect(records.where(_isMatchEnded), hasLength(1));
  });

  test('the wrong PERIOD_ENDED target blocks MATCH_ENDED', () async {
    final opened = await _open(temp);
    final ended = await _bothPeriodsEnded(opened);
    final before = await _records(opened.composition);
    await _saveRules(opened, _noneRequired);
    final blocked = await _endMatch(
      opened,
      periodEndedRecordId: ended.periodOneEndId,
    );
    expect(blocked, isA<DurableCommitFailure>());
    expect(
      (blocked as DurableCommitFailure).reason,
      contains('does not match the final PERIOD_ENDED'),
    );
    expect(await _records(opened.composition), hasLength(before.length));
  });

  test('ambiguous lineage blocks MATCH_ENDED', () async {
    final opened = await _open(temp);
    final ended = await _bothPeriodsEnded(opened);
    final matchStartId = (await _records(opened.composition)).first.recordId;
    expect(
      await opened.composition.boundary.captureAndCommit(
        AuthoritativeCaptureCommand(
          context: await _context(opened),
          recordKind: RecordKind.temporalFact,
          payload: TemporalTransitionPayload(
            semanticType: V1SemanticTypeCode.periodStarted,
            period: const PeriodIdentity(index: 3),
          ),
          integrity: const IntegrityMetadata(),
          relationships: [CausalDependency(targetRecordId: matchStartId)],
        ),
      ),
      isA<DurableCommitSuccess>(),
    );
    final before = await _records(opened.composition);
    await _saveRules(opened, _noneRequired);
    final blocked = await _endMatch(
      opened,
      periodEndedRecordId: ended.finalPeriodEndId,
    );
    expect(blocked, isA<DurableCommitFailure>());
    expect(
      (blocked as DurableCommitFailure).reason,
      contains('blockedAmbiguousLineage'),
    );
    expect(await _records(opened.composition), hasLength(before.length));
  });

  test('a failed MATCH_ENDED consumes no origin sequence', () async {
    final opened = await _open(temp);
    final ended = await _bothPeriodsEnded(opened);
    final before = await _records(opened.composition);
    final maxBefore = before
        .map((record) => record.originSequence)
        .reduce((a, b) => a > b ? a : b);
    await _saveRules(opened, MatchCompetitionRulesStore.unresolvedDefault);
    final blocked = await _endMatch(
      opened,
      periodEndedRecordId: ended.finalPeriodEndId,
    );
    expect(blocked, isA<DurableCommitFailure>());
    final afterFailure = await _records(opened.composition);
    expect(
      afterFailure.map((record) => record.originSequence).reduce((a, b) => a > b ? a : b),
      maxBefore,
    );
    await _saveRules(opened, _noneRequired);
    final committed = await _endMatch(
      opened,
      periodEndedRecordId: ended.finalPeriodEndId,
    );
    expect(committed, isA<DurableCommitSuccess>());
    final matchEnded = (await _records(opened.composition)).where(_isMatchEnded).single;
    expect(matchEnded.originSequence, maxBefore + 1);
  });

  test('MATCH_ENDED survives close and reopen', () async {
    final opened = await _open(temp);
    final ended = await _bothPeriodsEnded(opened);
    await _saveRules(opened, _noneRequired);
    expect(
      await _endMatch(
        opened,
        periodEndedRecordId: ended.finalPeriodEndId,
      ),
      isA<DurableCommitSuccess>(),
    );
    await opened.composition.close();
    opened.closed = true;

    final reopened = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(reopened.close);
    final temporal = await _temporal(reopened);
    expect(temporal.matchNormallyEnded, isTrue);
    expect(temporal.activePeriod, isNull);
    expect(temporal.intervalActive, isFalse);
    expect(temporal.formallySuspended, isFalse);
    expect((await _records(reopened)).where(_isMatchEnded), hasLength(1));
  });

  test('shoot-out after match end does not block MATCH_ENDED', () async {
    final opened = await _open(temp);
    final ended = await _bothPeriodsEnded(opened);
    const rules = CompetitionRulesContext(
      rulesetId: 'cup',
      additionalPlayingPhase: AdditionalPlayingPhaseDisposition.noneRequired,
      penaltyShootOutAfterMatchEnd: true,
    );
    await _saveRules(opened, rules);
    final committed = await _endMatch(
      opened,
      periodEndedRecordId: ended.finalPeriodEndId,
    );
    expect(committed, isA<DurableCommitSuccess>());
    final records = await _records(opened.composition);
    final matchEnded = records.where(_isMatchEnded).single;
    final payload = matchEnded.payload as TemporalTransitionPayload;
    expect(payload.competitionRulesContext, rules);
    expect(records.where(_isMatchEnded), hasLength(1));
    expect(
      records.where((record) {
        final item = record.payload;
        return item is TemporalTransitionPayload &&
            item.semanticType != V1SemanticTypeCode.matchStarted &&
            item.semanticType != V1SemanticTypeCode.periodStarted &&
            item.semanticType != V1SemanticTypeCode.periodEnded &&
            item.semanticType != V1SemanticTypeCode.matchEnded;
      }),
      isEmpty,
    );
    final temporal = await _temporal(opened.composition);
    expect(temporal.matchNormallyEnded, isTrue);
  });

  test('command path derives no fixture finality and writes no legacy terminal', () {
    final boundary = File(
      'lib/match_application/match_application_boundary.dart',
    ).readAsStringSync();
    final command = RegExp(
      r'Future<DurableCommitResult> commitMatchEnded[\s\S]*?\n  \}\r?\n',
    ).firstMatch(boundary)!.group(0)!;
    final page = File(
      'lib/features/live_match/live_match_page.dart',
    ).readAsStringSync();
    final legacy = File('lib/match/match_session.dart').readAsStringSync();
    final projection = File(
      '../../packages/forref_match_core/lib/projection/temporal_match_projection.dart',
    ).readAsStringSync();

    expect(command, contains('assessNormalMatchEnd'));
    expect(command, contains('finalCompletedPeriodEnd'));
    expect(command, isNot(contains('fullTime')));
    expect(command, isNot(contains('finish')));
    expect(command, isNot(contains('halfTime')));
    expect(command, isNot(contains('elapsedSeconds')));
    expect(command, isNot(contains('score')));
    expect(command, isNot(contains('bothOrdinaryPeriodsEnded')));
    expect(command, isNot(contains('required CompetitionRulesContext rules')));
    expect(command, contains('context.competitionRulesContext'));
    expect(command, isNot(contains('MatchLifecycle')));
    expect(page, contains('commitMatchEnded'));
    expect(page, isNot(contains('captureAndCommit')));
    expect(legacy, isNot(contains('MATCH_ENDED')));
    expect(legacy, isNot(contains('commitMatchEnded')));
    expect(projection, isNot(contains('fixtureValidated')));
    expect(projection, isNot(contains('resultFinal')));
    expect(projection, isNot(contains('organizerApproved')));
    expect(projection, isNot(contains('shootoutCompleted')));
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

Future<_Opened> _open(Directory temp) async {
  final evidence = PhoneTemporalEvidenceStore(
    storageRoot: temp,
    clock: ManualContinuityClock(),
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

Future<KickOffAuthorityCommitted> _kickOff(_Opened opened) async {
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
  return result as KickOffAuthorityCommitted;
}

Future<_EndedPeriods> _bothPeriodsEnded(_Opened opened) async {
  final kickOff = await _kickOff(opened);
  final periodOne = await _endPeriod(
    opened,
    period: const PeriodIdentity(index: 1),
    periodStartedRecordId: kickOff.periodStartedRecordId,
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
    periodOneEndId: periodOneEndId,
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

Future<DurableCommitResult> _suspend(
  _Opened opened,
  String periodStartedRecordId,
) async {
  final captured = await opened.evidence.captureAnchor();
  return opened.composition.boundary.commitTemporarySuspensionStarted(
    await _context(opened),
    period: const PeriodIdentity(index: 1),
    periodStartedRecordId: periodStartedRecordId,
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

Future<TemporalMatchProjection> _temporal(
  MatchApplicationComposition composition,
) async {
  final records = await _records(composition);
  final projection = await composition.boundary.project(
    'match-1',
    evaluatedAuthorityGeneration: PhoneCaptureIdentity.initialAuthorityGeneration,
  );
  return TemporalMatchProjection.derive(
    projection: projection,
    records: records,
  );
}

bool _isMatchEnded(MatchRecord record) {
  final payload = record.payload;
  return payload is TemporalTransitionPayload &&
      payload.semanticType == V1SemanticTypeCode.matchEnded;
}

final class _EndedPeriods {
  const _EndedPeriods({
    required this.periodOneEndId,
    required this.finalPeriodEndId,
  });

  final String periodOneEndId;
  final String finalPeriodEndId;
}

final class ManualContinuityClock implements MonotonicContinuityClock {
  @override
  String get continuityDomainId => 'domain-live';

  @override
  Duration get monotonicElapsed => Duration.zero;

  @override
  DateTime get chronology => DateTime.utc(2026, 10, 4, 12);
}
