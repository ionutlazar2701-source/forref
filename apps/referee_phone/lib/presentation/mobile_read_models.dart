import 'package:forref_match_core/forref_match_core.dart';

import '../companion/companion_device.dart';
import '../mobile_commands/mobile_command_availability.dart';

/// Read model. Flags describe readiness. They do not grant authority.
final class MobileMatchReadiness {
  const MobileMatchReadiness({
    required this.matchConfigured,
    required this.localStorageReady,
    required this.temporalEvidenceReady,
    required this.authorityKnown,
    required this.companionPresent,
    required this.companionCertified,
    required this.companionProvisioned,
    required this.mode,
  });

  final bool matchConfigured;
  final bool localStorageReady;
  final bool temporalEvidenceReady;
  final bool authorityKnown;
  final bool companionPresent;
  final bool companionCertified;
  final bool companionProvisioned;
  final MobileOperatingMode mode;
}

/// Product mode derived for display. Never invents watch-primary authority.
MobileOperatingMode deriveOperatingMode({
  required CompanionDevice? device,
  required MobileAuthoritySnapshot authority,
}) {
  if (authority.mode == MobileOperatingMode.watchPrimaryFuture) {
    return MobileOperatingMode.watchPrimaryFuture;
  }
  if (device == null) return MobileOperatingMode.phoneOnly;
  final prepared =
      device.certificationState == CompanionCertificationState.certified ||
          device.pairingReadiness == PairingReadiness.readyForProvisioning;
  if (prepared) return MobileOperatingMode.companionPrepared;
  return MobileOperatingMode.phonePrimary;
}

/// Established production report content. Disciplinary rows are not synthesized.
final class MobileMatchReportState {
  const MobileMatchReportState({
    required this.matchId,
    required this.score,
  });

  final String matchId;
  final ScoreProjection? score;

  bool get includesDisciplinaryRows => false;

  bool get includesSubstitutionRows => false;
}

final class MobileDeviceReadModel {
  const MobileDeviceReadModel({
    required this.pairingReadiness,
    required this.device,
    required this.mode,
  });

  final PairingReadiness pairingReadiness;
  final CompanionDevice? device;
  final MobileOperatingMode mode;

  bool get companionPresent => device != null;
}

/// Committed identity stays put when transport notices arrive out of order.
List<String> authoritativeRecordOrder({
  required List<String> committedRecordIds,
  required List<Object> transportArrivals,
}) {
  return List.unmodifiable(committedRecordIds);
}
