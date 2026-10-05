import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/app.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/infrastructure/competition_rules/match_competition_rules_store.dart';
import 'package:referee_phone/infrastructure/competition_rules/phone_match_capture_context.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/temporal/phone_temporal_evidence_store.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/l10n/app_localizations.dart';

void main() {
  late LocalMatchDatabase db;
  late Directory temp;
  late MatchApplicationComposition composition;
  late PhoneCaptureIdentity identity;
  late PhoneMatchCaptureContext matchCaptureContext;
  late PhoneTemporalEvidenceStore evidence;

  setUp(() async {
    db = LocalMatchDatabase.memory();
    temp = await Directory.systemTemp.createTemp('referee_widget_');
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
        // Windows may still hold the sqlite handle briefly.
      }
    }
  });

  int clockSeconds(String? label) {
    final match = RegExp(r'(\d{2}):(\d{2})').firstMatch(label!);
    return int.parse(match!.group(1)!) * 60 + int.parse(match.group(2)!);
  }

  Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    int maxPumps = 50,
  }) async {
    for (var i = 0; i < maxPumps; i++) {
      if (finder.evaluate().isNotEmpty) {
        return;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    fail('Timed out waiting for $finder');
  }

  Future<void> pumpUntilAnyFound(
    WidgetTester tester,
    List<Finder> finders, {
    int maxPumps = 50,
  }) async {
    for (var i = 0; i < maxPumps; i++) {
      for (final finder in finders) {
        if (finder.evaluate().isNotEmpty) {
          return;
        }
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    fail('Timed out waiting for any of $finders');
  }

  Future<void> pumpMatchesLoaded(WidgetTester tester, RefereeApp app) async {
    await tester.pumpWidget(app);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await pumpUntilFound(tester, find.text('Matches'));
  }

  RefereeApp testApp() {
    return RefereeApp(
      database: db,
      matchApplication: composition.boundary,
      captureIdentity: identity,
      matchCaptureContext: matchCaptureContext,
      temporalEvidence: evidence,
    );
  }

  Future<void> startNewMatchSetup(WidgetTester tester) async {
    await tester.tap(find.text('New Match'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await pumpUntilFound(tester, find.text('Match setup'));
  }

  Future<void> enterLiveMatch(WidgetTester tester) async {
    await tester.tap(find.text('Live Match'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await pumpUntilAnyFound(tester, [
      find.text('Kick-off'),
      find.text('Complete period start'),
      find.text('Match started'),
      find.text('Suspend match'),
    ]);
  }

  testWidgets('shell builds', (tester) async {
    await pumpMatchesLoaded(tester, testApp());
    expect(find.text('Matches'), findsOneWidget);
  });

  testWidgets('New Match → Live Match → Kick-off → Goal', (tester) async {
    await pumpMatchesLoaded(tester, testApp());

    await startNewMatchSetup(tester);
    expect(find.text('Match setup'), findsOneWidget);

    await enterLiveMatch(tester);
    expect(find.text('Kick-off'), findsOneWidget);
    expect(find.textContaining('Ready'), findsWidgets);
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
    expect(find.textContaining('Period 1'), findsOneWidget);
    expect(find.text('Continuity exact'), findsOneWidget);
    expect(find.textContaining('Period start incomplete'), findsNothing);
    expect(find.text('Kick-off'), findsNothing);
    expect(find.text('Pause'), findsNothing);

    final matchId = (await db.listNewestFirst()).single.matchId;
    await tester.pump(const Duration(seconds: 2));
    await tester.runAsync(() async {
      final records =
          await composition.boundary.durableStore.readCommittedForMatch(matchId);
      expect(records, hasLength(2));
    });

    await tester.tap(find.text('Goal'));
    await tester.pump();
    final homeGoal = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'HOME'),
    );
    await tester.runAsync(() async {
      homeGoal.onPressed!();
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pump();

    expect(find.text('Goal saved'), findsAtLeastNWidgets(1));
    expect(find.textContaining('HOME 1 — 0 AWAY'), findsWidgets);
    late final List<Match> stored;
    late final List<MatchRecord> records;
    await tester.runAsync(() async {
      stored = await db.listNewestFirst();
      records = await composition.boundary.durableStore.readCommittedForMatch(
        matchId,
      );
    });
    expect(stored, hasLength(1));
    expect(stored.single.status, MatchStatus.ready);
    expect(stored.single.events, isEmpty);
    expect(stored.single.score.home, 0);
    expect(stored.single.score.away, 0);
    final goals = [
      for (final record in records)
        if (record.payload is GoalPayload) record,
    ];
    expect(goals, hasLength(1));
    expect(goals.single.recordKind, RecordKind.humanDetermination);
    expect(
      (goals.single.payload as GoalPayload).creditedSide,
      CreditedSide.home,
    );
  });

  testWidgets('failed kick-off does not show started state', (tester) async {
    composition.boundary.durableStore.abortBeforeCommitForTest = () {
      throw StateError('abort before commit');
    };
    await pumpMatchesLoaded(tester, testApp());
    await startNewMatchSetup(tester);
    await enterLiveMatch(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
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

    expect(find.text('Match started'), findsNothing);
    expect(find.textContaining('Period 1'), findsNothing);
    expect(find.text('Kick-off'), findsOneWidget);
    expect(find.text('Kick-off was not saved'), findsAtLeastNWidgets(1));
    expect((await db.listNewestFirst()).single.status, MatchStatus.ready);
  });

  testWidgets('incomplete period start is recoverable without a second match start', (
    tester,
  ) async {
    var commits = 0;
    composition.boundary.durableStore.abortBeforeCommitForTest = () {
      commits += 1;
      if (commits > 1) {
        throw StateError('abort period start');
      }
    };

    await pumpMatchesLoaded(tester, testApp());
    await startNewMatchSetup(tester);
    await enterLiveMatch(tester);

    await tester.runAsync(() async {
      await tester.tap(find.text('Kick-off'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    await pumpUntilFound(
      tester,
      find.text('Complete period start'),
      maxPumps: 20,
    );

    final matchId = (await db.listNewestFirst()).single.matchId;
    expect(find.text('Match started'), findsOneWidget);
    expect(find.textContaining('Period start incomplete'), findsOneWidget);
    expect(find.textContaining('Period 1'), findsNothing);
    expect(find.text('Kick-off'), findsNothing);
    expect(find.text('Complete period start'), findsOneWidget);
    expect(find.text('Pause'), findsNothing);
    expect((await db.listNewestFirst()).single.status, MatchStatus.ready);

    composition.boundary.durableStore.abortBeforeCommitForTest = null;
    await tester.runAsync(() async {
      await tester.tap(find.text('Complete period start'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    await pumpUntilAnyFound(tester, [
      find.textContaining('Period 1'),
      find.text('Continuity exact'),
    ], maxPumps: 20);

    expect(find.textContaining('Period start incomplete'), findsNothing);
    expect(find.text('Complete period start'), findsNothing);
    late List<MatchRecord> records;
    await tester.runAsync(() async {
      records = await composition.boundary.durableStore.readCommittedForMatch(
        matchId,
      );
    });
    expect(records, hasLength(2));
    expect(
      (records[1].payload as TemporalTransitionPayload).semanticType,
      V1SemanticTypeCode.periodStarted,
    );
    expect((await db.listNewestFirst()).single.status, MatchStatus.ready);
  });

  testWidgets('Suspend match freezes Period 1 without a legacy pause', (
    tester,
  ) async {
    await pumpMatchesLoaded(tester, testApp());
    await startNewMatchSetup(tester);
    await enterLiveMatch(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Kick-off'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    expect(find.text('Suspend match'), findsOneWidget);
    expect(find.text('Pause'), findsNothing);
    expect(find.text('Match suspended'), findsNothing);

    await tester.runAsync(() async {
      await tester.tap(find.text('Suspend match'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();

    expect(find.text('Match suspended'), findsOneWidget);
    expect(find.text('Suspension ongoing'), findsOneWidget);
    expect(find.text('Suspend match'), findsNothing);
    expect(find.text('Pause'), findsNothing);
    final before = tester.widget<Text>(find.textContaining('Period 1')).data;
    await tester.pump(const Duration(seconds: 3));
    expect(tester.widget<Text>(find.textContaining('Period 1')).data, before);

    final matchId = (await db.listNewestFirst()).single.matchId;
    late List<MatchRecord> records;
    await tester.runAsync(() async {
      records = await composition.boundary.durableStore.readCommittedForMatch(
        matchId,
      );
    });
    expect(records, hasLength(3));
    expect(
      (records[2].payload as TemporalTransitionPayload).semanticType,
      V1SemanticTypeCode.temporarySuspensionStarted,
    );
    expect(records[2].relationships.single, isA<CausalDependency>());
    expect(
      (records[2].relationships.single as CausalDependency).targetRecordId,
      records[1].recordId,
    );
    final stored = await db.listNewestFirst();
    expect(stored.single.status, MatchStatus.ready);
    expect(stored.single.events, isEmpty);
  });

  testWidgets('failed suspension does not show suspended state', (tester) async {
    await pumpMatchesLoaded(tester, testApp());
    await startNewMatchSetup(tester);
    await enterLiveMatch(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Kick-off'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    composition.boundary.durableStore.abortBeforeCommitForTest = () {
      throw StateError('abort before commit');
    };

    await tester.runAsync(() async {
      await tester.tap(find.text('Suspend match'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();

    expect(find.text('Match suspended'), findsNothing);
    expect(find.text('Suspension was not saved'), findsAtLeastNWidgets(1));
    expect(find.text('Suspend match'), findsOneWidget);
    expect(find.text('Continuity exact'), findsOneWidget);
    final matchId = (await db.listNewestFirst()).single.matchId;
    late List<MatchRecord> records;
    await tester.runAsync(() async {
      records = await composition.boundary.durableStore.readCommittedForMatch(
        matchId,
      );
    });
    expect(records, hasLength(2));
    expect((await db.listNewestFirst()).single.status, MatchStatus.ready);
  });

  testWidgets('Resume match continues Period 1 without legacy resume', (
    tester,
  ) async {
    await pumpMatchesLoaded(tester, testApp());
    await startNewMatchSetup(tester);
    await enterLiveMatch(tester);
    expect(find.text('Added time'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Kick-off'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    expect(find.text('Added time'), findsNothing);
    expect(find.text('Resume match'), findsNothing);

    await tester.runAsync(() async {
      await tester.tap(find.text('Suspend match'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    expect(find.text('Resume match'), findsOneWidget);
    expect(find.text('Match suspended'), findsOneWidget);
    final frozen = tester.widget<Text>(find.textContaining('Period 1')).data;

    await tester.runAsync(() async {
      await tester.tap(find.text('Resume match'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();

    expect(find.text('Match suspended'), findsNothing);
    expect(find.text('Suspension ongoing'), findsNothing);
    expect(find.text('Resume match'), findsNothing);
    expect(find.text('Suspend match'), findsOneWidget);
    expect(find.text('Pause'), findsNothing);
    expect(find.text('Added time'), findsNothing);
    expect(find.text('Continuity exact'), findsOneWidget);
    expect(find.textContaining('Period 1'), findsOneWidget);
    final resumed = tester.widget<Text>(find.textContaining('Period 1')).data;
    final continued = clockSeconds(resumed) - clockSeconds(frozen);
    expect(continued, greaterThan(0));
    expect(continued, lessThan(15));

    await tester.runAsync(() async {
      await tester.tap(find.text('Suspend match'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    expect(find.text('Match suspended'), findsOneWidget);
    expect(find.text('Resume match'), findsOneWidget);
    expect(find.text('Pause'), findsNothing);

    await tester.runAsync(() async {
      await tester.tap(find.text('Resume match'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    expect(find.text('Match suspended'), findsNothing);
    expect(find.text('Suspend match'), findsOneWidget);
    expect(find.text('Pause'), findsNothing);
    expect(find.text('Added time'), findsNothing);
    expect(find.textContaining('Period 1'), findsOneWidget);

    final matchId = (await db.listNewestFirst()).single.matchId;
    late List<MatchRecord> records;
    await tester.runAsync(() async {
      records = await composition.boundary.durableStore.readCommittedForMatch(
        matchId,
      );
    });
    expect(records, hasLength(6));
    expect(
      (records[3].payload as TemporalTransitionPayload).semanticType,
      V1SemanticTypeCode.temporarySuspensionEnded,
    );
    expect(
      (records[3].relationships.single as CausalDependency).targetRecordId,
      records[2].recordId,
    );
    expect(
      (records[5].payload as TemporalTransitionPayload).semanticType,
      V1SemanticTypeCode.temporarySuspensionEnded,
    );
    expect(
      (records[5].relationships.single as CausalDependency).targetRecordId,
      records[4].recordId,
    );
    expect(records[2].recordId, isNot(records[4].recordId));
    expect(records.where(_isPeriodEnded), isEmpty);
    final stored = await db.listNewestFirst();
    expect(stored.single.status, MatchStatus.ready);
    expect(stored.single.events, isEmpty);
  });

  testWidgets('failed resume stays suspended', (tester) async {
    await pumpMatchesLoaded(tester, testApp());
    await startNewMatchSetup(tester);
    await enterLiveMatch(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Kick-off'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Suspend match'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    composition.boundary.durableStore.abortBeforeCommitForTest = () {
      throw StateError('abort before commit');
    };

    await tester.runAsync(() async {
      await tester.tap(find.text('Resume match'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();

    expect(find.text('Match suspended'), findsOneWidget);
    expect(find.text('Resume was not saved'), findsAtLeastNWidgets(1));
    expect(find.text('Resume match'), findsOneWidget);
    final matchId = (await db.listNewestFirst()).single.matchId;
    late List<MatchRecord> records;
    await tester.runAsync(() async {
      records = await composition.boundary.durableStore.readCommittedForMatch(
        matchId,
      );
    });
    expect(records, hasLength(3));
    expect((await db.listNewestFirst()).single.status, MatchStatus.ready);
  });

  testWidgets('End period freezes Period 1 without legacy half-time', (
    tester,
  ) async {
    await pumpMatchesLoaded(tester, testApp());
    await startNewMatchSetup(tester);
    await enterLiveMatch(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Kick-off'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    expect(find.text('End period'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('End period'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();

    expect(find.textContaining('Interval'), findsOneWidget);
    expect(find.text('Period 1 — ended'), findsOneWidget);
    expect(find.text('No active playing period'), findsOneWidget);
    expect(find.text('End period'), findsNothing);
    expect(find.text('Suspend match'), findsNothing);
    expect(find.text('Resume match'), findsNothing);
    expect(find.text('Half-time'), findsNothing);
    expect(find.text('Pause'), findsNothing);
    expect(find.text('Added time'), findsNothing);
    final frozen = tester.widget<Text>(find.textContaining('Period 1')).data;
    await tester.pump(const Duration(seconds: 3));
    expect(
      tester.widget<Text>(find.textContaining('Period 1')).data,
      frozen,
    );

    final matchId = (await db.listNewestFirst()).single.matchId;
    late List<MatchRecord> records;
    await tester.runAsync(() async {
      records = await composition.boundary.durableStore.readCommittedForMatch(
        matchId,
      );
    });
    expect(records, hasLength(3));
    expect(
      (records[2].payload as TemporalTransitionPayload).semanticType,
      V1SemanticTypeCode.periodEnded,
    );
    expect(
      (records[2].relationships.single as CausalDependency).targetRecordId,
      records[1].recordId,
    );
    expect((records[2].payload as TemporalTransitionPayload).period?.index, 1);
    final stored = await db.listNewestFirst();
    expect(stored.single.status, MatchStatus.ready);
    expect(stored.single.events, isEmpty);
  });

  testWidgets('Start Period 2 leaves the interval only after D1', (tester) async {
    await pumpMatchesLoaded(tester, testApp());
    await startNewMatchSetup(tester);
    await enterLiveMatch(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Kick-off'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('End period'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    expect(find.text('Start Period 2'), findsOneWidget);
    expect(find.textContaining('Interval'), findsOneWidget);
    final intervalClock =
        tester.widget<Text>(find.textContaining('Interval')).data;
    await tester.pump(const Duration(seconds: 3));
    expect(
      tester.widget<Text>(find.textContaining('Interval')).data,
      intervalClock,
    );

    await tester.runAsync(() async {
      await tester.tap(find.text('Start Period 2'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();

    expect(find.textContaining('Interval'), findsNothing);
    expect(find.text('Start Period 2'), findsNothing);
    expect(find.text('End period'), findsOneWidget);
    expect(find.text('Half-time'), findsNothing);
    expect(find.text('Start 2nd half'), findsNothing);
    expect(find.textContaining('Period 2'), findsOneWidget);
    final started = tester.widget<Text>(find.textContaining('Period 2')).data;
    expect(clockSeconds(started), greaterThan(0));
    expect(clockSeconds(started), lessThan(20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    final continued = clockSeconds(
          tester.widget<Text>(find.textContaining('Period 2')).data,
        ) -
        clockSeconds(started);
    expect(continued, greaterThan(0));
    expect(continued, lessThan(15));

    final matchId = (await db.listNewestFirst()).single.matchId;
    late List<MatchRecord> records;
    await tester.runAsync(() async {
      records = await composition.boundary.durableStore.readCommittedForMatch(
        matchId,
      );
    });
    expect(records, hasLength(4));
    expect(
      (records[3].payload as TemporalTransitionPayload).semanticType,
      V1SemanticTypeCode.periodStarted,
    );
    expect((records[3].payload as TemporalTransitionPayload).period?.index, 2);
    expect(
      (records[3].relationships.single as CausalDependency).targetRecordId,
      records[2].recordId,
    );
    expect(
      records[3].temporalContext!.evidenceIds.single,
      isNot(records[1].temporalContext!.evidenceIds.single),
    );
    expect((await db.listNewestFirst()).single.status, MatchStatus.ready);
    expect((await db.listNewestFirst()).single.events, isEmpty);
  });

  testWidgets('failed Period 2 start stays on the interval', (tester) async {
    await pumpMatchesLoaded(tester, testApp());
    await startNewMatchSetup(tester);
    await enterLiveMatch(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Kick-off'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('End period'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    composition.boundary.durableStore.abortBeforeCommitForTest = () {
      throw StateError('abort before commit');
    };

    await tester.runAsync(() async {
      await tester.tap(find.text('Start Period 2'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();

    expect(find.text('Period start was not saved'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Interval'), findsOneWidget);
    expect(find.text('Start Period 2'), findsOneWidget);
    expect(find.textContaining('  Period 2'), findsNothing);
    final matchId = (await db.listNewestFirst()).single.matchId;
    late List<MatchRecord> records;
    await tester.runAsync(() async {
      records = await composition.boundary.durableStore.readCommittedForMatch(
        matchId,
      );
    });
    expect(records, hasLength(3));
  });

  testWidgets('failed period end stays on active Period 1', (tester) async {
    await pumpMatchesLoaded(tester, testApp());
    await startNewMatchSetup(tester);
    await enterLiveMatch(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Kick-off'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    composition.boundary.durableStore.abortBeforeCommitForTest = () {
      throw StateError('abort before commit');
    };

    await tester.runAsync(() async {
      await tester.tap(find.text('End period'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();

    expect(find.text('Period end was not saved'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Period 1 ended'), findsNothing);
    expect(find.text('End period'), findsOneWidget);
    expect(find.textContaining('Period 1'), findsOneWidget);
    final matchId = (await db.listNewestFirst()).single.matchId;
    late List<MatchRecord> records;
    await tester.runAsync(() async {
      records = await composition.boundary.durableStore.readCommittedForMatch(
        matchId,
      );
    });
    expect(records, hasLength(2));
    expect(records.where(_isPeriodEnded), isEmpty);
    expect((await db.listNewestFirst()).single.status, MatchStatus.ready);
  });

  testWidgets('End period 2 freezes the clock without finishing the match', (
    tester,
  ) async {
    await pumpMatchesLoaded(tester, testApp());
    await startNewMatchSetup(tester);
    await enterLiveMatch(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Kick-off'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('End period'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Start Period 2'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    expect(find.text('End period'), findsOneWidget);
    expect(find.text('Period 2 ended'), findsNothing);

    await tester.runAsync(() async {
      await tester.tap(find.text('End period'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();

    expect(find.textContaining('Period 2 ended'), findsOneWidget);
    expect(find.text('No active playing period'), findsOneWidget);
    expect(find.textContaining('Interval'), findsNothing);
    expect(find.text('Start Period 2'), findsNothing);
    expect(find.text('End period'), findsNothing);
    expect(find.text('Suspend match'), findsNothing);
    expect(find.text('Full time'), findsNothing);
    expect(find.text('Match finished'), findsNothing);
    expect(find.text('Half-time'), findsNothing);
    expect(find.text('End match'), findsNothing);
    expect(
      find.textContaining('Competition format is unresolved'),
      findsOneWidget,
    );
    final frozen = tester.widget<Text>(find.textContaining('Period 2 ended')).data;
    await tester.pump(const Duration(seconds: 3));
    expect(
      tester.widget<Text>(find.textContaining('Period 2 ended')).data,
      frozen,
    );

    final matchId = (await db.listNewestFirst()).single.matchId;
    late List<MatchRecord> records;
    await tester.runAsync(() async {
      records = await composition.boundary.durableStore.readCommittedForMatch(
        matchId,
      );
    });
    expect(records, hasLength(5));
    expect(
      (records[4].payload as TemporalTransitionPayload).semanticType,
      V1SemanticTypeCode.periodEnded,
    );
    expect((records[4].payload as TemporalTransitionPayload).period?.index, 2);
    expect(
      (records[4].relationships.single as CausalDependency).targetRecordId,
      records[3].recordId,
    );
    expect((await db.listNewestFirst()).single.status, MatchStatus.ready);
    expect((await db.listNewestFirst()).single.events, isEmpty);
  });

  testWidgets('failed Period 2 end stays on active Period 2', (tester) async {
    await pumpMatchesLoaded(tester, testApp());
    await startNewMatchSetup(tester);
    await enterLiveMatch(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Kick-off'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('End period'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Start Period 2'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    composition.boundary.durableStore.abortBeforeCommitForTest = () {
      throw StateError('abort before commit');
    };

    await tester.runAsync(() async {
      await tester.tap(find.text('End period'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();

    expect(find.text('Period end was not saved'), findsAtLeastNWidgets(1));
    expect(find.text('Period 2 ended'), findsNothing);
    expect(find.text('End period'), findsOneWidget);
    expect(find.textContaining('Interval'), findsNothing);
    final matchId = (await db.listNewestFirst()).single.matchId;
    late List<MatchRecord> records;
    await tester.runAsync(() async {
      records = await composition.boundary.durableStore.readCommittedForMatch(
        matchId,
      );
    });
    expect(records, hasLength(4));
    expect((await db.listNewestFirst()).single.status, MatchStatus.ready);
  });

  testWidgets('English fallback localizations load', (tester) async {
    await pumpMatchesLoaded(tester, testApp());
    final l10n = AppLocalizations.of(
      tester.element(find.text('Matches')),
    );
    expect(l10n.newMatch, 'New Match');
  });
}

bool _isPeriodEnded(MatchRecord record) {
  final payload = record.payload;
  return payload is TemporalTransitionPayload &&
      payload.semanticType == V1SemanticTypeCode.periodEnded;
}
