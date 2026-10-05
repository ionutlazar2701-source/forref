import 'package:forref_match_core/forref_match_core.dart';

/// One authoritative capture intent before durable commit.
///
/// UI must not supply [originSequence]. Sequence allocation happens inside
/// the durable commit operation.
final class AuthoritativeCaptureCommand {
  const AuthoritativeCaptureCommand({
    required this.context,
    required this.recordKind,
    required this.payload,
    required this.integrity,
    this.relationships = const [],
    this.temporalContext,
    this.recordedAt,
  });

  final CaptureContext context;
  final RecordKind recordKind;
  final MatchRecordPayload payload;
  final IntegrityMetadata integrity;
  final List<RecordRelationship> relationships;
  final TemporalContext? temporalContext;
  final DateTime? recordedAt;
}
