import '../disciplinary_subject.dart';
import '../match_participant.dart';
import '../match_team.dart';
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
      V1SemanticTypeCode.temporalCorrection ||
      V1SemanticTypeCode.correction ||
      V1SemanticTypeCode.legalSupersession ||
      V1SemanticTypeCode.goal ||
      V1SemanticTypeCode.yellowCard ||
      V1SemanticTypeCode.sendOff ||
      V1SemanticTypeCode.refereeEnteredFieldForMatchStart =>
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
/// Explicit caution ledger. Unresolved scope has no value and cannot be stored.
enum DisciplinaryAccountingScope {
  match,
  shootout,
}

extension DisciplinaryAccountingScopeWire on DisciplinaryAccountingScope {
  String get wireValue => switch (this) {
        DisciplinaryAccountingScope.match => 'MATCH',
        DisciplinaryAccountingScope.shootout => 'SHOOTOUT',
      };

  static DisciplinaryAccountingScope? parseWire(String? value) =>
      switch (value) {
        'MATCH' => DisciplinaryAccountingScope.match,
        'SHOOTOUT' => DisciplinaryAccountingScope.shootout,
        _ => null,
      };
}

final class CorrectionPayload extends V1SemanticPayload {
  const CorrectionPayload({
    this.repairedScoringTeamId,
    this.repairedParticipantId,
    this.repairedAccountingScope,
    this.repairedDisciplinarySubject,
    this.repairedDisciplinaryScope,
    super.domainContractVersion,
    super.competitionRulesContext,
  });

  /// Required when this correction repairs a Goal; optional for other targets.
  final MatchTeamId? repairedScoringTeamId;

  /// Required when this correction repairs a v1 Yellow participant.
  final MatchParticipantId? repairedParticipantId;

  /// Required when this correction repairs a v1 Yellow accounting scope.
  final DisciplinaryAccountingScope? repairedAccountingScope;

  /// v2 subject repair. It does not rewrite the original Yellow record.
  final DisciplinarySubjectRef? repairedDisciplinarySubject;

  /// v2 scope repair. The same concept as [repairedAccountingScope].
  final DisciplinaryAccountingScope? repairedDisciplinaryScope;

  @override
  V1SemanticTypeCode get semanticType => V1SemanticTypeCode.correction;
}

/// Authoritative Goal awarded to [scoringTeamId].
final class GoalPayload extends V1SemanticPayload {
  GoalPayload({
    required this.scoringTeamId,
    required this.captureIntentId,
    super.domainContractVersion,
    super.competitionRulesContext,
  }) : assert(captureIntentId.isNotEmpty);

  final MatchTeamId scoringTeamId;
  final String captureIntentId;

  @override
  V1SemanticTypeCode get semanticType => V1SemanticTypeCode.goal;
}

/// Authoritative administered caution. Intention is not this record.
final class YellowCardPayload extends V1SemanticPayload {
  YellowCardPayload({
    required this.participantId,
    required this.accountingScope,
    required this.captureIntentId,
    this.situationAtDetermination,
    super.domainContractVersion,
    super.competitionRulesContext,
  }) : assert(captureIntentId.isNotEmpty);

  final MatchParticipantId participantId;
  final DisciplinaryAccountingScope accountingScope;
  final String captureIntentId;

  /// Historical context. It is not [participantId].
  final ParticipantSituation? situationAtDetermination;

  @override
  V1SemanticTypeCode get semanticType => V1SemanticTypeCode.yellowCard;

  /// Historical participant Yellow. Stored bytes stay participant-only.
  int get yellowSchemaVersion => yellowCardPayloadSchemaV1;
}

/// Additive Yellow schema. Team-official cautions use only this payload.
final class YellowCardPayloadV2 extends V1SemanticPayload {
  YellowCardPayloadV2({
    required this.disciplinarySubject,
    required this.accountingScope,
    required this.captureIntentId,
    this.participantSituationAtDetermination,
    super.domainContractVersion,
    super.competitionRulesContext,
  }) : assert(captureIntentId.isNotEmpty),
       assert(
         disciplinarySubject is ParticipantDisciplinarySubject ||
             participantSituationAtDetermination == null,
         'participant situation is only legal for a participant subject',
       );

  final DisciplinarySubjectRef disciplinarySubject;
  final DisciplinaryAccountingScope accountingScope;
  final String captureIntentId;

  /// Historical context for a participant subject. It is not identity.
  final ParticipantSituation? participantSituationAtDetermination;

  @override
  V1SemanticTypeCode get semanticType => V1SemanticTypeCode.yellowCard;

  int get yellowSchemaVersion => yellowCardPayloadSchemaV2;
}

/// Explicit sending-off pathway. Count is not a pathway.
enum SendOffPathway {
  direct,
  secondCaution,
}

