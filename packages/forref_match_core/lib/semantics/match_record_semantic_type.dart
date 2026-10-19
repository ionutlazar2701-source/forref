/// Category of typed record semantics, independent from [RecordKind].
enum SemanticTypeCategory {
  temporal,
  authorityControl,
  correctionSupersession,
  event,
}

/// How a supported semantic affects projection.
///
/// None of the v1 vocabulary computes elapsed time or sporting event state.
enum SemanticEffect {
  /// Authoritative temporal transition. Not a durable match state.
  temporalTransitionAuthority,

  /// New record that changes how prior history is interpreted.
  historicalInterpretation,
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
  temporalCorrection,
  correction,
  legalSupersession,
  goal,
  yellowCard,
  sendOff,
  refereeEnteredFieldForMatchStart,
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
        V1SemanticTypeCode.temporalCorrection => 'TEMPORAL_CORRECTION',
        V1SemanticTypeCode.correction => 'CORRECTION',
        V1SemanticTypeCode.legalSupersession => 'LEGAL_SUPERSESSION',
        V1SemanticTypeCode.goal => 'GOAL',
        V1SemanticTypeCode.yellowCard => 'YELLOW_CARD',
        V1SemanticTypeCode.sendOff => 'SEND_OFF',
        V1SemanticTypeCode.refereeEnteredFieldForMatchStart =>
          'REFEREE_ENTERED_FIELD_FOR_MATCH_START',
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
        V1SemanticTypeCode.correction ||
        V1SemanticTypeCode.legalSupersession =>
          SemanticTypeCategory.correctionSupersession,
        V1SemanticTypeCode.goal => SemanticTypeCategory.event,
        V1SemanticTypeCode.yellowCard => SemanticTypeCategory.event,
        V1SemanticTypeCode.sendOff => SemanticTypeCategory.event,
        V1SemanticTypeCode.refereeEnteredFieldForMatchStart =>
          SemanticTypeCategory.authorityControl,
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
        'TEMPORAL_CORRECTION' => V1SemanticTypeCode.temporalCorrection,
        'CORRECTION' => V1SemanticTypeCode.correction,
        'LEGAL_SUPERSESSION' => V1SemanticTypeCode.legalSupersession,
        'GOAL' => V1SemanticTypeCode.goal,
        'YELLOW_CARD' => V1SemanticTypeCode.yellowCard,
        'SEND_OFF' => V1SemanticTypeCode.sendOff,
        'REFEREE_ENTERED_FIELD_FOR_MATCH_START' =>
          V1SemanticTypeCode.refereeEnteredFieldForMatchStart,
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
