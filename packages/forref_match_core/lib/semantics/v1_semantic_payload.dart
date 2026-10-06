import '../participant/match_participant_id.dart';
import '../participant/participant_binding.dart';
import '../participant/participant_status_at_determination.dart';
import '../participant/participant_team_side.dart';
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

/// Side credited with a goal. This is the scoring side, not a player.
enum CreditedSide { home, away }

extension CreditedSideWire on CreditedSide {
  String get wireValue => switch (this) {
        CreditedSide.home => 'HOME',
        CreditedSide.away => 'AWAY',
      };

  static CreditedSide? parseWire(String value) => switch (value) {
        'HOME' => CreditedSide.home,
        'AWAY' => CreditedSide.away,
        _ => null,
      };
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
      V1SemanticTypeCode.temporalCorrection ||
      V1SemanticTypeCode.correction ||
      V1SemanticTypeCode.legalSupersession ||
      V1SemanticTypeCode.goal ||
      V1SemanticTypeCode.participantRegistered ||
      V1SemanticTypeCode.participantBindingCorrected ||
      V1SemanticTypeCode.participantIdentityReconciliation =>
        false,
      V1SemanticTypeCode.refereeEnteredFieldForMatchStart ||
      V1SemanticTypeCode.refereeLeftFieldAfterMatch =>
        true,
    };
  }
}

/// Credited goal. Player attribution is later enrichment and is not required.
///
/// [captureIntentId] is the referee action's idempotency key. It is not
/// match time and it is not a player identifier.
final class GoalPayload extends V1SemanticPayload {
  GoalPayload({
    required this.creditedSide,
    required this.captureIntentId,
    super.domainContractVersion,
    super.competitionRulesContext,
  }) : assert(
          captureIntentId.isNotEmpty,
          'GOAL requires a capture intent',
        );

  final CreditedSide creditedSide;

  /// Stable id for one deliberate Goal capture. A retry of the same intent
  /// must not append another GOAL.
  final String captureIntentId;

  @override
  V1SemanticTypeCode get semanticType => V1SemanticTypeCode.goal;
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

/// Establishes one durable [MatchParticipantId] and its initial binding.
final class ParticipantRegisteredPayload extends V1SemanticPayload {
  ParticipantRegisteredPayload({
    required this.matchParticipantId,
    required this.teamSide,
    required this.binding,
    this.initialStatus,
    super.domainContractVersion,
    super.competitionRulesContext,
  });

  final MatchParticipantId matchParticipantId;
  final ParticipantTeamSide teamSide;
  final ParticipantBinding binding;

  /// Optional status snapshot at registration. Does not define identity.
  final ParticipantStatusAtDetermination? initialStatus;

  @override
  V1SemanticTypeCode get semanticType => V1SemanticTypeCode.participantRegistered;
}

/// Corrects binding evidence for an existing participant registration.
final class ParticipantBindingCorrectionPayload extends V1SemanticPayload {
  ParticipantBindingCorrectionPayload({
    required this.matchParticipantId,
    required this.correctedBinding,
    super.domainContractVersion,
    super.competitionRulesContext,
  });

  final MatchParticipantId matchParticipantId;
  final ParticipantBinding correctedBinding;

  @override
  V1SemanticTypeCode get semanticType =>
      V1SemanticTypeCode.participantBindingCorrected;
}

/// Maps a provisional participant identity to a canonical participant identity.
final class ParticipantIdentityReconciliationPayload extends V1SemanticPayload {
  ParticipantIdentityReconciliationPayload({
    required this.fromParticipantId,
    required this.toParticipantId,
    super.domainContractVersion,
    super.competitionRulesContext,
  }) : assert(
          fromParticipantId.value != toParticipantId.value,
          'Reconciliation requires distinct participant ids',
        );

  final MatchParticipantId fromParticipantId;
  final MatchParticipantId toParticipantId;

  @override
  V1SemanticTypeCode get semanticType =>
      V1SemanticTypeCode.participantIdentityReconciliation;
}
