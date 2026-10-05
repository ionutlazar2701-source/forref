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
    temp = await Directory.systemTemp.createTemp('resumption_');
  });

  tearDown(() async {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('resume closes the open suspension and continues playing elapsed once', () async {
    final clock = ManualContinuityClock();
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
    expect(suspended, isA<DurableCommitSuccess>());
    final suspensionId =
        (suspended as DurableCommitSuccess).committedRecordId;

    clock.elapsed = const Duration(seconds: 40);
    clock.wallChronology = DateTime.utc(2099);
    final frozen = await _elapsed(composition, evidence);
    expect(frozen.exactElapsed, const Duration(seconds: 10));
    expect(frozen.formalSuspensionActive, isTrue);
    expect(frozen.suspensionDurationOpen, isTrue);

    final resumed = await _resume(
      composition,
      identity,
      evidence,
      suspensionStartedRecordId: suspensionId,
    );
    expect(resumed, isA<DurableCommitSuccess>());
    final atResume = await _elapsed(composition, evidence);
    expect(atResume.exactElapsed, const Duration(seconds: 10));
    expect(atResume.formalSuspensionActive, isFalse);
    expect(atResume.suspensionStarted, isTrue);
    expect(atResume.suspensionEnded, isTrue);
    expect(atResume.suspensionDurationOpen, isFalse);
    expect(atResume.suspensionDuration, const Duration(seconds: 30));

    clock.elapsed = const Duration(seconds: 47);
    clock.wallChronology = DateTime.utc(1990);
    final later = await _elapsed(composition, evidence);
    expect(later.exactElapsed, const Duration(seconds: 17));
    expect(later.suspensionDuration, const Duration(seconds: 30));
    expect(
      later.exactElapsed! + later.suspensionDuration!,
      const Duration(seconds: 47),
    );

    final records = await _records(composition);
    expect(records, hasLength(4));
    expect(records.map((record) => record.originSequence), [1, 2, 3, 4]);
    final end = records[3];
    final payload = end.payload as TemporalTransitionPayload;
    expect(payload.semanticType, V1SemanticTypeCode.temporarySuspensionEnded);
    expect(payload.period, const PeriodIdentity(index: 1));
    expect(
      (end.relationships.single as CausalDependency).targetRecordId,
      suspensionId,
    );
    expect(records[2].recordId, suspensionId);
    expect(records[2].temporalContext!.evidenceIds, hasLength(1));
    expect(records.where(_isPeriodEnded), isEmpty);
    final stored = await File('${temp.path}/forref_temporal_evidence.json')
        .readAsString();
    expect(stored, isNot(contains('elapsedSeconds')));

    final again = await _suspend(
      composition,
      identity,
      evidence,
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    expect(again, isA<DurableCommitSuccess>());
    final secondId = (again as DurableCommitSuccess).committedRecordId;
    expect(secondId, isNot(suspensionId));
    final afterSecond = await _records(composition);
    expect(afterSecond, hasLength(5));
    expect(afterSecond.last.recordId, secondId);
    expect(
      (afterSecond.last.payload as TemporalTransitionPayload).semanticType,
      V1SemanticTypeCode.temporarySuspensionStarted,
    );
    final frozenAgain = await _elapsed(composition, evidence);
    expect(frozenAgain.formalSuspensionActive, isTrue);
    expect(frozenAgain.exactElapsed, const Duration(seconds: 17));
    expect(frozenAgain.suspensionDurations, [const Duration(seconds: 30)]);
  });

  test('resume without an open suspension or a second end writes nothing', () async {
    final evidence = PhoneTemporalEvidenceStore(
      storageRoot: temp,
      clock: ManualContinuityClock(),
    );
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final context = identity.contextFor('match-1');

    final before = await composition.boundary.commitTemporarySuspensionEnded(
      context,
      period: const PeriodIdentity(index: 1),
      suspensionStartedRecordId: 'missing',
      temporalContext: const TemporalContext(evidenceIds: ['anchor']),
    );
    expect(before, isA<DurableCommitFailure>());
    expect(await _records(composition), isEmpty);

    final kickOff = await _kickOff(composition, identity, evidence);
    final withoutSuspension = await _resume(
      composition,
      identity,
      evidence,
      suspensionStartedRecordId: kickOff.periodStartedRecordId,
    );
    expect(withoutSuspension, isA<DurableCommitFailure>());
    expect(await _records(composition), hasLength(2));

    final suspended = await _suspend(
      composition,
      identity,
      evidence,
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    final suspensionId =
        (suspended as DurableCommitSuccess).committedRecordId;
    final wrongPeriod = await composition.boundary.commitTemporarySuspensionEnded(
      context,
      period: const PeriodIdentity(index: 2),
      suspensionStartedRecordId: suspensionId,
      temporalContext: const TemporalContext(evidenceIds: ['other']),
    );
    expect(wrongPeriod, isA<DurableCommitFailure>());
    final wrongLineage = await _resume(
      composition,
      identity,
      evidence,
      suspensionStartedRecordId: kickOff.periodStartedRecordId,
    );
    expect(wrongLineage, isA<DurableCommitFailure>());
    final emptyEvidence =
        await composition.boundary.commitTemporarySuspensionEnded(
      context,
      period: const PeriodIdentity(index: 1),
      suspensionStartedRecordId: suspensionId,
      temporalContext: const TemporalContext(),
    );
    expect(emptyEvidence, isA<DurableCommitFailure>());
    expect(await _records(composition), hasLength(3));

    expect(
      await _resume(
        composition,
        identity,
        evidence,
        suspensionStartedRecordId: suspensionId,
      ),
      isA<DurableCommitSuccess>(),
    );
    final duplicate = await _resume(
      composition,
      identity,
      evidence,
      suspensionStartedRecordId: suspensionId,
    );
    expect(duplicate, isA<DurableCommitFailure>());
    expect((duplicate as DurableCommitFailure).reason, contains('already'));
    expect((await _records(composition)).where(_isResumption), hasLength(1));
  });

  test('failed resume leaves the suspension open', () async {
    final clock = ManualContinuityClock();
    final evidence = PhoneTemporalEvidenceStore(storageRoot: temp, clock: clock);
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final kickOff = await _kickOff(composition, identity, evidence);
    clock.elapsed = const Duration(seconds: 8);
    final suspended = await _suspend(
      composition,
      identity,
      evidence,
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    composition.boundary.durableStore.abortBeforeCommitForTest = () {
      throw StateError('abort before commit');
    };

    final result = await _resume(
      composition,
      identity,
      evidence,
      suspensionStartedRecordId:
          (suspended as DurableCommitSuccess).committedRecordId,
    );
    expect(result, isA<DurableCommitFailure>());
    expect(await _records(composition), hasLength(3));
    final elapsed = await _elapsed(composition, evidence);
    expect(elapsed.formalSuspensionActive, isTrue);
    expect(elapsed.suspensionEnded, isFalse);
    expect(elapsed.exactElapsed, const Duration(seconds: 8));
  });

  test('reopen after resume keeps the period active and drops exact elapsed', () async {
    final clock = ManualContinuityClock(domainId: 'domain-a');
    final evidence = PhoneTemporalEvidenceStore(storageRoot: temp, clock: clock);
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
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
    expect(
      await _resume(
        composition,
        identity,
        evidence,
        suspensionStartedRecordId:
            (suspended as DurableCommitSuccess).committedRecordId,
      ),
      isA<DurableCommitSuccess>(),
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
    final elapsed = await _elapsed(reopened, restarted);
    final temporal = await _temporal(reopened);
    expect(temporal.formallySuspended, isFalse);
    expect(temporal.activePeriod, const PeriodIdentity(index: 1));
    expect(elapsed.suspensionEnded, isTrue);
    expect(elapsed.formalSuspensionActive, isFalse);
    expect(elapsed.exactElapsed, isNull);
    expect(elapsed.suspensionDuration, const Duration(seconds: 30));
    expect(await _records(reopened), hasLength(4));
  });

  test('a second cycle is 22s of play and two independent suspensions', () async {
    final clock = ManualContinuityClock(domainId: 'domain-a');
    final evidence = PhoneTemporalEvidenceStore(storageRoot: temp, clock: clock);
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final kickOff = await _kickOff(composition, identity, evidence);

    clock.elapsed = const Duration(seconds: 10);
    final first = await _suspend(
      composition,
      identity,
      evidence,
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    final firstId = (first as DurableCommitSuccess).committedRecordId;
    clock.elapsed = const Duration(seconds: 40);
    expect(
      await _resume(
        composition,
        identity,
        evidence,
        suspensionStartedRecordId: firstId,
      ),
      isA<DurableCommitSuccess>(),
    );

    clock.elapsed = const Duration(seconds: 47);
    final second = await _suspend(
      composition,
      identity,
      evidence,
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    expect(second, isA<DurableCommitSuccess>());
    final secondId = (second as DurableCommitSuccess).committedRecordId;
    expect(secondId, isNot(firstId));
    final overlap = await _suspend(
      composition,
      identity,
      evidence,
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    expect(overlap, isA<DurableCommitFailure>());
    expect((overlap as DurableCommitFailure).reason, contains('already'));

    clock.elapsed = const Duration(seconds: 67);
    final secondEnd = await _resume(
      composition,
      identity,
      evidence,
      suspensionStartedRecordId: secondId,
    );
    expect(secondEnd, isA<DurableCommitSuccess>());
    final closedAgain = await _resume(
      composition,
      identity,
      evidence,
      suspensionStartedRecordId: firstId,
    );
    expect(closedAgain, isA<DurableCommitFailure>());
    expect((closedAgain as DurableCommitFailure).reason, contains('already'));

    clock.elapsed = const Duration(seconds: 72);
    clock.wallChronology = DateTime.utc(2099);
    final elapsed = await _elapsed(composition, evidence);
    expect(elapsed.exactElapsed, const Duration(seconds: 22));
    expect(elapsed.playingSegments, [
      const Duration(seconds: 10),
      const Duration(seconds: 7),
      const Duration(seconds: 5),
    ]);
    expect(elapsed.suspensionDurations, [
      const Duration(seconds: 30),
      const Duration(seconds: 20),
    ]);
    expect(elapsed.exactElapsed, isNot(const Duration(seconds: 72)));
    expect(elapsed.exactElapsed, isNot(const Duration(seconds: 42)));
    expect(elapsed.formalSuspensionActive, isFalse);
    expect(elapsed.certified, isFalse);

    final records = await _records(composition);
    expect(records, hasLength(6));
    expect(
      (records[5].relationships.single as CausalDependency).targetRecordId,
      secondId,
    );
    expect(
      (records[3].relationships.single as CausalDependency).targetRecordId,
      firstId,
    );
    expect(records.where(_isPeriodEnded), isEmpty);
    final stored = await File('${temp.path}/forref_temporal_evidence.json')
        .readAsString();
    expect(stored, isNot(contains('elapsedSeconds')));
    expect(stored, isNot(contains('playingElapsed')));

    clock.elapsed = const Duration(seconds: 72);
    final third = await _suspend(
      composition,
      identity,
      evidence,
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    expect(third, isA<DurableCommitSuccess>());
    clock.elapsed = const Duration(seconds: 82);
    expect(
      await _resume(
        composition,
        identity,
        evidence,
        suspensionStartedRecordId:
            (third as DurableCommitSuccess).committedRecordId,
      ),
      isA<DurableCommitSuccess>(),
    );
    clock.elapsed = const Duration(seconds: 86);
    final three = await _elapsed(composition, evidence);
    expect(three.exactElapsed, const Duration(seconds: 26));
    expect(three.suspensionDurations, [
      const Duration(seconds: 30),
      const Duration(seconds: 20),
      const Duration(seconds: 10),
    ]);
    expect(await _records(composition), hasLength(8));
  });

  test('reopen reconstructs every closed cycle and an open final suspension', () async {
    final clock = ManualContinuityClock(domainId: 'domain-a');
    final evidence = PhoneTemporalEvidenceStore(storageRoot: temp, clock: clock);
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final kickOff = await _kickOff(composition, identity, evidence);
    clock.elapsed = const Duration(seconds: 10);
    final first = await _suspend(
      composition,
      identity,
      evidence,
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    final firstId = (first as DurableCommitSuccess).committedRecordId;
    clock.elapsed = const Duration(seconds: 40);
    await _resume(
      composition,
      identity,
      evidence,
      suspensionStartedRecordId: firstId,
    );
    clock.elapsed = const Duration(seconds: 47);
    final second = await _suspend(
      composition,
      identity,
      evidence,
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    await composition.close();

    final openStore = await MatchApplicationComposition.open(storageRoot: temp);
    final restarted = PhoneTemporalEvidenceStore(
      storageRoot: temp,
      clock: ManualContinuityClock(domainId: 'domain-b')
        ..elapsed = const Duration(hours: 2)
        ..wallChronology = DateTime.utc(2099),
    );
    final openElapsed = await _elapsed(openStore, restarted);
    final openTemporal = await _temporal(openStore);
    expect(openTemporal.formallySuspended, isTrue);
    expect(openTemporal.activePeriod, const PeriodIdentity(index: 1));
    expect(openElapsed.formalSuspensionActive, isTrue);
    expect(openElapsed.exactElapsed, const Duration(seconds: 17));
    expect(openElapsed.suspensionDurations, [const Duration(seconds: 30)]);
    expect(openElapsed.exactElapsed, isNot(const Duration(hours: 2)));
    await openStore.close();

    final finishing = await MatchApplicationComposition.open(storageRoot: temp);
    final sameDomain = PhoneTemporalEvidenceStore(
      storageRoot: temp,
      clock: ManualContinuityClock(domainId: 'domain-a')..elapsed = const Duration(seconds: 67),
    );
    expect(
      await _resume(
        finishing,
        identity,
        sameDomain,
        suspensionStartedRecordId:
            (second as DurableCommitSuccess).committedRecordId,
      ),
      isA<DurableCommitSuccess>(),
    );
    await finishing.close();

    final closedStore = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(closedStore.close);
    final after = await _elapsed(
      closedStore,
      PhoneTemporalEvidenceStore(
        storageRoot: temp,
        clock: ManualContinuityClock(domainId: 'domain-b')
          ..elapsed = const Duration(hours: 2)
          ..wallChronology = DateTime.utc(2099),
      ),
    );
    final closedTemporal = await _temporal(closedStore);
    expect(closedTemporal.formallySuspended, isFalse);
    expect(closedTemporal.activePeriod, const PeriodIdentity(index: 1));
    expect(after.formalSuspensionActive, isFalse);
    expect(after.suspensionEnded, isTrue);
    expect(after.exactElapsed, isNull);
    expect(after.suspensionDurations, [
      const Duration(seconds: 30),
      const Duration(seconds: 20),
    ]);
    expect(after.playingSegments[0], const Duration(seconds: 10));
    expect(after.playingSegments[1], const Duration(seconds: 7));
    expect(after.playingSegments.last, isNull);
    expect(await _records(closedStore), hasLength(6));
    expect((await _records(closedStore)).where(_isPeriodEnded), isEmpty);
  });

  test('resume action source does not write legacy resume', () {
    final page = File(
      'lib/features/live_match/live_match_page.dart',
    ).readAsStringSync();
    final resume = RegExp(
      r'Future<void> _resumeMatch[\s\S]*?\n  \}',
    ).firstMatch(page)!.group(0)!;

    expect(resume, contains('commitTemporarySuspensionEnded'));
    expect(resume, isNot(contains('session.resume')));
    expect(resume, isNot(contains('.pause')));
    expect(resume, isNot(contains('elapsedSeconds')));
    expect(resume, isNot(contains('addedTime')));
    expect(page, isNot(contains("'RESUMED'")));
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
  final anchorId = records
      .map((record) => record.temporalContext?.evidenceIds ?? const <String>[])
      .expand((ids) => ids)
      .first;
  final suspension = findFormalSuspensionStart(
    records: records,
    activePeriod: temporal.activePeriod,
  );
  final boundaryIds =
      suspension.record?.temporalContext?.evidenceIds ?? const <String>[];
  final resumptionIds =
      suspension.end?.temporalContext?.evidenceIds ?? const <String>[];
  return deriveActivePeriodElapsed(
    temporal: temporal,
    projection: projection,
    records: records,
    anchor: await evidence.resolve(anchorId),
    current: evidence.currentObservation(),
    suspensionBoundary:
        boundaryIds.isEmpty ? null : await evidence.resolve(boundaryIds.first),
    resumptionAnchor: resumptionIds.isEmpty
        ? null
        : await evidence.resolve(resumptionIds.first),
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

bool _isResumption(MatchRecord record) {
  final payload = record.payload;
  return payload is TemporalTransitionPayload &&
      payload.semanticType == V1SemanticTypeCode.temporarySuspensionEnded;
}

bool _isPeriodEnded(MatchRecord record) {
  final payload = record.payload;
  return payload is TemporalTransitionPayload &&
      payload.semanticType == V1SemanticTypeCode.periodEnded;
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
