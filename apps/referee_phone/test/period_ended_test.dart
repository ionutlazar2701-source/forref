import 'dart:convert';
import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/match_application/authoritative_capture_command.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/infrastructure/temporal/phone_temporal_evidence_store.dart';
import 'package:referee_phone/match_application/kick_off_authority.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('period_ended_');
  });

  tearDown(() async {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('end period writes one PERIOD_ENDED on the active period lineage', () async {
    final clock = ManualContinuityClock();
    final evidence = PhoneTemporalEvidenceStore(storageRoot: temp, clock: clock);
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();

    final beforeStart = await _end(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 1),
      periodStartedRecordId: 'missing',
    );
    expect(beforeStart, isA<DurableCommitFailure>());
    expect(await _records(composition), isEmpty);

    await composition.boundary.commitMatchStarted(identity.contextFor('match-1'));
    final beforePeriod = await _end(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 1),
      periodStartedRecordId: 'missing',
    );
    expect(beforePeriod, isA<DurableCommitFailure>());
    expect((beforePeriod as DurableCommitFailure).reason, contains('active period'));
    expect(await _records(composition), hasLength(1));

    final kickOff = await _kickOff(composition, identity, evidence);
    clock.elapsed = const Duration(seconds: 12);
    final ended = await _end(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 1),
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    expect(ended, isA<DurableCommitSuccess>());
    final atEnd = await _elapsed(composition, evidence);
    final temporal = await _temporal(composition);
    expect(temporal.activePeriod, isNull);
    expect(temporal.endedPeriod, const PeriodIdentity(index: 1));
    expect(temporal.intervalActive, isTrue);
    expect(temporal.formallySuspended, isFalse);
    expect(atEnd.periodEnded, isTrue);
    expect(atEnd.activePeriod, isNull);
    expect(atEnd.exactElapsed, const Duration(seconds: 12));
    expect(atEnd.pastRegulationDisplayThreshold, isFalse);

    clock.elapsed = const Duration(minutes: 50);
    clock.wallChronology = DateTime.utc(2099);
    final later = await _elapsed(composition, evidence);
    expect(later.exactElapsed, const Duration(seconds: 12));
    expect(later, atEnd);

    final records = await _records(composition);
    expect(records.where(_isPeriodEnded), hasLength(1));
    final end = records.last;
    expect(
      (end.relationships.single as CausalDependency).targetRecordId,
      kickOff.periodStartedRecordId,
    );
    expect((end.payload as TemporalTransitionPayload).period?.index, 1);
    expect(records[1].recordId, kickOff.periodStartedRecordId);

    final duplicate = await _end(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 1),
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    expect(duplicate, isA<DurableCommitFailure>());
    expect((duplicate as DurableCommitFailure).reason, contains('already'));
    expect((await _records(composition)).where(_isPeriodEnded), hasLength(1));
    final afterEnd = await _suspend(
      composition,
      identity,
      evidence,
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    expect(afterEnd, isA<DurableCommitFailure>());
    expect((afterEnd as DurableCommitFailure).reason, contains('unfinished'));
    expect((await _records(composition)).where(_isPeriodEnded), hasLength(1));
    final stored = await File('${temp.path}/forref_temporal_evidence.json')
        .readAsString();
    expect(stored, isNot(contains('elapsedSeconds')));
    expect(stored, isNot(contains('playingElapsed')));
    expect(stored, isNot(contains('finalPlayingElapsed')));
  });

  test('wrong period, open suspension, and missing evidence write nothing', () async {
    final evidence = PhoneTemporalEvidenceStore(
      storageRoot: temp,
      clock: ManualContinuityClock(),
    );
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final kickOff = await _kickOff(composition, identity, evidence);
    final context = identity.contextFor('match-1');

    final wrongPeriod = await _end(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 2),
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    expect(wrongPeriod, isA<DurableCommitFailure>());
    expect((wrongPeriod as DurableCommitFailure).reason, contains('does not match'));

    final emptyEvidence = await composition.boundary.commitPeriodEnded(
      context,
      period: const PeriodIdentity(index: 1),
      periodStartedRecordId: kickOff.periodStartedRecordId,
      temporalContext: const TemporalContext(),
    );
    expect(emptyEvidence, isA<DurableCommitFailure>());
    expect(await _records(composition), hasLength(2));

    expect(
      await _suspend(
        composition,
        identity,
        evidence,
        periodStartedRecordId: kickOff.periodStartedRecordId,
      ),
      isA<DurableCommitSuccess>(),
    );
    final whileOpen = await _end(
      composition,
      identity,
      evidence,
      period: const PeriodIdentity(index: 1),
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    expect(whileOpen, isA<DurableCommitFailure>());
    expect(
      (whileOpen as DurableCommitFailure).reason,
      contains('open formal suspension'),
    );
    expect(await _records(composition), hasLength(3));
    expect((await _temporal(composition)).activePeriod, const PeriodIdentity(index: 1));
    expect((await _temporal(composition)).formallySuspended, isTrue);
  });

  test('two active period starts make period end ambiguous', () async {
    final evidence = PhoneTemporalEvidenceStore(
      storageRoot: temp,
      clock: ManualContinuityClock(),
    );
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final kickOff = await _kickOff(composition, identity, evidence);
    final matchStartId = (await _records(composition)).first.recordId;
    expect(
      await composition.boundary.captureAndCommit(
        AuthoritativeCaptureCommand(
          context: identity.contextFor('match-1'),
          recordKind: RecordKind.temporalFact,
          payload: TemporalTransitionPayload(
            semanticType: V1SemanticTypeCode.periodStarted,
            period: const PeriodIdentity(index: 2),
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
      period: const PeriodIdentity(index: 1),
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    expect(ambiguous, isA<DurableCommitFailure>());
    expect((ambiguous as DurableCommitFailure).reason, contains('ambiguous'));
    expect((await _records(composition)).where(_isPeriodEnded), isEmpty);
  });

  test('45:00 stays active until the referee ends the period', () async {
    final clock = ManualContinuityClock();
    final evidence = PhoneTemporalEvidenceStore(storageRoot: temp, clock: clock);
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final kickOff = await _kickOff(composition, identity, evidence);
    clock.elapsed = const Duration(minutes: 45, seconds: 1);
    final before = await _elapsed(composition, evidence);
    expect(before.pastRegulationDisplayThreshold, isTrue);
    expect(before.periodEnded, isFalse);
    expect((await _records(composition)).where(_isPeriodEnded), isEmpty);
    expect(
      (await _temporal(composition)).activePeriod,
      const PeriodIdentity(index: 1),
    );

    clock.elapsed = const Duration(minutes: 46);
    expect(
      await _end(
        composition,
        identity,
        evidence,
        period: const PeriodIdentity(index: 1),
        periodStartedRecordId: kickOff.periodStartedRecordId,
      ),
      isA<DurableCommitSuccess>(),
    );
    final ended = await _elapsed(composition, evidence);
    expect(ended.periodEnded, isTrue);
    expect(ended.exactElapsed, const Duration(minutes: 46));
    expect((await _temporal(composition)).activePeriod, isNull);
    expect((await _records(composition)).where(_isPeriodEnded), hasLength(1));
  });

  test('two suspensions then period end freeze 25s and survive reopen', () async {
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
    clock.elapsed = const Duration(seconds: 40);
    await _resume(
      composition,
      identity,
      evidence,
      suspensionStartedRecordId: (first as DurableCommitSuccess).committedRecordId,
    );
    clock.elapsed = const Duration(seconds: 47);
    final second = await _suspend(
      composition,
      identity,
      evidence,
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    clock.elapsed = const Duration(seconds: 67);
    await _resume(
      composition,
      identity,
      evidence,
      suspensionStartedRecordId:
          (second as DurableCommitSuccess).committedRecordId,
    );
    clock.elapsed = const Duration(seconds: 75);
    expect(
      await _end(
        composition,
        identity,
        evidence,
        period: const PeriodIdentity(index: 1),
        periodStartedRecordId: kickOff.periodStartedRecordId,
      ),
      isA<DurableCommitSuccess>(),
    );
    final ended = await _elapsed(composition, evidence);
    expect(ended.exactElapsed, const Duration(seconds: 25));
    expect(ended.suspensionDurations, [
      const Duration(seconds: 30),
      const Duration(seconds: 20),
    ]);
    expect(ended.playingSegments, [
      const Duration(seconds: 10),
      const Duration(seconds: 7),
      const Duration(seconds: 8),
    ]);
    expect(ended.exactElapsed, isNot(const Duration(seconds: 75)));
    clock.elapsed = const Duration(minutes: 3);
    expect((await _elapsed(composition, evidence)).exactElapsed, const Duration(seconds: 25));
    await composition.close();

    final reopened = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(reopened.close);
    final restarted = PhoneTemporalEvidenceStore(
      storageRoot: temp,
      clock: ManualContinuityClock(domainId: 'domain-b')
        ..elapsed = const Duration(hours: 2)
        ..wallChronology = DateTime.utc(2099),
    );
    final recovered = await _elapsed(reopened, restarted);
    final temporal = await _temporal(reopened);
    expect(temporal.activePeriod, isNull);
    expect(temporal.endedPeriod, const PeriodIdentity(index: 1));
    expect(temporal.intervalActive, isTrue);
    expect(temporal.formallySuspended, isFalse);
    expect(recovered.periodEnded, isTrue);
    expect(recovered.activePeriod, isNull);
    expect(recovered.exactElapsed, const Duration(seconds: 25));
    expect(recovered.suspensionDurations, [
      const Duration(seconds: 30),
      const Duration(seconds: 20),
    ]);
    expect(recovered.exactElapsed, isNot(const Duration(hours: 2)));
    expect((await _records(reopened)).where(_isPeriodEnded), hasLength(1));

    final records = await _records(reopened);
    final endId = records.last.temporalContext!.evidenceIds.single;
    final file = File('${temp.path}/forref_temporal_evidence.json');
    final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final artifacts = decoded['artifacts']! as List<dynamic>;
    for (final item in artifacts) {
      final artifact = item as Map<String, dynamic>;
      if (artifact['evidenceId'] == endId) {
        artifact['continuityDomainId'] = 'domain-other';
      }
    }
    await file.writeAsString(jsonEncode(decoded));
    final degraded = await _elapsed(reopened, restarted);
    expect((await _temporal(reopened)).endedPeriod, const PeriodIdentity(index: 1));
    expect(degraded.periodEnded, isTrue);
    expect(degraded.exactElapsed, isNull);
    expect(degraded.suspensionDurations, [
      const Duration(seconds: 30),
      const Duration(seconds: 20),
    ]);
  });

  test('end period action does not write legacy half-time', () {
    final page = File(
      'lib/features/live_match/live_match_page.dart',
    ).readAsStringSync();
    final end = RegExp(
      r'Future<void> _endPeriod[\s\S]*?\n  \}',
    ).firstMatch(page)!.group(0)!;
    expect(end, contains('commitPeriodEnded'));
    expect(end, isNot(contains('halfTime')));
    expect(end, isNot(contains('fullTime')));
    expect(end, isNot(contains('.pause')));
    expect(end, isNot(contains('elapsedSeconds')));
    expect(
      V1SemanticContract.byCode[V1SemanticTypeCode.periodEnded]!.isDurableMatchState,
      isFalse,
    );
    expect(
      V1SemanticTypeCode.values.map((code) => code.wireValue),
      isNot(contains('HALF_TIME')),
    );
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
