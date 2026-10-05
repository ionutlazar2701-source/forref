import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:referee_phone/infrastructure/competition_rules/match_competition_rules_store.dart';
import 'package:referee_phone/infrastructure/competition_rules/phone_match_capture_context.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/infrastructure/temporal/phone_temporal_evidence_store.dart';
import 'package:referee_phone/match_application/kick_off_authority.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('end_match_ui_');
  });

  tearDown(() async {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('NONE_REQUIRED with valid lineage makes terminal eligibility eligible', () async {
    final opened = await _open(temp);
    await _bothPeriodsEnded(opened);
    await opened.rulesStore.saveForMatch('match-1', _noneRequired);
    expect(
      await assessStoredNormalMatchEndEligibility(
        capture: opened.capture,
        matchId: 'match-1',
        records: await _records(opened.composition),
      ),
      NormalMatchEndEligibility.eligible,
    );
  });

  test('unresolved rules after both periods ended block terminal eligibility', () async {
    final opened = await _open(temp);
    await _bothPeriodsEnded(opened);
    expect(
      await assessStoredNormalMatchEndEligibility(
        capture: opened.capture,
        matchId: 'match-1',
        records: await _records(opened.composition),
      ),
      NormalMatchEndEligibility.blockedPhaseDispositionUnresolved,
    );
  });

  test('additional playing phase required blocks terminal eligibility', () async {
    final opened = await _open(temp);
    await _bothPeriodsEnded(opened);
    await opened.rulesStore.saveForMatch(
      'match-1',
      const CompetitionRulesContext(
        rulesetId: 'ifab',
        additionalPlayingPhase:
            AdditionalPlayingPhaseDisposition.additionalPlayingPhaseRequired,
      ),
    );
    expect(
      await assessStoredNormalMatchEndEligibility(
        capture: opened.capture,
        matchId: 'match-1',
        records: await _records(opened.composition),
      ),
      NormalMatchEndEligibility.blockedAdditionalPlayingPhase,
    );
  });

  test('active period blocks terminal eligibility', () async {
    final opened = await _open(temp);
    await _kickOff(opened);
    await opened.rulesStore.saveForMatch('match-1', _noneRequired);
    expect(
      await assessStoredNormalMatchEndEligibility(
        capture: opened.capture,
        matchId: 'match-1',
        records: await _records(opened.composition),
      ),
      NormalMatchEndEligibility.blockedActivePeriod,
    );
  });

  test('open suspension blocks terminal eligibility', () async {
    final opened = await _open(temp);
    final kickOff = await _kickOff(opened);
    await opened.rulesStore.saveForMatch('match-1', _noneRequired);
    await _suspend(opened, kickOff.periodStartedRecordId);
    expect(
      await assessStoredNormalMatchEndEligibility(
        capture: opened.capture,
        matchId: 'match-1',
        records: await _records(opened.composition),
      ),
      NormalMatchEndEligibility.blockedOpenSuspension,
    );
  });

  test('shoot-out after match does not block eligibility when NONE_REQUIRED', () async {
    final opened = await _open(temp);
    await _bothPeriodsEnded(opened);
    await opened.rulesStore.saveForMatch(
      'match-1',
      const CompetitionRulesContext(
        rulesetId: 'cup',
        additionalPlayingPhase: AdditionalPlayingPhaseDisposition.noneRequired,
        penaltyShootOutAfterMatchEnd: true,
      ),
    );
    expect(
      await assessStoredNormalMatchEndEligibility(
        capture: opened.capture,
        matchId: 'match-1',
        records: await _records(opened.composition),
      ),
      NormalMatchEndEligibility.eligible,
    );
  });

  test('committed MATCH_ENDED reconstructs normally ended after reopen', () async {
    final opened = await _open(temp);
    await _bothPeriodsEnded(opened);
    await opened.rulesStore.saveForMatch('match-1', _noneRequired);
    final finalEnd = finalCompletedPeriodEnd(
      records: await _records(opened.composition),
    );
    expect(
      await opened.composition.boundary.commitMatchEnded(
        await opened.capture.captureContextFor('match-1'),
        periodEndedRecordId: finalEnd!.recordId,
      ),
      isA<DurableCommitSuccess>(),
    );
    await opened.composition.close();
    final reopened = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(reopened.close);
    final records = await reopened.boundary.durableStore.readCommittedForMatch(
      'match-1',
    );
    final projection = await reopened.boundary.project(
      'match-1',
      evaluatedAuthorityGeneration: PhoneCaptureIdentity.initialAuthorityGeneration,
    );
    final temporal = TemporalMatchProjection.derive(
      projection: projection,
      records: records,
    );
    expect(temporal.matchNormallyEnded, isTrue);
    expect(
      await assessStoredNormalMatchEndEligibility(
        capture: opened.capture,
        matchId: 'match-1',
        records: records,
      ),
      NormalMatchEndEligibility.blockedAlreadyEnded,
    );
  });

  test('live match UI uses commitMatchEnded and not generic capture', () {
    final page = File(
      'lib/features/live_match/live_match_page.dart',
    ).readAsStringSync();
    final endMatch = RegExp(
      r'Future<void> _endMatch[\s\S]*?\n  \}\r?\n',
    ).firstMatch(page)!.group(0)!;
    expect(endMatch, contains('commitMatchEnded'));
    expect(endMatch, isNot(contains('captureAndCommit')));
    expect(endMatch, isNot(contains('TemporalTransitionPayload')));
    expect(endMatch, isNot(contains('fullTime')));
    expect(endMatch, isNot(contains('finish')));
    expect(endMatch, isNot(contains('MatchLifecycle')));
    expect(page, contains('assessStoredNormalMatchEndEligibility'));
    expect(page, isNot(contains('fixtureValidated')));
    expect(page, isNot(contains('resultFinal')));
    expect(page, isNot(contains('organizerApproved')));
    expect(page, isNot(contains('shootoutCompleted')));
    expect(page, isNot(contains('statusCompleted')));
  });
}

const _noneRequired = CompetitionRulesContext(
  rulesetId: 'ifab',
  additionalPlayingPhase: AdditionalPlayingPhaseDisposition.noneRequired,
);

final class _Opened {
  const _Opened({
    required this.composition,
    required this.capture,
    required this.rulesStore,
    required this.evidence,
  });

  final MatchApplicationComposition composition;
  final PhoneMatchCaptureContext capture;
  final MatchCompetitionRulesStore rulesStore;
  final PhoneTemporalEvidenceStore evidence;
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
  addTearDown(composition.close);
  return _Opened(
    composition: composition,
    capture: PhoneMatchCaptureContext(identity: identity, rulesStore: rulesStore),
    rulesStore: rulesStore,
    evidence: evidence,
  );
}

Future<KickOffAuthorityCommitted> _kickOff(_Opened opened) async {
  final captured = await opened.evidence.captureAnchor();
  final result = await opened.composition.boundary.commitKickOff(
    await opened.capture.captureContextFor('match-1'),
    period: const PeriodIdentity(index: 1),
    periodAnchor: () async => TemporalContext(
      evidenceIds: [captured.evidenceId],
      domainClockPolicyVersion: PhoneCaptureIdentity.domainClockContract.value,
    ),
  );
  expect(result, isA<KickOffAuthorityCommitted>());
  return result as KickOffAuthorityCommitted;
}

Future<void> _bothPeriodsEnded(_Opened opened) async {
  final kickOff = await _kickOff(opened);
  await _endPeriod(
    opened,
    period: const PeriodIdentity(index: 1),
    periodStartedRecordId: kickOff.periodStartedRecordId,
  );
  final periodOneEnd = (await _records(opened.composition))
      .where(
        (record) =>
            (record.payload as TemporalTransitionPayload).semanticType ==
            V1SemanticTypeCode.periodEnded,
      )
      .single
      .recordId;
  final started = await opened.composition.boundary.commitNextPeriodStarted(
    await opened.capture.captureContextFor('match-1'),
    period: const PeriodIdentity(index: 2),
    periodEndedRecordId: periodOneEnd,
    temporalContext: TemporalContext(
      evidenceIds: [(await opened.evidence.captureAnchor()).evidenceId],
      domainClockPolicyVersion: PhoneCaptureIdentity.domainClockContract.value,
    ),
  );
  await _endPeriod(
    opened,
    period: const PeriodIdentity(index: 2),
    periodStartedRecordId: (started as DurableCommitSuccess).committedRecordId,
  );
}

Future<DurableCommitResult> _endPeriod(
  _Opened opened, {
  required PeriodIdentity period,
  required String periodStartedRecordId,
}) async {
  final captured = await opened.evidence.captureAnchor();
  return opened.composition.boundary.commitPeriodEnded(
    await opened.capture.captureContextFor('match-1'),
    period: period,
    periodStartedRecordId: periodStartedRecordId,
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
    await opened.capture.captureContextFor('match-1'),
    period: const PeriodIdentity(index: 1),
    periodStartedRecordId: periodStartedRecordId,
    temporalContext: TemporalContext(
      evidenceIds: [captured.evidenceId],
      domainClockPolicyVersion: PhoneCaptureIdentity.domainClockContract.value,
    ),
  );
}

Future<List<MatchRecord>> _records(MatchApplicationComposition composition) {
  return composition.boundary.durableStore.readCommittedForMatch('match-1');
}

final class ManualContinuityClock implements MonotonicContinuityClock {
  @override
  String get continuityDomainId => 'domain-live';

  @override
  Duration get monotonicElapsed => Duration.zero;

  @override
  DateTime get chronology => DateTime.utc(2026, 10, 4, 12);
}
