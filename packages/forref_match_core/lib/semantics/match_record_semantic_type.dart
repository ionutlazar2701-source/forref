/// Category of typed record semantics, independent from [RecordKind].
enum SemanticTypeCategory {
  temporal,
  authorityControl,
  correctionSupersession,
  event,
}

/// How a supported semantic affects projection.
///
/// Temporal codes do not compute elapsed time. A sporting event declares a
/// facet; it does not store a mutable score.
enum SemanticEffect {
  /// Authoritative temporal transition. Not a durable match state.
  temporalTransitionAuthority,

  /// New record that changes how prior history is interpreted.
  historicalInterpretation,

  /// Authoritative sporting event. Projection rebuilds its effect.
  sportingEvent,
}

/// Version-1 production semantic type codes.
///
/// Adding a code does not require a new [schemaVersion]. These codes share
/// the v1 structural contract: typed semantic identity, record kind, and
/// optional target relationships.
enum V1SemanticTypeCode {
  matchStarted,
  periodStarted,
  periodEnded,
  temporarySuspensionStarted,
  temporarySuspensionEnded,
  matchAbandoned,
  matchEnded,
  goal,
  temporalCorrection,
  correction,
  legalSupersession,
}

extension V1SemanticTypeCodeWire on V1SemanticTypeCode {
  String get wireValue => switch (this) {
        V1SemanticTypeCode.matchStarted => 'MATCH_STARTED',
        V1SemanticTypeCode.periodStarted => 'PERIOD_STARTED',
        V1SemanticTypeCode.periodEnded => 'PERIOD_ENDED',
        V1SemanticTypeCode.temporarySuspensionStarted =>
          'TEMPORARY_SUSPENSION_STARTED',
        V1SemanticTypeCode.temporarySuspensionEnded =>
          'TEMPORARY_SUSPENSION_ENDED',
        V1SemanticTypeCode.matchAbandoned => 'MATCH_ABANDONED',
        V1SemanticTypeCode.matchEnded => 'MATCH_ENDED',
        V1SemanticTypeCode.goal => 'GOAL',
        V1SemanticTypeCode.temporalCorrection => 'TEMPORAL_CORRECTION',
        V1SemanticTypeCode.correction => 'CORRECTION',
        V1SemanticTypeCode.legalSupersession => 'LEGAL_SUPERSESSION',
      };

  SemanticTypeCategory get category => switch (this) {
        V1SemanticTypeCode.matchStarted ||
        V1SemanticTypeCode.periodStarted ||
        V1SemanticTypeCode.periodEnded ||
        V1SemanticTypeCode.temporarySuspensionStarted ||
        V1SemanticTypeCode.temporarySuspensionEnded ||
        V1SemanticTypeCode.matchAbandoned ||
        V1SemanticTypeCode.matchEnded ||
        V1SemanticTypeCode.temporalCorrection =>
          SemanticTypeCategory.temporal,
        V1SemanticTypeCode.goal => SemanticTypeCategory.event,
        V1SemanticTypeCode.correction ||
        V1SemanticTypeCode.legalSupersession =>
          SemanticTypeCategory.correctionSupersession,
      };

  static V1SemanticTypeCode? parseWire(String value) => switch (value) {
        'MATCH_STARTED' => V1SemanticTypeCode.matchStarted,
        'PERIOD_STARTED' => V1SemanticTypeCode.periodStarted,
        'PERIOD_ENDED' => V1SemanticTypeCode.periodEnded,
        'TEMPORARY_SUSPENSION_STARTED' =>
          V1SemanticTypeCode.temporarySuspensionStarted,
        'TEMPORARY_SUSPENSION_ENDED' =>
          V1SemanticTypeCode.temporarySuspensionEnded,
        'MATCH_ABANDONED' => V1SemanticTypeCode.matchAbandoned,
        'MATCH_ENDED' => V1SemanticTypeCode.matchEnded,
        'GOAL' => V1SemanticTypeCode.goal,
        'TEMPORAL_CORRECTION' => V1SemanticTypeCode.temporalCorrection,
        'CORRECTION' => V1SemanticTypeCode.correction,
        'LEGAL_SUPERSESSION' => V1SemanticTypeCode.legalSupersession,
        _ => null,
      };
}

/// Typed semantic identity. Distinct from [RecordKind] and schema version.
final class MatchRecordSemanticIdentity {
  const MatchRecordSemanticIdentity({
    required this.schemaVersion,
    required this.code,
  });

  final int schemaVersion;
  final V1SemanticTypeCode code;

  SemanticTypeCategory get category => code.category;
}
