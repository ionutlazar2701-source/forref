import 'dart:io';

import 'package:forref_match_benchmark/environment_info.dart';
import 'package:forref_match_benchmark/harness/d1_commit_benchmark.dart';
import 'package:forref_match_benchmark/harness/encoding_benchmark.dart';
import 'package:forref_match_benchmark/harness/memory_benchmark.dart';
import 'package:forref_match_benchmark/harness/projection_benchmark.dart';
import 'package:forref_match_benchmark/harness/recovery_benchmark.dart';
import 'package:forref_match_benchmark/harness/sqlite_profile.dart';
import 'package:forref_match_benchmark/harness/ticker_trace.dart';

/// PERF-MEASURE-001 — Baseline Benchmark Execution
Future<void> main(List<String> args) async {
  final artifactsRoot = Directory(
    args.isNotEmpty
        ? args.first
        : '${Directory.current.path}/tool/perf_measure_001/artifacts',
  );
  if (!artifactsRoot.existsSync()) {
    artifactsRoot.createSync(recursive: true);
  }

  final runDir = Directory(
    '${artifactsRoot.path}/run_${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-').split('.').first}',
  );
  runDir.createSync(recursive: true);

  final tempRoot = Directory('${runDir.path}/temp');
  tempRoot.createSync(recursive: true);

  stdout.writeln('PERF-MEASURE-001 starting…');
  stdout.writeln('Artifacts: ${runDir.path}');

  final environment = await EnvironmentInfo.collect(databaseRoot: tempRoot);

  stdout.writeln('[1/7] D1 commit benchmark…');
  final d1 = await D1CommitBenchmark().run(tempRoot);

  stdout.writeln('[2/7] Projection benchmark…');
  final projection = ProjectionBenchmark().run();

  stdout.writeln('[3/7] Ticker trace…');
  final ticker = TickerTraceHarness().run();

  stdout.writeln('[4/7] SQLite profile…');
  final sqlite = await SqliteProfileHarness().run(tempRoot);

  stdout.writeln('[5/7] Recovery benchmark…');
  final recovery = await RecoveryBenchmark().run(tempRoot);

  stdout.writeln('[6/7] Encoding microbenchmark…');
  final encoding = EncodingBenchmark().run();

  stdout.writeln('[7/7] Memory / heap…');
  final memory = await MemoryBenchmark().run(tempRoot);

  final report = {
    'task': 'PERF-MEASURE-001',
    'status': 'completed',
    'environment': environment.toJson(),
    'scenarios': {
      'A_normalMatchTimeline': 'MatchRecordFixtures.scenarioANormalTimeline',
      'B_suspensionHeavyTimeline': 'MatchRecordFixtures.scenarioBSuspensionHeavy',
      'C_synthetic5000': 'MatchRecordFixtures.scenarioCSynthetic',
      'D_fileBackedCloseReopen': 'RecoveryBenchmark',
    },
    'd1Commit': d1,
    'projection': projection,
    'tickerTrace': ticker,
    'sqliteProfile': sqlite,
    'recovery': recovery,
    'encoding': encoding,
    'memory': memory,
  };

  final jsonPath = File('${runDir.path}/perf_measure_001_raw.json');
  jsonPath.writeAsStringSync(jsonEncodePretty(report));

  final mdPath = File('${runDir.path}/perf_measure_001_report.md');
  mdPath.writeAsStringSync(_markdownReport(report, runDir.path));

  stdout.writeln('');
  stdout.writeln('STATUS: completed');
  stdout.writeln('JSON: ${jsonPath.path}');
  stdout.writeln('Report: ${mdPath.path}');
}

