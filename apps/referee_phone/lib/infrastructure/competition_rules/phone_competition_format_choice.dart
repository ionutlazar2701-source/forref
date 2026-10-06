import 'package:forref_match_core/forref_match_core.dart';

/// Setup-facing competition format choice. Not a Match Record semantic type.
enum PhoneCompetitionFormatChoice {
  noAdditionalPlayingPeriods,
  additionalPlayingPhaseMayApply,
}

extension PhoneCompetitionFormatChoiceMapping on PhoneCompetitionFormatChoice {
  static PhoneCompetitionFormatChoice fromRules(
    CompetitionRulesContext rules,
  ) {
    return switch (rules.additionalPlayingPhase) {
      AdditionalPlayingPhaseDisposition.noneRequired =>
        PhoneCompetitionFormatChoice.noAdditionalPlayingPeriods,
      AdditionalPlayingPhaseDisposition.unresolved ||
      AdditionalPlayingPhaseDisposition.additionalPlayingPhaseRequired =>
        PhoneCompetitionFormatChoice.additionalPlayingPhaseMayApply,
    };
  }

  AdditionalPlayingPhaseDisposition get additionalPlayingPhase =>
      switch (this) {
        PhoneCompetitionFormatChoice.noAdditionalPlayingPeriods =>
          AdditionalPlayingPhaseDisposition.noneRequired,
        PhoneCompetitionFormatChoice.additionalPlayingPhaseMayApply =>
          AdditionalPlayingPhaseDisposition.unresolved,
      };

  CompetitionRulesContext toRulesContext({
    required bool penaltyShootOutAfterMatchEnd,
    String rulesetId = 'ifab',
  }) {
    return CompetitionRulesContext(
      rulesetId: rulesetId,
      additionalPlayingPhase: additionalPlayingPhase,
      penaltyShootOutAfterMatchEnd: penaltyShootOutAfterMatchEnd,
      disciplinarySystem: DisciplinarySystem.ordinaryIfab,
    );
  }
}
