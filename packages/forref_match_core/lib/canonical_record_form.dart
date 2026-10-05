import 'authority.dart';
import 'integrity.dart';
import 'match_record.dart';
import 'payload.dart';
import 'record_kind.dart';
import 'relationships.dart';
import 'semantics/match_record_semantic_type.dart';
import 'semantics/v1_semantic_payload.dart';
import 'temporal.dart';

/// Compares canonical record content for idempotent append and conflict detection.
bool identicalCanonicalRecordContent(MatchRecord a, MatchRecord b) {
  return _CanonicalParts.from(a) == _CanonicalParts.from(b);
}

final class _CanonicalParts {
  _CanonicalParts({
    required this.matchId,
    required this.recordKind,
    required this.schemaVersion,
    required this.recordedAtUtcMicros,
    required this.originDeviceId,
    required this.originSequence,
    required this.temporalContext,
    required this.authorityContext,
    required this.relationships,
    required this.payload,
    required this.integrity,
  });

  factory _CanonicalParts.from(MatchRecord record) {
    return _CanonicalParts(
      matchId: record.matchId,
      recordKind: record.recordKind,
      schemaVersion: record.schemaVersion,
      recordedAtUtcMicros: record.recordedAt.toUtc().microsecondsSinceEpoch,
      originDeviceId: record.originDeviceId,
      originSequence: record.originSequence,
      temporalContext: record.temporalContext == null
          ? null
          : _TemporalSnapshot.from(record.temporalContext!),
      authorityContext: record.authorityContext == null
          ? null
          : _AuthoritySnapshot.from(record.authorityContext!),
      relationships: [
        for (final link in record.relationships)
          _RelationshipSnapshot.from(link),
      ],
      payload: _PayloadSnapshot.from(record.payload),
      integrity: _IntegritySnapshot.from(record.integrity),
    );
  }

  final String matchId;
  final RecordKind recordKind;
  final int schemaVersion;
  final int recordedAtUtcMicros;
  final String originDeviceId;
  final int originSequence;
  final _TemporalSnapshot? temporalContext;
  final _AuthoritySnapshot? authorityContext;
  final List<_RelationshipSnapshot> relationships;
  final _PayloadSnapshot payload;
  final _IntegritySnapshot integrity;

  @override
  bool operator ==(Object other) {
    return other is _CanonicalParts &&
        matchId == other.matchId &&
        recordKind == other.recordKind &&
        schemaVersion == other.schemaVersion &&
        recordedAtUtcMicros == other.recordedAtUtcMicros &&
        originDeviceId == other.originDeviceId &&
        originSequence == other.originSequence &&
        temporalContext == other.temporalContext &&
        authorityContext == other.authorityContext &&
        _listEquals(relationships, other.relationships) &&
        payload == other.payload &&
        integrity == other.integrity;
  }

  @override
  int get hashCode => Object.hash(
        matchId,
        recordKind,
        schemaVersion,
        recordedAtUtcMicros,
        originDeviceId,
        originSequence,
        temporalContext,
        authorityContext,
        Object.hashAll(relationships),
        payload,
        integrity,
      );
}

final class _TemporalSnapshot {
  const _TemporalSnapshot({
    required this.evidenceIds,
    required this.domainClockPolicyVersion,
  });

  factory _TemporalSnapshot.from(TemporalContext context) {
    return _TemporalSnapshot(
      evidenceIds: List<String>.from(context.evidenceIds),
      domainClockPolicyVersion: context.domainClockPolicyVersion,
    );
  }

  final List<String> evidenceIds;
  final String? domainClockPolicyVersion;

  @override
  bool operator ==(Object other) {
    return other is _TemporalSnapshot &&
        _listEquals(evidenceIds, other.evidenceIds) &&
        domainClockPolicyVersion == other.domainClockPolicyVersion;
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(evidenceIds), domainClockPolicyVersion);
}

final class _AuthoritySnapshot {
  const _AuthoritySnapshot({
    required this.scopeKind,
    required this.principalId,
    required this.activeCaptureDeviceId,
    required this.generation,
  });

  factory _AuthoritySnapshot.from(AuthorityContext context) {
    return _AuthoritySnapshot(
      scopeKind: context.scope is MainRefereeScope ? 'MAIN_REFEREE' : 'UNKNOWN',
      principalId: context.principal?.principalId,
      activeCaptureDeviceId: context.activeCaptureDevice?.deviceId,
      generation: context.generation?.value,
    );
  }

