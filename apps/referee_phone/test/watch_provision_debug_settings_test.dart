import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/app.dart';
import 'package:referee_phone/infrastructure/competition_rules/match_competition_rules_store.dart';
import 'package:referee_phone/infrastructure/competition_rules/phone_match_capture_context.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/infrastructure/temporal/phone_temporal_evidence_store.dart';
import 'package:referee_phone/match/new_match.dart';

void main() {
  const installationId = '6f1e2d3c-4b5a-4678-9abc-def012345678';

  late LocalMatchDatabase db;
  late Directory temp;
  late MatchApplicationComposition composition;
  late PhoneCaptureIdentity identity;
  late PhoneMatchCaptureContext matchCaptureContext;
  late PhoneTemporalEvidenceStore evidence;

  setUp(() async {
    db = LocalMatchDatabase.memory();
    temp = await Directory.systemTemp.createTemp('watch_provision_settings_');
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
      temp.deleteSync(recursive: true);
    }
  });

  test('debug settings keep the bridge behind kDebugMode', () {
    final settings =
        File('lib/features/settings/settings_page.dart').readAsStringSync();
    final section =
        File('lib/features/settings/watch_provision_debug_section.dart')
            .readAsStringSync();
    final bridge = File('lib/officiate/watch_provision_debug_bridge.dart')
        .readAsStringSync();
    final release =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(settings,
        contains('if (kDebugMode) const WatchProvisionDebugSection()'));
    expect(
        section, contains('if (!kDebugMode) return const SizedBox.shrink()'));
    expect(section, contains('bridge.start(match.matchId)'));
    expect(section, contains('boundary.cancelPreparedWatchMatch('));
    expect(section, contains('boundary.inspectWatchProvision('));
    expect(section, contains('describeDebugCorrelation('));
    expect(section, contains('readAsStringSync()'));
    expect(section.contains('writeAsStringSync'), isFalse);
    expect(section.contains('DELETE FROM'), isFalse);
    expect(section, contains("'\${listening.name} \${prepared.contentHash}'"));
    expect(bridge, contains('kDebugMode && _debugPermitted()'));
    expect(release.contains('android.permission.INTERNET'), isFalse);
  });

  testWidgets(
      'debug settings shows the installation field, match selector, and prepare action',
      (tester) async {
    final match = newLocalMatch(DateTime.utc(2026, 11, 27)).copyWith(
      teams: const Teams(
        home: Team(teamId: 'team-north-001', name: 'North'),
        away: Team(teamId: 'team-south-001', name: 'South'),
      ),
    );
    await db.upsertMatch(match);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    await tester.pumpWidget(
      RefereeApp(
        database: db,
        matchApplication: composition.boundary,
        captureIdentity: identity,
        matchCaptureContext: matchCaptureContext,
        temporalEvidence: evidence,
        storageRoot: temp,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Watch provision'), findsOneWidget);
    expect(find.text('Watch installation UUID'), findsOneWidget);
    expect(find.text('No saved match selected'), findsOneWidget);
    expect(find.text('Prepare and listen'), findsOneWidget);
    expect(find.text('Inspect provision'), findsOneWidget);
    expect(find.text('Cancel prepared'), findsOneWidget);

    await tester.enterText(find.byType(TextField), installationId);
    await tester.tap(find.text('No saved match selected'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(match.matchId));
    await tester.pumpAndSettle();
    expect(find.text(match.matchId), findsOneWidget);
    expect(find.text('Prepare and listen'), findsOneWidget);
  });
}
