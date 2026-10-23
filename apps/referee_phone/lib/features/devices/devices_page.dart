import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../l10n/app_localizations.dart';
import '../live_match/command_availability_panel.dart';

class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final device = AppScope.of(context).mobileCommands.deviceState().device;
    return Scaffold(
      key: const Key('devices-page'),
      appBar: AppBar(title: Text(l10n.devicesTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (device == null) ...[
            Text(l10n.noCompanionDevice),
            const SizedBox(height: 8),
            Text(l10n.phoneCanRunMatch),
            const SizedBox(height: 8),
            Text(l10n.phoneOnlyMode),
            Text(l10n.pairingNotPaired),
          ] else ...[
            Text(device.displayName),
            Text(platformFamilyLabel(l10n, device.platformFamily)),
            Text(connectionLabel(l10n, device.connectionState)),
            Text(certificationLabel(l10n, device.certificationState)),
            if (device.capabilities.isEmpty)
              Text(l10n.noDeclaredCapabilities)
            else
              for (final capability in device.capabilities)
                Text(capabilityLabel(l10n, capability)),
            if (!device.holdsCaptureAuthority)
              Text(l10n.companionDoesNotControlMatch),
          ],
        ],
      ),
    );
  }
}
