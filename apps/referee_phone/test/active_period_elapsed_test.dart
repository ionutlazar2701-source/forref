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
    temp = await Directory.systemTemp.createTemp('period_elapsed_');
  });

  tearDown(() async {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('period anchor plus live evidence derives elapsed and ticking writes nothing', () async {
    final clock = ManualContinuityClock();
    final evidence = PhoneTemporalEvidenceStore(storageRoot: temp, clock: clock);
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();

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

    clock.elapsed = const Duration(seconds: 12);
    clock.wallChronology = DateTime.utc(2020, 1, 1);
    final elapsed = await _elapsed(composition, evidence);

    expect(elapsed.exactElapsed, const Duration(seconds: 12));
    expect(elapsed.continuity, TemporalContinuityStatus.exactContinuity);
    expect(elapsed.certified, isFalse);
    final records = await composition.boundary.durableStore.readCommittedForMatch(
      'match-1',
    );
    expect(records, hasLength(2));
    expect(records.last.temporalContext!.evidenceIds, hasLength(1));
    final stored = await File('${temp.path}/forref_temporal_evidence.json')
        .readAsString();
    expect(stored, isNot(contains('elapsedSeconds')));
    expect('phone-live-monotonic'.allMatches(stored), isEmpty);

    clock.elapsed = const Duration(minutes: 45, seconds: 1);
    final atRegulation = await _elapsed(composition, evidence);
    expect(atRegulation.pastRegulationDisplayThreshold, isTrue);
    expect(
      await composition.boundary.durableStore.readCommittedForMatch('match-1'),
      hasLength(2),
    );
    expect(
      (await composition.boundary.durableStore.readCommittedForMatch('match-1'))
          .any(_isPeriodEnded),
      isFalse,
    );
  });

  test('reopen with a new continuity domain does not invent exact elapsed', () async {
    final firstClock = ManualContinuityClock(domainId: 'domain-a');
    final first = PhoneTemporalEvidenceStore(
      storageRoot: temp,
      clock: firstClock,
    );
    final anchor = await first.captureAnchor();
    firstClock.elapsed = const Duration(minutes: 10);

    final reopened = PhoneTemporalEvidenceStore(
      storageRoot: temp,
      clock: ManualContinuityClock(domainId: 'domain-b')
        ..elapsed = const Duration(seconds: 1)
        ..wallChronology = DateTime.utc(2026, 10, 3, 13),
    );
    final loaded = await reopened.resolve(anchor.evidenceId);
    final live = reopened.currentObservation();
    final records = _records(anchor.evidenceId);
    final projection = DeterministicMatchProjector(ProductionSemanticsResolver())
        .projectRecords(
      matchId: 'match-1',
      records: records,
      context: const ProjectionContext(evaluatedAuthorityGeneration: 1),
    );
    final elapsed = deriveActivePeriodElapsed(
      temporal: TemporalMatchProjection.derive(
        projection: projection,
        records: records,
      ),
      projection: projection,
      records: records,
      anchor: loaded,
      current: live,
    );

    expect(loaded!.continuityDomainId, 'domain-a');
    expect(live.continuityDomainId, 'domain-b');
    expect(elapsed.exactElapsed, isNull);
    expect(
      elapsed.continuity,
      TemporalContinuityStatus.continuityUnresolved,
    );
    expect(elapsed.precisionSafeToShow, isFalse);
  });

  test('cut-over clock source does not read legacy elapsed or commit on tick', () {
    final page = File('lib/features/live_match/live_match_page.dart')
        .readAsStringSync();
    final clockLabel = RegExp(
      r'String _cutOverClockLabel[\s\S]*?\n  \}',
    ).firstMatch(page)!.group(0)!;
    final tick = RegExp(
      r'void _onClockTick[\s\S]*?\n  \}',
    ).firstMatch(page)!.group(0)!;

    expect(clockLabel, isNot(contains('displayedElapsed')));
    expect(clockLabel, isNot(contains('elapsedSeconds')));
    expect(tick, contains('deriveActivePeriodElapsed'));
    expect(tick, isNot(contains('commit')));
    expect(tick, isNot(contains('captureAnchor')));
    expect(tick, isNot(contains('upsertMatch')));
    expect(page, isNot(contains('currentState.elapsedSeconds')));
  });
}

Future<ActivePeriodElapsedProjection> _elapsed(
  MatchApplicationComposition composition,
  PhoneTemporalEvidenceStore evidence,
) async {
  final records = await composition.boundary.durableStore.readCommittedForMatch(
    'match-1',
  );
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

List<MatchRecord> _records(String anchorId) {
  return [
    MatchRecord(
      recordId: 'start',
      matchId: 'match-1',
      recordKind: RecordKind.temporalFact,
      schemaVersion: 1,
      recordedAt: DateTime.utc(2026, 10, 3),
      originDeviceId: 'dev-a',
      originSequence: 1,
      payload: TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.matchStarted,
      ),
      integrity: const IntegrityMetadata(),
    ),
    MatchRecord(
      recordId: 'period',
      matchId: 'match-1',
      recordKind: RecordKind.temporalFact,
      schemaVersion: 1,
      recordedAt: DateTime.utc(2026, 10, 3, 0, 1),
      originDeviceId: 'dev-a',
      originSequence: 2,
      payload: TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.periodStarted,
        period: const PeriodIdentity(index: 1),
      ),
      integrity: const IntegrityMetadata(),
      relationships: [CausalDependency(targetRecordId: 'start')],
      temporalContext: TemporalContext(evidenceIds: [anchorId]),
    ),
  ];
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
