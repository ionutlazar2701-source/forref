import 'package:forref_match_persistence/forref_match_persistence.dart';

import '../fixtures/match_record_fixtures.dart';
import '../stats.dart';

/// Adapter-local V1 encoding/decoding microbenchmark.
final class EncodingBenchmark {
  EncodingBenchmark({
    this.warmUp = 20,
    this.samples = 200,
  });

  final int warmUp;
  final int samples;

  Map<String, Object?> run() {
    final record = MatchRecordFixtures.representativeProductionRecord();
    final encoded = encodeMatchRecordJson(record);

    final encodeStats = benchmarkVoid(
      warmUp: warmUp,
      samples: samples,
      action: () {
        encodeMatchRecordJson(record);
      },
    );

    final decodeStats = benchmarkVoid(
      warmUp: warmUp,
      samples: samples,
      action: () {
        decodeMatchRecordFromStorage(encoded);
      },
    );

    // Allocation proxy: repeated encode produces new strings each call.
    final allocationProxy = benchmark(
      warmUp: warmUp,
      samples: samples,
      action: () {
        final text = encodeMatchRecordJson(record);
        return text.length;
      },
    );

    return {
      'warmUpCount': warmUp,
      'sampleCount': samples,
      'encoding': adapterLocalStorageEncoding,
      'encodedByteLength': encoded.length,
      'encode': encodeStats.toJson(),
      'decode': decodeStats.toJson(),
      'encodeWithLengthCheckProxy': allocationProxy.toJson(),
      'allocationNote':
          'Dart VM does not expose per-call heap delta; encodeWithLengthCheckProxy measures full encode path including string allocation',
    };
  }
}
