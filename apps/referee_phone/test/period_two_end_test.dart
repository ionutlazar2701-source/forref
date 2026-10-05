import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/infrastructure/temporal/phone_temporal_evidence_store.dart';
import 'package:referee_phone/match_application/authoritative_capture_command.dart';
import 'package:referee_phone/match_application/kick_off_authority.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('period_two_end_');
  });

  tearDown(() async {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('end period 2 writes one PERIOD_ENDED on the period 2 start', () async {
    final clock = ManualContinuityClock();
    final evidence = PhoneTemporalEvidenceStore(storageRoot: temp, clock: clock);
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();

    final kickOff = await _kickOff(composition, identity, evidence);
    clock.elapsed = const Duration(seconds: 18);
    final periodOneEnd = await _end(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 1),
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    final beforePeriodTwo = await _end(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 2),
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    expect(beforePeriodTwo, isA<DurableCommitFailure>());
    expect(
      (beforePeriodTwo as DurableCommitFailure).reason,
      contains('active period'),
    );
    expect((await _records(composition)).where(_isPeriodEnded), hasLength(1));

    final started = await _startPeriod2(
      composition,
      identity,
      evidence,
      periodEndedRecordId:
          (periodOneEnd as DurableCommitSuccess).committedRecordId,
    );
    final periodTwoId = (started as DurableCommitSuccess).committedRecordId;
    final wrongIndex = await _end(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 1),
      periodStartedRecordId: periodTwoId,
    );
    expect(wrongIndex, isA<DurableCommitFailure>());
    expect((wrongIndex as DurableCommitFailure).reason, contains('does not match'));
    final wrongStart = await _end(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 2),
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    expect(wrongStart, isA<DurableCommitFailure>());
    expect((wrongStart as DurableCommitFailure).reason, contains('does not match'));
    final emptyEvidence = await composition.boundary.commitPeriodEnded(
      identity.contextFor('match-1'),
      period: const PeriodIdentity(index: 2),
      periodStartedRecordId: periodTwoId,
      temporalContext: const TemporalContext(),
    );
    expect(emptyEvidence, isA<DurableCommitFailure>());
    expect((await _temporal(composition)).activePeriod, const PeriodIdentity(index: 2));
    expect(await _records(composition), hasLength(4));

    final suspended = await _suspend(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 2),
      periodStartedRecordId: periodTwoId,
    );
    final whileOpen = await _end(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 2),
      periodStartedRecordId: periodTwoId,
    );
    expect(whileOpen, isA<DurableCommitFailure>());
    expect(
      (whileOpen as DurableCommitFailure).reason,
      contains('open formal suspension'),
    );
    await _resume(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 2),
      suspensionStartedRecordId:
          (suspended as DurableCommitSuccess).committedRecordId,
    );

    clock.elapsed = const Duration(seconds: 30);
    final ended = await _end(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 2),
      periodStartedRecordId: periodTwoId,
    );
    expect(ended, isA<DurableCommitSuccess>());
    final records = await _records(composition);
    final periodEnds = records.where(_isPeriodEnded).toList();
    expect(periodEnds, hasLength(2));
    final end = periodEnds.last;
    expect((end.payload as TemporalTransitionPayload).period?.index, 2);
    expect(
      (end.relationships.single as CausalDependency).targetRecordId,
      periodTwoId,
    );
    expect(
      end.temporalContext!.evidenceIds.single,
      isNot(records[3].temporalContext!.evidenceIds.single),
    );
    final temporal = await _temporal(composition);
    expect(temporal.activePeriod, isNull);
    expect(temporal.endedPeriod, const PeriodIdentity(index: 2));
    expect(temporal.endedPeriods, [
      const PeriodIdentity(index: 1),
      const PeriodIdentity(index: 2),
    ]);
    expect(temporal.intervalActive, isFalse);
    expect(temporal.bothOrdinaryPeriodsEnded, isTrue);
    final atEnd = await _elapsed(composition, evidence);
    expect(atEnd.periodEnded, isTrue);
    expect(atEnd.activePeriod, isNull);
    expect(atEnd.exactElapsed, const Duration(seconds: 12));
    expect(atEnd.pastRegulationDisplayThreshold, isFalse);
    clock.elapsed = const Duration(minutes: 50);
    clock.wallChronology = DateTime.utc(2099);
    expect(
      (await _elapsed(composition, evidence)).exactElapsed,
      const Duration(seconds: 12),
    );

    final duplicate = await _end(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 2),
      periodStartedRecordId: periodTwoId,
    );
    expect(duplicate, isA<DurableCommitFailure>());
    expect((duplicate as DurableCommitFailure).reason, contains('already'));
    expect((await _records(composition)).where(_isPeriodEnded), hasLength(2));
    expect(records.where(_isPeriodStarted), hasLength(2));
    expect(
      V1SemanticTypeCode.values.map((code) => code.wireValue),
      isNot(contains('MATCH_FINISHED')),
    );
    expect(
      V1SemanticTypeCode.values.map((code) => code.wireValue),
      isNot(contains('FULL_TIME')),
    );
    expect(
      V1SemanticTypeCode.values.map((code) => code.wireValue),
      isNot(contains('COMPLETED')),
    );
  });

  test('threshold does not end period 2 and an explicit end may be after it', () async {
    final clock = ManualContinuityClock();
    final evidence = PhoneTemporalEvidenceStore(storageRoot: temp, clock: clock);
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final periodTwoId = await _activePeriod2(composition, identity, evidence);

    clock.elapsed = const Duration(minutes: 44, seconds: 30);
    expect((await _elapsed(composition, evidence)).pastRegulationDisplayThreshold, isFalse);
    expect((await _temporal(composition)).activePeriod, const PeriodIdentity(index: 2));
    clock.elapsed = const Duration(minutes: 45);
    final atThreshold = await _elapsed(composition, evidence);
    expect(atThreshold.pastRegulationDisplayThreshold, isTrue);
    expect(atThreshold.periodEnded, isFalse);
    expect((await _records(composition)).where(_isPeriodEnded), hasLength(1));
    clock.elapsed = const Duration(minutes: 47, seconds: 30);
    expect((await _temporal(composition)).activePeriod, const PeriodIdentity(index: 2));
    expect((await _records(composition)).where(_isPeriodEnded), hasLength(1));

    expect(
      await _end(
        composition,
        identity,
        evidence,
        period: const PeriodIdentity(index: 2),
        periodStartedRecordId: periodTwoId,
      ),
      isA<DurableCommitSuccess>(),
    );
    final ended = await _elapsed(composition, evidence);
    expect(ended.exactElapsed, const Duration(minutes: 47, seconds: 30));
    expect(ended.periodEnded, isTrue);
    expect((await _temporal(composition)).bothOrdinaryPeriodsEnded, isTrue);
    expect((await _temporal(composition)).intervalActive, isFalse);
    expect((await _records(composition)).where(_isPeriodEnded), hasLength(2));
  });

  test('explicit period 2 end at 45:00 is the referee boundary', () async {
    final clock = ManualContinuityClock();
    final evidence = PhoneTemporalEvidenceStore(storageRoot: temp, clock: clock);
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final periodTwoId = await _activePeriod2(composition, identity, evidence);
    clock.elapsed = const Duration(minutes: 45);
    expect(
      await _end(
        composition,
        identity,
        evidence,
        period: const PeriodIdentity(index: 2),
        periodStartedRecordId: periodTwoId,
      ),
      isA<DurableCommitSuccess>(),
    );
    final ended = await _elapsed(composition, evidence);
    expect(ended.exactElapsed, const Duration(minutes: 45));
    expect(ended.pastRegulationDisplayThreshold, isTrue);
    expect((await _temporal(composition)).activePeriod, isNull);
    expect((await _temporal(composition)).intervalActive, isFalse);
  });

  test('ambiguous lineage does not end period 2', () async {
    final evidence = PhoneTemporalEvidenceStore(
      storageRoot: temp,
      clock: ManualContinuityClock(),
    );
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final periodTwoId = await _activePeriod2(composition, identity, evidence);
    final matchStartId = (await _records(composition)).first.recordId;
    expect(
      await composition.boundary.captureAndCommit(
        AuthoritativeCaptureCommand(
          context: identity.contextFor('match-1'),
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
    final ambiguous = await _end(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 2),
      periodStartedRecordId: periodTwoId,
    );
    expect(ambiguous, isA<DurableCommitFailure>());
    expect((ambiguous as DurableCommitFailure).reason, contains('ambiguous'));
    expect((await _records(composition)).where(_isPeriodEnded), hasLength(1));
  });

  test('two period 2 suspensions freeze 26s and leave period 1 untouched', () async {
    final clock = ManualContinuityClock(domainId: 'domain-a');
    final evidence = PhoneTemporalEvidenceStore(storageRoot: temp, clock: clock);
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final kickOff = await _kickOff(composition, identity, evidence);
    clock.elapsed = const Duration(seconds: 10);
    final firstPeriodHold = await _suspend(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 1),
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    clock.elapsed = const Duration(seconds: 40);
    await _resume(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 1),
      suspensionStartedRecordId:
          (firstPeriodHold as DurableCommitSuccess).committedRecordId,
    );
    clock.elapsed = const Duration(seconds: 47);
    final periodOneEnd = await _end(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 1),
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    clock.elapsed = const Duration(seconds: 100);
    final started = await _startPeriod2(
      composition,
      identity,
      evidence,
      periodEndedRecordId:
          (periodOneEnd as DurableCommitSuccess).committedRecordId,
    );
    final periodTwoId = (started as DurableCommitSuccess).committedRecordId;
    clock.elapsed = const Duration(seconds: 112);
    final first = await _suspend(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 2),
      periodStartedRecordId: periodTwoId,
    );
    clock.elapsed = const Duration(seconds: 132);
    await _resume(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 2),
      suspensionStartedRecordId: (first as DurableCommitSuccess).committedRecordId,
    );
    clock.elapsed = const Duration(seconds: 140);
    final second = await _suspend(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 2),
      periodStartedRecordId: periodTwoId,
    );
    clock.elapsed = const Duration(seconds: 150);
    await _resume(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 2),
      suspensionStartedRecordId:
          (second as DurableCommitSuccess).committedRecordId,
    );
    clock.elapsed = const Duration(seconds: 156);
    expect(
      await _end(
        composition,
        identity,
        evidence,
        period: const PeriodIdentity(index: 2),
        periodStartedRecordId: periodTwoId,
      ),
      isA<DurableCommitSuccess>(),
    );
    final periodTwo = await _elapsed(composition, evidence);
    final periodOne = await _elapsed(
      composition,
      evidence,
      period: const PeriodIdentity(index: 1),
    );
    expect(periodTwo.exactElapsed, const Duration(seconds: 26));
    expect(periodTwo.suspensionDurations, [
      const Duration(seconds: 20),
      const Duration(seconds: 10),
    ]);
    expect(periodTwo.playingSegments, [
      const Duration(seconds: 12),
      const Duration(seconds: 8),
      const Duration(seconds: 6),
    ]);
    expect(periodOne.exactElapsed, const Duration(seconds: 17));
    expect(periodOne.suspensionDurations, [const Duration(seconds: 30)]);
    clock.elapsed = const Duration(minutes: 8);
    expect(
      (await _elapsed(composition, evidence)).exactElapsed,
      const Duration(seconds: 26),
    );
    expect(
      (await _elapsed(composition, evidence, period: const PeriodIdentity(index: 1)))
          .exactElapsed,
      const Duration(seconds: 17),
    );
    await composition.close();

    final reopened = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(reopened.close);
    final restarted = PhoneTemporalEvidenceStore(
      storageRoot: temp,
      clock: ManualContinuityClock(domainId: 'domain-b')
        ..elapsed = const Duration(hours: 2)
        ..wallChronology = DateTime.utc(2099),
    );
    final temporal = await _temporal(reopened);
    expect(temporal.activePeriod, isNull);
    expect(temporal.intervalActive, isFalse);
    expect(temporal.bothOrdinaryPeriodsEnded, isTrue);
    expect(temporal.endedPeriods, [
      const PeriodIdentity(index: 1),
      const PeriodIdentity(index: 2),
    ]);
    final recoveredTwo = await _elapsed(reopened, restarted);
    final recoveredOne = await _elapsed(
      reopened,
      restarted,
      period: const PeriodIdentity(index: 1),
    );
    expect(recoveredTwo.exactElapsed, const Duration(seconds: 26));
    expect(recoveredOne.exactElapsed, const Duration(seconds: 17));
    expect(recoveredTwo.exactElapsed, isNot(const Duration(hours: 2)));
    expect(recoveredTwo.activePeriod, isNull);
    expect((await _records(reopened)).where(_isPeriodStarted), hasLength(2));
    expect((await _records(reopened)).where(_isPeriodEnded), hasLength(2));
  });

  test('end period action does not write legacy full time', () {
    final page = File(
      'lib/features/live_match/live_match_page.dart',
    ).readAsStringSync();
    final end = RegExp(
      r'Future<void> _endPeriod[\s\S]*?\n  \}',
    ).firstMatch(page)!.group(0)!;
    expect(end, contains('commitPeriodEnded'));
    expect(end, isNot(contains('fullTime')));
    expect(end, isNot(contains('finish')));
    expect(end, isNot(contains('halfTime')));
    expect(end, isNot(contains('MatchLifecycle')));
    expect(end, isNot(contains('elapsedSeconds')));
    final ticker = RegExp(
      r'void _syncClockTicker[\s\S]*?\n  \}',
    ).firstMatch(page)!.group(0)!;
    expect(ticker, contains('_activePeriod != null'));
    expect(page, contains('bothOrdinaryPeriodsEnded'));
  });
}