String _markdownReport(Map<String, Object?> report, String artifactDir) {
  final env = report['environment'] as Map<String, Object?>;
  final d1 = report['d1Commit'] as Map<String, Object?>;
  final projection = report['projection'] as Map<String, Object?>;
  final ticker = report['tickerTrace'] as Map<String, Object?>;
  final sqlite = report['sqliteProfile'] as Map<String, Object?>;
  final recovery = report['recovery'] as Map<String, Object?>;
  final encoding = report['encoding'] as Map<String, Object?>;
  final memory = report['memory'] as Map<String, Object?>;

  final buffer = StringBuffer()
    ..writeln('# PERF-MEASURE-001 Raw Measurement Report')
    ..writeln()
    ..writeln('## STATUS')
    ..writeln()
    ..writeln('completed')
    ..writeln()
    ..writeln('## ENVIRONMENT')
    ..writeln()
    ..writeln('- OS: ${env['os']}')
    ..writeln('- CPU cores: ${env['cpuCores']}')
    ..writeln('- Dart: ${env['dartVersion']}')
    ..writeln('- Flutter: ${env['flutterVersion'] ?? 'not detected'}')
    ..writeln('- Run mode: ${env['runMode']}')
    ..writeln('- Database root: ${env['databaseRoot']}')
    ..writeln('- Timestamp (UTC): ${env['timestampUtc']}')
    ..writeln()
    ..writeln('## BENCHMARK FILES ADDED / CHANGED')
    ..writeln()
    ..writeln('- packages/forref_match_benchmark/ (new isolated benchmark package)')
    ..writeln('- pubspec.yaml (workspace entry)')
    ..writeln()
    ..writeln('## D1 COMMIT RAW RESULTS')
    ..writeln()
    ..writeln(_statsBlock('End-to-end (commitAtNextOriginSequence)', d1['endToEndCommitAtNextOriginSequence']))
    ..writeln(_statsBlock('Record construction', d1['recordConstruction']))
    ..writeln(_statsBlock('Sequence allocation', d1['sequenceAllocation']))
    ..writeln(_statsBlock('Encoding', d1['encoding']))
    ..writeln(_statsBlock('SQLite transaction (approx)', d1['sqliteTransactionApproxMinusMedianEncoding']))
    ..writeln('Warm-up: ${d1['warmUpCount']}; samples: ${d1['sampleCount']}')
    ..writeln()
    ..writeln('## PROJECTION RAW RESULTS')
    ..writeln();
  final bySize = projection['byRecordCount'] as Map<String, Object?>;
  for (final size in ['25', '100', '500', '1000', '5000']) {
    buffer.writeln('### $size records');
    buffer.writeln(_statsBlock('', bySize[size]));
    buffer.writeln();
  }
  buffer
    ..writeln('Complexity shape: ${projection['complexityShapeEstimate']}')
    ..writeln()
    ..writeln('## TICKER TRACE')
    ..writeln();
  final perTick = ticker['perTick'] as Map<String, Object?>;
  buffer
    ..writeln('- DB reads/tick: ${perTick['dbReads']}')
    ..writeln('- Projector calls/tick: ${perTick['projectorCalls']}')
    ..writeln('- JSON decodes/tick: ${perTick['jsonDecodes']}')
    ..writeln('- Evidence reads/tick: ${perTick['temporalEvidenceReads']}')
    ..writeln('- deriveActivePeriodElapsed calls/tick: ${perTick['deriveActivePeriodElapsedCalls']}')
    ..writeln('- Rebuild scope: ${perTick['setStateRebuildScope']}')
    ..writeln('- Tick latency: ${_statsBlock('', ticker['tickLatencyMicros'])}')
    ..writeln()
    ..writeln('## SQLITE PROFILE')
    ..writeln();
  final pragmas = sqlite['pragmas'] as Map<String, Object?>;
  buffer
    ..writeln('- journal_mode: ${pragmas['journal_mode']}')
    ..writeln('- synchronous: ${pragmas['synchronousLabel']}')
    ..writeln('- Statements per commit: ${(sqlite['statementsPerAuthoritativeCommitAtNextOriginSequence'] as Map)['estimatedStatementCount']}')
    ..writeln('- Query plans: see JSON artifact')
    ..writeln('- Indexes: see JSON artifact')
    ..writeln()
    ..writeln('## RECOVERY RAW RESULTS')
    ..writeln();
  final recoveryBySize = recovery['byRecordCount'] as Map<String, Object?>;
  for (final size in ['25', '100', '500', '1000', '5000']) {
    final entry = recoveryBySize[size] as Map<String, Object?>;
    buffer
      ..writeln('### $size records')
      ..writeln(_statsBlock('SQLite open/recovery', entry['sqliteOpenRecovery']))
      ..writeln(_statsBlock('Row fetch', entry['rowFetch']))
      ..writeln(_statsBlock('Decode/validation', entry['decodeValidation']))
      ..writeln(_statsBlock('Projection rebuild', entry['projectionRebuild']))
      ..writeln(_statsBlock('Temporal continuity', entry['temporalContinuityEvaluation']))
      ..writeln(_statsBlock('Total usable-state latency', entry['totalUsableStateLatency']))
      ..writeln();
  }
  buffer
    ..writeln('## ENCODING RAW RESULTS')
    ..writeln()
    ..writeln(_statsBlock('Encode', encoding['encode']))
    ..writeln(_statsBlock('Decode', encoding['decode']))
    ..writeln()
    ..writeln('## MEMORY / HEAP RESULTS')
    ..writeln()
    ..writeln('RSS available: ${memory['rssAvailable']}')
    ..writeln('Method: ${memory['measurementMethod']}')
    ..writeln('See JSON for phase-level RSS snapshots and deltas.')
    ..writeln()
    ..writeln('## CORRECTNESS REGRESSION CHECK')
    ..writeln()
    ..writeln('Run separately: dart test in forref_match_core, forref_match_persistence, referee_phone')
    ..writeln()
    ..writeln('## MEASUREMENT LIMITATIONS')
    ..writeln()
    ..writeln('- Single Windows x64 workstation; not representative of all phones')
    ..writeln('- Dart VM `ProcessInfo.currentRss` is approximate heap proxy')
    ..writeln('- SQLite transaction phase approximated by subtracting encoding p50 from end-to-end')
    ..writeln('- Ticker trace combines static analysis with simulated tick harness')
    ..writeln('- Benchmark package not linked into production app paths')
    ..writeln()
    ..writeln('## RAW ARTIFACT LOCATIONS')
    ..writeln()
    ..writeln('- $artifactDir/perf_measure_001_raw.json')
    ..writeln('- $artifactDir/perf_measure_001_report.md');

  return buffer.toString();
}

String _statsBlock(String label, Object? stats) {
  if (stats is! Map) return '$label: (no data)';
  final p99 = stats['p99'];
  return '${label.isEmpty ? '' : '$label: '}n=${stats['count']}, p50=${stats['p50']}µs, p95=${stats['p95']}µs${p99 != null ? ', p99=${stats['p99']}µs' : ''}, max=${stats['max']}µs';
}
