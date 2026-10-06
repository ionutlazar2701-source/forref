import 'dart:convert';
import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/infrastructure/temporal/phone_temporal_evidence_store.dart';
import 'package:referee_phone/match_application/kick_off_authority.dart';
import 'package:test/test.dart';

/// CLOUD ENGINEERING BASELINE. NOT PHONE HARDWARE CERTIFICATION.
///
/// Measurement only. No latency gate. SQLite durability is unchanged.
void main() {
  test('goal authoritative path cloud engineering baseline', () async {
    final temp = await Directory.systemTemp.createTemp('goal_perf_');
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final clock = _Clock();
    final evidence = PhoneTemporalEvidenceStore(storageRoot: temp, clock: clock);
    final context = identity.contextFor('match-perf');

    final kickOff = await composition.boundary.commitKickOff(
      context,
      period: const PeriodIdentity(index: 1),
      periodAnchor: () async {
        final captured = await evidence.captureAnchor();
        return TemporalContext(
          evidenceIds: [captured.evidenceId],
          domainClockPolicyVersion:
              PhoneCaptureIdentity.domainClockContract.value,
        );
      },
    );
    expect(kickOff, isA<KickOffAuthorityCommitted>());

    const checkpoints = {1, 10, 50, 100};
    final commitMicros = <int>[];
    final refreshAt = <String, int>{};
    for (var i = 1; i <= 100; i++) {
      clock.elapsed = Duration(seconds: i);
      final started = Stopwatch()..start();
      final captured = await evidence.captureAnchor();
      final result = await composition.boundary.commitGoal(
        context,
        creditedSide: i.isEven ? CreditedSide.away : CreditedSide.home,
        captureIntentId: 'perf-$i',
        temporalContext: TemporalContext(
          evidenceIds: [captured.evidenceId],
          domainClockPolicyVersion:
              PhoneCaptureIdentity.domainClockContract.value,
        ),
      );
      started.stop();
      expect(result, isA<DurableCommitSuccess>());
      commitMicros.add(started.elapsedMicroseconds);
      if (checkpoints.contains(i)) {
        refreshAt['$i'] = await _refreshMicros(
          composition: composition,
          evidence: evidence,
          matchId: context.matchId,
        );
      }
    }

    final d1 = await _prebuiltD1Micros(
      composition: composition,
      context: context,
      samples: 20,
    );

    final projection = <String, Map<String, Object?>>{};
    for (final size in [10, 50, 100, 500]) {
      projection['$size'] = _projectionMicros(size);
    }

    final report = <String, Object?>{
      'label': 'CLOUD ENGINEERING BASELINE',
      'certification': 'NOT PHONE HARDWARE CERTIFICATION',
      'sqliteDurability': 'unchanged journal_mode=DELETE synchronous=FULL',
      'goalCommitIncludes':
          'capture anchor file write, admission preview read, record build, D1',
      'goalCommitMicroseconds': _stats(commitMicros),
      'goalCommitFirst5Microseconds': _stats(commitMicros.take(5).toList()),
      'goalCommitLast5Microseconds': _stats(commitMicros.skip(95).toList()),
      'projectionRefreshAfterGoalsMicroseconds': refreshAt,
      'projectionRefreshIncludes':
          'boundary.project, readCommittedForMatch, resolve every stored evidence id, GoalMatchProjection.derive. Excludes widget build.',
      'prebuiltGoalD1Microseconds': _stats(d1),
      'prebuiltGoalD1Note':
          'commitAtNextOriginSequence of an already built GOAL after 100 committed goals. Excludes admission preview.',
      'inMemoryGoalProjectionMicroseconds': projection,
      'matchMemoryReadsPerGoalRefresh': {
        'commitGoalPreviewRead': 1,
        'transactionalReadInsideD1': 1,
        'boundaryProjectRead': 1,
        'refreshReadCommittedForMatch': 1,
        'evidenceResolvePerDistinctEvidenceId':
            'one file read per id, including the full goal history',
      },
      'ticker':
          'LiveMatchPage._onClockTick recomputes ActivePeriodElapsed from cached records and does not call GoalMatchProjection.derive',
      'fullHistoryReplay':
          'Each Goal D1 refresh re-reads the match and re-derives GoalMatchProjection from the full record list. The 1s clock tick does not.',
    };

    final encoded = const JsonEncoder.withIndent('  ').convert(report);
    // ignore: avoid_print
    print(encoded);
    try {
      final out = Directory('/opt/cursor/artifacts');
      if (!out.existsSync()) out.createSync(recursive: true);
      File('${out.path}/goal_performance_baseline.json').writeAsStringSync(
        encoded,
      );
    } on FileSystemException {
      // Artifact mount may be unavailable in some cloud runs; stdout report suffices.
    }

    await composition.close();
    temp.deleteSync(recursive: true);
  });
}

Future<int> _refreshMicros({
  required MatchApplicationComposition composition,
  required PhoneTemporalEvidenceStore evidence,
  required String matchId,
}) async {
  final started = Stopwatch()..start();
  await composition.boundary.project(
    matchId,
    evaluatedAuthorityGeneration: 1,
  );
  final records = await composition.boundary.durableStore.readCommittedForMatch(
    matchId,
  );
  final resolved = <TemporalEvidence>[];
  final ids = <String>{
    for (final record in records) ...?record.temporalContext?.evidenceIds,
  };
  for (final id in ids) {
    final item = await evidence.resolve(id);
    if (item != null) resolved.add(item);
  }
  final projection = GoalMatchProjection.derive(
    records: records,
    evidence: resolved,
  );
  started.stop();
  expect(projection.homeScore + projection.awayScore, records.length - 2);
  return started.elapsedMicroseconds;
}