extension SendOffPathwayWire on SendOffPathway {
  String get wireValue => switch (this) {
        SendOffPathway.direct => 'DIRECT',
        SendOffPathway.secondCaution => 'SECOND_CAUTION',
      };

  static SendOffPathway? parseWire(String? value) => switch (value) {
        'DIRECT' => SendOffPathway.direct,
        'SECOND_CAUTION' => SendOffPathway.secondCaution,
        _ => null,
      };
}

/// Explicit referee sending-off. Two Yellow records do not construct this.
final class SendOffPayload extends V1SemanticPayload {
  SendOffPayload({
    required this.disciplinarySubject,
    required this.disciplinaryScope,
    required this.pathway,
    required this.captureIntentId,
    this.firstStandingCautionRecordId,
    this.secondCautionRecordId,
    super.domainContractVersion,
    super.competitionRulesContext,
  }) : assert(captureIntentId.isNotEmpty),
       assert(
         _rolesMatch(
           pathway: pathway,
           firstStandingCautionRecordId: firstStandingCautionRecordId,
           secondCautionRecordId: secondCautionRecordId,
         ),
       );

  final DisciplinarySubjectRef disciplinarySubject;
  final DisciplinaryAccountingScope disciplinaryScope;
  final SendOffPathway pathway;
  final String captureIntentId;
  final String? firstStandingCautionRecordId;
  final String? secondCautionRecordId;

  static bool _rolesMatch({
    required SendOffPathway pathway,
    required String? firstStandingCautionRecordId,
    required String? secondCautionRecordId,
  }) {
    if (pathway == SendOffPathway.direct) {
      return firstStandingCautionRecordId == null &&
          secondCautionRecordId == null;
    }
    return firstStandingCautionRecordId != null &&
        firstStandingCautionRecordId.isNotEmpty &&
        secondCautionRecordId != null &&
        secondCautionRecordId.isNotEmpty &&
        firstStandingCautionRecordId != secondCautionRecordId;
  }

  @override
  V1SemanticTypeCode get semanticType => V1SemanticTypeCode.sendOff;
}

/// Referee entered the field for match start.
///
/// This is not MATCH_STARTED and not PERIOD_STARTED.
final class RefereeEnteredFieldPayload extends V1SemanticPayload {
  RefereeEnteredFieldPayload({
    required this.captureIntentId,
    super.domainContractVersion,
    super.competitionRulesContext,
  }) : assert(captureIntentId.isNotEmpty);

  final String captureIntentId;

  @override
  V1SemanticTypeCode get semanticType =>
      V1SemanticTypeCode.refereeEnteredFieldForMatchStart;
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

/// Stored Yellow payload schema. Distinct from Match Record structural schema.
const int yellowCardPayloadSchemaV1 = 1;

/// Team-official Yellow and optional participant Yellow v2.
const int yellowCardPayloadSchemaV2 = 2;

/// True for historical v1 and additive v2 Yellow payloads.
bool isYellowCardPayload(MatchRecordPayload payload) =>
    payload is YellowCardPayload || payload is YellowCardPayloadV2;

/// v1 stays participant-only. v2 carries [DisciplinarySubjectRef].
int yellowCardPayloadSchemaVersion(MatchRecordPayload payload) {
  if (payload is YellowCardPayload) return yellowCardPayloadSchemaV1;
  if (payload is YellowCardPayloadV2) return yellowCardPayloadSchemaV2;
  throw ArgumentError.value(payload, 'payload', 'not a Yellow payload');
}

/// Read-time subject. v1 normalizes to a participant subject.
DisciplinarySubjectRef subjectOfYellowCard(MatchRecordPayload payload) {
  if (payload is YellowCardPayload) {
    return ParticipantDisciplinarySubject(payload.participantId);
  }
  if (payload is YellowCardPayloadV2) return payload.disciplinarySubject;
  throw ArgumentError.value(payload, 'payload', 'not a Yellow payload');
}

DisciplinaryAccountingScope scopeOfYellowCard(MatchRecordPayload payload) {
  if (payload is YellowCardPayload) return payload.accountingScope;
  if (payload is YellowCardPayloadV2) return payload.accountingScope;
  throw ArgumentError.value(payload, 'payload', 'not a Yellow payload');
}

String captureIntentOfYellowCard(MatchRecordPayload payload) {
  if (payload is YellowCardPayload) return payload.captureIntentId;
  if (payload is YellowCardPayloadV2) return payload.captureIntentId;
  throw ArgumentError.value(payload, 'payload', 'not a Yellow payload');
}

ParticipantSituation? situationOfYellowCard(MatchRecordPayload payload) {
  if (payload is YellowCardPayload) return payload.situationAtDetermination;
  if (payload is YellowCardPayloadV2) {
    return payload.participantSituationAtDetermination;
  }
  throw ArgumentError.value(payload, 'payload', 'not a Yellow payload');
}
