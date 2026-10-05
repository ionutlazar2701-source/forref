import 'dart:io';

/// Latency sample collector for benchmark runs.
final class LatencyStats {
  LatencyStats(this.samplesMicros);

  final List<int> samplesMicros;

  int get count => samplesMicros.length;

  int get minimum =>
      samplesMicros.isEmpty ? 0 : samplesMicros.reduce(mathMin);

  int get maximum =>
      samplesMicros.isEmpty ? 0 : samplesMicros.reduce(mathMax);

  int get p50 => _percentile(50);

  int get p95 => _percentile(95);

  int? get p99 => count >= 20 ? _percentile(99) : null;

  int _percentile(int p) {
    if (samplesMicros.isEmpty) return 0;
    final sorted = [...samplesMicros]..sort();
    final rank = (p / 100.0) * (sorted.length - 1);
    final lower = rank.floor();
    final upper = rank.ceil();
    if (lower == upper) return sorted[lower];
    final weight = rank - lower;
    return (sorted[lower] * (1 - weight) + sorted[upper] * weight).round();
  }

  Map<String, Object?> toJson({String unit = 'microseconds'}) => {
        'count': count,
        'unit': unit,
        'p50': p50,
        'p95': p95,
        if (p99 != null) 'p99': p99,
        'max': maximum,
        'min': minimum,
      };
}

/// Runs [action] [warmUp] times then collects [samples] timed runs.
LatencyStats benchmarkVoid({
  required int warmUp,
  required int samples,
  required void Function() action,
}) {
  for (var i = 0; i < warmUp; i++) {
    action();
  }
  final collected = <int>[];
  for (var i = 0; i < samples; i++) {
    final stopwatch = Stopwatch()..start();
    action();
    stopwatch.stop();
    collected.add(stopwatch.elapsedMicroseconds);
  }
  return LatencyStats(collected);
}

/// Runs [action] [warmUp] times then collects [samples] timed runs.
LatencyStats benchmark({
  required int warmUp,
  required int samples,
  required int Function() action,
}) {
  return benchmarkVoid(
    warmUp: warmUp,
    samples: samples,
    action: () {
      action();
    },
  );
}

/// Async variant of [benchmark].
Future<LatencyStats> benchmarkAsync({
  required int warmUp,
  required int samples,
  required Future<void> Function() action,
}) async {
  for (var i = 0; i < warmUp; i++) {
    await action();
  }
  final collected = <int>[];
  for (var i = 0; i < samples; i++) {
    final stopwatch = Stopwatch()..start();
    await action();
    stopwatch.stop();
    collected.add(stopwatch.elapsedMicroseconds);
  }
  return LatencyStats(collected);
}

/// Estimates complexity shape from size→median pairs.
String estimateComplexityShape(List<(int size, int medianMicros)> points) {
  if (points.length < 2) return 'insufficient data';
  final ratios = <double>[];
  for (var i = 1; i < points.length; i++) {
    final prev = points[i - 1];
    final curr = points[i];
    if (prev.$1 == 0 || prev.$2 == 0) continue;
    final sizeRatio = curr.$1 / prev.$1;
    final timeRatio = curr.$2 / prev.$2;
    ratios.add(timeRatio / sizeRatio);
  }
  if (ratios.isEmpty) return 'insufficient data';
  final avg = ratios.reduce((a, b) => a + b) / ratios.length;
  if (avg < 0.3) return 'sub-linear (possible caching or fixed overhead dominates)';
  if (avg <= 1.5) return 'O(N) — median grows roughly linearly with record count';
  if (avg <= 2.5) {
    return 'O(N log N) or worse — median grows faster than linear';
  }
  return 'super-linear (worse than O(N log N))';
}

int? rssBytes() {
  try {
    // ignore: deprecated_member_use
    return ProcessInfo.currentRss;
  } catch (_) {
    return null;
  }
}

int deltaRss(int before, int after) => mathMax(0, after - before);

int mathMin(int a, int b) => a < b ? a : b;

int mathMax(int a, int b) => a > b ? a : b;