Future<List<int>> _prebuiltD1Micros({
  required MatchApplicationComposition composition,
  required CaptureContext context,
  required int samples,
}) async {
  final samplesMicros = <int>[];
  for (var i = 0; i < samples; i++) {
    final request = composition.boundary.recordBuilder.build(
      context: context,
      recordKind: RecordKind.humanDetermination,
      payload: GoalPayload(
        creditedSide: CreditedSide.home,
        captureIntentId: 'd1-only-$i',
      ),
      integrity: const IntegrityMetadata(),
      temporalContext: TemporalContext(
        evidenceIds: ['d1-evidence-$i'],
        domainClockPolicyVersion: PhoneCaptureIdentity.domainClockContract.value,
      ),
    );
    final started = Stopwatch()..start();
    final result = await composition.boundary.durableStore
        .commitAtNextOriginSequence(request);
    started.stop();
    expect(result, isA<DurableCommitSuccess>());
    samplesMicros.add(started.elapsedMicroseconds);
  }
  return samplesMicros;
}

Map<String, Object?> _projectionMicros(int goals) {
  final evidence = <TemporalEvidence>[
    TemporalEvidence(
      evidenceId: 'anchor',
      capturedAt: DateTime.utc(2026, 10, 5),
      continuityDomainId: 'domain-perf',
      monotonicElapsed: Duration.zero,
    ),
  ];
  final records = <MatchRecord>[
    MatchRecord(
      recordId: 'start',
      matchId: 'match-perf',
      recordKind: RecordKind.temporalFact,
      schemaVersion: 1,
      recordedAt: DateTime.utc(2026, 10, 5),
      originDeviceId: 'dev',
      originSequence: 1,
      payload: TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.matchStarted,
      ),
      integrity: const IntegrityMetadata(),
    ),
    MatchRecord(
      recordId: 'period',
      matchId: 'match-perf',
      recordKind: RecordKind.temporalFact,
      schemaVersion: 1,
      recordedAt: DateTime.utc(2026, 10, 5),
      originDeviceId: 'dev',
      originSequence: 2,
      payload: TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.periodStarted,
        period: const PeriodIdentity(index: 1),
      ),
      integrity: const IntegrityMetadata(),
      relationships: [const CausalDependency(targetRecordId: 'start')],
      temporalContext: const TemporalContext(evidenceIds: ['anchor']),
    ),
  ];
  for (var i = 0; i < goals; i++) {
    final evidenceId = 'ev-$i';
    evidence.add(
      TemporalEvidence(
        evidenceId: evidenceId,
        capturedAt: DateTime.utc(2026, 10, 5),
        continuityDomainId: 'domain-perf',
        monotonicElapsed: Duration(seconds: i + 1),
      ),
    );
    records.add(
      MatchRecord(
        recordId: 'goal-$i',
        matchId: 'match-perf',
        recordKind: RecordKind.humanDetermination,
        schemaVersion: 1,
        recordedAt: DateTime.utc(2026, 10, 5, 12, i),
        originDeviceId: 'dev',
        originSequence: i + 3,
        payload: GoalPayload(
          creditedSide: i.isEven ? CreditedSide.home : CreditedSide.away,
          captureIntentId: 'synthetic-$i',
        ),
        integrity: const IntegrityMetadata(),
        relationships: [const CausalDependency(targetRecordId: 'period')],
        temporalContext: TemporalContext(evidenceIds: [evidenceId]),
        authorityContext: const AuthorityContext(
          scope: MainRefereeScope(),
          principal: AuthorityPrincipal(principalId: 'ref'),
          generation: AuthorityGeneration(value: 1),
        ),
      ),
    );
  }

  for (var i = 0; i < 3; i++) {
    GoalMatchProjection.derive(records: records, evidence: evidence);
  }
  final samples = <int>[];
  for (var i = 0; i < 20; i++) {
    final started = Stopwatch()..start();
    final projection = GoalMatchProjection.derive(
      records: records,
      evidence: evidence,
    );
    started.stop();
    expect(projection.goals, hasLength(goals));
    samples.add(started.elapsedMicroseconds);
  }
  return _stats(samples);
}

Map<String, Object?> _stats(List<int> samples) {
  final sorted = [...samples]..sort();
  int percentile(int p) {
    final rank = (p / 100 * (sorted.length - 1)).round();
    return sorted[rank];
  }

  return {
    'count': samples.length,
    'unit': 'microseconds',
    'min': sorted.first,
    'p50': percentile(50),
    'p95': percentile(95),
    'max': sorted.last,
  };
}

final class _Clock implements MonotonicContinuityClock {
  Duration elapsed = Duration.zero;

  @override
  String get continuityDomainId => 'domain-perf';

  @override
  Duration get monotonicElapsed => elapsed;

  @override
  DateTime get chronology => DateTime.utc(2026, 10, 5, 12);
}
