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
    temp = await Directory.systemTemp.createTemp('formal_suspension_');
  });

  tearDown(() async {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('formal suspension is one record on the active period lineage', () async {
    final clock = ManualContinuityClock();
    final evidence = PhoneTemporalEvidenceStore(storageRoot: temp, clock: clock);
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final kickOff = await _kickOff(composition, identity, evidence);
    clock.elapsed = const Duration(seconds: 12);

    final result = await _suspend(
      composition,
      identity,
      evidence,
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );

    expect(result, isA<DurableCommitSuccess>());
    final records = await _records(composition);
    expect(records, hasLength(3));
    expect(records.map((record) => record.originSequence), [1, 2, 3]);
    final suspension = records[2];
    final payload = suspension.payload as TemporalTransitionPayload;
    expect(payload.semanticType, V1SemanticTypeCode.temporarySuspensionStarted);
    expect(payload.period, const PeriodIdentity(index: 1));
    expect(
      (suspension.relationships.single as CausalDependency).targetRecordId,
      kickOff.periodStartedRecordId,
    );
    expect(suspension.temporalContext!.evidenceIds, hasLength(1));
    expect(records[1].recordId, kickOff.periodStartedRecordId);
    expect(records[1].temporalContext!.evidenceIds, hasLength(1));
    final stored = await File('${temp.path}/forref_temporal_evidence.json')
        .readAsString();
    expect(stored, isNot(contains('elapsedSeconds')));
    expect('phone-live-monotonic'.allMatches(stored), isEmpty);

    clock.elapsed = const Duration(minutes: 4);
    clock.wallChronology = DateTime.utc(2099, 1, 1);
    final elapsed = await _elapsed(composition, evidence);
    expect(elapsed.exactElapsed, const Duration(seconds: 12));
    expect(elapsed.formalSuspensionActive, isTrue);
    expect(elapsed.suspensionStarted, isTrue);
    expect(elapsed.suspensionDurationOpen, isTrue);
    expect(elapsed.pastRegulationDisplayThreshold, isFalse);
    expect(records.where(_isPeriodEnded), isEmpty);
  });

  test('duplicate suspension and early suspension write nothing', () async {
    final clock = ManualContinuityClock();
    final evidence = PhoneTemporalEvidenceStore(storageRoot: temp, clock: clock);
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final context = identity.contextFor('match-1');

    final beforeStart = await composition.boundary.commitTemporarySuspensionStarted(
      context,
      period: const PeriodIdentity(index: 1),
      periodStartedRecordId: 'missing',
      temporalContext: const TemporalContext(evidenceIds: ['boundary']),
    );
    expect(beforeStart, isA<DurableCommitFailure>());
    expect(await _records(composition), isEmpty);

    expect(
      await composition.boundary.commitMatchStarted(context),
      isA<DurableCommitSuccess>(),
    );
    final beforePeriod =
        await composition.boundary.commitTemporarySuspensionStarted(
      context,
      period: const PeriodIdentity(index: 1),
      periodStartedRecordId: 'missing',
      temporalContext: const TemporalContext(evidenceIds: ['boundary']),
    );
    expect(beforePeriod, isA<DurableCommitFailure>());
    expect(await _records(composition), hasLength(1));

    final kickOff = await _kickOff(composition, identity, evidence);
    final emptyEvidence =
        await composition.boundary.commitTemporarySuspensionStarted(
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
    final duplicate = await _suspend(
      composition,
      identity,
      evidence,
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    expect(duplicate, isA<DurableCommitFailure>());
    expect((duplicate as DurableCommitFailure).reason, contains('already'));
    final records = await _records(composition);
    expect(records, hasLength(3));
    expect(
      records.where(_isSuspension),
      hasLength(1),
    );
  });

  test('two open periods cannot be suspended', () async {
    final evidence = PhoneTemporalEvidenceStore(
      storageRoot: temp,
      clock: ManualContinuityClock(),
    );
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final kickOff = await _kickOff(composition, identity, evidence);
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
          relationships: [
            CausalDependency(targetRecordId: kickOff.matchStartedRecordId),
          ],
        ),
      ),
      isA<DurableCommitSuccess>(),
    );

    final result = await _suspend(
      composition,
      identity,
      evidence,
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    expect(result, isA<DurableCommitFailure>());
    expect(await _records(composition), hasLength(3));
    expect((await _records(composition)).where(_isSuspension), isEmpty);
  });

  test('commit failure leaves the period running', () async {
    final clock = ManualContinuityClock();
    final evidence = PhoneTemporalEvidenceStore(storageRoot: temp, clock: clock);
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final kickOff = await _kickOff(composition, identity, evidence);
    clock.elapsed = const Duration(seconds: 8);
    composition.boundary.durableStore.abortBeforeCommitForTest = () {
      throw StateError('abort before commit');
    };

    final result = await _suspend(
      composition,
      identity,
      evidence,
      periodStartedRecordId: kickOff.periodStartedRecordId,
    );
    expect(result, isA<DurableCommitFailure>());
    expect(await _records(composition), hasLength(2));
    final elapsed = await _elapsed(composition, evidence);
    expect(elapsed.formalSuspensionActive, isFalse);
    expect(elapsed.exactElapsed, const Duration(seconds: 8));
  });

  test('reopen keeps the frozen boundary and a broken domain does not invent it', () async {
    final clock = ManualContinuityClock(domainId: 'domain-a');
    final evidence = PhoneTemporalEvidenceStore(storageRoot: temp, clock: clock);
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final kickOff = await _kickOff(composition, identity, evidence);
    clock.elapsed = const Duration(seconds: 12);
    expect(
      await _suspend(
        composition,
        identity,
        evidence,
        periodStartedRecordId: kickOff.periodStartedRecordId,
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
    expect(elapsed.formalSuspensionActive, isTrue);
    expect(elapsed.suspensionStarted, isTrue);
    expect(elapsed.suspensionDurationOpen, isTrue);
    expect(elapsed.exactElapsed, const Duration(seconds: 12));
    expect(await _records(reopened), hasLength(3));

    final records = await _records(reopened);
    final boundaryId = records.last.temporalContext!.evidenceIds.single;
    final file = File('${temp.path}/forref_temporal_evidence.json');
    final decoded =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final artifacts = decoded['artifacts']! as List<dynamic>;
    for (final item in artifacts) {
      final artifact = item as Map<String, dynamic>;
      if (artifact['evidenceId'] == boundaryId) {
        artifact['continuityDomainId'] = 'domain-other';
      }
    }
    await file.writeAsString(jsonEncode(decoded));

    final degraded = await _elapsed(reopened, restarted);
    expect(degraded.formalSuspensionActive, isTrue);
    expect(degraded.suspensionStarted, isTrue);
    expect(degraded.exactElapsed, isNull);
    expect(
      degraded.continuity,
      TemporalContinuityStatus.continuityUnresolved,
    );
    expect(degraded.precisionSafeToShow, isFalse);
  });

  test('suspend action source does not write legacy pause', () {
    final page = File(
      'lib/features/live_match/live_match_page.dart',
    ).readAsStringSync();
    final suspend = RegExp(
      r'Future<void> _suspendMatch[\s\S]*?\n  \}',
    ).firstMatch(page)!.group(0)!;

    expect(suspend, contains('commitTemporarySuspensionStarted'));
    expect(suspend, isNot(contains('.pause')));
    expect(suspend, isNot(contains('clockRunning')));
    expect(suspend, isNot(contains('elapsedSeconds')));
    expect(page, isNot(contains('currentState.elapsedSeconds')));
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

Future<List<MatchRecord>> _records(MatchApplicationComposition composition) {
  return composition.boundary.durableStore.readCommittedForMatch('match-1');
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

bool _isSuspension(MatchRecord record) {
  final payload = record.payload;
  return payload is TemporalTransitionPayload &&
      payload.semanticType == V1SemanticTypeCode.temporarySuspensionStarted;
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
