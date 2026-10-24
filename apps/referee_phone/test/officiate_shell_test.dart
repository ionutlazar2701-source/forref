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
  late LocalMatchDatabase db;
  late Directory temp;
  late MatchApplicationComposition composition;
  late PhoneCaptureIdentity identity;
  late PhoneMatchCaptureContext matchCaptureContext;
  late PhoneTemporalEvidenceStore evidence;

  setUp(() async {
    db = LocalMatchDatabase.memory();
    temp = await Directory.systemTemp.createTemp('officiate_shell_');
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
        // The store may release the directory a moment later.
      }
    }
  });

  RefereeApp testApp({Key? key}) {
    return RefereeApp(
      key: key,
      database: db,
      matchApplication: composition.boundary,
      captureIdentity: identity,
      matchCaptureContext: matchCaptureContext,
      temporalEvidence: evidence,
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

  Future<void> openMatches(WidgetTester tester) async {
    await tester.pumpWidget(testApp());
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }
    fail('Matches did not finish loading');
  }

  testWidgets('empty matches stay a simple list', (tester) async {
    await openMatches(tester);
    expect(find.text('No matches yet'), findsOneWidget);
    expect(find.text('New Match'), findsOneWidget);
    expect(find.text('Training'), findsNothing);
    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('Devices'), findsNothing);
  });

  testWidgets('current comes only from established lifecycle', (tester) async {
    final current = newLocalMatch(DateTime.now()).copyWith(
      status: MatchStatus.live,
      teams: Teams(
        home: Team(teamId: 'home-current', name: 'Current Home'),
        away: Team(teamId: 'away-current', name: 'Current Away'),
      ),
    );
    final unnamed = newLocalMatch(DateTime.now());
    final ready = newLocalMatch(DateTime.now()).copyWith(
      status: MatchStatus.ready,
      teams: Teams(
        home: Team(teamId: 'home-ready', name: 'Ready Home'),
        away: Team(teamId: 'away-ready', name: 'Ready Away'),
      ),
    );
    final completed = newLocalMatch(DateTime.now()).copyWith(
      status: MatchStatus.completed,
      teams: Teams(
        home: Team(teamId: 'home-done', name: 'Done Home'),
        away: Team(teamId: 'away-done', name: 'Done Away'),
      ),
    );
    await db.upsertMatch(current);
    await db.upsertMatch(unnamed);
    await db.upsertMatch(completed);
    await db.upsertMatch(ready);
    await openMatches(tester);

    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Current Home — Current Away'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Ready Home — Ready Away'), findsOneWidget);
    expect(find.text('Needs attention'), findsWidgets);
    expect(find.textContaining('Home team not set'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Done Home — Done Away'), findsOneWidget);
    expect(find.text('HOME — AWAY'), findsNothing);
  });

  testWidgets('preparation orders sections and gates live entry', (
    tester,
  ) async {
    await openMatches(tester);
    await tester.tap(find.text('New Match'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await pumpUntilFound(tester, find.text('Preparation'));

    final matchTop =
        tester.getTopLeft(find.byKey(const Key('section-match'))).dy;
    final teamsTop =
        tester.getTopLeft(find.byKey(const Key('section-teams'))).dy;
    final crewTop = tester.getTopLeft(find.byKey(const Key('section-crew'))).dy;
    final readinessTop =
        tester.getTopLeft(find.byKey(const Key('section-readiness'))).dy;
    expect(matchTop, lessThan(teamsTop));
    expect(teamsTop, lessThan(crewTop));
    expect(crewTop, lessThan(readinessTop));
    expect(find.text('Required'), findsWidgets);
    expect(find.text('Optional'), findsWidgets);
    expect(find.text('Watch'), findsNothing);
    expect(find.textContaining('coming soon'), findsNothing);

    final blocked = tester.widget<FilledButton>(
      find.byKey(const Key('enter-live-match')),
    );
    expect(blocked.onPressed, isNull);
    expect(find.text('Ready to officiate on this phone'), findsNothing);
    expect(find.text('Home team required'), findsOneWidget);
    expect(find.text('Away team required'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('home-team')), 'North');
    await tester.enterText(find.byKey(const Key('away-team')), 'South');
    await tester.pump();
    expect(find.text('Ready to officiate on this phone'), findsOneWidget);
    expect(find.text('Home team required'), findsNothing);
    final open = tester.widget<FilledButton>(
      find.byKey(const Key('enter-live-match')),
    );
    expect(open.onPressed, isNotNull);
  });

  testWidgets('preparation survives restart without inventing ready', (
    tester,
  ) async {
    await openMatches(tester);
    await tester.tap(find.text('New Match'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await pumpUntilFound(tester, find.text('Preparation'));
    await tester.enterText(find.byKey(const Key('home-team')), 'Restart Home');
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );

    await tester.pumpWidget(testApp(key: UniqueKey()));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await pumpUntilFound(tester, find.text('Restart Home — Away team not set'));
    expect(find.text('Ready to officiate on this phone'), findsNothing);
    await tester.tap(find.text('Restart Home — Away team not set'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await pumpUntilFound(tester, find.text('Preparation'));
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('home-team')))
          .controller
          ?.text,
      'Restart Home',
    );
    expect(find.text('Ready to officiate on this phone'), findsNothing);
    expect(find.text('Away team required'), findsOneWidget);
  });

  testWidgets('Romanian preparation labels resolve', (tester) async {
    await openMatches(tester);
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await pumpUntilFound(tester, find.text('Romanian'));
    await tester.tap(find.text('Romanian'));
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Meci nou'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await pumpUntilFound(tester, find.text('Pregătire'));
    expect(find.text('Meci'), findsOneWidget);
    expect(find.text('Echipe'), findsOneWidget);
    expect(find.text('Brigadă'), findsOneWidget);
    expect(find.text('Verificare'), findsOneWidget);
    expect(find.text('Intră în meciul live'), findsOneWidget);
  });

  testWidgets('dark theme follows the platform brightness', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await openMatches(tester);
    final context = tester.element(find.text('Matches'));
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}
