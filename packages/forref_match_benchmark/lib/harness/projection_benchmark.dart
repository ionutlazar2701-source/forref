import 'package:forref_match_core/forref_match_core.dart';

import '../fixtures/match_record_fixtures.dart';
import '../stats.dart';

/// Deterministic projection rebuild benchmarks.
final class ProjectionBenchmark {
  ProjectionBenchmark({
    this.warmUp = 5,
    this.samplesPerSize = 30,
    this.sizes = const [25, 100, 500, 1000, 5000],
  });

  final int warmUp;
  final int samplesPerSize;
  final List<int> sizes;

  Map<String, Object?> run() {
    final projector = DeterministicMatchProjector(ProductionSemanticsResolver());
    const context = ProjectionContext(
      evaluatedAuthorityGeneration: MatchRecordFixtures.authorityGeneration,
    );
    final bySize = <String, Object?>{};
    final shapePoints = <(int, int)>[];

    for (final size in sizes) {
      final records = MatchRecordFixtures.scenarioCSynthetic(count: size);
      for (var i = 0; i < warmUp; i++) {
        projector.projectRecords(
          matchId: MatchRecordFixtures.matchId,
          records: records,
          context: context,
        );
      }

      final rssBefore = rssBytes();
      final samples = <int>[];
      for (var i = 0; i < samplesPerSize; i++) {
        final stopwatch = Stopwatch()..start();
        projector.projectRecords(
          matchId: MatchRecordFixtures.matchId,
          records: records,
          context: context,
        );
        stopwatch.stop();
        samples.add(stopwatch.elapsedMicroseconds);
      }
      final rssAfter = rssBytes();
      final stats = LatencyStats(samples);
      shapePoints.add((size, stats.p50));

      bySize['$size'] = {
        ...stats.toJson(),
        if (rssBefore != null && rssAfter != null)
          'approxAdditionalRssBytes': deltaRss(rssBefore, rssAfter),
        if (rssBefore == null) 'memoryNote': 'ProcessInfo.currentRss unavailable',
      };
    }

    return {
      'warmUpCount': warmUp,
      'samplesPerSize': samplesPerSize,
      'byRecordCount': bySize,
      'complexityShapeEstimate': estimateComplexityShape(shapePoints),
      'note': 'Uses projectRecords (in-memory); no snapshots or caches added',
    };
  }
}
