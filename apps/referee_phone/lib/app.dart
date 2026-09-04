import 'package:flutter/material.dart';
import 'package:referee_phone/app_scope.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/l10n/app_localizations.dart';
import 'package:referee_phone/routing/app_router.dart';

class RefereeApp extends StatefulWidget {
  const RefereeApp({super.key, required this.database});

  final LocalMatchDatabase database;

  @override
  State<RefereeApp> createState() => _RefereeAppState();
}

class _RefereeAppState extends State<RefereeApp> {
  final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);

  @override
  void dispose() {
    locale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      database: widget.database,
      locale: locale,
      child: ValueListenableBuilder<Locale?>(
        valueListenable: locale,
        builder: (context, resolved, _) {
          return MaterialApp(
            onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: resolved,
            localeResolutionCallback: (device, supported) {
              if (resolved != null) return resolved;
              if (device == null) return const Locale('en');
              for (final locale in supported) {
                if (locale.languageCode == device.languageCode) {
                  return locale;
                }
              }
              return const Locale('en');
            },
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            onGenerateRoute: AppRouter.onGenerateRoute,
            initialRoute: AppRouter.matches,
          );
        },
      ),
    );
  }
}
