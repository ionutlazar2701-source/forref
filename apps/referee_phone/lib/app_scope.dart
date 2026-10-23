import 'package:flutter/widgets.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/infrastructure/competition_rules/phone_match_capture_context.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/temporal/phone_temporal_evidence_store.dart';
import 'package:referee_phone/match_application/match_application_boundary.dart';
import 'package:referee_phone/mobile_commands/mobile_command_runtime.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.database,
    required this.locale,
    this.matchApplication,
    this.captureIdentity,
    this.matchCaptureContext,
    this.temporalEvidence,
    required this.mobileCommands,
    required super.child,
  });

  final LocalMatchDatabase database;
  final ValueNotifier<Locale?> locale;

  /// New-core boundary. Kick-off uses this. Other flows stay on [database].
  final MatchApplicationBoundary? matchApplication;

  /// Local installation identity for new-core capture. Not a crew name.
  final PhoneCaptureIdentity? captureIdentity;

  /// Match-scoped capture context including persisted competition rules.
  final PhoneMatchCaptureContext? matchCaptureContext;

  /// In-process temporal evidence. Not Match Memory and not a certified clock.
  final PhoneTemporalEvidenceStore? temporalEvidence;

  /// Phone command layer. Peer transport defaults to a no-op.
  final MobileCommandRuntime mobileCommands;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      oldWidget.database != database ||
      oldWidget.locale != locale ||
      oldWidget.matchApplication != matchApplication ||
      oldWidget.captureIdentity != captureIdentity ||
      oldWidget.matchCaptureContext != matchCaptureContext ||
      oldWidget.temporalEvidence != temporalEvidence ||
      oldWidget.mobileCommands != mobileCommands;
}
