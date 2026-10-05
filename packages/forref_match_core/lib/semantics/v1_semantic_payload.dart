import '../payload.dart';
import 'match_record_semantic_type.dart';

/// Domain-contract generation. Distinct from Match Record [schemaVersion].
final class DomainContractVersion {
  const DomainContractVersion(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      other is DomainContractVersion && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Competition period identified by index.
///
/// Index 1 is the first period of the current rules context. This is not a
/// football half count and does not configure the full period schedule.
final class PeriodIdentity {
  const PeriodIdentity({required this.index}) : assert(index >= 1);

  final int index;

  @override
  bool operator ==(Object other) =>
      other is PeriodIdentity && index == other.index;

  @override
  int get hashCode => index.hashCode;
}

/// Whether another playing period is required before normal match end.
///
/// A penalty shoot-out is not a playing period and is not one of these values.
enum AdditionalPlayingPhaseDisposition {
  noneRequired,
  additionalPlayingPhaseRequired,
  unresolved,
}

extension AdditionalPlayingPhaseDispositionWire on AdditionalPlayingPhaseDisposition {
  String get wireValue => switch (this) {
        AdditionalPlayingPhaseDisposition.noneRequired => 'NONE_REQUIRED',
        AdditionalPlayingPhaseDisposition.additionalPlayingPhaseRequired =>
          'ADDITIONAL_PLAYING_PHASE_REQUIRED',
        AdditionalPlayingPhaseDisposition.unresolved => 'UNRESOLVED',
      };

  static AdditionalPlayingPhaseDisposition? parseWire(String value) =>
      switch (value) {
        'NONE_REQUIRED' => AdditionalPlayingPhaseDisposition.noneRequired,
        'ADDITIONAL_PLAYING_PHASE_REQUIRED' =>
          AdditionalPlayingPhaseDisposition.additionalPlayingPhaseRequired,
        'UNRESOLVED' => AdditionalPlayingPhaseDisposition.unresolved,
        _ => null,
      };
}

/// Competition-rules context. Distinct from semantic type and schema version.
///
/// [additionalPlayingPhase] is an explicit rules decision. It is unresolved
/// unless a competition format states otherwise. Period count and score do
/// not fill it in.
final class CompetitionRulesContext {
  const CompetitionRulesContext({
    required this.rulesetId,
    this.additionalPlayingPhase = AdditionalPlayingPhaseDisposition.unresolved,
    this.penaltyShootOutAfterMatchEnd = false,
  });

  final String rulesetId;

  /// Explicit playing-phase decision for this rules context.
  final AdditionalPlayingPhaseDisposition additionalPlayingPhase;

  /// Kicks from the penalty mark after the match has ended.
  ///
  /// This does not require another playing period.
  final bool penaltyShootOutAfterMatchEnd;

  @override
  bool operator ==(Object other) =>
      other is CompetitionRulesContext &&
      rulesetId == other.rulesetId &&
      additionalPlayingPhase == other.additionalPlayingPhase &&
      penaltyShootOutAfterMatchEnd == other.penaltyShootOutAfterMatchEnd;

  @override
  int get hashCode => Object.hash(
        rulesetId,
        additionalPlayingPhase,
        penaltyShootOutAfterMatchEnd,
      );
}

/// Typed v1 production payload. Not a foundation facet-key map.
sealed class V1SemanticPayload extends MatchRecordPayload {
  const V1SemanticPayload({
    this.domainContractVersion,
    this.competitionRulesContext,
  });

  V1SemanticTypeCode get semanticType;

  /// Optional domain clock / operating contract pin. Not schemaVersion.
  final DomainContractVersion? domainContractVersion;

  /// Optional competition rules pin. Not a semantic type.
  final CompetitionRulesContext? competitionRulesContext;
}

/// Temporal transition fact. [semanticType] is the transition, not a match state.
final class TemporalTransitionPayload extends V1SemanticPayload {
  TemporalTransitionPayload({
    required this.semanticType,
    this.period,
    super.domainContractVersion,
    super.competitionRulesContext,
  }) : assert(_isTransition(semanticType)),
       assert(
         semanticType != V1SemanticTypeCode.periodStarted || period != null,
         'PERIOD_STARTED requires a period identity',
       ),
       assert(
         semanticType != V1SemanticTypeCode.temporarySuspensionStarted ||
             period != null,
         'TEMPORARY_SUSPENSION_STARTED requires a period identity',
       ),
       assert(
         semanticType != V1SemanticTypeCode.temporarySuspensionEnded ||
             period != null,
         'TEMPORARY_SUSPENSION_ENDED requires a period identity',
       ),
       assert(
         semanticType != V1SemanticTypeCode.periodEnded || period != null,
         'PERIOD_ENDED requires a period identity',
       );

  @override
  final V1SemanticTypeCode semanticType;

  /// Set for period start, period end, formal suspension start, and resumption.
  final PeriodIdentity? period;

  static bool _isTransition(V1SemanticTypeCode code) {
    return switch (code) {
      V1SemanticTypeCode.matchStarted ||
      V1SemanticTypeCode.periodStarted ||
      V1SemanticTypeCode.periodEnded ||
      V1SemanticTypeCode.temporarySuspensionStarted ||
      V1SemanticTypeCode.temporarySuspensionEnded ||
      V1SemanticTypeCode.matchAbandoned ||
      V1SemanticTypeCode.matchEnded =>
        true,
      V1SemanticTypeCode.goal ||
      V1SemanticTypeCode.temporalCorrection ||
      V1SemanticTypeCode.correction ||
      V1SemanticTypeCode.legalSupersession =>
        false,
    };
  }
}

/// Temporal correction of an existing record. Does not replace that record's id.
final class TemporalCorrectionPayload extends V1SemanticPayload {
  const TemporalCorrectionPayload({
    super.domainContractVersion,
    super.competitionRulesContext,
  });

  @override
  V1SemanticTypeCode get semanticType => V1SemanticTypeCode.temporalCorrection;
}

/// Historical correction. The corrected record remains in Match Memory.
final class CorrectionPayload extends V1SemanticPayload {
  const CorrectionPayload({
    super.domainContractVersion,
    super.competitionRulesContext,
  });

  @override
  V1SemanticTypeCode get semanticType => V1SemanticTypeCode.correction;
}

/// Legal supersession. The superseded record remains in Match Memory.
final class LegalSupersessionPayload extends V1SemanticPayload {
  const LegalSupersessionPayload({
    super.domainContractVersion,
    super.competitionRulesContext,
  });

  @override
  V1SemanticTypeCode get semanticType => V1SemanticTypeCode.legalSupersession;
}

/// Side credited with the goal. This is the scoring identity, not a stored score.
///
/// An own goal uses the side that is credited. It is not a separate semantic.
enum GoalScoringSide {
  home,
  away,
}

extension GoalScoringSideWire on GoalScoringSide {
  String get wireValue => switch (this) {
        GoalScoringSide.home => 'HOME',
        GoalScoringSide.away => 'AWAY',
      };

  static GoalScoringSide? parseWire(String value) => switch (value) {
        'HOME' => GoalScoringSide.home,
        'AWAY' => GoalScoringSide.away,
        _ => null,
      };
}

/// GOAL means the main referee has determined that a valid goal stands for one side.
///
/// [scoringSide] is the required sporting content: the side credited with the
/// goal, including when that goal is an own goal. [playerId] and [playerNumber]
/// are optional enrichment and are never required for the commit.
///
/// [period] is placement context. It must match the causally targeted
/// `PERIOD_STARTED`. Elapsed match time is not stored here; temporal evidence
/// on the record is what a later projection uses to reconstruct match time.
final class GoalPayload extends V1SemanticPayload {
  GoalPayload({
    required this.scoringSide,
    required this.period,
    this.playerId,
    this.playerNumber,
    super.domainContractVersion,
    super.competitionRulesContext,
  }) : assert(playerId == null || playerId.isNotEmpty),
       assert(playerNumber == null || playerNumber.isNotEmpty);

  @override
  V1SemanticTypeCode get semanticType => V1SemanticTypeCode.goal;

  final GoalScoringSide scoringSide;
  final PeriodIdentity period;
  final String? playerId;
  final String? playerNumber;

  @override
  bool operator ==(Object other) {
    return other is GoalPayload &&
        scoringSide == other.scoringSide &&
        period == other.period &&
        playerId == other.playerId &&
        playerNumber == other.playerNumber &&
        domainContractVersion == other.domainContractVersion &&
        competitionRulesContext == other.competitionRulesContext;
  }

  @override
  int get hashCode => Object.hash(
        scoringSide,
        period,
        playerId,
        playerNumber,
        domainContractVersion,
        competitionRulesContext,
      );
}
