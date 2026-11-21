import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/app.dart';
import 'package:referee_phone/features/settings/debug_local_bridge_section.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/officiate/local_configuration_bridge.dart';

void main() {
  late LocalMatchDatabase database;

  setUp(() {
    database = LocalMatchDatabase.memory();
  });

  tearDown(() async {
    await database.close();
  });

  test('a refused bridge does not read the match or listen', () async {
    var reads = 0;
    final bridge = LocalConfigurationBridge(
      readPersistedMatch: (_) async {
        reads += 1;
        return null;
      },
      debugPermitted: () => false,
      port: 0,
    );
    addTearDown(bridge.stop);

    expect(
      await bridge.start('match-1'),
      LocalBridgeDisposition.refused,
    );
    expect(reads, 0);
    expect(bridge.isListening, isFalse);
    expect(bridge.loopbackEndpoint, isEmpty);
  });

  test('the loopback serves the persisted configuration and follows edits',
      () async {
    final bridge = LocalConfigurationBridge(
      readPersistedMatch: database.getMatch,
      port: 0,
    );
    addTearDown(bridge.stop);
    final stored = _match(
      matchId: 'match-river',
      home: 'River',
      away: 'Delta',
      score: const Score(home: 3, away: 1),
    );
    await database.upsertMatch(stored);

    expect(
      await bridge.start('missing-match'),
      LocalBridgeDisposition.missing,
    );
    expect(bridge.isListening, isFalse);

    expect(
      await bridge.start(stored.matchId),
      LocalBridgeDisposition.listening,
    );
    expect(bridge.loopbackEndpoint, startsWith('127.0.0.1:'));
    expect(bridge.loopbackEndpoint, isNot(contains('0.0.0.0')));

    final first = await _get(bridge);
    expect(first.status, 200);
    expect(first.json['homeTeamName'], 'River');
    expect(first.json['awayTeamName'], 'Delta');
    expect(first.json['matchId'], 'match-river');
    expect(first.json['payloadVersion'], 1);
    expect(first.json.containsKey('score'), isFalse);
    expect(first.json.containsKey('events'), isFalse);
    expect(first.json.containsKey('status'), isFalse);
    expect(first.json.containsKey('sync'), isFalse);
    expect(first.json.containsKey('history'), isFalse);
    expect(first.body.contains('North'), isFalse);
    expect(first.body.contains('South'), isFalse);

    await database.upsertMatch(
      stored.copyWith(
        updatedAt: DateTime.utc(2026, 11, 21, 12),
        teams: const Teams(
          home: Team(teamId: 'home', name: 'Oak'),
          away: Team(teamId: 'away', name: 'Elm'),
        ),
      ),
    );
    final edited = await _get(bridge);
    expect(edited.json['homeTeamName'], 'Oak');
    expect(edited.json['awayTeamName'], 'Elm');

    final other = _match(matchId: 'match-other', home: 'Cedar', away: 'Pine');
    await database.upsertMatch(other);
    expect(
      await bridge.select(other.matchId),
      LocalBridgeDisposition.listening,
    );
    final switched = await _get(bridge);
    expect(switched.json['matchId'], 'match-other');
    expect(switched.json['homeTeamName'], 'Cedar');

    await database.upsertMatch(stored);
    await (database.delete(database.matches)
          ..where((row) => row.matchId.equals(other.matchId)))
        .go();
    final gone = await _get(bridge);
    expect(gone.status, 404);
    expect(gone.json['disposition'], 'missing');
    expect(gone.json.containsKey('homeTeamName'), isFalse);

    final rejected = await _get(bridge, path: '/score');
    expect(rejected.status, 404);
    expect(rejected.json.containsKey('homeTeamName'), isFalse);

    final endpoint = bridge.loopbackEndpoint;
    await bridge.stop();
    expect(bridge.isListening, isFalse);
    await expectLater(
      _getUrl(endpoint),
      throwsA(isA<SocketException>()),
    );
  });

  testWidgets('starting the bridge is a settings action', (tester) async {
    final bridge = LocalConfigurationBridge(
      readPersistedMatch: database.getMatch,
      port: 0,
    );
    addTearDown(bridge.stop);
    await database.upsertMatch(
      _match(matchId: 'match-ui', home: 'Harbor', away: 'Field'),
    );
    await tester.pumpWidget(
      RefereeApp(database: database, localBridge: bridge),
    );
    await tester.pump();
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final section = find.byType(DebugLocalBridgeSection);
    expect(
      find.descendant(
        of: section,
        matching: find.text('Harbor — Field'),
      ),
      findsOneWidget,
    );
    expect(find.text('Start local bridge'), findsOneWidget);
    expect(bridge.isListening, isFalse);

    await tester.tap(
      find.descendant(
        of: section,
        matching: find.text('Harbor — Field'),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Start local bridge'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    expect(bridge.isListening, isTrue);
    expect(find.textContaining('Listening on 127.0.0.1:'), findsOneWidget);
    expect(bridge.selectedMatchId, 'match-ui');

    await tester.tap(find.text('Stop local bridge'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(bridge.isListening, isFalse);
  });
}

Match _match({
  required String matchId,
  required String home,
  required String away,
  Score score = const Score(home: 0, away: 0),
}) {
  return Match(
    matchId: matchId,
    status: MatchStatus.live,
    createdAt: DateTime.utc(2026, 11, 21, 10),
    updatedAt: DateTime.utc(2026, 11, 21, 11),
    date: '2026-11-21',
    teams: Teams(
      home: Team(teamId: 'home', name: home),
      away: Team(teamId: 'away', name: away),
    ),
    settings: const MatchSettings(halfDurationSeconds: 2700),
    periods: defaultMatchPeriods(),
    currentState: const MatchState(
      periodId: PeriodId.firstHalf,
      clockRunning: true,
      elapsedSeconds: 90,
    ),
    score: score,
    events: [
      MatchEvent(
        eventId: 'goal-$matchId',
        matchId: matchId,
        type: EventType.goal,
        status: EventStatus.complete,
        periodId: PeriodId.firstHalf,
        matchTime: 40,
        createdAt: DateTime.utc(2026, 11, 21, 11),
        updatedAt: DateTime.utc(2026, 11, 21, 11),
        data: const EventData(teamId: 'home'),
      ),
    ],
  );
}

class _Response {
  _Response(this.status, this.body)
      : json = jsonDecode(body) as Map<String, Object?>;

  final int status;
  final String body;
  final Map<String, Object?> json;
}

Future<_Response> _get(
  LocalConfigurationBridge bridge, {
  String path = forrefLocalBridgePath,
}) {
  return _getUrl(bridge.loopbackEndpoint, path: path);
}

Future<_Response> _getUrl(
  String endpoint, {
  String path = forrefLocalBridgePath,
}) async {
  final uri = Uri.parse('http://$endpoint$path');
  final socket = await Socket.connect(
    uri.host,
    uri.port,
    timeout: const Duration(seconds: 2),
  );
  socket.write(
    'GET ${uri.path} HTTP/1.1\r\nHost: ${uri.host}\r\nConnection: close\r\n\r\n',
  );
  final bytes = await socket.fold<List<int>>(
    <int>[],
    (collected, chunk) => collected..addAll(chunk),
  );
  final text = utf8.decode(bytes);
  final headerEnd = text.indexOf('\r\n\r\n');
  final header = text.substring(0, headerEnd);
  final body = text.substring(headerEnd + 4);
  final status = int.parse(header.split(' ')[1]);
  return _Response(status, body);
}
