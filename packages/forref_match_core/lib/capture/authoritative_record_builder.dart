import '../authority.dart';
import '../integrity.dart';
import '../payload.dart';
import '../record_kind.dart';
import '../relationships.dart';
import '../temporal.dart';
import 'authoritative_record_commit_request.dart';
import 'capture_context.dart';
import 'record_identity_generator.dart';

/// Constructs immutable authoritative records before durable commit.
final class AuthoritativeRecordBuilder {
  const AuthoritativeRecordBuilder({required this.identityGenerator});

  final RecordIdentityGenerator identityGenerator;

  AuthoritativeRecordCommitRequest build({
    required CaptureContext context,
    required RecordKind recordKind,
    required MatchRecordPayload payload,
    required IntegrityMetadata integrity,
    List<RecordRelationship> relationships = const [],
    TemporalContext? temporalContext,
    DateTime? recordedAt,
    String? recordId,
  }) {
    if (context.authorityScope is! MainRefereeScope) {
      throw ArgumentError.value(
        context.authorityScope,
        'context.authorityScope',
        'V1 capture supports MAIN_REFEREE only',
      );
    }

    return AuthoritativeRecordCommitRequest(
      recordId: recordId ?? identityGenerator.newRecordId(),
      matchId: context.matchId,
      originDeviceId: context.originDeviceId,
      recordKind: recordKind,
      schemaVersion: context.schemaVersion,
      recordedAt: recordedAt ?? DateTime.now().toUtc(),
      payload: payload,
      integrity: integrity,
      temporalContext: temporalContext,
      authorityContext: AuthorityContext(
        scope: context.authorityScope,
        principal: AuthorityPrincipal(principalId: context.authorityPrincipalId),
        activeCaptureDevice: context.activeCaptureDeviceId == null
            ? null
            : ActiveCaptureDevice(deviceId: context.activeCaptureDeviceId!),
        generation: AuthorityGeneration(value: context.authorityGeneration),
      ),
      relationships: relationships,
    );
  }
}