Future<String> _activePeriod2(
  MatchApplicationComposition composition,
  PhoneCaptureIdentity identity,
  PhoneTemporalEvidenceStore evidence,
) async {
  final kickOff = await _kickOff(composition, identity, evidence);
  final periodOneEnd = await _end(
    composition,
    identity,
    evidence,
    period: const PeriodIdentity(index: 1),
    periodStartedRecordId: kickOff.periodStartedRecordId,
  );
  final started = await _startPeriod2(
    composition,
    identity,
    evidence,
    periodEndedRecordId: (periodOneEnd as DurableCommitSuccess).committedRecordId,
  );
  return (started as DurableCommitSuccess).committedRecordId;
}

Future<KickOffAuthorityCommitted> _kickOff(
  MatchApplicationComposition composition,
  PhoneCaptureIdentity identity,
  PhoneTemporalEvidenceStore evidence,
) async {
  final result = await composition.boundary.commitKickOff(
    identity.contextFor('match-1'),
    period: const PeriodIdentity(index: 1),
    periodAnchor: () async {
      final captured = await evidence.captureAnchor();
      return TemporalContext(
        evidenceIds: [captured.evidenceId],
        domainClockPolicyVersion: PhoneCaptureIdentity.domainClockContract.value,
      );
    },
  );
  expect(result, isA<KickOffAuthorityCommitted>());
  return result as KickOffAuthorityCommitted;
}

