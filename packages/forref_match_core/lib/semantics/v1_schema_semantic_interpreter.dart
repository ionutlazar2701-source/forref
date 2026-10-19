import '../match_record.dart';
import '../projection/projection_semantics_resolver.dart';
import '../relationships.dart';
import 'match_record_semantic_type.dart';
import 'schema_semantic_interpreter.dart';
import 'v1_semantic_contract.dart';
import 'v1_semantic_payload.dart';

/// Frozen v1 semantic interpretation table.
///
/// New semantic types that fit this contract stay on schema version 1.
/// Historical meaning of an already-registered code is not redefined here.
final class V1SchemaSemanticInterpreter implements SchemaSemanticInterpreter {
  const V1SchemaSemanticInterpreter();

  @override
  int get schemaVersion => V1SemanticContract.schemaContractVersion;

  @override
  SemanticProjectionContribution? interpret({
    required MatchRecord record,
    required MatchRecordSemanticIdentity identity,
  }) {
    if (identity.schemaVersion != schemaVersion) return null;
    final contract = V1SemanticContract.byCode[identity.code];
    if (contract == null) return null;
    if (record.recordKind != contract.requiredRecordKind) return null;
    if (!_payloadMatchesIdentity(record, identity.code)) return null;

    final targetId = _targetRecordId(record, identity.code);
    final missingTarget = contract.requiresTargetRelationship && targetId == null;

    return SemanticProjectionContribution(
      status: SemanticSupportStatus.supported,
      supportedFacets: contract.projectionFacets,
      missingRequiredRelationship: missingTarget,
      requiredTargetRecordId: targetId,
    );
  }

  static bool _payloadMatchesIdentity(
    MatchRecord record,
    V1SemanticTypeCode code,
  ) {
    final payload = record.payload;
    return switch (code) {
      V1SemanticTypeCode.goal => payload is GoalPayload,
      V1SemanticTypeCode.yellowCard => isYellowCardPayload(payload),
      V1SemanticTypeCode.refereeEnteredFieldForMatchStart =>
        payload is RefereeEnteredFieldPayload,
      V1SemanticTypeCode.correction => payload is CorrectionPayload,
      V1SemanticTypeCode.temporalCorrection => payload is TemporalCorrectionPayload,
      V1SemanticTypeCode.legalSupersession => payload is LegalSupersessionPayload,
      V1SemanticTypeCode.matchStarted ||
      V1SemanticTypeCode.periodStarted ||
      V1SemanticTypeCode.periodEnded ||
      V1SemanticTypeCode.temporarySuspensionStarted ||
      V1SemanticTypeCode.temporarySuspensionEnded ||
      V1SemanticTypeCode.matchAbandoned ||
      V1SemanticTypeCode.matchEnded =>
        payload is TemporalTransitionPayload &&
            payload.semanticType == code,
    };
  }

  static String? _targetRecordId(MatchRecord record, V1SemanticTypeCode code) {
    for (final link in record.relationships) {
      final matches = switch (code) {
        V1SemanticTypeCode.correction ||
        V1SemanticTypeCode.temporalCorrection =>
          link is CorrectionTarget,
        V1SemanticTypeCode.legalSupersession => link is LegalSupersessionTarget,
        _ => false,
      };
      if (matches) return link.targetRecordId;
    }
    return null;
  }
}
