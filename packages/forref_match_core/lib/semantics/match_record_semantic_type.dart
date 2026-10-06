/// Category of typed record semantics, independent from [RecordKind].
enum SemanticTypeCategory {
  temporal,
  authorityControl,
  correctionSupersession,
  event,
  participantIdentity,
  cardAuthority,
  disciplinary,
}

/// How a supported semantic affects projection.
///
/// None of these effects compute elapsed time. GOAL records which side is
/// credited; it does not define own-goal, correction, or disciplinary meaning.
enum SemanticEffect {
  /// Authoritative temporal transition. Not a durable match state.
  temporalTransitionAuthority,

  /// New record that changes how prior history is interpreted.
  historicalInterpretation,

  /// Authoritative human determination of one sporting event.
  ///
  /// Does not compute playing time and does not rewrite temporal transitions.
  sportingHumanDetermination,

  /// Establishes or reconciles durable participant identity evidence.
  participantIdentityAuthority,

  /// Opens or closes card-display authority boundaries.
  cardAuthorityTransition,
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
  participantRegistered,
  participantBindingCorrected,
  participantIdentityReconciliation,
  refereeEnteredFieldForMatchStart,
  refereeLeftFieldAfterMatch,
  yellowCard,
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
        V1SemanticTypeCode.participantRegistered => 'PARTICIPANT_REGISTERED',
        V1SemanticTypeCode.participantBindingCorrected =>
          'PARTICIPANT_BINDING_CORRECTED',
        V1SemanticTypeCode.participantIdentityReconciliation =>
          'PARTICIPANT_IDENTITY_RECONCILIATION',
        V1SemanticTypeCode.refereeEnteredFieldForMatchStart =>
          'REFEREE_ENTERED_FIELD_FOR_MATCH_START',
        V1SemanticTypeCode.refereeLeftFieldAfterMatch =>
          'REFEREE_LEFT_FIELD_AFTER_MATCH',
        V1SemanticTypeCode.yellowCard => 'YELLOW_CARD',
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
        V1SemanticTypeCode.participantRegistered ||
        V1SemanticTypeCode.participantIdentityReconciliation =>
          SemanticTypeCategory.participantIdentity,
        V1SemanticTypeCode.participantBindingCorrected =>
          SemanticTypeCategory.participantIdentity,
        V1SemanticTypeCode.refereeEnteredFieldForMatchStart ||
        V1SemanticTypeCode.refereeLeftFieldAfterMatch =>
          SemanticTypeCategory.cardAuthority,
        V1SemanticTypeCode.yellowCard => SemanticTypeCategory.disciplinary,
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
        'PARTICIPANT_REGISTERED' => V1SemanticTypeCode.participantRegistered,
        'PARTICIPANT_BINDING_CORRECTED' =>
          V1SemanticTypeCode.participantBindingCorrected,
        'PARTICIPANT_IDENTITY_RECONCILIATION' =>
          V1SemanticTypeCode.participantIdentityReconciliation,
        'REFEREE_ENTERED_FIELD_FOR_MATCH_START' =>
          V1SemanticTypeCode.refereeEnteredFieldForMatchStart,
        'REFEREE_LEFT_FIELD_AFTER_MATCH' =>
          V1SemanticTypeCode.refereeLeftFieldAfterMatch,
        'YELLOW_CARD' => V1SemanticTypeCode.yellowCard,
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
