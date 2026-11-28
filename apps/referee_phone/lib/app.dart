import 'dart:io';

import 'package:flutter/material.dart';
import 'package:referee_phone/app_scope.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/infrastructure/competition_rules/phone_match_capture_context.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/temporal/phone_temporal_evidence_store.dart';
import 'package:referee_phone/l10n/app_localizations.dart';
import 'package:referee_phone/match_application/match_application_boundary.dart';
import 'package:referee_phone/officiate/watch_sync_coordinator.dart';
import 'package:referee_phone/routing/app_router.dart';

class RefereeApp extends StatefulWidget {
  const RefereeApp({
    super.key,
    required this.database,
    this.matchApplication,
    this.captureIdentity,
    this.matchCaptureContext,
    this.temporalEvidence,
    this.storageRoot,
  });

  final LocalMatchDatabase database;

  /// New-core boundary. Kick-off uses this. Other flows stay on [database].
  final MatchApplicationBoundary? matchApplication;

  final PhoneCaptureIdentity? captureIdentity;

  final PhoneMatchCaptureContext? matchCaptureContext;

  final PhoneTemporalEvidenceStore? temporalEvidence;

  final Directory? storageRoot;

  @override
  State<RefereeApp> createState() => _RefereeAppState();
}

class _RefereeAppState extends State<RefereeApp> with WidgetsBindingObserver {
  final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);
  final WatchSyncCoordinator sync = WatchSyncCoordinator();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreSync();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _restoreSync();
    }
  }

  void _restoreSync() {
    final boundary = widget.matchApplication;
    final identity = widget.captureIdentity;
    final root = widget.storageRoot;
    if (boundary == null || identity == null || root == null) return;
    sync.bind(
      storageRoot: root,
      boundary: boundary,
      database: widget.database,
      phoneOriginDeviceId: identity.originDeviceId,
      principalId: identity.authorityPrincipalId,
    );
    sync.restore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    sync.close();
    locale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      database: widget.database,
      locale: locale,
      matchApplication: widget.matchApplication,
      captureIdentity: widget.captureIdentity,
      matchCaptureContext: widget.matchCaptureContext,
      temporalEvidence: widget.temporalEvidence,
      storageRoot: widget.storageRoot,
      sync: sync,
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
