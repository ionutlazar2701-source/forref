import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';

void main() {
  late LocalMatchDatabase db;
  const codec = MatchJson();
  const reducer = EventReducer();
  const factory = EventFactory();
  const lifecycle = MatchLifecycle();

  setUp(() {
    db = LocalMatchDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  test('upsert and get round-trip the canonical match', () async {
    final match = codec.fromJson(_canonicalMap());
    await db.upsertMatch(match);

    final loaded = await db.getMatch(match.matchId);
    expect(loaded, isNotNull);
    expect(loaded!.status, MatchStatus.live);
    expect(loaded.score.home, 1);
    expect(loaded.events, hasLength(3));
    expect(loaded.events[1].status, EventStatus.incomplete);
    expect(loaded.events[2].data.inPlayer!.shirtNumber, 18);
    expect(loaded.currentState.elapsedSeconds, 642);
    expect(loaded.sync.syncState, SyncState.localOnly);
  });

  test('event + derived score + history write in one save', () async {
    final now = DateTime.utc(2026, 9, 4, 10);
    var match = lifecycle.applyKickOff(_readyMatch(now), now);
    final goal = factory.create(
      eventId: 'g1',
      matchId: match.matchId,
      type: EventType.goal,
      periodId: PeriodId.firstHalf,
      matchTime: 12,
      now: now,
      data: const EventData(
        teamId: 'h',
        player: PlayerRef(playerId: 'p', isUnknown: false),
      ),
    );
    match = reducer.applyNewEvent(match, goal);
    match = reducer.applyEventUpdate(
      match,
      goal.copyWith(type: EventType.yellowCard),
      historyId: 'h1',
      now: now.add(const Duration(seconds: 5)),
    );

    await db.upsertMatch(match);
    final loaded = await db.getMatch(match.matchId);
    expect(loaded!.events.single.type, EventType.yellowCard);
    expect(loaded.score.home, 0);
    expect(loaded.history, hasLength(1));
    expect(loaded.history.single.previousValue['type'], 'goal');
  });

  test('list is newest first', () async {
    final older = _readyMatch(DateTime.utc(2026, 9, 4, 9), id: 'old');
    final newer = _readyMatch(DateTime.utc(2026, 9, 4, 10), id: 'new');
    await db.upsertMatch(older);
    await db.upsertMatch(newer);

    final list = await db.listNewestFirst();
    expect(list.map((m) => m.matchId).toList(), ['new', 'old']);
  });

  test('missing match is null', () async {
    expect(await db.getMatch('nope'), isNull);
  });
}

Map<String, dynamic> _canonicalMap() {
  final file = _canonicalFile();
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

File _canonicalFile() {
  final fromApp = File('../../docs/examples/match-canonical.json');
  if (fromApp.existsSync()) return fromApp;
  final fromRepo = File('docs/examples/match-canonical.json');
  if (fromRepo.existsSync()) return fromRepo;
  throw StateError('docs/examples/match-canonical.json not found');
}

Match _readyMatch(DateTime now, {String id = 'm'}) {
  return Match(
    matchId: id,
    status: MatchStatus.ready,
    createdAt: now,
    updatedAt: now,
    date: '2026-09-04',
    teams: const Teams(
      home: Team(teamId: 'h', name: 'Home'),
      away: Team(teamId: 'a', name: 'Away'),
    ),
    settings: const MatchSettings(halfDurationSeconds: 2700),
    currentState: const MatchState(
      periodId: PeriodId.firstHalf,
      clockRunning: false,
      elapsedSeconds: 0,
    ),
    score: const Score(home: 0, away: 0),
  );
}
