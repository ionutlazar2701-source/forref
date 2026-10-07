import 'dart:convert';
import 'dart:io';

import 'package:forref_match_core/canonical_record_form.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:sqlite3/sqlite3.dart';

import 'record_storage_encoding.dart';

/// File-backed append-only Match Memory.
///
/// **D1 boundary used by this adapter**
///
/// Successful [DurableCommitSuccess] is returned only after SQLite `COMMIT`
/// returns on a file-backed database whose connection has been verified as:
///
/// - `PRAGMA journal_mode = DELETE` (rollback journal)
/// - `PRAGMA synchronous = FULL` (2) or `EXTRA` (3)
///
/// `BEGIN IMMEDIATE` is used so the write lock is held before the insert.
/// SQLite, under `synchronous=FULL` and a rollback journal, calls the VFS
/// `xSync` before `COMMIT` returns. On Windows that is `FlushFileBuffers`.
///
/// This is the same SQLite engine family Drift uses (`package:sqlite3`). Drift
/// itself does not set these pragmas; this adapter sets and re-checks them
/// immediately before `COMMIT`.
///
/// Assumption, not a certification: the operating system and storage honor
/// that sync. Power-loss survival is not claimed. `:memory:` databases are
/// refused. A returned transaction API future is not treated as durability
/// unless `COMMIT` itself returned under the pragmas above.
///
/// Opening the file lets SQLite roll back a hot journal, so a torn transaction
/// is not visible as a committed record. There is no projection table.
final class SqliteDurableMatchStore
    implements MatchMemory, DurableCommitPort, AuthoritativeOriginCommitPort {
  SqliteDurableMatchStore._(this._db);

  final Database _db;
  Future<void> _queue = Future<void>.value();
  int _debugSerialId = 0;

  /// Test-only abort injected after insert and before `COMMIT`.
  ///
  /// A throw rolls the transaction back. It does not simulate power loss.
  void Function()? abortBeforeCommitForTest;

  /// Opens [file], applies the D1 pragmas, and creates the append-only table.
  ///
  /// SQLite replays or rolls back a hot rollback journal during open.
  factory SqliteDurableMatchStore.open(File file) {
    if (_isMemoryPath(file.path)) {
      throw ArgumentError.value(
        file.path,
        'file',
        'In-memory SQLite cannot satisfy D1',
      );
    }
    final db = sqlite3.open(file.path);
    final store = SqliteDurableMatchStore._(db);
    store._configureDurability();
    store._createSchema();
    store._requireIntegrity();
    return store;
  }

  static bool _isMemoryPath(String path) {
    final normalized = path.replaceAll('\\', '/').toLowerCase();
    return normalized == ':memory:' || normalized.endsWith('/:memory:');
  }

  void _configureDurability() {
    _db.select('PRAGMA journal_mode = DELETE');
    _db.execute('PRAGMA synchronous = FULL');
    _requireDurabilityConfiguration();
  }

  void _requireDurabilityConfiguration() {
    final journal = _pragmaText('journal_mode').toLowerCase();
    final synchronous = _pragmaInt('synchronous');
    if (journal != 'delete' || synchronous < 2) {
      throw StateError(
        'D1 configuration refused: journal_mode=$journal synchronous=$synchronous',
      );
    }
  }

  void _createSchema() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS committed_match_records (
        record_id TEXT PRIMARY KEY,
        match_id TEXT NOT NULL,
        origin_device_id TEXT NOT NULL,
        origin_sequence INTEGER NOT NULL,
        record_json TEXT NOT NULL
      )
    ''');
    _db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS ux_origin_slot
      ON committed_match_records(match_id, origin_device_id, origin_sequence)
    ''');
  }

  void _requireIntegrity() {
    final rows = _db.select('PRAGMA integrity_check');
    final messages = [
      for (final row in rows) row.columnAt(0).toString(),
    ];
    if (messages.length != 1 || messages.single != 'ok') {
      throw StateError('SQLite integrity_check failed: $messages');
    }
  }

  /// Table names in this file. Recovery reads only [committed_match_records].
  List<String> tableNames() {
    final rows = _db.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    return [for (final row in rows) row.columnAt(0) as String];
  }

  @override
  Future<DurableCommitResult> commit(MatchRecord record) {
    return _serialized(() async => _commit(record));
  }

  @override
  Future<DurableCommitResult> commitAtNextOriginSequence(
    AuthoritativeRecordCommitRequest request, {
    String? Function(List<MatchRecord> committedForMatch)? rejectCommitted,
  }) {
    return _serialized(
      () async => _commitAtNextOriginSequence(
        request,
        rejectCommitted: rejectCommitted,
      ),
    );
  }

  DurableCommitResult _commitAtNextOriginSequence(
    AuthoritativeRecordCommitRequest request, {
    String? Function(List<MatchRecord> committedForMatch)? rejectCommitted,
  }) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      final existingById = _readById(request.recordId);
      if (existingById != null) {
        _db.execute('ROLLBACK');
        return DurableCommitFailure(
          recordId: request.recordId,
          reason: 'identity conflict: recordId already committed',
        );
      }

      if (rejectCommitted != null) {
        final reason = rejectCommitted(
          _readCommittedForMatchLocked(request.matchId),
        );
        if (reason != null) {
          _db.execute('ROLLBACK');
          return DurableCommitFailure(
            recordId: request.recordId,
            reason: reason,
          );
        }
      }

      final nextSequence = _nextOriginSequenceLocked(
        matchId: request.matchId,
        originDeviceId: request.originDeviceId,
      );
      final record = request.toMatchRecord(originSequence: nextSequence);
      return _insertCommittedRecord(record);
    } catch (error) {
      _rollbackIfNeeded();
      // #region agent log
      File('/opt/cursor/logs/debug.log').writeAsStringSync(
        '${jsonEncode({
              'hypothesisId': 'B,C',
              'location':
                  'sqlite_durable_match_store.dart:_commitAtNextOriginSequence:catch',
              'message': 'commit abort caught and rolled back',
              'data': {'errorType': error.runtimeType.toString()},
              'timestamp': DateTime.now().millisecondsSinceEpoch
            })}\n',
        mode: FileMode.append,
      );
      // #endregion
      return DurableCommitFailure(
        recordId: request.recordId,
        reason: 'commit aborted: $error',
      );
    }
  }

  DurableCommitResult _commit(MatchRecord record) {
    if (record.originSequence < 1) {
      return DurableCommitFailure(
        recordId: record.recordId,
        reason: 'originSequence must be >= 1',
      );
    }

    _db.execute('BEGIN IMMEDIATE');
    try {
      return _insertCommittedRecord(record);
    } catch (error) {
      _rollbackIfNeeded();
      return DurableCommitFailure(
        recordId: record.recordId,
        reason: 'commit aborted: $error',
      );
    }
  }

  DurableCommitResult _insertCommittedRecord(MatchRecord record) {
    final String recordJson;
    try {
      recordJson = encodeMatchRecordJson(record);
    } catch (error) {
      _db.execute('ROLLBACK');
      return DurableCommitFailure(
        recordId: record.recordId,
        reason: 'cannot encode authoritative record: $error',
      );
    }

    final existingById = _readById(record.recordId);
    if (existingById != null) {
      if (identicalCanonicalRecordContent(existingById, record)) {
        _commitTransaction();
        return DurableCommitSuccess(
          committedRecordId: record.recordId,
          diagnostics: 'idempotent-no-op; already committed',
        );
      }
      _db.execute('ROLLBACK');
      return DurableCommitFailure(
        recordId: record.recordId,
        reason: 'identity conflict: same recordId, different canonical content',
      );
    }

    final existingAtSlot = _readByOriginSlot(
      matchId: record.matchId,
      originDeviceId: record.originDeviceId,
      originSequence: record.originSequence,
    );
    if (existingAtSlot != null) {
      _db.execute('ROLLBACK');
      return DurableCommitFailure(
        recordId: record.recordId,
        reason:
            'origin-sequence conflict: (matchId, originDeviceId, originSequence) already committed',
      );
    }

    _db.execute(
      '''
      INSERT INTO committed_match_records (
        record_id, match_id, origin_device_id, origin_sequence, record_json
      ) VALUES (?, ?, ?, ?, ?)
      ''',
      [
        record.recordId,
        record.matchId,
        record.originDeviceId,
        record.originSequence,
        recordJson,
      ],
    );

    final abort = abortBeforeCommitForTest;
    if (abort != null) {
      // #region agent log
      File('/opt/cursor/logs/debug.log').writeAsStringSync(
        '${jsonEncode({
              'hypothesisId': 'B,C',
              'location':
                  'sqlite_durable_match_store.dart:_insertCommittedRecord:abort',
              'message': 'abort hook invoked before commit',
              'data': {'recordId': record.recordId},
              'timestamp': DateTime.now().millisecondsSinceEpoch
            })}\n',
        mode: FileMode.append,
      );
      // #endregion
      abort();
    }

    _commitTransaction();
    return DurableCommitSuccess(
      committedRecordId: record.recordId,
      diagnostics:
          'd1-boundary: journal_mode=DELETE synchronous=FULL commit-returned',
    );
  }

  int _nextOriginSequenceLocked({
    required String matchId,
    required String originDeviceId,
  }) {
    final rows = _db.select(
      '''
      SELECT COALESCE(MAX(origin_sequence), 0) + 1 AS next_sequence
      FROM committed_match_records
      WHERE match_id = ? AND origin_device_id = ?
      ''',
      [matchId, originDeviceId],
    );
    return rows.first.columnAt(0) as int;
  }

  void _commitTransaction() {
    _requireDurabilityConfiguration();
    _db.execute('COMMIT');
  }

  void _rollbackIfNeeded() {
    try {
      _db.execute('ROLLBACK');
    } on SqliteException {
      // Already rolled back, or no transaction was open.
    }
  }

  @override
  Future<MatchRecord?> getById(String recordId) {
    return _serialized(() async => _readById(recordId));
  }

  @override
  Future<List<MatchRecord>> readCommittedForMatch(String matchId) {
    return _serialized(() async {
      final rows = _db.select(
        '''
        SELECT record_json FROM committed_match_records
        WHERE match_id = ?
        ORDER BY rowid
        ''',
        [matchId],
      );
      return [
        for (final row in rows)
          decodeMatchRecordFromStorage(row.columnAt(0) as String),
      ];
    });
  }

  /// Frontier reconstructed only from committed rows for one origin.
  Future<OriginSequenceFrontier> originSequenceFrontier({
    required String matchId,
    required String originDeviceId,
  }) {
    return _serialized(() async => _originSequenceFrontier(
          matchId: matchId,
          originDeviceId: originDeviceId,
        ));
  }

  OriginSequenceFrontier _originSequenceFrontier({
    required String matchId,
    required String originDeviceId,
  }) {
    final rows = _db.select(
      '''
      SELECT origin_sequence FROM committed_match_records
      WHERE match_id = ? AND origin_device_id = ?
      ORDER BY origin_sequence
      ''',
      [matchId, originDeviceId],
    );
    final sequences = <int>{
      for (final row in rows) row.columnAt(0) as int,
    };
    final sorted = sequences.toList()..sort();
    final highestObserved = sorted.isEmpty ? 0 : sorted.last;
    var highestContiguous = 0;
    for (var sequence = 1; sequence <= highestObserved; sequence++) {
      if (!sequences.contains(sequence)) break;
      highestContiguous = sequence;
    }
    final missing = <int>[
      for (var sequence = 1; sequence <= highestObserved; sequence++)
        if (!sequences.contains(sequence)) sequence,
    ];
    return OriginSequenceFrontier(
      matchId: matchId,
      originDeviceId: originDeviceId,
      committedSequences: sorted,
      highestContiguousCommitted: highestContiguous,
      highestObserved: highestObserved,
      missingSequences: missing,
    );
  }

  List<MatchRecord> _readCommittedForMatchLocked(String matchId) {
    final rows = _db.select(
      '''
      SELECT record_json FROM committed_match_records
      WHERE match_id = ?
      ORDER BY rowid
      ''',
      [matchId],
    );
    return [
      for (final row in rows)
        decodeMatchRecordFromStorage(row.columnAt(0) as String),
    ];
  }

  MatchRecord? _readById(String recordId) {
    final rows = _db.select(
      'SELECT record_json FROM committed_match_records WHERE record_id = ?',
      [recordId],
    );
    if (rows.isEmpty) return null;
    return decodeMatchRecordFromStorage(rows.first.columnAt(0) as String);
  }

  MatchRecord? _readByOriginSlot({
    required String matchId,
    required String originDeviceId,
    required int originSequence,
  }) {
    final rows = _db.select(
      '''
      SELECT record_json FROM committed_match_records
      WHERE match_id = ? AND origin_device_id = ? AND origin_sequence = ?
      ''',
      [matchId, originDeviceId, originSequence],
    );
    if (rows.isEmpty) return null;
    return decodeMatchRecordFromStorage(rows.first.columnAt(0) as String);
  }

  int _pragmaInt(String name) {
    final value = _db.select('PRAGMA $name').first.columnAt(0);
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw StateError('Unexpected pragma $name value: $value');
  }

  String _pragmaText(String name) {
    return _db.select('PRAGMA $name').first.columnAt(0).toString();
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final operationId = ++_debugSerialId;
    // #region agent log
    File('/opt/cursor/logs/debug.log').writeAsStringSync(
      '${jsonEncode({
            'hypothesisId': 'A,E',
            'location': 'sqlite_durable_match_store.dart:_serialized:enqueue',
            'message': 'serialized operation enqueued',
            'data': {'operationId': operationId},
            'timestamp': DateTime.now().millisecondsSinceEpoch
          })}\n',
      mode: FileMode.append,
    );
    // #endregion
    final result = _queue.then((_) async {
      // #region agent log
      File('/opt/cursor/logs/debug.log').writeAsStringSync(
        '${jsonEncode({
              'hypothesisId': 'A,B,E',
              'location': 'sqlite_durable_match_store.dart:_serialized:action',
              'message': 'serialized action started',
              'data': {'operationId': operationId},
              'timestamp': DateTime.now().millisecondsSinceEpoch
            })}\n',
        mode: FileMode.append,
      );
      // #endregion
      final value = await action();
      // #region agent log
      File('/opt/cursor/logs/debug.log').writeAsStringSync(
        '${jsonEncode({
              'hypothesisId': 'A,B',
              'location': 'sqlite_durable_match_store.dart:_serialized:result',
              'message': 'serialized action returned',
              'data': {
                'operationId': operationId,
                'resultType': value.runtimeType.toString()
              },
              'timestamp': DateTime.now().millisecondsSinceEpoch
            })}\n',
        mode: FileMode.append,
      );
      // #endregion
      return value;
    });
    final tail = result.then<void>((value) {
      // #region agent log
      File('/opt/cursor/logs/debug.log').writeAsStringSync(
        '${jsonEncode({
              'hypothesisId': 'A,B,E',
              'location': 'sqlite_durable_match_store.dart:_serialized:tail',
              'message': 'serialized tail advanced',
              'data': {
                'operationId': operationId,
                'resultType': value.runtimeType.toString()
              },
              'timestamp': DateTime.now().millisecondsSinceEpoch
            })}\n',
        mode: FileMode.append,
      );
      // #endregion
    }, onError: (Object error, StackTrace stackTrace) {});
    _queue = tail;
    return tail.then((_) {
      // #region agent log
      File('/opt/cursor/logs/debug.log').writeAsStringSync(
        '${jsonEncode({
              'hypothesisId': 'A,E',
              'location': 'sqlite_durable_match_store.dart:_serialized:release',
              'message': 'serialized caller released',
              'data': {'operationId': operationId},
              'timestamp': DateTime.now().millisecondsSinceEpoch
            })}\n',
        mode: FileMode.append,
      );
      // #endregion
      return result;
    });
  }

  Future<void> close() {
    return _serialized(() async {
      _db.close();
    });
  }
}
