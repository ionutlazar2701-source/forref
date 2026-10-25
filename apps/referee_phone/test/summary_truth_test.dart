import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/app.dart';
import 'package:referee_phone/features/match_summary/match_summary_page.dart';
import 'package:referee_phone/features/match_summary/summary_truth.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/l10n/app_localizations.dart';
import 'package:referee_phone/match/new_match.dart';
import 'package:referee_phone/match_application/kick_off_authority.dart';
import 'package:referee_phone/routing/app_router.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory temp;
  late LocalMatchDatabase db;
  late MatchApplicationComposition composition;
  late PhoneCaptureIdentity identity;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('summary_truth_');
    db = LocalMatchDatabase.memory();
    composition = await MatchApplicationComposition.open(storageRoot: temp);
    identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
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

  Future<int> committedCount(String matchId) async {
    final records =
        await composition.boundary.durableStore.readCommittedForMatch(matchId);
    return records.length;
  }

  Future<void> rootAndKickOff(Match match) async {
    final context = identity.contextFor(match.matchId);
    expect(
      await composition.boundary.durableStore.commitGenerationOneAuthorityRoot(
        GenerationOneAuthorityRoot(
          matchId: match.matchId,
          principalId: context.authorityPrincipalId,
          deviceId: context.originDeviceId,
        ),
      ),
      isA<GenerationOneRootCommitSuccess>(),
    );
    expect(
      await composition.boundary.commitKickOff(
        context,
        period: const PeriodIdentity(index: 1),
      ),
      isA<KickOffAuthorityCommitted>(),
    );
  }

  Match legacyFullTime({int home = 7, int away = 3, String? homeName}) {
    final created = newLocalMatch(DateTime.utc(2026, 10, 25, 12));
    return created.copyWith(
      status: MatchStatus.fullTime,
      teams: Teams(
        home: Team(teamId: created.teams.home.teamId, name: homeName),
        away: Team(teamId: created.teams.away.teamId, name: 'South'),
      ),
      score: Score(home: home, away: away),
      currentState: const MatchState(
        periodId: PeriodId.firstHalf,
        clockRunning: false,
        elapsedSeconds: 3725,
      ),
      events: [
        MatchEvent(
          eventId: 'event-goal',
          matchId: created.matchId,
          type: EventType.goal,
          status: EventStatus.complete,
          periodId: PeriodId.firstHalf,
          matchTime: 600,
          createdAt: DateTime.utc(2026, 10, 25, 12, 10),
          updatedAt: DateTime.utc(2026, 10, 25, 12, 10),
          data: EventData(teamId: created.teams.home.teamId),
        ),
      ],
    );
  }

  Future<void> openSummary(
    WidgetTester tester,
    Match match, {
    bool withBoundary = true,
  }) async {
    await tester.pumpWidget(
      RefereeApp(
        database: db,
        matchApplication: withBoundary ? composition.boundary : null,
        captureIdentity: withBoundary ? identity : null,
      ),
    );
    await tester.pump();
    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(
          AppRouter.matchSummary,
          arguments: match.matchId,
        );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
  }

  test('conflicted and unavailable projections hide the scoreboard', () {
    final conflicted = summarizeMatchTruth(
      boundaryPresent: true,
      projection: const ScoreConflicted(),
      legacyStatus: MatchStatus.fullTime,
      homeTeamId: 'north-team',
      awayTeamId: 'south-team',
    );
    expect(conflicted.evidence, SummaryEvidence.conflicted);
    expect(conflicted.showProjectedScore, isFalse);
    expect(conflicted.showMutableTimeline, isFalse);
    expect(conflicted.showLegacyFinish, isFalse);

    final unavailable = summarizeMatchTruth(
      boundaryPresent: true,
      projection: const ScoreUnavailable(),
      legacyStatus: MatchStatus.fullTime,
      homeTeamId: 'north-team',
      awayTeamId: 'south-team',
    );
    expect(unavailable.evidence, SummaryEvidence.unavailable);
    expect(unavailable.showLegacyFinish, isFalse);

    final missing = summarizeMatchTruth(
      boundaryPresent: false,
      projection: KnownScore({
        MatchTeamId('north-team'): 1,
        MatchTeamId('south-team'): 0,
      }),
      legacyStatus: MatchStatus.fullTime,
      homeTeamId: 'north-team',
      awayTeamId: 'south-team',
    );
    expect(missing.evidence, SummaryEvidence.boundaryMissing);
    expect(missing.showProjectedScore, isFalse);

    final known = summarizeMatchTruth(
      boundaryPresent: true,
      projection: KnownScore({
        MatchTeamId('north-team'): 1,
        MatchTeamId('south-team'): 0,
      }),
      legacyStatus: MatchStatus.fullTime,
      homeTeamId: 'north-team',
      awayTeamId: 'south-team',
    );
    expect(known.showProjectedScore, isTrue);
    expect(known.homeGoals, 1);
    expect(known.awayGoals, 0);
    expect(known.showLegacyFinish, isTrue);

    final live = summarizeMatchTruth(
      boundaryPresent: true,
      projection: KnownScore({
        MatchTeamId('north-team'): 1,
        MatchTeamId('south-team'): 0,
      }),
      legacyStatus: MatchStatus.live,
      homeTeamId: 'north-team',
      awayTeamId: 'south-team',
    );
    expect(live.showLegacyFinish, isFalse);
  });

  testWidgets('conflicted evidence shows no numeral', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SummaryEvidenceNotice(evidence: SummaryEvidence.conflicted),
        ),
      ),
    );
    expect(find.text('Score conflicted'), findsOneWidget);
    expect(find.text('Full time is not match completion'), findsOneWidget);
    expect(find.textContaining('—'), findsNothing);
    expect(find.text('Finish match'), findsNothing);
  });

  testWidgets('a missing boundary does not present the legacy scoreboard', (
    tester,
  ) async {
    final match = legacyFullTime();
    await db.upsertMatch(match);
    await openSummary(tester, match, withBoundary: false);

    expect(find.text('HOME 7 — 3 AWAY'), findsNothing);
    expect(find.text('62:05'), findsNothing);
    expect(find.text('10:00'), findsNothing);
    expect(find.text('Goal'), findsNothing);
    expect(find.text('Finish match'), findsNothing);
    expect(find.text('Full time'), findsNothing);
    expect(find.text('Completed'), findsNothing);
    expect(find.byKey(const Key('open-match-record')), findsOneWidget);
    expect(find.text('Match record cannot be read'), findsOneWidget);
    expect(find.text('Full time is not match completion'), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
  });

  testWidgets('empty Match Memory does not show a legacy or zero score', (
    tester,
  ) async {
    final match = legacyFullTime();
    await db.upsertMatch(match);
    await openSummary(tester, match);

    expect(find.text('Score unavailable'), findsOneWidget);
    expect(find.text('HOME 7 — 3 AWAY'), findsNothing);
    expect(find.textContaining('0 —'), findsNothing);
    expect(find.text('62:05'), findsNothing);
    expect(find.text('Finish match'), findsNothing);
    expect(find.text('Full time is not match completion'), findsOneWidget);
    expect(find.byKey(const Key('open-match-record')), findsOneWidget);
    await tester.runAsync(() async {
      expect(await committedCount(match.matchId), 0);
    });

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
  });

  testWidgets('a known goal shows that score and finish writes no record', (
    tester,
  ) async {
    final match = legacyFullTime(homeName: 'North');
    await db.upsertMatch(match);
    await tester.runAsync(() async {
      await rootAndKickOff(match);
      expect(
        await composition.boundary.commitGoal(
          identity.contextFor(match.matchId),
          scoringTeamId: MatchTeamId(match.teams.home.teamId),
          captureIntentId: 'intent-summary-goal',
        ),
        isA<DurableCommitSuccess>(),
      );
    });
    final before = await tester.runAsync(() => committedCount(match.matchId));

    await openSummary(tester, match);

    expect(find.text('North 1 — 0 South'), findsOneWidget);
    expect(find.text('North 7 — 3 South'), findsNothing);
    expect(find.byKey(const Key('summary-finish')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MatchSummaryPage),
        matching: find.textContaining('· Full time'),
      ),
      findsOneWidget,
    );

    final finish = find.byKey(const Key('summary-finish'));
    await tester.ensureVisible(finish);
    await tester.pump();
    await tester.tap(finish);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    if (find.text('Finish anyway').evaluate().isNotEmpty) {
      await tester.tap(find.text('Finish anyway'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
    }

    final after = await tester.runAsync(() => committedCount(match.matchId));
    expect(after, before);
    final stored = await tester.runAsync(() => db.getMatch(match.matchId));
    expect(stored!.status, MatchStatus.completed);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('a quarantined record is unavailable rather than the legacy score',
      () async {
    final match = legacyFullTime(homeName: 'North');
    await db.upsertMatch(match);
    await rootAndKickOff(match);
    await composition.boundary.commitGoal(
      identity.contextFor(match.matchId),
      scoringTeamId: MatchTeamId(match.teams.home.teamId),
      captureIntentId: 'intent-summary-corrupt',
    );
    final records =
        await composition.boundary.durableStore.readCommittedForMatch(
      match.matchId,
    );
    final recordId = records.first.recordId;
    await composition.close();
    final database =
        sqlite3.open('${temp.path}/forref_match_memory/match_memory.sqlite');
    database.execute(
      'UPDATE committed_match_records SET record_json = ? WHERE record_id = ?',
      ['"not-an-object"', recordId],
    );
    database.close();
    composition = await MatchApplicationComposition.open(storageRoot: temp);
    final projection = await composition.boundary.readScoreProjection(
      matchId: match.matchId,
      evaluatedAuthorityGeneration:
          PhoneCaptureIdentity.initialAuthorityGeneration,
      homeTeamId: MatchTeamId(match.teams.home.teamId),
      awayTeamId: MatchTeamId(match.teams.away.teamId),
    );
    expect(projection, isA<ScoreUnavailable>());
    final truth = summarizeMatchTruth(
      boundaryPresent: true,
      projection: projection,
      legacyStatus: match.status,
      homeTeamId: match.teams.home.teamId,
      awayTeamId: match.teams.away.teamId,
    );
    expect(truth.evidence, SummaryEvidence.unavailable);
    expect(truth.showProjectedScore, isFalse);
    expect(truth.showMutableTimeline, isFalse);
    expect(truth.showLegacyFinish, isFalse);
  });
}
