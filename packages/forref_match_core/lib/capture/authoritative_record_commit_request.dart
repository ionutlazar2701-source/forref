import '../authority.dart';
import '../integrity.dart';
import '../match_record.dart';
import '../payload.dart';
import '../record_kind.dart';
import '../relationships.dart';
import '../temporal.dart';

/// Immutable authoritative record content awaiting origin-sequence allocation.
///
/// [originSequence] is assigned atomically during durable commit. It must not
/// be chosen by UI or pre-committed counters.
final class AuthoritativeRecordCommitRequest {
  AuthoritativeRecordCommitRequest({
    required this.recordId,
    required this.matchId,
    required this.originDeviceId,
    required this.recordKind,
    required this.schemaVersion,
    required this.recordedAt,
    required this.payload,
    required this.integrity,
    this.temporalContext,
    this.authorityContext,
    this.relationships = const [],
  });

  final String recordId;
  final String matchId;
  final String originDeviceId;
  final RecordKind recordKind;
  final int schemaVersion;
  final DateTime recordedAt;
  final MatchRecordPayload payload;
  final IntegrityMetadata integrity;
  final TemporalContext? temporalContext;
  final AuthorityContext? authorityContext;
  final List<RecordRelationship> relationships;

  MatchRecord toMatchRecord({required int originSequence}) {
    return MatchRecord(
      recordId: recordId,
      matchId: matchId,
      recordKind: recordKind,
      schemaVersion: schemaVersion,
      recordedAt: recordedAt,
      originDeviceId: originDeviceId,
      originSequence: originSequence,
      payload: payload,
      integrity: integrity,
      temporalContext: temporalContext,
      authorityContext: authorityContext,
      relationships: relationships,
    );
  }
}
