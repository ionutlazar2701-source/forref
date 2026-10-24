import 'package:flutter/material.dart';
import 'package:referee_phone/app_scope.dart';
import 'package:referee_phone/l10n/app_localizations.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = AppScope.of(context).locale;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          ListTile(title: Text(l10n.language)),
          ListTile(
            title: Text(l10n.english),
            onTap: () => locale.value = const Locale('en'),
          ),
          ListTile(
            title: Text(l10n.romanian),
            onTap: () => locale.value = const Locale('ro'),
          ),
        ],
      ),
    );
  }
}