Future<DurableCommitResult> _end(
  MatchApplicationComposition composition,
  PhoneCaptureIdentity identity,
  PhoneTemporalEvidenceStore evidence, {
  required PeriodIdentity period,
  required String periodStartedRecordId,
}) async {
  final captured = await evidence.captureAnchor();
  return composition.boundary.commitPeriodEnded(
    identity.contextFor('match-1'),
    period: period,
    periodStartedRecordId: periodStartedRecordId,
    temporalContext: TemporalContext(
      evidenceIds: [captured.evidenceId],
      domainClockPolicyVersion: PhoneCaptureIdentity.domainClockContract.value,
    ),
  );
}

Future<DurableCommitResult> _startPeriod2(
  MatchApplicationComposition composition,
  PhoneCaptureIdentity identity,
  PhoneTemporalEvidenceStore evidence, {
  required String periodEndedRecordId,
}) async {
  final captured = await evidence.captureAnchor();
  return composition.boundary.commitNextPeriodStarted(
    identity.contextFor('match-1'),
    period: const PeriodIdentity(index: 2),
    periodEndedRecordId: periodEndedRecordId,
    temporalContext: TemporalContext(
      evidenceIds: [captured.evidenceId],
      domainClockPolicyVersion: PhoneCaptureIdentity.domainClockContract.value,
    ),
  );
}

