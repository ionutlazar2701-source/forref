import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:sqlite3/sqlite3.dart';

import '../fixtures/match_record_fixtures.dart';

/// SQLite PRAGMA, query plan, and statement profile.
final class SqliteProfileHarness {
  Future<Map<String, Object?>> run(Directory tempRoot) async {
    final file = File('${tempRoot.path}/sqlite_profile.sqlite');
    final store = SqliteDurableMatchStore.open(file);

    // Seed records for query plans.
    final seed = MatchRecordFixtures.scenarioCSynthetic(count: 100);
    for (final record in seed) {
      final outcome = await store.commit(record);
      if (outcome is! DurableCommitSuccess) {
        throw StateError('Seed failed: $outcome');
      }
    }

    final db = sqlite3.open(file.path);
    final journalMode = _pragmaText(db, 'journal_mode');
    final synchronous = _pragmaInt(db, 'synchronous');

    final queryPlans = {
      'recordIdLookup': _explain(
        db,
        'SELECT record_json FROM committed_match_records WHERE record_id = ?',
        ['c-rec-50'],
      ),
      'originSlotLookup': _explain(
        db,
        '''
        SELECT record_json FROM committed_match_records
        WHERE match_id = ? AND origin_device_id = ? AND origin_sequence = ?
        ''',
        [MatchRecordFixtures.matchId, MatchRecordFixtures.originDeviceId, 50],
      ),
      'highestOriginSequence': _explain(
        db,
        '''
        SELECT COALESCE(MAX(origin_sequence), 0) + 1 AS next_sequence
        FROM committed_match_records
        WHERE match_id = ? AND origin_device_id = ?
        ''',
        [MatchRecordFixtures.matchId, MatchRecordFixtures.originDeviceId],
      ),
      'readCommittedForMatch': _explain(
        db,
        '''
        SELECT record_json FROM committed_match_records
        WHERE match_id = ?
        ORDER BY rowid
        ''',
        [MatchRecordFixtures.matchId],
      ),
    };

    final indexes = [
      for (final row in db.select(
        "SELECT name, sql FROM sqlite_master WHERE type = 'index' AND tbl_name = 'committed_match_records'",
      ))
        {
          'name': row.columnAt(0),
          'sql': row.columnAt(1),
        },
    ];

    db.close();
    await store.close();

    return {
      'pragmas': {
        'journal_mode': journalMode,
        'synchronous': synchronous,
        'synchronousLabel': synchronous == 2
            ? 'FULL'
            : synchronous == 3
                ? 'EXTRA'
                : 'other($synchronous)',
      },
      'statementsPerAuthoritativeCommitAtNextOriginSequence': {
        'note': 'Derived from sqlite_durable_match_store.dart control flow',
        'statements': [
          'BEGIN IMMEDIATE',
          'SELECT record_json WHERE record_id = ? (conflict check)',
          'SELECT COALESCE(MAX(origin_sequence)... (sequence allocation)',
          'SELECT record_json WHERE record_id = ? (insert path duplicate check)',
          'SELECT record_json WHERE match_id AND origin_device_id AND origin_sequence (slot check)',
          'INSERT INTO committed_match_records (...)',
          'PRAGMA journal_mode (durability re-check)',
          'PRAGMA synchronous (durability re-check)',
          'COMMIT',
        ],
        'transactionCount': 1,
        'estimatedStatementCount': 9,
      },
      'statementsPerIdempotentReplay': {
        'statements': [
          'BEGIN IMMEDIATE',
          'SELECT record_json WHERE record_id = ?',
          'PRAGMA journal_mode',
          'PRAGMA synchronous',
          'COMMIT (idempotent no-op path)',
        ],
        'transactionCount': 1,
        'estimatedStatementCount': 5,
      },
      'queryPlans': queryPlans,
      'indexes': indexes,
      'integrityChecks': {
        'onOpen': ['PRAGMA integrity_check (full database)'],
        'onCommit': [
          'PRAGMA journal_mode re-check',
          'PRAGMA synchronous re-check',
        ],
        'perRead': 'none (decode validation only on JSON parse)',
        'frequency': 'integrity_check once per SqliteDurableMatchStore.open(); durability pragmas before every COMMIT',
      },
    };
  }

  static String _pragmaText(Database db, String name) {
    return db.select('PRAGMA $name').first.columnAt(0).toString();
  }

  static int _pragmaInt(Database db, String name) {
    final value = db.select('PRAGMA $name').first.columnAt(0);
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw StateError('Unexpected pragma $name: $value');
  }

  static List<String> _explain(Database db, String sql, List<Object?> args) {
    final rows = db.select('EXPLAIN QUERY PLAN $sql', args);
    return [
      for (final row in rows)
        row.values.map((value) => value?.toString() ?? 'null').join(' | '),
    ];
  }
}
