import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/app.dart';
import 'package:referee_phone/features/live_match/goal_time_label.dart';
import 'package:referee_phone/infrastructure/competition_rules/match_competition_rules_store.dart';
import 'package:referee_phone/infrastructure/competition_rules/phone_match_capture_context.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/infrastructure/temporal/phone_temporal_evidence_store.dart';
import 'package:referee_phone/l10n/app_localizations_en.dart';

void main() {
  late LocalMatchDatabase db;
  late Directory temp;
  late MatchApplicationComposition composition;
  late PhoneCaptureIdentity identity;
  late PhoneMatchCaptureContext matchCaptureContext;
  late PhoneTemporalEvidenceStore evidence;
  late _ManualClock clock;

  setUp(() async {
    db = LocalMatchDatabase.memory();
    temp = await Directory.systemTemp.createTemp('goal_cutover_widget_');
    composition = await MatchApplicationComposition.open(storageRoot: temp);
    identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    matchCaptureContext = PhoneMatchCaptureContext(
      identity: identity,
      rulesStore: MatchCompetitionRulesStore(temp),
    );
    clock = _ManualClock();
    evidence = PhoneTemporalEvidenceStore(storageRoot: temp, clock: clock);
  });

  tearDown(() async {
    await composition.close();
    await db.close();
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  RefereeApp testApp() {
    return RefereeApp(
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

  Future<void> pumpUntilNotFound(
    WidgetTester tester,
    Finder finder, {
    int maxPumps = 50,
  }) async {
    for (var i = 0; i < maxPumps; i++) {
      if (finder.evaluate().isEmpty) return;
      await tester.pump(const Duration(milliseconds: 100));
    }
    fail('Timed out waiting for $finder to disappear');
  }

  Future<void> pumpUntilAnyFound(
    WidgetTester tester,
    List<Finder> finders, {
    int maxPumps = 50,
  }) async {
    for (var i = 0; i < maxPumps; i++) {
      for (final finder in finders) {
        if (finder.evaluate().isNotEmpty) return;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    fail('Timed out waiting for any of $finders');
  }

  Future<void> openLive(WidgetTester tester) async {
    await tester.pumpWidget(testApp());
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await pumpUntilFound(tester, find.text('Matches'));
    await tester.tap(find.text('New Match'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await pumpUntilFound(tester, find.text('Match setup'));
    await tester.tap(find.text('Live Match'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await pumpUntilAnyFound(tester, [
      find.text('Kick-off'),
      find.text('Complete period start'),
    ]);
    await tester.runAsync(() async {
      await tester.tap(find.text('Kick-off'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    await pumpUntilFound(tester, find.text('Match started'));
  }

  Finder liveScore(String value) {
    return find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.data == value &&
          widget.textAlign == TextAlign.center,
    );
  }

  Future<FilledButton> sideButton(WidgetTester tester, String side) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Goal'));
    await tester.pump();
    expect(find.text('Unknown'), findsNothing);
    expect(find.text('Shirt number'), findsNothing);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, side),
    );
    expect(button.onPressed, isNotNull);
    return button;
  }

  /// Opens Goal, then invokes the side button inside [WidgetTester.runAsync].
  ///
  /// The live clock is a real [Timer.periodic]. [WidgetTester.tap] inside
  /// runAsync holds a test guard that deadlocks if that timer fires. A future
  /// started outside runAsync stays in fake async and does not finish D1.
  Future<({List<Match> stored, List<MatchRecord> records})> readStores(
    WidgetTester tester,
  ) async {
    late List<Match> stored;
    late List<MatchRecord> records;
    await tester.runAsync(() async {
      stored = await db.listNewestFirst();
      records = await composition.boundary.durableStore.readCommittedForMatch(
        stored.single.matchId,
      );
    });
    return (stored: stored, records: records);
  }

  Future<void> chooseSide(WidgetTester tester, String side) async {
    final button = await sideButton(tester, side);
    await tester.runAsync(() async {
      button.onPressed!();
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pump();
  }

  test('exact and uncertain goal times are not formatted as 00:00', () {
    final l10n = AppLocalizationsEn();
    expect(
      formatProjectedGoalTime(
        const ProjectedGoalTemporal(
          continuity: TemporalContinuityStatus.exactContinuity,
          exactPlayingTime: Duration(minutes: 8),
          playingTimeLowerBound: null,
          playingTimeUpperBound: null,
          period: PeriodIdentity(index: 1),
        ),
        l10n,
      ),
      '08:00',
    );
    expect(
      formatProjectedGoalTime(ProjectedGoalTemporal.unresolved, l10n),
      'Elapsed unavailable',
    );
    expect(
      formatProjectedGoalTime(
        const ProjectedGoalTemporal(
          continuity: TemporalContinuityStatus.boundedContinuity,
          exactPlayingTime: null,
          playingTimeLowerBound: Duration(minutes: 7),
          playingTimeUpperBound: Duration(minutes: 9),
          period: PeriodIdentity(index: 1),
        ),
        l10n,
      ),
      '07:00–09:00',
    );
    expect(
      formatProjectedGoalTime(ProjectedGoalTemporal.unresolved, l10n),
      isNot('00:00'),
    );
  });

  testWidgets('Goal to Away updates the projected score and not the legacy row',
      (
    tester,
  ) async {
    await openLive(tester);
    await chooseSide(tester, 'AWAY');

    expect(find.text('Goal saved'), findsAtLeastNWidgets(1));
    expect(liveScore('HOME 0 — 1 AWAY'), findsOneWidget);
    late final List<Match> stored;
    late final List<MatchRecord> records;
    await tester.runAsync(() async {
      stored = await db.listNewestFirst();
      records = await composition.boundary.durableStore.readCommittedForMatch(
        stored.single.matchId,
      );
    });
    expect(stored.single.events, isEmpty);
    expect(stored.single.score.home, 0);
    expect(stored.single.score.away, 0);
    final goals = [
      for (final record in records)
        if (record.payload is GoalPayload) record.payload as GoalPayload,
    ];
    expect(goals.single.creditedSide, CreditedSide.away);
  });

  testWidgets(
      'failed goal commit leaves score and history unchanged and can retry', (
    tester,
  ) async {
    await openLive(tester);
    composition.boundary.durableStore.abortBeforeCommitForTest = () {
      throw StateError('goal commit aborted');
    };

    final button = await sideButton(tester, 'HOME');
    await tester.runAsync(() async {
      button.onPressed!();
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pump();

    expect(find.text('Goal was not saved'), findsAtLeastNWidgets(1));
    expect(find.text('Goal saved'), findsNothing);
    expect(liveScore('HOME 0 — 0 AWAY'), findsOneWidget);
    expect(find.textContaining('00:00  Goal'), findsNothing);
    final failed = await readStores(tester);
    final stored = failed.stored;
    expect(stored.single.score.home, 0);
    expect(stored.single.events, isEmpty);
    final before = failed.records;
    expect(before.where((record) => record.payload is GoalPayload), isEmpty);

    composition.boundary.durableStore.abortBeforeCommitForTest = null;
    final retry = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'HOME'),
    );
    await tester.runAsync(() async {
      retry.onPressed!();
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pump();
    expect(liveScore('HOME 1 — 0 AWAY'), findsOneWidget);
    expect(find.text('Goal saved'), findsAtLeastNWidgets(1));
  });

  testWidgets('visible score stays unchanged until D1 returns', (tester) async {
    await openLive(tester);
    final gate = Completer<void>();
    evidence.beforeAnchorForTest = () => gate.future;

    final button = await sideButton(tester, 'HOME');
    await tester.runAsync(() async {
      button.onPressed!();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    expect(liveScore('HOME 0 — 0 AWAY'), findsOneWidget);
    expect(liveScore('HOME 1 — 0 AWAY'), findsNothing);
    expect(find.text('Goal saved'), findsNothing);

    gate.complete();
    evidence.beforeAnchorForTest = null;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();

    expect(liveScore('HOME 1 — 0 AWAY'), findsOneWidget);
    expect(find.text('Goal saved'), findsAtLeastNWidgets(1));
  });

  testWidgets('an eight minute goal shows derived time instead of 00:00', (
    tester,
  ) async {
    await openLive(tester);
    clock.elapsed = const Duration(minutes: 8);
    await chooseSide(tester, 'HOME');

    expect(find.textContaining('08:00  Goal'), findsOneWidget);
    expect(find.textContaining('00:00  Goal'), findsNothing);
    final stored = (await readStores(tester)).stored;
    expect(stored.single.currentState.elapsedSeconds, 0);
    expect(stored.single.score.home, 0);
  });

  testWidgets(
      'a second tap while a goal commit is pending does not duplicate it', (
    tester,
  ) async {
    await openLive(tester);
    final gate = Completer<void>();
    evidence.beforeAnchorForTest = () => gate.future;
    final button = await sideButton(tester, 'HOME');
    await tester.runAsync(() async {
      button.onPressed!();
      button.onPressed!();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    expect(liveScore('HOME 1 — 0 AWAY'), findsNothing);
    gate.complete();
    evidence.beforeAnchorForTest = null;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();

    expect(liveScore('HOME 1 — 0 AWAY'), findsOneWidget);
    final recorded = await readStores(tester);
    final records = recorded.records;
    expect(
        records.where((record) => record.payload is GoalPayload), hasLength(1));
  });

  testWidgets('Yellow opens authoritative selector without changing Goal state',
      (
    tester,
  ) async {
    await openLive(tester);
    await tester.tap(find.text('Yellow'));
    await tester.pump();
    await pumpUntilFound(tester, find.text('Record Yellow'));
    await pumpUntilNotFound(
      tester,
      find.byKey(const Key('yellow-loading')),
    );

    expect(liveScore('HOME 0 — 0 AWAY'), findsOneWidget);
    final recorded = await readStores(tester);
    final stored = recorded.stored;
    expect(stored.single.events, isEmpty);
    expect(stored.single.score.home, 0);
    final records = recorded.records;
    expect(records.where((record) => record.payload is GoalPayload), isEmpty);
    expect(records.where((record) => record.payload is YellowCardPayload),
        isEmpty);
    expect(records, hasLength(2));
  });
}

final class _ManualClock implements MonotonicContinuityClock {
  Duration elapsed = Duration.zero;

  @override
  String get continuityDomainId => 'domain-widget';

  @override
  Duration get monotonicElapsed => elapsed;

  @override
  DateTime get chronology => DateTime.utc(2026, 10, 5, 18);
}