Future<DurableCommitResult> _suspend(
  MatchApplicationComposition composition,
  PhoneCaptureIdentity identity,
  PhoneTemporalEvidenceStore evidence, {
  required PeriodIdentity period,
  required String periodStartedRecordId,
}) async {
  final captured = await evidence.captureAnchor();
  return composition.boundary.commitTemporarySuspensionStarted(
    identity.contextFor('match-1'),
    period: period,
    periodStartedRecordId: periodStartedRecordId,
    temporalContext: TemporalContext(
      evidenceIds: [captured.evidenceId],
      domainClockPolicyVersion: PhoneCaptureIdentity.domainClockContract.value,
    ),
  );
}

Future<DurableCommitResult> _resume(
  MatchApplicationComposition composition,
  PhoneCaptureIdentity identity,
  PhoneTemporalEvidenceStore evidence, {
  required PeriodIdentity period,
  required String suspensionStartedRecordId,
}) async {
  final captured = await evidence.captureAnchor();
  return composition.boundary.commitTemporarySuspensionEnded(
    identity.contextFor('match-1'),
    period: period,
    suspensionStartedRecordId: suspensionStartedRecordId,
    temporalContext: TemporalContext(
      evidenceIds: [captured.evidenceId],
      domainClockPolicyVersion: PhoneCaptureIdentity.domainClockContract.value,
    ),
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

Future<ActivePeriodElapsedProjection> _elapsed(
  MatchApplicationComposition composition,
  PhoneTemporalEvidenceStore evidence, {
  PeriodIdentity? period,
}) async {
  final records = await _records(composition);
  final projection = await composition.boundary.project(
    'match-1',
    evaluatedAuthorityGeneration: PhoneCaptureIdentity.initialAuthorityGeneration,
  );
  final derived = TemporalMatchProjection.derive(
    projection: projection,
    records: records,
  );
  final temporal = period == null
      ? derived
      : TemporalMatchProjection(
          matchStarted: true,
          activePeriod: null,
          endedPeriod: period,
          periodEndAmbiguous: false,
          intervalActive: true,
          temporallyIncomplete: false,
          formallySuspended: false,
        );
  final shown = temporal.activePeriod ?? temporal.endedPeriod;
  final anchorId = anchoredPeriodStart(records, shown!)!
      .temporalContext!
      .evidenceIds
      .single;
  return deriveActivePeriodElapsed(
    temporal: temporal,
    projection: projection,
    records: records,
    anchor: await evidence.resolve(anchorId),
    current: evidence.currentObservation(),
    recordedEvidence: await _recordedEvidence(records, evidence),
  );
}

Future<List<TemporalEvidence>> _recordedEvidence(
  List<MatchRecord> records,
  PhoneTemporalEvidenceStore evidence,
) async {
  final resolved = <TemporalEvidence>[];
  final seen = <String>{};
  for (final record in records) {
    for (final id in record.temporalContext?.evidenceIds ?? const <String>[]) {
      if (!seen.add(id)) continue;
      final item = await evidence.resolve(id);
      if (item != null) resolved.add(item);
    }
  }
  return resolved;
}

bool _isPeriodEnded(MatchRecord record) {
  final payload = record.payload;
  return payload is TemporalTransitionPayload &&
      payload.semanticType == V1SemanticTypeCode.periodEnded;
}

bool _isPeriodStarted(MatchRecord record) {
  final payload = record.payload;
  return payload is TemporalTransitionPayload &&
      payload.semanticType == V1SemanticTypeCode.periodStarted;
}

final class ManualContinuityClock implements MonotonicContinuityClock {
  ManualContinuityClock({this.domainId = 'domain-live'});

  final String domainId;
  Duration elapsed = Duration.zero;
  DateTime wallChronology = DateTime.utc(2026, 10, 4, 12);

  @override
  String get continuityDomainId => domainId;

  @override
  Duration get monotonicElapsed => elapsed;

  @override
  DateTime get chronology => wallChronology;
}
