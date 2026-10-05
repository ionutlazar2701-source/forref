import 'dart:convert';
import 'dart:io';

/// Build / environment metadata for benchmark runs.
final class EnvironmentInfo {
  EnvironmentInfo({
    required this.os,
    required this.cpuCores,
    required this.dartVersion,
    required this.flutterVersion,
    required this.runMode,
    required this.databaseRoot,
    required this.timestampUtc,
  });

  final String os;
  final int cpuCores;
  final String dartVersion;
  final String? flutterVersion;
  final String runMode;
  final String databaseRoot;
  final String timestampUtc;

  static Future<EnvironmentInfo> collect({
    required Directory databaseRoot,
    String runMode = 'release (dart run, AOT via dart compile exe or VM optimized)',
  }) async {
    final flutterVersion = await _flutterVersion();
    return EnvironmentInfo(
      os: '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      cpuCores: Platform.numberOfProcessors,
      dartVersion: Platform.version,
      flutterVersion: flutterVersion,
      runMode: Platform.environment['FORREF_BENCH_MODE'] ?? runMode,
      databaseRoot: databaseRoot.path,
      timestampUtc: DateTime.now().toUtc().toIso8601String(),
    );
  }

  static Future<String?> _flutterVersion() async {
    try {
      final result = await Process.run('flutter', ['--version'], runInShell: true);
      if (result.exitCode != 0) return null;
      return (result.stdout as String).split('\n').first.trim();
    } catch (_) {
      return null;
    }
  }

  Map<String, Object?> toJson() => {
        'os': os,
        'cpuCores': cpuCores,
        'dartVersion': dartVersion,
        if (flutterVersion != null) 'flutterVersion': flutterVersion,
        'runMode': runMode,
        'databaseRoot': databaseRoot,
        'timestampUtc': timestampUtc,
      };

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('- OS: $os')
      ..writeln('- CPU cores: $cpuCores')
      ..writeln('- Dart: $dartVersion')
      ..writeln('- Flutter: ${flutterVersion ?? 'not detected'}')
      ..writeln('- Run mode: $runMode')
      ..writeln('- Database root: $databaseRoot')
      ..writeln('- Timestamp (UTC): $timestampUtc');
    return buffer.toString();
  }
}

String jsonEncodePretty(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);
