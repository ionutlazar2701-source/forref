import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:referee_phone/infrastructure/competition_rules/phone_competition_format_choice.dart';
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
    temp = await Directory.systemTemp.createTemp('match_competition_rules_');
  });

  tearDown(() async {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('new match gets explicit unresolved competition rules', () async {
    final store = MatchCompetitionRulesStore(temp);
    await store.ensureForMatch('match-1');
    final rules = await store.loadForMatch('match-1');
    expect(rules.additionalPlayingPhase, AdditionalPlayingPhaseDisposition.unresolved);
    expect(rules.penaltyShootOutAfterMatchEnd, isFalse);
    expect(rules.rulesetId, 'ifab');
    expect(rules.disciplinarySystem, DisciplinarySystem.unresolved);
  });

  test('default rules are not NONE_REQUIRED', () async {
    final store = MatchCompetitionRulesStore(temp);
    await store.ensureForMatch('match-1');
    final rules = await store.loadForMatch('match-1');
    expect(rules.additionalPlayingPhase, isNot(AdditionalPlayingPhaseDisposition.noneRequired));
  });

  test('unresolved rules survive close and reopen', () async {
    final store = MatchCompetitionRulesStore(temp);
    await store.ensureForMatch('match-1');
    final reopened = MatchCompetitionRulesStore(temp);
    final rules = await reopened.loadForMatch('match-1');
    expect(rules.additionalPlayingPhase, AdditionalPlayingPhaseDisposition.unresolved);
  });

  test('explicit no-additional-playing-period rules survive close and reopen', () async {
    const rules = CompetitionRulesContext(
      rulesetId: 'ifab',
      additionalPlayingPhase: AdditionalPlayingPhaseDisposition.noneRequired,
    );
    final store = MatchCompetitionRulesStore(temp);
    await store.saveForMatch('match-1', rules);
    final reopened = MatchCompetitionRulesStore(temp);
    expect(await reopened.loadForMatch('match-1'), rules);
  });

  test('terminal eligibility reads the match-associated rules context', () async {
    final opened = await _open(temp);
    await _bothPeriodsEnded(opened);
    final eligibility = await assessStoredNormalMatchEndEligibility(
      capture: opened.capture,
      matchId: 'match-1',
      records: await _records(opened.composition),
    );
    expect(eligibility, NormalMatchEndEligibility.blockedPhaseDispositionUnresolved);

    await opened.rulesStore.saveForMatch('match-1', _noneRequired);
    final eligible = await assessStoredNormalMatchEndEligibility(
      capture: opened.capture,
      matchId: 'match-1',
      records: await _records(opened.composition),
    );
    expect(eligible, NormalMatchEndEligibility.eligible);
  });

  test('commitMatchEnded reads rules from capture context not ad hoc parameters', () {
    final boundary = File(
      'lib/match_application/match_application_boundary.dart',
    ).readAsStringSync();
    final live = File(
      'lib/features/live_match/live_match_page.dart',
    ).readAsStringSync();
    expect(boundary, isNot(contains('required CompetitionRulesContext rules')));
    expect(boundary, contains('context.competitionRulesContext'));
    expect(live, isNot(contains('NONE_REQUIRED')));
    expect(live, isNot(contains('noneRequired')));
    expect(live, contains('commitMatchEnded'));
    expect(live, isNot(contains('captureAndCommit')));
  });

  test('penalty shoot-out after match end stays independent from playing phase', () async {
    const rules = CompetitionRulesContext(
      rulesetId: 'cup',
      additionalPlayingPhase: AdditionalPlayingPhaseDisposition.unresolved,
      penaltyShootOutAfterMatchEnd: true,
    );
    final store = MatchCompetitionRulesStore(temp);
    await store.saveForMatch('match-1', rules);
    final loaded = await store.loadForMatch('match-1');
    expect(loaded.additionalPlayingPhase, AdditionalPlayingPhaseDisposition.unresolved);
    expect(loaded.penaltyShootOutAfterMatchEnd, isTrue);
  });

  test('kick-off records carry the same competition rules as the match context', () async {
    final opened = await _open(temp);
    await opened.rulesStore.saveForMatch('match-1', _noneRequired);
    final kickOff = await _kickOff(opened);
    expect(kickOff, isA<KickOffAuthorityCommitted>());
    final records = await _records(opened.composition);
    final matchStarted = records.firstWhere(
      (record) =>
          (record.payload as TemporalTransitionPayload).semanticType ==
          V1SemanticTypeCode.matchStarted,
    );
    final periodStarted = records.firstWhere(
      (record) =>
          (record.payload as TemporalTransitionPayload).semanticType ==
          V1SemanticTypeCode.periodStarted,
    );
    expect(
      (matchStarted.payload as TemporalTransitionPayload).competitionRulesContext,
      _noneRequired,
    );
    expect(
      (periodStarted.payload as TemporalTransitionPayload).competitionRulesContext,
      _noneRequired,
    );
  });

  test('standard competition format does not establish ORDINARY_IFAB', () {
    final rules = PhoneCompetitionFormatChoice.noAdditionalPlayingPeriods
        .toRulesContext(penaltyShootOutAfterMatchEnd: false);
    expect(rules.additionalPlayingPhase,
        AdditionalPlayingPhaseDisposition.noneRequired);
    expect(rules.disciplinarySystem, DisciplinarySystem.unresolved);
  });

  test('extra time may apply does not establish ORDINARY_IFAB', () {
    final rules = PhoneCompetitionFormatChoice.additionalPlayingPhaseMayApply
        .toRulesContext(penaltyShootOutAfterMatchEnd: false);
    expect(rules.additionalPlayingPhase,
        AdditionalPlayingPhaseDisposition.unresolved);
    expect(rules.disciplinarySystem, DisciplinarySystem.unresolved);
  });

  test('shoot-out selection does not establish ORDINARY_IFAB', () {
    final rules = PhoneCompetitionFormatChoice.noAdditionalPlayingPeriods
        .toRulesContext(penaltyShootOutAfterMatchEnd: true);
    expect(rules.penaltyShootOutAfterMatchEnd, isTrue);
    expect(rules.disciplinarySystem, DisciplinarySystem.unresolved);
  });

  test('setup persist without disciplinary selection remains UNRESOLVED', () async {
    final store = MatchCompetitionRulesStore(temp);
    await store.saveForMatch(
      'match-1',
      PhoneCompetitionFormatChoice.noAdditionalPlayingPeriods.toRulesContext(
        penaltyShootOutAfterMatchEnd: true,
      ),
    );
    expect(
      (await store.loadForMatch('match-1')).disciplinarySystem,
      DisciplinarySystem.unresolved,
    );
  });

  test('explicit ORDINARY_IFAB remains supported and persists', () async {
    const rules = CompetitionRulesContext(
      rulesetId: 'ifab',
      disciplinarySystem: DisciplinarySystem.ordinaryIfab,
    );
    expect(
      YellowCardDisciplinarySystemSupportGate.assess(rules),
      YellowCardDisciplinarySystemSupport.supported,
    );
    final store = MatchCompetitionRulesStore(temp);
    await store.saveForMatch('match-1', rules);
    expect(await store.loadForMatch('match-1'), rules);
  });

  test('explicit TEMPORARY_DISMISSAL remains unsupported for Yellow Card V1', () {
    expect(
      YellowCardDisciplinarySystemSupportGate.assess(
        const CompetitionRulesContext(
          rulesetId: 'youth',
          disciplinarySystem: DisciplinarySystem.temporaryDismissal,
        ),
      ),
      YellowCardDisciplinarySystemSupport.unsupportedModifiedSystem,
    );
  });

  test('CaptureContext carries persisted disciplinary system', () async {
    const rules = CompetitionRulesContext(
      rulesetId: 'ifab',
      disciplinarySystem: DisciplinarySystem.ordinaryIfab,
    );
    final opened = await _open(temp);
    await opened.rulesStore.saveForMatch('match-1', rules);
    final context = await opened.capture.captureContextFor('match-1');
    expect(context.competitionRulesContext?.disciplinarySystem,
        DisciplinarySystem.ordinaryIfab);
  });

  test('reopen preserves disciplinary system in match rules store', () async {
    const rules = CompetitionRulesContext(
      rulesetId: 'ifab',
      disciplinarySystem: DisciplinarySystem.temporaryDismissal,
    );
    final store = MatchCompetitionRulesStore(temp);
    await store.saveForMatch('match-1', rules);
    final reopened = MatchCompetitionRulesStore(temp);
    expect(await reopened.loadForMatch('match-1'), rules);
  });

  test('legacy Match status is not the competition rules authority', () {
    final session = File('lib/match/match_session.dart').readAsStringSync();
    final store = File(
      'lib/infrastructure/competition_rules/match_competition_rules_store.dart',
    ).readAsStringSync();
    expect(session, isNot(contains('CompetitionRulesContext')));
    expect(session, isNot(contains('additionalPlayingPhase')));
    expect(store, isNot(contains('MatchStatus')));
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
