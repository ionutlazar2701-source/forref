/// What the research UI is allowed to say about recovery.
///
/// Bank K classifies production capability. This label never upgrades a
/// simulated restart into a production guarantee.
abstract final class RecoveryClaim {
  static const finishLaterLabel = 'SIMULATED RECOVERY BEHAVIOR';
  static const simulatedSavedLabel = 'SIMULATED SAVED — not production D1';
  static const saveNotVerifiedLabel =
      'SAVE NOT VERIFIED — outcome is not known';
  static const notSavedLabel = 'NOT SAVED — known simulated failure';

  static const claimsProductionRecoveryGuarantee = false;
  static const claimsProductionFinishLater = false;
}
