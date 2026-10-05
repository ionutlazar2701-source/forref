import 'package:forref_match_core/forref_match_core.dart';

import '../fixtures/match_record_fixtures.dart';
import '../stats.dart';

/// Simulates live_match_page _onClockTick path with operation counters.
final class TickerTraceHarness {
  Map<String, Object?> run() {
    final records = MatchRecordFixtures.scenarioANormalTimeline();
    final projector = DeterministicMatchProjector(ProductionSemanticsResolver());
    const context = ProjectionContext(
      evaluatedAuthorityGeneration: MatchRecordFixtures.authorityGeneration,
    );

    // Simulate _refreshTemporal (full refresh — NOT the tick path).
    var dbReadsOnRefresh = 0;
    var projectorCallsOnRefresh = 0;
    var jsonDecodesOnRefresh = 0;

    dbReadsOnRefresh++; // readCommittedForMatch
    projectorCallsOnRefresh++;
    final projection = projector.projectRecords(
      matchId: MatchRecordFixtures.matchId,
      records: records,
      context: context,
    );
    jsonDecodesOnRefresh += records.length;

    final temporal = TemporalMatchProjection.derive(
      projection: projection,
      records: records,
    );

    // Cached state after refresh (mirrors live_match_page fields).
    final cachedProjection = projection;
    final cachedTemporal = temporal;
    final cachedRecords = records;
    final cachedAnchor = _syntheticAnchor();
    final cachedSuspensionBoundary = null as TemporalEvidence?;
    final cachedResumptionAnchor = null as TemporalEvidence?;
    final cachedRecordedEvidence = <TemporalEvidence>[];

    // Simulate 60 one-second ticks.
    var dbReadsPerTick = 0;
    var projectorCallsPerTick = 0;
    var jsonDecodesPerTick = 0;
    var evidenceReadsPerTick = 0;
    var elapsedCallsPerTick = 0;
    var setStateCallsPerTick = 1; // one rebuild scope per tick

    final tickLatencies = <int>[];
    for (var tick = 0; tick < 60; tick++) {
      final stopwatch = Stopwatch()..start();

      // Mirrors PhoneTemporalEvidenceStore.currentObservation() — in-memory only.
      evidenceReadsPerTick++;
      final current = _syntheticLiveObservation(tick);

      elapsedCallsPerTick++;
      deriveActivePeriodElapsed(
        temporal: cachedTemporal,
        projection: cachedProjection,
        records: cachedRecords,
        anchor: cachedAnchor,
        current: current,
        suspensionBoundary: cachedSuspensionBoundary,
        resumptionAnchor: cachedResumptionAnchor,
        recordedEvidence: cachedRecordedEvidence,
      );

      stopwatch.stop();
      tickLatencies.add(stopwatch.elapsedMicroseconds);
    }

    final stats = LatencyStats(tickLatencies);

    return {
      'sourceReference':
          'apps/referee_phone/lib/features/live_match/live_match_page.dart _onClockTick',
      'tickerCadence': '1 second (unchanged; simulated 60 ticks)',
      'perTick': {
        'dbReads': dbReadsPerTick ~/ 60,
        'projectorCalls': projectorCallsPerTick ~/ 60,
        'jsonDecodes': jsonDecodesPerTick ~/ 60,
        'temporalEvidenceReads': evidenceReadsPerTick ~/ 60,
        'deriveActivePeriodElapsedCalls': elapsedCallsPerTick ~/ 60,
        'setStateRebuildScope': 'LiveMatchPage setState (1 widget subtree)',
        'setStateCallsPerTick': setStateCallsPerTick,
      },
      'onRefreshTemporalBaseline': {
        'dbReads': dbReadsOnRefresh,
        'projectorCalls': projectorCallsOnRefresh,
        'jsonDecodes': jsonDecodesOnRefresh,
        'note': '_refreshTemporal runs on commit/navigation; not on tick',
      },
      'tickLatencyMicros': stats.toJson(),
      'staticAnalysis': {
        '_onClockTick': [
          'No SQLite reads',
          'No Match Memory full reads',
          'No JSON decode',
          'No DeterministicMatchProjector invocation',
          'TemporalEvidence.currentObservation() only (in-process clock)',
          'deriveActivePeriodElapsed arithmetic',
          'setState rebuild of LiveMatchPage',
        ],
      },
      'allocationsNote':
          'Per-tick heap delta not available via standard Dart APIs; tick path reuses cached List<MatchRecord> and MatchProjectionState',
    };
  }

  static TemporalEvidence _syntheticAnchor() {
    return TemporalEvidence(
      evidenceId: 'anchor-1',
      capturedAt: DateTime.utc(2026, 10, 4, 12),
      continuityDomainId: 'domain-bench',
      monotonicElapsed: Duration.zero,
      certified: false,
    );
  }

  static TemporalEvidence _syntheticLiveObservation(int tick) {
    return TemporalEvidence(
      evidenceId: 'phone-live-monotonic',
      capturedAt: DateTime.utc(2026, 10, 4, 12, 0, tick),
      continuityDomainId: 'domain-bench',
      monotonicElapsed: Duration(seconds: tick),
      certified: false,
    );
  }
}
