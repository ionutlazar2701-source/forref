import 'dart:convert';
import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:uuid/uuid.dart';

/// Monotonic clock inside one in-process continuity domain.
///
/// The domain id is not reused after process restart. [chronology] is wall
/// time for ordering evidence, not match elapsed.
abstract interface class MonotonicContinuityClock {
  String get continuityDomainId;
  Duration get monotonicElapsed;
  DateTime get chronology;
}

/// Production phone clock. Not a certified temporal platform.
final class StopwatchContinuityClock implements MonotonicContinuityClock {
  StopwatchContinuityClock()
      : continuityDomainId = const Uuid().v4(),
        _watch = Stopwatch()..start();

  @override
  final String continuityDomainId;

  final Stopwatch _watch;

  @override
  Duration get monotonicElapsed => _watch.elapsed;

  @override
  DateTime get chronology => DateTime.now().toUtc();
}

/// Phone [TemporalEvidencePort].
///
/// Anchor artifacts are stored beside Match Memory. The live observation is
/// read from the in-process clock and is never written. This store does not
/// certify the phone clock.
final class PhoneTemporalEvidenceStore implements TemporalEvidencePort {
  PhoneTemporalEvidenceStore({
    required Directory storageRoot,
    MonotonicContinuityClock? clock,
  })  : _file = File('${storageRoot.path}/forref_temporal_evidence.json'),
        _clock = clock ?? StopwatchContinuityClock();

  /// Reserved id for the current in-process sample. Not a stored artifact.
  static const liveObservationId = 'phone-live-monotonic';

  final File _file;
  final MonotonicContinuityClock _clock;

  /// Captures one monotonic evidence artifact. Does not write a Match Record.
  Future<TemporalEvidence> captureAnchor() async {
    final evidence = TemporalEvidence(
      evidenceId: const Uuid().v4(),
      capturedAt: _clock.chronology.toUtc(),
      continuityDomainId: _clock.continuityDomainId,
      monotonicElapsed: _clock.monotonicElapsed,
      certified: false,
    );
    final stored = await _readArtifacts();
    stored.add(evidence);
    await _writeArtifacts(stored);
    return evidence;
  }

  /// Current monotonic sample. Not persisted.
  TemporalEvidence currentObservation() {
    return TemporalEvidence(
      evidenceId: liveObservationId,
      capturedAt: _clock.chronology.toUtc(),
      continuityDomainId: _clock.continuityDomainId,
      monotonicElapsed: _clock.monotonicElapsed,
      certified: false,
    );
  }

  @override
  Future<TemporalEvidence?> resolve(String evidenceId) async {
    if (evidenceId == liveObservationId) return currentObservation();
    final stored = await _readArtifacts();
    for (final evidence in stored) {
      if (evidence.evidenceId == evidenceId) return evidence;
    }
    return null;
  }

  Future<List<TemporalEvidence>> _readArtifacts() async {
    if (!_file.existsSync()) return [];
    final decoded = jsonDecode(await _file.readAsString());
    if (decoded is! Map) {
      throw FormatException('Stored temporal evidence is invalid');
    }
    final json = decoded.map((key, value) => MapEntry(key.toString(), value));
    _requireKeys(json, {'artifacts'});
    final artifacts = json['artifacts'];
    if (artifacts is! List) {
      throw FormatException('Stored temporal evidence artifacts are invalid');
    }
    return [
      for (final item in artifacts) _decodeArtifact(item),
    ];
  }

  Future<void> _writeArtifacts(List<TemporalEvidence> artifacts) async {
    if (!_file.parent.existsSync()) {
      _file.parent.createSync(recursive: true);
    }
    await _file.writeAsString(
      jsonEncode({
        'artifacts': [for (final evidence in artifacts) _encode(evidence)],
      }),
    );
  }
}

Map<String, Object?> _encode(TemporalEvidence evidence) {
  return {
    'evidenceId': evidence.evidenceId,
    'capturedAt': evidence.capturedAt.toUtc().toIso8601String(),
    'continuityDomainId': evidence.continuityDomainId,
    'monotonicMicros': evidence.monotonicElapsed?.inMicroseconds,
    'monotonicUpperMicros': evidence.monotonicUpperBound?.inMicroseconds,
    'certified': false,
  };
}

TemporalEvidence _decodeArtifact(Object? value) {
  if (value is! Map) {
    throw FormatException('Stored temporal evidence artifact is invalid');
  }
  final json = value.map((key, item) => MapEntry(key.toString(), item));
  _requireKeys(json, {
    'evidenceId',
    'capturedAt',
    'continuityDomainId',
    'monotonicMicros',
    'monotonicUpperMicros',
    'certified',
  });
  final evidenceId = json['evidenceId'];
  final capturedAt = json['capturedAt'];
  final domainId = json['continuityDomainId'];
  if (evidenceId is! String || evidenceId.isEmpty) {
    throw FormatException('Stored temporal evidence id is invalid');
  }
  if (evidenceId == PhoneTemporalEvidenceStore.liveObservationId) {
    throw FormatException('Live temporal observation cannot be stored');
  }
  if (capturedAt is! String) {
    throw FormatException('Stored temporal evidence chronology is invalid');
  }
  if (domainId is! String || domainId.isEmpty) {
    throw FormatException('Stored temporal continuity domain is invalid');
  }
  final monotonic = _micros(json['monotonicMicros'], 'monotonicMicros');
  final upper = _micros(json['monotonicUpperMicros'], 'monotonicUpperMicros');
  if (json['certified'] != false) {
    throw FormatException('Phone temporal evidence cannot claim certification');
  }
  return TemporalEvidence(
    evidenceId: evidenceId,
    capturedAt: DateTime.parse(capturedAt).toUtc(),
    continuityDomainId: domainId,
    monotonicElapsed: monotonic,
    monotonicUpperBound: upper,
    certified: false,
  );
}

Duration? _micros(Object? value, String label) {
  if (value == null) return null;
  if (value is! int || value < 0) {
    throw FormatException('Stored $label is invalid');
  }
  return Duration(microseconds: value);
}

void _requireKeys(Map<String, Object?> json, Set<String> allowed) {
  for (final key in json.keys) {
    if (!allowed.contains(key)) {
      throw FormatException('Unknown temporal evidence field: $key');
    }
  }
}
