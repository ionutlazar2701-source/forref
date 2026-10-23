import 'mobile_command.dart';

enum MobileCommandAvailabilityKind {
  available,
  unavailable,
  unsupported,
  authorityRequired,
  notYetCutOver,
}

enum MobileOperatingMode {
  phoneOnly,
  phonePrimary,
  companionPrepared,

  /// Explicit test/reference state. Production composition never selects it.
  watchPrimaryFuture,
}

/// Device permission to append authoritative records.
///
/// Pairing, connection, and certification do not belong in this snapshot.
final class MobileAuthoritySnapshot {
  const MobileAuthoritySnapshot({
    required this.localCaptureAuthorized,
    required this.companionHoldsCaptureAuthority,
    required this.mode,
  });

  final bool localCaptureAuthorized;
  final bool companionHoldsCaptureAuthority;
  final MobileOperatingMode mode;

  static const phoneOnly = MobileAuthoritySnapshot(
    localCaptureAuthorized: true,
    companionHoldsCaptureAuthority: false,
    mode: MobileOperatingMode.phoneOnly,
  );
}

/// Match-phase hint for the catalog. It does not decide sporting truth.
final class MobilePhaseHint {
  const MobilePhaseHint({this.kickOffCommitted = false});

  final bool kickOffCommitted;

  static const open = MobilePhaseHint();
}

final class MobileCommandAvailability {
  const MobileCommandAvailability({
    required this.commandType,
    required this.kind,
    required this.reasonCode,
  });

  final MobileCommandType commandType;
  final MobileCommandAvailabilityKind kind;
  final String reasonCode;
}

abstract final class MobileCommandReason {
  static const productionCutOver = 'production_cut_over';
  static const notYetCutOver = 'not_yet_cut_over';
  static const authorityUnavailable = 'authority_unavailable';
  static const singleWriter = 'single_writer';
  static const watchPrimaryNotAuthorized = 'watch_primary_not_authorized';
  static const alreadyCommitted = 'already_committed';
  static const schemaMismatch = 'schema_mismatch';
  static const commandIdentityConflict = 'command_identity_conflict';
}

/// Commands the phone boundary can commit today.
abstract final class ProductionCommandCatalog {
  static const cutOver = {
    MobileCommandType.kickOff,
    MobileCommandType.goal,
  };

  static bool isCutOver(MobileCommandType type) => cutOver.contains(type);
}
