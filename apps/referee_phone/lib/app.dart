import 'package:flutter/material.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:referee_phone/app_scope.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/infrastructure/competition_rules/phone_match_capture_context.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/temporal/phone_temporal_evidence_store.dart';
import 'package:referee_phone/l10n/app_localizations.dart';
import 'package:referee_phone/match_application/match_application_boundary.dart';
import 'package:referee_phone/mobile_commands/mobile_command_runtime.dart';
import 'package:referee_phone/routing/app_router.dart';

class RefereeApp extends StatefulWidget {
  const RefereeApp({
    super.key,
    required this.database,
    this.matchApplication,
    this.captureIdentity,
    this.matchCaptureContext,
    this.temporalEvidence,
    this.mobileCommands,
  });

  final LocalMatchDatabase database;

  /// New-core boundary. Kick-off and Goal reach it through the mobile
  /// command runtime. Other live controls stay on [database].
  final MatchApplicationBoundary? matchApplication;

  final PhoneCaptureIdentity? captureIdentity;

  final PhoneMatchCaptureContext? matchCaptureContext;

  final PhoneTemporalEvidenceStore? temporalEvidence;

  /// Overrides the phone-only command runtime. Tests may inject a fixture.
  final MobileCommandRuntime? mobileCommands;

  @override
  State<RefereeApp> createState() => _RefereeAppState();
}

class _RefereeAppState extends State<RefereeApp> {
  final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);
  late final MobileCommandRuntime _mobileCommands;

  @override
  void initState() {
    super.initState();
    _mobileCommands = widget.mobileCommands ?? _phoneOnlyRuntime();
  }

  MobileCommandRuntime _phoneOnlyRuntime() {
    final evidence = widget.temporalEvidence;
    return MobileCommandRuntime.phoneOnly(
      boundary: widget.matchApplication,
      originDeviceId: widget.captureIdentity?.originDeviceId ?? 'phone-unbound',
      temporalEvidenceReady: evidence != null,
      captureContext: (matchId) async {
        final matchCapture = widget.matchCaptureContext;
        if (matchCapture != null) {
          return matchCapture.captureContextFor(matchId);
        }
        final identity = widget.captureIdentity;
        if (identity == null) return null;
        return identity.contextFor(matchId);
      },
      periodAnchor: evidence == null
          ? null
          : () async {
              final captured = await evidence.captureAnchor();
              return TemporalContext(
                evidenceIds: [captured.evidenceId],
                domainClockPolicyVersion:
                    PhoneCaptureIdentity.domainClockContract.value,
              );
            },
    );
  }

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
      matchApplication: widget.matchApplication,
      captureIdentity: widget.captureIdentity,
      matchCaptureContext: widget.matchCaptureContext,
      temporalEvidence: widget.temporalEvidence,
      mobileCommands: _mobileCommands,
      child: ValueListenableBuilder<Locale?>(
        valueListenable: locale,
        builder: (context, resolved, _) {
          return MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1F3A4C),
                brightness: Brightness.light,
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1F3A4C),
                brightness: Brightness.dark,
              ),
            ),
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