  final String scopeKind;
  final String? principalId;
  final String? activeCaptureDeviceId;
  final int? generation;

  @override
  bool operator ==(Object other) {
    return other is _AuthoritySnapshot &&
        scopeKind == other.scopeKind &&
        principalId == other.principalId &&
        activeCaptureDeviceId == other.activeCaptureDeviceId &&
        generation == other.generation;
  }

  @override
  int get hashCode => Object.hash(
        scopeKind,
        principalId,
        activeCaptureDeviceId,
        generation,
      );
}

final class _RelationshipSnapshot {
  const _RelationshipSnapshot({
    required this.kind,
    required this.targetRecordId,
  });

  factory _RelationshipSnapshot.from(RecordRelationship link) {
    final kind = switch (link) {
      CausalDependency() => 'CAUSAL',
      CorrectionTarget() => 'CORRECTION',
      LegalSupersessionTarget() => 'SUPERSESSION',
      RelatesTo() => 'RELATES_TO',
    };
    return _RelationshipSnapshot(
      kind: kind,
      targetRecordId: link.targetRecordId,
    );
  }

  final String kind;
  final String targetRecordId;

  @override
  bool operator ==(Object other) {
    return other is _RelationshipSnapshot &&
        kind == other.kind &&
        targetRecordId == other.targetRecordId;
  }

  @override
  int get hashCode => Object.hash(kind, targetRecordId);
}

final class _PayloadSnapshot {
  const _PayloadSnapshot({required this.structuredFields});

  factory _PayloadSnapshot.from(MatchRecordPayload payload) {
    if (payload is StructuredPayload) {
      return _PayloadSnapshot(
        structuredFields: Map<String, Object?>.from(payload.fields),
      );
    }
    if (payload is V1SemanticPayload) {
      return _PayloadSnapshot(
        structuredFields: {
          'semanticType': payload.semanticType.wireValue,
          if (payload is TemporalTransitionPayload && payload.period != null)
            'periodIndex': payload.period!.index,
          if (payload is GoalPayload) ...{
            'scoringSide': payload.scoringSide.wireValue,
            'periodIndex': payload.period.index,
            if (payload.playerId != null) 'playerId': payload.playerId,
            if (payload.playerNumber != null)
              'playerNumber': payload.playerNumber,
          },
          if (payload.domainContractVersion != null)
            'domainContractVersion': payload.domainContractVersion!.value,
          if (payload.competitionRulesContext != null)
            'competitionRulesContext':
                payload.competitionRulesContext!.rulesetId,
        },
      );
    }
    throw UnsupportedError(
      'Unsupported payload type for canonical comparison: $payload',
    );
  }

  final Map<String, Object?> structuredFields;

  @override
  bool operator ==(Object other) {
    return other is _PayloadSnapshot &&
        _deepEquals(structuredFields, other.structuredFields);
  }

  @override
  int get hashCode => _deepHashCode(structuredFields);
}

final class _IntegritySnapshot {
  const _IntegritySnapshot({required this.evidenceRefs});

  factory _IntegritySnapshot.from(IntegrityMetadata integrity) {
    return _IntegritySnapshot(
      evidenceRefs: List<String>.from(integrity.evidenceRefs),
    );
  }

  final List<String> evidenceRefs;

  @override
  bool operator ==(Object other) {
    return other is _IntegritySnapshot &&
        _listEquals(evidenceRefs, other.evidenceRefs);
  }

  @override
  int get hashCode => Object.hashAll(evidenceRefs);
}

/// Deterministic structural equality for supported canonical payload values.
bool _deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a is bool && b is bool) return a == b;
  if (a is num && b is num) return a == b;
  if (a is String && b is String) return a == b;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (entry.key is! String) return false;
      final key = entry.key as String;
      if (!b.containsKey(key) || !_deepEquals(entry.value, b[key])) {
        return false;
      }
    }
    return true;
  }
  return false;
}

int _deepHashCode(Object? value) {
  if (value == null) return 0;
  if (value is bool || value is num || value is String) return value.hashCode;
  if (value is List) {
    return Object.hashAll(value.map(_deepHashCode));
  }
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort((a, b) => (a.key as String).compareTo(b.key as String));
    return Object.hashAll(
      entries.map((entry) => Object.hash(entry.key, _deepHashCode(entry.value))),
    );
  }
  return value.hashCode;
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
