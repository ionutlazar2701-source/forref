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
    temp = await Directory.systemTemp.createTemp('interval_');
  });

  tearDown(() async {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('period end produces interval projection without a new record', () async {
    final clock = ManualContinuityClock();
    final evidence = PhoneTemporalEvidenceStore(storageRoot: temp, clock: clock);
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final kickOff = await _kickOff(composition, identity, evidence);
    clock.elapsed = const Duration(seconds: 18);
    expect(
      await _end(
        composition,
        identity,
        evidence,
        periodStartedRecordId: kickOff.periodStartedRecordId,
      ),
      isA<DurableCommitSuccess>(),
    );

    final records = await _records(composition);
    expect(records, hasLength(3));
    expect(records.where(_isPeriodEnded), hasLength(1));
    expect(
      V1SemanticTypeCode.values.map((code) => code.wireValue),
      isNot(contains('HALF_TIME')),
    );

    final temporal = await _temporal(composition);
    expect(temporal.intervalActive, isTrue);
    expect(temporal.activePeriod, isNull);
    expect(temporal.endedPeriod, const PeriodIdentity(index: 1));
    expect(temporal.formallySuspended, isFalse);

    final atEnd = await _elapsed(composition, evidence);
    expect(atEnd.activePeriod, isNull);
    expect(atEnd.periodEnded, isTrue);
    expect(atEnd.exactElapsed, const Duration(seconds: 18));
    expect(atEnd.formalSuspensionActive, isFalse);

    clock.elapsed = const Duration(minutes: 20);
    clock.wallChronology = DateTime.utc(2099);
    final later = await _elapsed(composition, evidence);
    expect(later.exactElapsed, const Duration(seconds: 18));
    expect(later, atEnd);
    expect(await _records(composition), hasLength(3));
  });

  test('reopen reconstructs interval and does not start period 2', () async {
    final clock = ManualContinuityClock(domainId: 'domain-a');
    final evidence = PhoneTemporalEvidenceStore(storageRoot: temp, clock: clock);
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final kickOff = await _kickOff(composition, identity, evidence);
    clock.elapsed = const Duration(seconds: 22);
    expect(
      await _end(
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
    final temporal = await _temporal(reopened);
    expect(temporal.intervalActive, isTrue);
    expect(temporal.activePeriod, isNull);
    expect(temporal.endedPeriod, const PeriodIdentity(index: 1));

    final elapsed = await _elapsed(reopened, restarted);
    expect(elapsed.activePeriod, isNull);
    expect(elapsed.exactElapsed, const Duration(seconds: 22));
    expect(elapsed.exactElapsed, isNot(const Duration(hours: 2)));
    expect((await _records(reopened)).where(_isPeriodStarted), hasLength(1));
    expect((await _records(reopened)).where(_isPeriodEnded), hasLength(1));
  });

  test('manual period 2 start in memory clears interval without auto-start', () async {
    final evidence = PhoneTemporalEvidenceStore(
      storageRoot: temp,
      clock: ManualContinuityClock(),
    );
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final kickOff = await _kickOff(composition, identity, evidence);
    expect(
      await _end(
        composition,
        identity,
        evidence,
        periodStartedRecordId: kickOff.periodStartedRecordId,
      ),
      isA<DurableCommitSuccess>(),
    );
    expect((await _temporal(composition)).intervalActive, isTrue);

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
    expect((await _temporal(composition)).intervalActive, isFalse);
    expect(await _records(composition), hasLength(4));
  });

  test('interval UI source does not call legacy half-time', () {
    final page = File(
      'lib/features/live_match/live_match_page.dart',
    ).readAsStringSync();
    expect(page, contains('intervalActive'));
    expect(page, contains('l10n.interval'));
    expect(page, contains('noActivePlayingPeriod'));
    final endPeriod = RegExp(
      r'Future<void> _endPeriod[\s\S]*?\n  \}',
    ).firstMatch(page)!.group(0)!;
    expect(endPeriod, isNot(contains('halfTime')));
    expect(endPeriod, isNot(contains('session.halfTime')));
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
