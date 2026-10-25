import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/app.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/match/new_match.dart';
import 'package:referee_phone/training/training_session.dart';
import 'package:referee_phone/training/training_store.dart';

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data)
      .join(' | ');
  fail(
    'Missing $finder. Visible text: $texts. Exception: ${tester.takeException()}',
  );
}

void main() {
  late Directory temp;
  late DateTime now;
  late int ids;
  late TrainingStore store;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('training_v1_');
    now = DateTime.utc(2026, 10, 25, 8);
    ids = 0;
    store = TrainingStore(
      directory: temp,
      clock: () => now,
      ids: () => 'training-${++ids}',
    );
  });

  tearDown(() async {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('two sessions persist across a reopened ledger', () async {
    final first = await store.startGeneral();
    expect(first, isA<TrainingStarted>());
    now = now.add(const Duration(minutes: 5));
    final paused = await store.pause('training-1');
    expect(paused!.phase, TrainingPhase.paused);
    now = now.add(const Duration(minutes: 1));
    final resumed = await store.resume('training-1');
    expect(resumed!.phase, TrainingPhase.active);
    now = now.add(const Duration(minutes: 4));
    final finished = await store.finish('training-1');
    expect(finished!.phase, TrainingPhase.finished);
    final facts = trainingFacts(finished, now);
    expect(facts.elapsed.known, isTrue);
    expect(facts.elapsed.duration, const Duration(minutes: 9));
    expect(facts.pauseCount, 1);

    final second = await store.startGeneral();
    expect(second, isA<TrainingStarted>());
    expect((second as TrainingStarted).session.id, 'training-2');

    final reopened = TrainingStore(
      directory: temp,
      clock: () => now,
      ids: () => 'should-not-allocate',
    );
    final ledger = await reopened.load();
    expect(ledger.unreadable, isFalse);
    expect(ledger.sessions, hasLength(2));
    expect(ledger.sessions.first.phase, TrainingPhase.finished);
    expect(ledger.sessions.last.phase, TrainingPhase.active);
    final continued = trainingFacts(ledger.sessions.last, now);
    expect(continued.elapsed.duration, Duration.zero);
    now = now.add(const Duration(seconds: 30));
    expect(
      trainingFacts(ledger.sessions.last, now).elapsed.duration,
      const Duration(seconds: 30),
    );
  });

  test('duplicate start is one session and finish is idempotent', () async {
    final first = await store.startGeneral(requestId: 'tap-1');
    final second = await store.startGeneral(requestId: 'tap-1');
    final third = await store.startGeneral();
    expect(first, isA<TrainingStarted>());
    expect(second, isA<TrainingAlreadyPresent>());
    expect(third, isA<TrainingStartBlocked>());
    expect((await store.load()).sessions, hasLength(1));

    now = now.add(const Duration(minutes: 2));
    await store.finish('training-1');
    final again = await store.finish('training-1');
    expect(again!.events.where((e) => e.kind == TrainingEventKind.finished),
        hasLength(1));
    final facts = trainingFacts(again, now.subtract(const Duration(hours: 1)));
    expect(facts.elapsed.known, isTrue);
    expect(facts.elapsed.duration!.isNegative, isFalse);
  });

  test('a clock that moves backwards leaves elapsed unknown', () async {
    await store.startGeneral();
    now = now.subtract(const Duration(seconds: 5));
    final session = (await store.load()).sessions.single;
    final facts = trainingFacts(session, now);
    expect(facts.phase, TrainingPhase.active);
    expect(facts.elapsed.known, isFalse);
    expect(facts.elapsed.duration, isNull);
  });

  test('warm-up is one record and does not change match status', () async {
    final database = LocalMatchDatabase.memory();
    final match = newLocalMatch(DateTime.utc(2026, 10, 25));
    await database.upsertMatch(match);
    expect(match.status, MatchStatus.setup);

    final created = await store.startWarmUp(matchId: match.matchId);
    final again = await store.startWarmUp(matchId: match.matchId);
    expect(created, isA<TrainingStarted>());
    expect(again, isA<TrainingAlreadyPresent>());
    expect(
      (again as TrainingAlreadyPresent).session.id,
      (created as TrainingStarted).session.id,
    );
    expect((await store.load()).sessions, hasLength(1));
    final stored = (await database.getMatch(match.matchId))!;
    expect(stored.status, MatchStatus.setup);
    await database.close();
  });

  test('an unreadable ledger is not an empty history', () async {
    await File('${temp.path}/training_sessions.json').writeAsString('not-json');
    final ledger = await store.load();
    expect(ledger.unreadable, isTrue);
    expect(ledger.sessions, isEmpty);
    final result = await store.startGeneral();
    expect(result, isA<TrainingStartBlocked>());
    expect(
      await File('${temp.path}/training_sessions.json').readAsString(),
      'not-json',
    );
  });

  testWidgets('leaving Training does not pause the open session',
      (tester) async {
    final database = LocalMatchDatabase.memory();
    addTearDown(database.close);
    await store.startGeneral();
    await tester.pumpWidget(RefereeApp(database: database, training: store));
    await tester.pump();
    await tester.tap(find.byKey(const Key('open-training')));
    await _pumpUntil(
      tester,
      find.byKey(const Key('training-session-training-1')),
    );
    await tester.tap(find.byKey(const Key('training-session-training-1')));
    await _pumpUntil(tester, find.byKey(const Key('training-pause')));
    expect(find.byKey(const Key('training-pause')), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump(const Duration(milliseconds: 250));
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const Key('open-training')), findsOneWidget);

    await tester.tap(find.byKey(const Key('open-training')));
    await _pumpUntil(tester, find.text('Active · 00:00'));
    expect(find.text('Active · 00:00'), findsOneWidget);
    expect(find.text('Paused'), findsNothing);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump(const Duration(milliseconds: 250));
  });

  test('match gate blocks an open match and an unverified read', () {
    expect(
      denyTrainingStart(
        anotherSessionOpen: false,
        matchInProgress: true,
        matchStateUnverified: false,
      ),
      TrainingStartDenial.matchInProgress,
    );
    expect(
      denyTrainingStart(
        anotherSessionOpen: true,
        matchInProgress: false,
        matchStateUnverified: true,
      ),
      TrainingStartDenial.matchStateUnverified,
    );
  });
}
