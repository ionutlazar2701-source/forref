import 'authority.dart';
import 'integrity.dart';
import 'payload.dart';
import 'record_kind.dart';
import 'relationships.dart';
import 'temporal.dart';

/// Immutable authoritative Match Record (Match Memory entry).
final class MatchRecord {
  MatchRecord({
    required this.recordId,
    required this.matchId,
    required this.recordKind,
    required this.schemaVersion,
    required this.recordedAt,
    required this.originDeviceId,
    required this.originSequence,
    required this.payload,
    required this.integrity,
    this.temporalContext,
    this.authorityContext,
    List<RecordRelationship> relationships = const [],
  }) : relationships = List<RecordRelationship>.unmodifiable(relationships);

  final String recordId;
  final String matchId;
  final RecordKind recordKind;
  final int schemaVersion;
  final DateTime recordedAt;
  final String originDeviceId;
  final int originSequence;
  final TemporalContext? temporalContext;
  final AuthorityContext? authorityContext;
  final List<RecordRelationship> relationships;
  final MatchRecordPayload payload;
  final IntegrityMetadata integrity;
}
