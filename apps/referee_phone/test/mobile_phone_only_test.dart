import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:referee_phone/app.dart';
import 'package:referee_phone/companion/companion_device.dart';
import 'package:referee_phone/companion/companion_registry.dart';
import 'package:referee_phone/infrastructure/competition_rules/match_competition_rules_store.dart';
import 'package:referee_phone/infrastructure/competition_rules/phone_match_capture_context.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/infrastructure/temporal/phone_temporal_evidence_store.dart';
import 'package:referee_phone/mobile_commands/mobile_command_runtime.dart';

void main() {
  late LocalMatchDatabase db;
  late Directory temp;
  late MatchApplicationComposition composition;
  late PhoneCaptureIdentity identity;
  late PhoneMatchCaptureContext matchCaptureContext;
  late PhoneTemporalEvidenceStore evidence;

  setUp(() async {
    db = LocalMatchDatabase.memory();
    temp = await Directory.systemTemp.createTemp('mobile_phone_only_');
    composition = await MatchApplicationComposition.open(storageRoot: temp);
    identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    matchCaptureContext = PhoneMatchCaptureContext(
      identity: identity,
      rulesStore: MatchCompetitionRulesStore(temp),
    );
    evidence = PhoneTemporalEvidenceStore(storageRoot: temp);
  });

  tearDown(() async {
    await composition.close();
    await db.close();
    if (temp.existsSync()) {
      try {
        temp.deleteSync(recursive: true);
      } on FileSystemException {
        // The sqlite handle can outlive the test on some hosts.
      }
    }
  });

  RefereeApp testApp({MobileCommandRuntime? mobileCommands}) {
    return RefereeApp(
      database: db,
      matchApplication: composition.boundary,
      captureIdentity: identity,
      matchCaptureContext: matchCaptureContext,
      temporalEvidence: evidence,
      mobileCommands: mobileCommands,
    );
  }

  Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    int maxPumps = 50,
  }) async {
    for (var i = 0; i < maxPumps; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.pump(const Duration(milliseconds: 100));
    }
    fail('Timed out waiting for $finder');
  }

  Future<void> pumpMatches(WidgetTester tester, RefereeApp app) async {
    await tester.pumpWidget(app);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await pumpUntilFound(tester, find.text('Matches'));
  }

  testWidgets('F1 F7 the app launches phone-only without login',
      (tester) async {
    await pumpMatches(tester, testApp());
    expect(find.text('Matches'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
    expect(find.text('Google'), findsNothing);
    expect(find.textContaining('firebase'), findsNothing);
  });

  testWidgets('F2 F3 F4 F5 setup, ready, and phone capture', (tester) async {
    await pumpMatches(tester, testApp());
    await tester.tap(find.text('New Match'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await pumpUntilFound(tester, find.text('Preparation'));
    expect(find.text('Home team'), findsOneWidget);
    expect(find.text('Watch'), findsNothing);
    expect(find.textContaining('coming soon'), findsNothing);
    await tester.enterText(find.byKey(const Key('home-team')), 'Home FC');
    await tester.enterText(find.byKey(const Key('away-team')), 'Away FC');
    await tester.pump();
    tester.testTextInput.hide();
    await tester.pump();
    expect(find.text('Ready to officiate on this phone'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.ensureVisible(find.byKey(const Key('enter-live-match')));
    await tester.tap(find.byKey(const Key('enter-live-match')));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await pumpUntilFound(tester, find.text('Kick-off'));
    expect(find.textContaining('Ready'), findsWidgets);
    expect(find.text('Kick-off available'), findsOneWidget);
    expect(find.text('Goal available'), findsOneWidget);
    expect(find.text('Phone only'), findsOneWidget);
    expect(
      find.text('Yellow card is not available in this production build yet'),
      findsOneWidget,
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Kick-off'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    expect(find.text('Match started'), findsOneWidget);
    expect(find.text('Kick-off'), findsNothing);
    expect(find.text('Kick-off unavailable'), findsOneWidget);

    final matchId = (await db.listNewestFirst()).single.matchId;
    await tester.tap(find.text('Goal'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Home FC'));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Unknown'));
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump();

    final stored = await db.listNewestFirst();
    expect(stored.single.events, isEmpty);
    await tester.runAsync(() async {
      final records = await composition.boundary.durableStore
          .readCommittedForMatch(matchId);
      expect(records.where((record) => record.payload is GoalPayload),
          hasLength(1));
      final score = await composition.boundary.readScoreProjection(
        matchId: matchId,
        evaluatedAuthorityGeneration:
            PhoneCaptureIdentity.initialAuthorityGeneration,
        homeTeamId: MatchTeamId(stored.single.teams.home.teamId),
        awayTeamId: MatchTeamId(stored.single.teams.away.teamId),
      );
      expect(score, isA<KnownScore>());
    });
  });

  testWidgets('F6 settings stays secondary and has no device destination', (
    tester,
  ) async {
    await pumpMatches(tester, testApp());
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await pumpUntilFound(tester, find.text('English'));
    expect(find.text('Devices'), findsNothing);
    expect(find.text('Training'), findsNothing);
    expect(find.textContaining('Watch'), findsNothing);
    expect(find.textContaining('controls the match'), findsNothing);
  });

  testWidgets('a simulated companion is not a production surface', (
    tester,
  ) async {
    final registry = CompanionRegistry()
      ..present(
        const CompanionDevice(
          deviceId: 'lab-watch',
          displayName: 'Lab Watch',
          platformFamily: PlatformFamily.wearOs,
          capabilities: {CompanionCapability.canCaptureGoal},
          connectionState: CompanionConnectionState.connected,
          certificationState: CompanionCertificationState.certified,
          pairingReadiness: PairingReadiness.paired,
        ),
      );
    final runtime = MobileCommandRuntime.phoneOnly(
      boundary: composition.boundary,
      originDeviceId: identity.originDeviceId,
      captureContext: matchCaptureContext.captureContextFor,
      companions: registry,
      temporalEvidenceReady: true,
    );
    await pumpMatches(tester, testApp(mobileCommands: runtime));
    expect(find.text('Lab Watch'), findsNothing);
    expect(find.text('Wear OS'), findsNothing);
    expect(find.text('Certified'), findsNothing);
    expect(find.textContaining('Watch controls'), findsNothing);
    expect(runtime.authority.companionHoldsCaptureAuthority, isFalse);
    expect(runtime.companions.device?.holdsCaptureAuthority, isFalse);
  });
}
