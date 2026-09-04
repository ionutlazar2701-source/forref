import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:match_core/match_core.dart';
import 'package:path_provider/path_provider.dart';

part 'local_match_database.g.dart';

@DataClassName('StoredMatch')
class Matches extends Table {
  TextColumn get matchId => text()();
  TextColumn get status => text()();
  TextColumn get date => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get scoreHome => integer()();
  IntColumn get scoreAway => integer()();
  TextColumn get homeName => text().nullable()();
  TextColumn get awayName => text().nullable()();
  TextColumn get syncState => text()();
  TextColumn get documentJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {matchId};
}

@DataClassName('StoredEvent')
class MatchEvents extends Table {
  TextColumn get eventId => text()();
  TextColumn get matchId => text().references(
        Matches,
        #matchId,
        onDelete: KeyAction.cascade,
      )();
  IntColumn get sortOrder => integer()();
  TextColumn get eventJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {eventId};
}

@DataClassName('StoredHistory')
class MatchHistory extends Table {
  TextColumn get historyId => text()();
  TextColumn get matchId => text().references(
        Matches,
        #matchId,
        onDelete: KeyAction.cascade,
      )();
  TextColumn get eventId => text().nullable()();
  IntColumn get sortOrder => integer()();
  TextColumn get historyJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {historyId};
}

/// Drift + SQLite. One transaction writes match + events + history.
@DriftDatabase(tables: [Matches, MatchEvents, MatchHistory])
class LocalMatchDatabase extends _$LocalMatchDatabase {
  LocalMatchDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  factory LocalMatchDatabase.memory() =>
      LocalMatchDatabase(NativeDatabase.memory());

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'ref_app_matches',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  final MatchJson codec = const MatchJson();

  /// Persist the whole aggregate. No network.
  Future<void> upsertMatch(Match match) {
    return transaction(() async {
      await into(matches).insertOnConflictUpdate(
        MatchesCompanion(
          matchId: Value(match.matchId),
          status: Value(match.status.jsonValue),
          date: Value(match.date),
          createdAt: Value(match.createdAt.toUtc()),
          updatedAt: Value(match.updatedAt.toUtc()),
          scoreHome: Value(match.score.home),
          scoreAway: Value(match.score.away),
          homeName: Value(match.teams.home.name),
          awayName: Value(match.teams.away.name),
          syncState: Value(match.sync.syncState.jsonValue),
          documentJson: Value(jsonEncode(codec.documentToJson(match))),
        ),
      );

      await (delete(matchEvents)
            ..where((row) => row.matchId.equals(match.matchId)))
          .go();
      await (delete(matchHistory)
            ..where((row) => row.matchId.equals(match.matchId)))
          .go();

      for (var i = 0; i < match.events.length; i++) {
        final event = match.events[i];
        await into(matchEvents).insert(
          MatchEventsCompanion.insert(
            eventId: event.eventId,
            matchId: match.matchId,
            sortOrder: i,
            eventJson: jsonEncode(codec.eventToJson(event)),
          ),
        );
      }

      for (var i = 0; i < match.history.length; i++) {
        final entry = match.history[i];
        await into(matchHistory).insert(
          MatchHistoryCompanion.insert(
            historyId: entry.historyId,
            matchId: match.matchId,
            eventId: Value(entry.eventId),
            sortOrder: i,
            historyJson: jsonEncode(codec.historyToJson(entry)),
          ),
        );
      }
    });
  }

  Future<Match?> getMatch(String matchId) async {
    final row = await (select(matches)
          ..where((t) => t.matchId.equals(matchId)))
        .getSingleOrNull();
    if (row == null) return null;
    return _assemble(row);
  }

  /// Match list: newest first.
  Future<List<Match>> listNewestFirst() async {
    final rows = await (select(matches)
          ..orderBy([
            (t) => OrderingTerm.desc(t.updatedAt),
          ]))
        .get();
    final result = <Match>[];
    for (final row in rows) {
      result.add(await _assemble(row));
    }
    return result;
  }

  Future<Match> _assemble(StoredMatch row) async {
    final document = jsonDecode(row.documentJson) as Map;
    final base = codec.fromJson(document);

    final eventRows = await (select(matchEvents)
          ..where((t) => t.matchId.equals(row.matchId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    final historyRows = await (select(matchHistory)
          ..where((t) => t.matchId.equals(row.matchId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();

    return base.copyWith(
      events: [
        for (final eventRow in eventRows)
          codec.eventFromJson(jsonDecode(eventRow.eventJson) as Map),
      ],
      history: [
        for (final historyRow in historyRows)
          codec.historyFromJson(jsonDecode(historyRow.historyJson) as Map),
      ],
    );
  }
}
