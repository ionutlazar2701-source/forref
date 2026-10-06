import 'v1_semantic_payload.dart';
import 'disciplinary_system.dart';

/// Whether competition rules support ordinary Yellow Card V1 semantics.
enum YellowCardDisciplinarySystemSupport {
  /// Ordinary IFAB Yellow Card V1 is supported for lawful admission.
  supported,

  /// Known modified disciplinary system; ordinary standing effect unsupported.
  unsupportedModifiedSystem,

  /// Disciplinary system unresolved; authoritative capture must fail closed.
  unresolved,
}

/// Reusable domain assessment for future [commitYellowCard] admission.
abstract final class YellowCardDisciplinarySystemSupportGate {
  static YellowCardDisciplinarySystemSupport assess(
    CompetitionRulesContext? rules,
  ) {
    if (rules == null) {
      return YellowCardDisciplinarySystemSupport.unresolved;
    }
    return switch (rules.disciplinarySystem) {
      DisciplinarySystem.ordinaryIfab =>
        YellowCardDisciplinarySystemSupport.supported,
      DisciplinarySystem.temporaryDismissal =>
        YellowCardDisciplinarySystemSupport.unsupportedModifiedSystem,
      DisciplinarySystem.unresolved =>
        YellowCardDisciplinarySystemSupport.unresolved,
    };
  }
}
