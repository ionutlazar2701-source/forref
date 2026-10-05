import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:sqlite3/sqlite3.dart';

import '../fixtures/match_record_fixtures.dart';
import '../stats.dart';

/// Cold reopen / recovery benchmarks (close → reopen).
final class RecoveryBenchmark {
  RecoveryBenchmark({
    this.sizes = const [25, 100, 500, 1000, 5000],
    this.warmUp = 2,
    this.samples = 10,
  });

  final List<int> sizes;
  final int warmUp;
  final int samples;

  Future<Map<String, Object?>> run(Directory tempRoot) async {
    final bySize = <String, Object?>{};
    final projector = DeterministicMatchProjector(ProductionSemanticsResolver());
    const projectionContext = ProjectionContext(
      evaluatedAuthorityGeneration: MatchRecordFixtures.authorityGeneration,
    );

    for (final size in sizes) {
      final file = File('${tempRoot.path}/recovery_$size.sqlite');
      await _seedDatabase(file, size);

      final openSamples = <int>[];
      final fetchSamples = <int>[];
      final decodeSamples = <int>[];
      final projectionSamples = <int>[];
      final continuitySamples = <int>[];
      final totalSamples = <int>[];

      for (var run = 0; run < warmUp + samples; run++) {
        final totalStopwatch = Stopwatch()..start();

        final openStopwatch = Stopwatch()..start();
        final store = SqliteDurableMatchStore.open(file);
        openStopwatch.stop();

        final fetchStopwatch = Stopwatch()..start();
        final rows = _fetchRawJsonFromFile(file);
        fetchStopwatch.stop();

        final decodeStopwatch = Stopwatch()..start();
        final records = [
          for (final json in rows) decodeMatchRecordFromStorage(json),
        ];
        decodeStopwatch.stop();

        final projectionStopwatch = Stopwatch()..start();
        final projection = projector.projectRecords(
          matchId: MatchRecordFixtures.matchId,
          records: records,
          context: projectionContext,
        );
        projectionStopwatch.stop();

        final continuityStopwatch = Stopwatch()..start();
        final temporal = TemporalMatchProjection.derive(
          projection: projection,
          records: records,
        );
        // Continuity evaluation proxy: deriveActivePeriodElapsed without evidence.
        deriveActivePeriodElapsed(
          temporal: temporal,
          projection: projection,
          records: records,
          anchor: _recoveryAnchor(),
          current: _recoveryLiveObservation(),
        );
        continuityStopwatch.stop();

        await store.close();
        totalStopwatch.stop();

        if (run >= warmUp) {
          openSamples.add(openStopwatch.elapsedMicroseconds);
          fetchSamples.add(fetchStopwatch.elapsedMicroseconds);
          decodeSamples.add(decodeStopwatch.elapsedMicroseconds);
          projectionSamples.add(projectionStopwatch.elapsedMicroseconds);
          continuitySamples.add(continuityStopwatch.elapsedMicroseconds);
          totalSamples.add(totalStopwatch.elapsedMicroseconds);
        }
      }

      bySize['$size'] = {
        'warmUpCount': warmUp,
        'sampleCount': samples,
        'databasePath': file.path,
        'sqliteOpenRecovery': LatencyStats(openSamples).toJson(),
        'rowFetch': LatencyStats(fetchSamples).toJson(),
        'decodeValidation': LatencyStats(decodeSamples).toJson(),
        'projectionRebuild': LatencyStats(projectionSamples).toJson(),
        'temporalContinuityEvaluation': LatencyStats(continuitySamples).toJson(),
        'totalUsableStateLatency': LatencyStats(totalSamples).toJson(),
      };
    }

    return {
      'method': 'close/reopen via SqliteDurableMatchStore.open',
      'byRecordCount': bySize,
    };
  }

  Future<void> _seedDatabase(File file, int size) async {
    if (file.existsSync()) file.deleteSync();
    final store = SqliteDurableMatchStore.open(file);
    final records = MatchRecordFixtures.scenarioCSynthetic(count: size);
    for (final record in records) {
      final outcome = await store.commit(record);
      if (outcome is! DurableCommitSuccess) {
        throw StateError('Seed failed at size $size: $outcome');
      }
    }
    await store.close();
  }

  List<String> _fetchRawJsonFromFile(File file) {
    final db = sqlite3.open(file.path);
    final rows = db.select(
      '''
      SELECT record_json FROM committed_match_records
      WHERE match_id = ?
      ORDER BY rowid
      ''',
      [MatchRecordFixtures.matchId],
    );
    db.close();
    return [for (final row in rows) row.columnAt(0) as String];
  }
}

TemporalEvidence _recoveryAnchor() {
  return TemporalEvidence(
    evidenceId: 'recovery-anchor',
    capturedAt: DateTime.utc(2026, 10, 4, 12),
    continuityDomainId: 'recovery-domain',
    monotonicElapsed: Duration.zero,
    certified: false,
  );
}

TemporalEvidence _recoveryLiveObservation() {
  return TemporalEvidence(
    evidenceId: 'phone-live-monotonic',
    capturedAt: DateTime.utc(2026, 10, 4, 12, 30),
    continuityDomainId: 'recovery-domain',
    monotonicElapsed: const Duration(minutes: 30),
    certified: false,
  );
}
