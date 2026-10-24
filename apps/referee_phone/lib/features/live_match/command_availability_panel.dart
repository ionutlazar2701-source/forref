import 'package:flutter/material.dart';

import '../../companion/companion_device.dart';
import '../../l10n/app_localizations.dart';
import '../../mobile_commands/mobile_command.dart';
import '../../mobile_commands/mobile_command_availability.dart';

class CommandAvailabilityPanel extends StatelessWidget {
  const CommandAvailabilityPanel({
    super.key,
    required this.catalog,
    required this.localStorageReady,
  });

  final List<MobileCommandAvailability> catalog;
  final bool localStorageReady;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      key: const Key('command-availability'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          l10n.commandAvailabilityTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (localStorageReady) Text(l10n.localStorageReady),
        Text(l10n.phoneOnlyMode),
        for (final entry in catalog) Text(_line(l10n, entry)),
        Text(l10n.matchReportDisciplineUnsupported),
      ],
    );
  }

  String _line(AppLocalizations l10n, MobileCommandAvailability entry) {
    return switch (entry.commandType) {
      MobileCommandType.kickOff => switch (entry.kind) {
          MobileCommandAvailabilityKind.available =>
            l10n.kickOffCommandAvailable,
          MobileCommandAvailabilityKind.authorityRequired =>
            l10n.authorityRequiredForCommand(l10n.kickOff),
          _ => l10n.kickOffCommandUnavailable,
        },
      MobileCommandType.goal => switch (entry.kind) {
          MobileCommandAvailabilityKind.available => l10n.goalCommandAvailable,
          MobileCommandAvailabilityKind.authorityRequired =>
            l10n.authorityRequiredForCommand(l10n.goal),
          _ => l10n.goalCommandUnavailable,
        },
      _ => switch (entry.kind) {
          MobileCommandAvailabilityKind.authorityRequired =>
            l10n.authorityRequiredForCommand(_name(l10n, entry.commandType)),
          _ => l10n.notInProductionBuild(_name(l10n, entry.commandType)),
        },
    };
  }

  String _name(AppLocalizations l10n, MobileCommandType type) {
    return switch (type) {
      MobileCommandType.kickOff => l10n.kickOff,
      MobileCommandType.goal => l10n.goal,
      MobileCommandType.yellow => l10n.commandNameYellow,
      MobileCommandType.directSendOff => l10n.commandNameDirectSendOff,
      MobileCommandType.secondCautionSendOff => l10n.commandNameSecondCaution,
      MobileCommandType.substitution => l10n.commandNameSubstitution,
      MobileCommandType.fullTime => l10n.commandNameFullTime,
      MobileCommandType.finishMatch => l10n.commandNameFinishMatch,
    };
  }
}

String platformFamilyLabel(AppLocalizations l10n, PlatformFamily family) {
  return switch (family) {
    PlatformFamily.wearOs => l10n.platformWearOs,
    PlatformFamily.watchOs => l10n.platformWatchOs,
    PlatformFamily.garmin => l10n.platformGarmin,
    PlatformFamily.zepp => l10n.platformZepp,
    PlatformFamily.huawei => l10n.platformHuawei,
    PlatformFamily.unknown => l10n.platformUnknown,
  };
}

String connectionLabel(
  AppLocalizations l10n,
  CompanionConnectionState state,
) {
  return switch (state) {
    CompanionConnectionState.connected => l10n.connectionConnected,
    CompanionConnectionState.disconnected => l10n.connectionDisconnected,
    CompanionConnectionState.connectionLost => l10n.connectionLostLabel,
  };
}

String certificationLabel(
  AppLocalizations l10n,
  CompanionCertificationState state,
) {
  return switch (state) {
    CompanionCertificationState.unknown => l10n.certificationUnknownLabel,
    CompanionCertificationState.known => l10n.certificationKnownLabel,
    CompanionCertificationState.compatible => l10n.certificationCompatibleLabel,
    CompanionCertificationState.certified => l10n.certificationCertifiedLabel,
  };
}

String capabilityLabel(AppLocalizations l10n, CompanionCapability capability) {
  return switch (capability) {
    CompanionCapability.canCaptureGoal => l10n.capabilityCaptureGoal,
    CompanionCapability.canCaptureYellow => l10n.capabilityCaptureYellow,
    CompanionCapability.canCaptureSendOff => l10n.capabilityCaptureSendOff,
    CompanionCapability.canCaptureSubstitution =>
      l10n.capabilityCaptureSubstitution,
    CompanionCapability.canStoreMatchMemoryLocally =>
      l10n.capabilityLocalMatchMemory,
    CompanionCapability.supportsIndependentMatchTiming =>
      l10n.capabilityIndependentTiming,
    CompanionCapability.supportsLocalHaptics => l10n.capabilityLocalHaptics,
    CompanionCapability.supportsPeerTransport => l10n.capabilityPeerTransport,
  };
}
