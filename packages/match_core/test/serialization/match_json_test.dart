import 'dart:convert';
import 'dart:io';

import 'package:match_core/match_core.dart';
import 'package:test/test.dart';

void main() {
  const codec = MatchJson();

  late String canonicalSource;
  late Map canonicalMap;

  setUpAll(() {
    canonicalSource = _canonicalFile().readAsStringSync();
    canonicalMap = jsonDecode(canonicalSource) as Map;
  });

  test('fromJson reads the canonical fixture', () {
    final match = codec.fromJson(canonicalMap);

    expect(match.matchId, '7b7d6f7a-5a9d-4c4e-9c1f-2c7a7e0b1234');
    expect(match.status, MatchStatus.live);
    expect(match.competition, 'Liga I');
    expect(match.crew.fourthOfficial, isNull);
    expect(match.score.home, 1);
    expect(match.score.away, 0);
    expect(match.currentState.elapsedSeconds, 642);
    expect(match.currentState.periodId, PeriodId.firstHalf);
    expect(match.events, hasLength(3));
    expect(match.events[0].type, EventType.goal);
    expect(match.events[0].data.isOwnGoal, isFalse);
    expect(match.events[1].status, EventStatus.incomplete);
    expect(match.events[1].data.player!.isUnknown, isTrue);
    expect(match.events[2].type, EventType.substitution);
    expect(match.events[2].data.inPlayer!.shirtNumber, 18);
    expect(match.history, isEmpty);
    expect(match.sync.syncState, SyncState.localOnly);
    expect(match.periods.last.id, PeriodId.penalties);
    expect(match.periods.last.status, PeriodStatus.pending);
  });

  test('toJson round-trips the canonical fixture', () {
    final match = codec.fromJson(canonicalMap);
    final encoded = codec.toJson(match);
    final again = codec.fromJson(encoded);

    expect(again.matchId, match.matchId);
    expect(again.status, match.status);
    expect(again.events.length, match.events.length);
    expect(again.events[2].data.inPlayer!.isUnknown, isTrue);
    expect(encoded['events'], isA<List>());
    expect((encoded['crew'] as Map)['fourthOfficial'], isNull);
    expect((encoded['sync'] as Map)['lastSyncedAt'], isNull);
  });
}

File _canonicalFile() {
  final fromPackage = File('../../docs/examples/match-canonical.json');
  if (fromPackage.existsSync()) {
    return fromPackage;
  }
  final fromRepo = File('docs/examples/match-canonical.json');
  if (fromRepo.existsSync()) {
    return fromRepo;
  }
  throw StateError('docs/examples/match-canonical.json not found');
}
