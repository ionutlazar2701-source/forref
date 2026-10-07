import 'package:flutter/widgets.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/infrastructure/competition_rules/phone_match_capture_context.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/temporal/phone_temporal_evidence_store.dart';
import 'package:referee_phone/infrastructure/yellow_card/phone_match_foundation.dart';
import 'package:referee_phone/infrastructure/yellow_card/phone_participant_registry_store.dart';
import 'package:referee_phone/infrastructure/yellow_card/phone_yellow_card_draft_store.dart';
import 'package:referee_phone/match_application/match_application_boundary.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.database,
    required this.locale,
    this.matchApplication,
    this.captureIdentity,
    this.matchCaptureContext,
    this.temporalEvidence,
    this.yellowCardDraftStore,
    this.participantRegistry,
    this.matchFoundation,
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

  /// Non-authoritative Yellow selector/intent recovery state.
  final PhoneYellowCardDraftStore? yellowCardDraftStore;

  /// Stable roster-to-participant mapping for Yellow foundation wiring.
  final PhoneParticipantRegistryStore? participantRegistry;

  /// Production Match Memory foundation commits for Yellow Card.
  final PhoneMatchFoundation? matchFoundation;

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
      oldWidget.yellowCardDraftStore != yellowCardDraftStore ||
      oldWidget.participantRegistry != participantRegistry ||
      oldWidget.matchFoundation != matchFoundation;
}
