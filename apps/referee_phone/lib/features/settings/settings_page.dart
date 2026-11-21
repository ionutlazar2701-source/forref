import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:referee_phone/app_scope.dart';
import 'package:referee_phone/design/forref_spacing.dart';
import 'package:referee_phone/features/settings/debug_local_bridge_section.dart';
import 'package:referee_phone/l10n/app_localizations.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final locale = scope.locale;
    final code = locale.value?.languageCode;
    final bridge = scope.localBridge;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: ForrefSpace.s8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ForrefSpace.s20,
              ForrefSpace.s16,
              ForrefSpace.s20,
              ForrefSpace.s8,
            ),
            child: Text(
              l10n.language,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: ForrefSpace.s20,
            ),
            title: Text(l10n.english),
            trailing:
                code == null || code == 'en' ? const Icon(Icons.check) : null,
            onTap: () => locale.value = const Locale('en'),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: ForrefSpace.s20,
            ),
            title: Text(l10n.romanian),
            trailing: code == 'ro' ? const Icon(Icons.check) : null,
            onTap: () => locale.value = const Locale('ro'),
          ),
          if (kDebugMode && bridge != null)
            DebugLocalBridgeSection(
              bridge: bridge,
              database: scope.database,
            ),
        ],
      ),
    );
  }
}
