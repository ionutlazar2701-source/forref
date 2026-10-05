import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/infrastructure/temporal/phone_temporal_evidence_store.dart';
import 'package:referee_phone/match_application/kick_off_authority.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('period_two_');
  });

  tearDown(() async {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('start period 2 writes one record tied to period 1 end', () async {
    final clock = ManualContinuityClock();
    final evidence = PhoneTemporalEvidenceStore(storageRoot: temp, clock: clock);
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final context = identity.contextFor('match-1');

    final before = await _start(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 2),
      periodEndedRecordId: 'missing',
    );
    expect(before, isA<DurableCommitFailure>());
    expect(await _records(composition), isEmpty);

    final kickOff = await _kickOff(composition, identity, evidence);
    clock.elapsed = const Duration(seconds: 10);
    final whileActive = await _start(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 2),
      periodEndedRecordId: kickOff.periodStartedRecordId,
    );
    expect(whileActive, isA<DurableCommitFailure>());
    expect((whileActive as DurableCommitFailure).reason, contains('active period'));
    expect(await _records(composition), hasLength(2));

    clock.elapsed = const Duration(seconds: 18);
    final ended = await _end(
      composition,
      identity,
      evidence,
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    final endId = (ended as DurableCommitSuccess).committedRecordId;
    final waiting = await _temporal(composition);
    expect(waiting.intervalActive, isTrue);
    expect(waiting.activePeriod, isNull);
    expect(await _records(composition), hasLength(3));

    final wrongIndex = await _start(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 3),
      periodEndedRecordId: endId,
    );
    expect(wrongIndex, isA<DurableCommitFailure>());
    expect((wrongIndex as DurableCommitFailure).reason, contains('not 2'));

    final wrongLineage = await _start(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 2),
      periodEndedRecordId: kickOff.periodStartedRecordId,
    );
    expect(wrongLineage, isA<DurableCommitFailure>());
    expect((wrongLineage as DurableCommitFailure).reason, contains('PERIOD_ENDED'));

    final emptyEvidence = await composition.boundary.commitNextPeriodStarted(
      context,
      period: const PeriodIdentity(index: 2),
      periodEndedRecordId: endId,
      temporalContext: const TemporalContext(),
    );
    expect(emptyEvidence, isA<DurableCommitFailure>());
    expect(await _records(composition), hasLength(3));
    expect((await _temporal(composition)).intervalActive, isTrue);

    clock.elapsed = const Duration(seconds: 80);
    final started = await _start(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 2),
      periodEndedRecordId: endId,
    );
    expect(started, isA<DurableCommitSuccess>());
    final records = await _records(composition);
    expect(records.where(_isPeriodStarted), hasLength(2));
    final periodTwo = records.last;
    expect((periodTwo.payload as TemporalTransitionPayload).period?.index, 2);
    expect(
      (periodTwo.relationships.single as CausalDependency).targetRecordId,
      endId,
    );
    expect(
      periodTwo.temporalContext!.evidenceIds.single,
      isNot(records[1].temporalContext!.evidenceIds.single),
    );

    final live = await _temporal(composition);
    expect(live.intervalActive, isFalse);
    expect(live.activePeriod, const PeriodIdentity(index: 2));
    expect(live.endedPeriod, const PeriodIdentity(index: 1));
    expect(live.formallySuspended, isFalse);

    final atStart = await _elapsed(composition, evidence);
    expect(atStart.activePeriod, const PeriodIdentity(index: 2));
    expect(atStart.exactElapsed, const Duration(seconds: 0));
    clock.elapsed = const Duration(seconds: 92);
    clock.wallChronology = DateTime.utc(2099);
    final later = await _elapsed(composition, evidence);
    expect(later.exactElapsed, const Duration(seconds: 12));
    expect(later.exactElapsed, isNot(const Duration(seconds: 18)));
    expect(later.exactElapsed, isNot(const Duration(seconds: 92)));

    final duplicate = await _start(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 2),
      periodEndedRecordId: endId,
    );
    expect(duplicate, isA<DurableCommitFailure>());
    expect((duplicate as DurableCommitFailure).reason, contains('already'));
    expect(await _records(composition), hasLength(4));
    expect(
      V1SemanticTypeCode.values.map((code) => code.wireValue),
      isNot(contains('HALF_TIME')),
    );
    expect(
      V1SemanticTypeCode.values.map((code) => code.wireValue),
      isNot(contains('INTERVAL_ENDED')),
    );
  });

  test('period 1 suspension history does not enter period 2 elapsed', () async {
    final clock = ManualContinuityClock(domainId: 'domain-a');
    final evidence = PhoneTemporalEvidenceStore(storageRoot: temp, clock: clock);
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final kickOff = await _kickOff(composition, identity, evidence);
    clock.elapsed = const Duration(seconds: 10);
    final suspended = await _suspend(
      composition,
      identity,
      evidence,
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    clock.elapsed = const Duration(seconds: 40);
    await _resume(
      composition,
      identity,
      evidence,
      suspensionStartedRecordId:
          (suspended as DurableCommitSuccess).committedRecordId,
    );
    clock.elapsed = const Duration(seconds: 47);
    final ended = await _end(
      composition,
      identity,
      evidence,
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    final periodOne = await _elapsed(composition, evidence);
    expect(periodOne.exactElapsed, const Duration(seconds: 17));
    expect(periodOne.suspensionDurations, [const Duration(seconds: 30)]);

    clock.elapsed = const Duration(seconds: 100);
    expect(
      await _start(
        composition,
        identity,
        evidence,
        period: const PeriodIdentity(index: 2),
        periodEndedRecordId: (ended as DurableCommitSuccess).committedRecordId,
      ),
      isA<DurableCommitSuccess>(),
    );
    final atTwo = await _elapsed(composition, evidence);
    expect(atTwo.exactElapsed, Duration.zero);
    expect(atTwo.suspensionDurations, isEmpty);
    clock.elapsed = const Duration(seconds: 112);
    final played = await _elapsed(composition, evidence);
    expect(played.exactElapsed, const Duration(seconds: 12));
    expect(played.activePeriod, const PeriodIdentity(index: 2));
    expect(played.exactElapsed, isNot(const Duration(seconds: 17)));
    expect(played.exactElapsed, isNot(const Duration(seconds: 29)));
    expect((await _temporal(composition)).endedPeriod, const PeriodIdentity(index: 1));
  });

  test('reopen reconstructs active period 2 and frozen period 1', () async {
    final clock = ManualContinuityClock(domainId: 'domain-a');
    final evidence = PhoneTemporalEvidenceStore(storageRoot: temp, clock: clock);
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final kickOff = await _kickOff(composition, identity, evidence);
    clock.elapsed = const Duration(seconds: 18);
    final ended = await _end(
      composition,
      identity,
      evidence,
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    clock.elapsed = const Duration(seconds: 40);
    expect(
      await _start(
        composition,
        identity,
        evidence,
        period: const PeriodIdentity(index: 2),
        periodEndedRecordId: (ended as DurableCommitSuccess).committedRecordId,
      ),
      isA<DurableCommitSuccess>(),
    );
    clock.elapsed = const Duration(seconds: 55);
    expect(
      (await _elapsed(composition, evidence)).exactElapsed,
      const Duration(seconds: 15),
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
    expect(temporal.intervalActive, isFalse);
    expect(temporal.activePeriod, const PeriodIdentity(index: 2));
    expect(temporal.endedPeriod, const PeriodIdentity(index: 1));
    final elapsed = await _elapsed(reopened, restarted);
    expect(elapsed.activePeriod, const PeriodIdentity(index: 2));
    expect(elapsed.exactElapsed, isNull);
    expect(elapsed.exactElapsed, isNot(const Duration(hours: 2)));
    expect(elapsed.exactElapsed, isNot(const Duration(seconds: 18)));
    expect((await _records(reopened)).where(_isPeriodStarted), hasLength(2));
  });

  test('start period 2 action does not call legacy second half', () {
    final page = File(
      'lib/features/live_match/live_match_page.dart',
    ).readAsStringSync();
    final start = RegExp(
      r'Future<void> _startPeriod2[\s\S]*?\n  \}',
    ).firstMatch(page)!.group(0)!;
    expect(start, contains('commitNextPeriodStarted'));
    expect(start, isNot(contains('startSecondHalf')));
    expect(start, isNot(contains('halfTime')));
    expect(start, isNot(contains('elapsedSeconds')));
    final ticker = RegExp(
      r'void _syncClockTicker[\s\S]*?\n  \}',
    ).firstMatch(page)!.group(0)!;
    expect(ticker, contains('_activePeriod != null'));
  });
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
  required String periodStartedRecordId,
}) async {
  final captured = await evidence.captureAnchor();
  return composition.boundary.commitPeriodEnded(
    identity.contextFor('match-1'),
    period: const PeriodIdentity(index: 1),
    periodStartedRecordId: periodStartedRecordId,
    temporalContext: TemporalContext(
      evidenceIds: [captured.evidenceId],
      domainClockPolicyVersion: PhoneCaptureIdentity.domainClockContract.value,
    ),
  );
}

Future<DurableCommitResult> _start(
  MatchApplicationComposition composition,
  PhoneCaptureIdentity identity,
  PhoneTemporalEvidenceStore evidence, {
  required PeriodIdentity period,
  required String periodEndedRecordId,
}) async {
  final captured = await evidence.captureAnchor();
  return composition.boundary.commitNextPeriodStarted(
    identity.contextFor('match-1'),
    period: period,
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
  required String periodStartedRecordId,
}) async {
  final captured = await evidence.captureAnchor();
  return composition.boundary.commitTemporarySuspensionStarted(
    identity.contextFor('match-1'),
    period: const PeriodIdentity(index: 1),
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
  required String suspensionStartedRecordId,
}) async {
  final captured = await evidence.captureAnchor();
  return composition.boundary.commitTemporarySuspensionEnded(
    identity.contextFor('match-1'),
    period: const PeriodIdentity(index: 1),
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
  PhoneTemporalEvidenceStore evidence,
) async {
  final records = await _records(composition);
  final projection = await composition.boundary.project(
    'match-1',
    evaluatedAuthorityGeneration: PhoneCaptureIdentity.initialAuthorityGeneration,
  );
  final temporal = TemporalMatchProjection.derive(
    projection: projection,
    records: records,
  );
  final period = temporal.activePeriod ?? temporal.endedPeriod;
  final anchorId = anchoredPeriodStart(records, period!)!
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

bool _isPeriodStarted(MatchRecord record) {
  final payload = record.payload;
  return payload is TemporalTransitionPayload &&
      payload.semanticType == V1SemanticTypeCode.periodStarted;
}

final class ManualContinuityClock implements MonotonicContinuityClock {
  ManualContinuityClock({this.domainId = 'domain-live'});

  final String domainId;
  Duration elapsed = Duration.zero;
  DateTime wallChronology = DateTime.utc(2026, 10, 3, 12);

  @override
  String get continuityDomainId => domainId;

  @override
  Duration get monotonicElapsed => elapsed;

  @override
  DateTime get chronology => wallChronology;
}
