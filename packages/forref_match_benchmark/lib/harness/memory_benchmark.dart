import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';

import '../fixtures/match_record_fixtures.dart';
import '../stats.dart';

/// Memory / heap observations around key lifecycle phases.
final class MemoryBenchmark {
  Future<Map<String, Object?>> run(Directory tempRoot) async {
    final rssAvailable = rssBytes() != null;

    final normalMatch = await _normalTemporalLifecycle(tempRoot);
    final synthetic5000 = await _synthetic5000History(tempRoot);

    return {
      'rssAvailable': rssAvailable,
      'measurementMethod': rssAvailable
          ? 'ProcessInfo.currentRss delta (VM-level, approximate)'
          : 'ProcessInfo.currentRss unavailable in this environment',
      'normalTemporalMatch': normalMatch,
      'synthetic5000RecordHistory': synthetic5000,
    };
  }

  Future<Map<String, Object?>> _normalTemporalLifecycle(Directory tempRoot) async {
    final file = File('${tempRoot.path}/memory_normal.sqlite');
    final baseline = rssBytes();
    final store = SqliteDurableMatchStore.open(file);

    final afterOpen = rssBytes();
    final records = MatchRecordFixtures.scenarioANormalTimeline();
    for (final record in records) {
      await store.commit(record);
    }
    final afterCommit = rssBytes();

    final fetched = await store.readCommittedForMatch(MatchRecordFixtures.matchId);
    final afterFetch = rssBytes();

    final decoded = [
      for (final record in fetched)
        decodeMatchRecordFromStorage(encodeMatchRecordJson(record)),
    ];
    final afterDecode = rssBytes();

    final projector = DeterministicMatchProjector(ProductionSemanticsResolver());
    final projection = projector.projectRecords(
      matchId: MatchRecordFixtures.matchId,
      records: decoded,
      context: const ProjectionContext(
        evaluatedAuthorityGeneration: MatchRecordFixtures.authorityGeneration,
      ),
    );
    final temporal = TemporalMatchProjection.derive(
      projection: projection,
      records: decoded,
    );
    deriveActivePeriodElapsed(
      temporal: temporal,
      projection: projection,
      records: decoded,
      anchor: _benchAnchor(),
      current: _benchLiveObservation(30),
    );
    final afterProjection = rssBytes();

    await store.close();
    final afterClose = rssBytes();

    return _phaseDeltas({
      'baseline': baseline,
      'afterSqliteOpen': afterOpen,
      'afterScenarioACommits': afterCommit,
      'afterRowFetch': afterFetch,
      'afterDecode': afterDecode,
      'afterProjectionAndContinuity': afterProjection,
      'afterClose': afterClose,
    });
  }

  Future<Map<String, Object?>> _synthetic5000History(Directory tempRoot) async {
    final file = File('${tempRoot.path}/memory_5000.sqlite');
    final baseline = rssBytes();

    final store = SqliteDurableMatchStore.open(file);
    final records = MatchRecordFixtures.scenarioCSynthetic(count: 5000);
    for (final record in records) {
      await store.commit(record);
    }
    final afterSeed = rssBytes();

    await store.close();
    final reopened = SqliteDurableMatchStore.open(file);
    final afterReopen = rssBytes();

    final fetched = await reopened.readCommittedForMatch(MatchRecordFixtures.matchId);
    final afterFetch = rssBytes();

    final decoded = [
      for (final record in fetched) decodeMatchRecordFromStorage(encodeMatchRecordJson(record)),
    ];
    final afterDecode = rssBytes();

    final sorted = List<MatchRecord>.from(decoded)
      ..sort((MatchRecord a, MatchRecord b) {
        final origin = a.originDeviceId.compareTo(b.originDeviceId);
        if (origin != 0) return origin;
        final sequence = a.originSequence.compareTo(b.originSequence);
        if (sequence != 0) return sequence;
        return a.recordId.compareTo(b.recordId);
      });
    final afterSorted = rssBytes();

    final projector = DeterministicMatchProjector(ProductionSemanticsResolver());
    projector.projectRecords(
      matchId: MatchRecordFixtures.matchId,
      records: sorted,
      context: const ProjectionContext(
        evaluatedAuthorityGeneration: MatchRecordFixtures.authorityGeneration,
      ),
    );
    final afterProjection = rssBytes();

    await reopened.close();
    final afterClose = rssBytes();

    return _phaseDeltas({
      'baseline': baseline,
      'after5000Commits': afterSeed,
      'afterCloseReopen': afterReopen,
      'afterRowRetrieval': afterFetch,
      'afterDecode': afterDecode,
      'afterSortedReplayRepresentation': afterSorted,
      'afterProjection': afterProjection,
      'afterClose': afterClose,
    });
  }

  Map<String, Object?> _phaseDeltas(Map<String, int?> phases) {
    final result = <String, Object?>{};
    int? previous;
    for (final entry in phases.entries) {
      result[entry.key] = entry.value;
      if (entry.value != null && previous != null) {
        result['deltaFromPrevious_${entry.key}'] =
            deltaRss(previous, entry.value!);
      }
      if (entry.value != null) previous = entry.value;
    }
    return result;
  }
}

TemporalEvidence _benchAnchor() {
  return TemporalEvidence(
    evidenceId: 'anchor-1',
    capturedAt: DateTime.utc(2026, 10, 4, 12),
    continuityDomainId: 'domain-bench',
    monotonicElapsed: Duration.zero,
    certified: false,
  );
}

TemporalEvidence _benchLiveObservation(int tick) {
  return TemporalEvidence(
    evidenceId: 'phone-live-monotonic',
    capturedAt: DateTime.utc(2026, 10, 4, 12, 0, tick),
    continuityDomainId: 'domain-bench',
    monotonicElapsed: Duration(seconds: tick),
    certified: false,
  );
}
