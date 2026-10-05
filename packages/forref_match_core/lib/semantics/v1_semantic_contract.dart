import '../projection/projection_trust.dart';
import '../record_kind.dart';
import 'match_record_semantic_type.dart';

/// Explicit v1 projection contribution for one semantic type.
///
/// Shared by every v1 code. A new semantic type does not require schema v2
/// while it can be expressed with this contract.
final class V1SemanticContract {
  const V1SemanticContract({
    required this.code,
    required this.requiredRecordKind,
    required this.schemaVersion,
    required this.category,
    required this.projectionFacets,
    required this.requiresTargetRelationship,
    required this.effect,
    required this.createsSportingState,
    required this.isDurableMatchState,
    this.requiresCausalDependencyOnFinalPeriodEnd = false,
  });

  final V1SemanticTypeCode code;
  final RecordKind requiredRecordKind;

  /// Historical schema boundary. Remains 1 for this vocabulary.
  final int schemaVersion;
  final SemanticTypeCategory category;
  final List<String> projectionFacets;

  /// Correction and supersession links are required. Temporal transitions are not.
  final bool requiresTargetRelationship;
  final SemanticEffect effect;

  /// Score, disciplinary, and other sporting event state are out of this vocabulary.
  final bool createsSportingState;

  /// Resumption and other transitions are events, not durable match states.
  final bool isDurableMatchState;

  /// Later `MATCH_ENDED` capture must causally follow the final playing period end.
  ///
  /// This is not a correction-target requirement and it does not commit a record.
  final bool requiresCausalDependencyOnFinalPeriodEnd;

  static const schemaContractVersion = 1;

  static const byCode = <V1SemanticTypeCode, V1SemanticContract>{
    V1SemanticTypeCode.matchStarted: V1SemanticContract(
      code: V1SemanticTypeCode.matchStarted,
      requiredRecordKind: RecordKind.temporalFact,
      schemaVersion: schemaContractVersion,
      category: SemanticTypeCategory.temporal,
      projectionFacets: [ProjectionFacet.temporal],
      requiresTargetRelationship: false,
      effect: SemanticEffect.temporalTransitionAuthority,
      createsSportingState: false,
      isDurableMatchState: false,
    ),
    V1SemanticTypeCode.periodStarted: V1SemanticContract(
      code: V1SemanticTypeCode.periodStarted,
      requiredRecordKind: RecordKind.temporalFact,
      schemaVersion: schemaContractVersion,
      category: SemanticTypeCategory.temporal,
      projectionFacets: [ProjectionFacet.temporal],
      requiresTargetRelationship: false,
      effect: SemanticEffect.temporalTransitionAuthority,
      createsSportingState: false,
      isDurableMatchState: false,
    ),
    V1SemanticTypeCode.periodEnded: V1SemanticContract(
      code: V1SemanticTypeCode.periodEnded,
      requiredRecordKind: RecordKind.temporalFact,
      schemaVersion: schemaContractVersion,
      category: SemanticTypeCategory.temporal,
      projectionFacets: [ProjectionFacet.temporal],
      requiresTargetRelationship: false,
      effect: SemanticEffect.temporalTransitionAuthority,
      createsSportingState: false,
      isDurableMatchState: false,
    ),
    V1SemanticTypeCode.temporarySuspensionStarted: V1SemanticContract(
      code: V1SemanticTypeCode.temporarySuspensionStarted,
      requiredRecordKind: RecordKind.temporalFact,
      schemaVersion: schemaContractVersion,
      category: SemanticTypeCategory.temporal,
      projectionFacets: [ProjectionFacet.temporal],
      requiresTargetRelationship: false,
      effect: SemanticEffect.temporalTransitionAuthority,
      createsSportingState: false,
      isDurableMatchState: false,
    ),
    V1SemanticTypeCode.temporarySuspensionEnded: V1SemanticContract(
      code: V1SemanticTypeCode.temporarySuspensionEnded,
      requiredRecordKind: RecordKind.temporalFact,
      schemaVersion: schemaContractVersion,
      category: SemanticTypeCategory.temporal,
      projectionFacets: [ProjectionFacet.temporal],
      requiresTargetRelationship: false,
      effect: SemanticEffect.temporalTransitionAuthority,
      createsSportingState: false,
      isDurableMatchState: false,
    ),
    V1SemanticTypeCode.matchAbandoned: V1SemanticContract(
      code: V1SemanticTypeCode.matchAbandoned,
      requiredRecordKind: RecordKind.temporalFact,
      schemaVersion: schemaContractVersion,
      category: SemanticTypeCategory.temporal,
      projectionFacets: [ProjectionFacet.temporal],
      requiresTargetRelationship: false,
      effect: SemanticEffect.temporalTransitionAuthority,
      createsSportingState: false,
      isDurableMatchState: false,
    ),
    V1SemanticTypeCode.matchEnded: V1SemanticContract(
      code: V1SemanticTypeCode.matchEnded,
      requiredRecordKind: RecordKind.temporalFact,
      schemaVersion: schemaContractVersion,
      category: SemanticTypeCategory.temporal,
      projectionFacets: [ProjectionFacet.temporal],
      requiresTargetRelationship: false,
      effect: SemanticEffect.temporalTransitionAuthority,
      createsSportingState: false,
      isDurableMatchState: false,
      requiresCausalDependencyOnFinalPeriodEnd: true,
    ),
    V1SemanticTypeCode.temporalCorrection: V1SemanticContract(
      code: V1SemanticTypeCode.temporalCorrection,
      requiredRecordKind: RecordKind.correction,
      schemaVersion: schemaContractVersion,
      category: SemanticTypeCategory.temporal,
      projectionFacets: [ProjectionFacet.temporal],
      requiresTargetRelationship: true,
      effect: SemanticEffect.historicalInterpretation,
      createsSportingState: false,
      isDurableMatchState: false,
    ),
    V1SemanticTypeCode.correction: V1SemanticContract(
      code: V1SemanticTypeCode.correction,
      requiredRecordKind: RecordKind.correction,
      schemaVersion: schemaContractVersion,
      category: SemanticTypeCategory.correctionSupersession,
      projectionFacets: [ProjectionFacet.coverage],
      requiresTargetRelationship: true,
      effect: SemanticEffect.historicalInterpretation,
      createsSportingState: false,
      isDurableMatchState: false,
    ),
    V1SemanticTypeCode.legalSupersession: V1SemanticContract(
      code: V1SemanticTypeCode.legalSupersession,
      requiredRecordKind: RecordKind.legalSupersession,
      schemaVersion: schemaContractVersion,
      category: SemanticTypeCategory.correctionSupersession,
      projectionFacets: [ProjectionFacet.coverage],
      requiresTargetRelationship: true,
      effect: SemanticEffect.historicalInterpretation,
      createsSportingState: false,
      isDurableMatchState: false,
    ),
  };
}
