import 'dart:io';

import 'package:forref_match_core/canonical_record_form.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:sqlite3/sqlite3.dart';

import 'record_storage_encoding.dart';

/// Decoded committed records plus any rows that could not be decoded.
final class CommittedMatchMemorySnapshot {
  const CommittedMatchMemorySnapshot({
    required this.records,
    required this.quarantinedRecordIds,
  });

  final List<MatchRecord> records;
  final List<String> quarantinedRecordIds;

  bool get hasQuarantine => quarantinedRecordIds.isNotEmpty;
}

/// Read failed because at least one committed row could not be decoded.
final class CommittedRecordQuarantineException implements Exception {
  CommittedRecordQuarantineException({
    required this.matchId,
    required this.quarantinedRecordIds,
    required this.decodedRecordCount,
  });

  final String matchId;
  final List<String> quarantinedRecordIds;
  final int decodedRecordCount;

  @override
  String toString() => 'CommittedRecordQuarantineException(matchId=$matchId, '
      'quarantinedRecordIds=$quarantinedRecordIds, '
      'decodedRecordCount=$decodedRecordCount)';
}

/// Outcome of persisting a generation-1 authority root.
sealed class GenerationOneRootCommitResult {
  const GenerationOneRootCommitResult();
}

final class GenerationOneRootCommitSuccess
    extends GenerationOneRootCommitResult {
  const GenerationOneRootCommitSuccess({this.diagnostics});

  final String? diagnostics;
}

final class GenerationOneRootCommitFailure
    extends GenerationOneRootCommitResult {
  const GenerationOneRootCommitFailure({required this.reason});

  final String reason;
}

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
    _db.execute('''
      CREATE TABLE IF NOT EXISTS capture_intent_admissions (
        match_id TEXT NOT NULL,
        authority_scope TEXT NOT NULL,
        capture_intent_id TEXT NOT NULL,
        committed_record_id TEXT NOT NULL,
        semantic_type_wire TEXT NOT NULL,
        authority_principal_id TEXT NOT NULL,
        authority_generation INTEGER NOT NULL,
        scoring_team_id TEXT,
        participant_id TEXT,
        accounting_scope TEXT,
        subject_kind TEXT,
        subject_id TEXT,
        pathway TEXT,
        first_caution_record_id TEXT,
        second_caution_record_id TEXT,
        outgoing_participant_id TEXT,
        incoming_participant_id TEXT,
        substitution_team_id TEXT,
        PRIMARY KEY (match_id, authority_scope, capture_intent_id)
      )
    ''');
    _ensureCaptureIntentSubjectColumns();
    _db.execute('''
      CREATE TABLE IF NOT EXISTS team_official_team_bindings (
        match_id TEXT NOT NULL,
        team_official_id TEXT NOT NULL,
        team_id TEXT NOT NULL,
        PRIMARY KEY (match_id, team_official_id)
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS participant_team_bindings (
        match_id TEXT NOT NULL,
        participant_id TEXT NOT NULL,
        team_id TEXT NOT NULL,
        PRIMARY KEY (match_id, participant_id)
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS generation_one_authority_roots (
        match_id TEXT PRIMARY KEY,
        principal_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        generation INTEGER NOT NULL CHECK (generation = 1)
      )
    ''');
  }

  static const _mainRefereeScopeWire = 'MAIN_REFEREE';

  void _ensureCaptureIntentSubjectColumns() {
    final rows = _db.select('PRAGMA table_info(capture_intent_admissions)');
    final names = <String>{
      for (final row in rows) row.columnAt(1) as String,
    };
    if (!names.contains('participant_id')) {
      _db.execute(
        'ALTER TABLE capture_intent_admissions ADD COLUMN participant_id TEXT',
      );
    }
    if (!names.contains('accounting_scope')) {
      _db.execute(
        'ALTER TABLE capture_intent_admissions ADD COLUMN accounting_scope TEXT',
      );
    }
    if (!names.contains('subject_kind')) {
      _db.execute(
        'ALTER TABLE capture_intent_admissions ADD COLUMN subject_kind TEXT',
      );
    }
    if (!names.contains('subject_id')) {
      _db.execute(
        'ALTER TABLE capture_intent_admissions ADD COLUMN subject_id TEXT',
      );
    }
    if (!names.contains('pathway')) {
      _db.execute(
        'ALTER TABLE capture_intent_admissions ADD COLUMN pathway TEXT',
      );
    }
    if (!names.contains('first_caution_record_id')) {
      _db.execute(
        'ALTER TABLE capture_intent_admissions ADD COLUMN first_caution_record_id TEXT',
      );
    }
    if (!names.contains('second_caution_record_id')) {
      _db.execute(
        'ALTER TABLE capture_intent_admissions ADD COLUMN second_caution_record_id TEXT',
      );
    }
    if (!names.contains('outgoing_participant_id')) {
      _db.execute(
        'ALTER TABLE capture_intent_admissions ADD COLUMN outgoing_participant_id TEXT',
      );
    }
    if (!names.contains('incoming_participant_id')) {
      _db.execute(
        'ALTER TABLE capture_intent_admissions ADD COLUMN incoming_participant_id TEXT',
      );
    }
    if (!names.contains('substitution_team_id')) {
      _db.execute(
        'ALTER TABLE capture_intent_admissions ADD COLUMN substitution_team_id TEXT',
      );
    }
  }

  /// Durable participant-team association used to admit a completed substitution.
  Future<TeamBindingCommitResult> commitParticipantTeamBinding(
    MatchParticipantTeamBinding binding,
  ) {
    return _serialized(() async {
      if (binding.matchId.isEmpty) {
        return const TeamBindingCommitConflict('match id is empty');
      }
      _db.execute('BEGIN IMMEDIATE');
      try {
        final rows = _db.select(
          '''
          SELECT team_id FROM participant_team_bindings
          WHERE match_id = ? AND participant_id = ?
          ''',
          [binding.matchId, binding.participantId.value],
        );
        if (rows.isNotEmpty) {
          final stored = rows.first.columnAt(0) as String;
          if (stored == binding.teamId.value) {
            _commitTransaction();
            return const TeamBindingCommitSuccess(idempotent: true);
          }
          _db.execute('ROLLBACK');
          return const TeamBindingCommitConflict(
            'participant team binding conflicts',
          );
        }
        _db.execute(
          '''
          INSERT INTO participant_team_bindings (
            match_id, participant_id, team_id
          ) VALUES (?, ?, ?)
          ''',
          [binding.matchId, binding.participantId.value, binding.teamId.value],
        );
        _commitTransaction();
        return const TeamBindingCommitSuccess(idempotent: false);
      } catch (error) {
        _rollbackIfNeeded();
        return TeamBindingCommitConflict('team binding aborted: $error');
      }
    });
  }

  /// Durable team-official association. A second team for the same official conflicts.
  Future<TeamBindingCommitResult> commitTeamOfficialTeamBinding(
    TeamOfficialTeamBinding binding,
  ) {
    return _serialized(() async {
      if (binding.matchId.isEmpty) {
        return const TeamBindingCommitConflict('match id is empty');
      }
      _db.execute('BEGIN IMMEDIATE');
      try {
        final rows = _db.select(
          '''
          SELECT team_id FROM team_official_team_bindings
          WHERE match_id = ? AND team_official_id = ?
          ''',
          [binding.matchId, binding.teamOfficialId.value],
        );
        if (rows.isNotEmpty) {
          final stored = rows.first.columnAt(0) as String;
          if (stored == binding.teamId.value) {
            _commitTransaction();
            return const TeamBindingCommitSuccess(idempotent: true);
          }
          _db.execute('ROLLBACK');
          return const TeamBindingCommitConflict(
            'team-official team binding conflicts',
          );
        }
        _db.execute(
          '''
          INSERT INTO team_official_team_bindings (
            match_id, team_official_id, team_id
          ) VALUES (?, ?, ?)
          ''',
          [
            binding.matchId,
            binding.teamOfficialId.value,
            binding.teamId.value,
          ],
        );
        _commitTransaction();
        return const TeamBindingCommitSuccess(idempotent: false);
      } catch (error) {
        _rollbackIfNeeded();
        return TeamBindingCommitConflict('team binding aborted: $error');
      }
    });
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

  /// Commits a generation-1 authority root when none exists for [root.matchId].
  Future<GenerationOneRootCommitResult> commitGenerationOneAuthorityRoot(
    GenerationOneAuthorityRoot root,
  ) {
    return _serialized(() async => _commitGenerationOneAuthorityRoot(root));
  }

  /// Reads the persisted generation-1 root, if any.
  Future<GenerationOneAuthorityRoot?> readGenerationOneAuthorityRoot(
    String matchId,
  ) {
    return _serialized(() async => _readGenerationOneAuthorityRoot(matchId));
  }

  /// Committed records for [matchId], including quarantined row ids when present.
  Future<CommittedMatchMemorySnapshot> readCommittedForMatchWithQuarantine(
    String matchId,
  ) {
    return _serialized(() async => _readCommittedSnapshotLocked(matchId));
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
      final admissionEarly = _captureIntentAdmissionBeforeInsert(
        matchId: request.matchId,
        originDeviceId: request.originDeviceId,
        authorityContext: request.authorityContext,
        payload: request.payload,
        failureRecordId: request.recordId,
      );
      if (admissionEarly != null) {
        return admissionEarly;
      }

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

    final admissionEarly = _captureIntentAdmissionBeforeInsert(
      matchId: record.matchId,
      originDeviceId: record.originDeviceId,
      authorityContext: record.authorityContext,
      payload: record.payload,
      failureRecordId: record.recordId,
    );
    if (admissionEarly != null) {
      return admissionEarly;
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

    _insertCaptureIntentAdmissionLocked(record);

    final abort = abortBeforeCommitForTest;
    if (abort != null) {
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
  Future<List<MatchRecord>> readCommittedForMatch(String matchId) async {
    final snapshot = await readCommittedForMatchWithQuarantine(matchId);
    if (snapshot.hasQuarantine) {
      throw CommittedRecordQuarantineException(
        matchId: matchId,
        quarantinedRecordIds: snapshot.quarantinedRecordIds,
        decodedRecordCount: snapshot.records.length,
      );
    }
    return snapshot.records;
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
    return _readCommittedSnapshotLocked(matchId).records;
  }

  CommittedMatchMemorySnapshot _readCommittedSnapshotLocked(String matchId) {
    final rows = _db.select(
      '''
      SELECT record_id, record_json FROM committed_match_records
      WHERE match_id = ?
      ORDER BY rowid
      ''',
      [matchId],
    );
    final records = <MatchRecord>[];
    final quarantined = <String>[];
    for (final row in rows) {
      final recordId = row.columnAt(0) as String;
      final jsonText = row.columnAt(1) as String;
      try {
        records.add(decodeMatchRecordFromStorage(jsonText));
      } on Object {
        quarantined.add(recordId);
      }
    }
    return CommittedMatchMemorySnapshot(
      records: records,
      quarantinedRecordIds: quarantined,
    );
  }

  GenerationOneRootCommitResult _commitGenerationOneAuthorityRoot(
    GenerationOneAuthorityRoot root,
  ) {
    if (root.generation != 1) {
      return const GenerationOneRootCommitFailure(
        reason: 'generation-1 root requires generation=1',
      );
    }
    _db.execute('BEGIN IMMEDIATE');
    try {
      final existing = _readGenerationOneAuthorityRootLocked(root.matchId);
      if (existing != null) {
        if (existing == root) {
          _commitTransaction();
          return const GenerationOneRootCommitSuccess(
            diagnostics:
                'idempotent-no-op; generation-1 root already committed',
          );
        }
        _db.execute('ROLLBACK');
        return const GenerationOneRootCommitFailure(
          reason:
              'generation-1 root conflict: match already has a different root',
        );
      }

      final hasRecords = _matchHasCommittedRecordsLocked(root.matchId);
      if (hasRecords) {
        _db.execute('ROLLBACK');
        return const GenerationOneRootCommitFailure(
          reason:
              'generation-1 root cannot be established after match records exist',
        );
      }

      _db.execute(
        '''
        INSERT INTO generation_one_authority_roots (
          match_id, principal_id, device_id, generation
        ) VALUES (?, ?, ?, ?)
        ''',
        [root.matchId, root.principalId, root.deviceId, root.generation],
      );
      _commitTransaction();
      return const GenerationOneRootCommitSuccess(
        diagnostics: 'generation-1 authority root committed',
      );
    } catch (error) {
      _rollbackIfNeeded();
      return GenerationOneRootCommitFailure(
        reason: 'generation-1 root commit aborted: $error',
      );
    }
  }

  GenerationOneAuthorityRoot? _readGenerationOneAuthorityRoot(String matchId) {
    return _readGenerationOneAuthorityRootLocked(matchId);
  }

  GenerationOneAuthorityRoot? _readGenerationOneAuthorityRootLocked(
    String matchId,
  ) {
    final rows = _db.select(
      '''
      SELECT principal_id, device_id, generation
      FROM generation_one_authority_roots
      WHERE match_id = ?
      ''',
      [matchId],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return GenerationOneAuthorityRoot(
      matchId: matchId,
      principalId: row.columnAt(0) as String,
      deviceId: row.columnAt(1) as String,
    );
  }

  bool _matchHasCommittedRecordsLocked(String matchId) {
    final rows = _db.select(
      'SELECT 1 FROM committed_match_records WHERE match_id = ? LIMIT 1',
      [matchId],
    );
    return rows.isNotEmpty;
  }

  DurableCommitResult? _captureIntentAdmissionBeforeInsert({
    required String matchId,
    required String originDeviceId,
    required AuthorityContext? authorityContext,
    required MatchRecordPayload payload,
    required String failureRecordId,
  }) {
    final intent = _authoritativeCaptureIntent(payload, authorityContext);
    if (intent == null) {
      return null;
    }

    final scope = authorityContext?.scope;
    if (scope is! MainRefereeScope) {
      _db.execute('ROLLBACK');
      return DurableCommitFailure(
        recordId: failureRecordId,
        reason:
            'capture-intent admission requires MAIN_REFEREE authority scope',
      );
    }

    final existing = _readCaptureIntentAdmissionLocked(
      matchId: matchId,
      authorityScopeWire: _mainRefereeScopeWire,
      captureIntentId: intent.captureIntentId,
    );
    if (existing == null) {
      final rejected = _rejectNewGoalAdmission(
        matchId: matchId,
        originDeviceId: originDeviceId,
        authorityContext: authorityContext,
        failureRecordId: failureRecordId,
      );
      if (rejected != null) {
        return rejected;
      }
      final bindingRejected = _rejectTeamOfficialYellowWithoutBinding(
        payload: payload,
        matchId: matchId,
        failureRecordId: failureRecordId,
      );
      if (bindingRejected != null) return bindingRejected;
      final substitutionRejected = _rejectSubstitutionWithoutTeamProof(
        payload: payload,
        matchId: matchId,
        failureRecordId: failureRecordId,
      );
      if (substitutionRejected != null) return substitutionRejected;
      return null;
    }

    if (_admissionMeaningMatches(existing, intent)) {
      _commitTransaction();
      return DurableCommitSuccess(
        committedRecordId: existing.committedRecordId,
        diagnostics: 'capture-intent-idempotent; already committed',
      );
    }

    _db.execute('ROLLBACK');
    return DurableCommitFailure(
      recordId: failureRecordId,
      reason: 'idempotency conflict: capture intent ${intent.captureIntentId} '
          'already bound to a different goal meaning',
    );
  }

  _AuthoritativeCaptureIntent? _authoritativeCaptureIntent(
    MatchRecordPayload payload,
    AuthorityContext? authorityContext,
  ) {
    final principalId = authorityContext?.principal?.principalId ?? '';
    final generation = authorityContext?.generation?.value ?? 0;
    if (payload is GoalPayload) {
      return _AuthoritativeCaptureIntent(
        captureIntentId: payload.captureIntentId,
        semanticTypeWire: V1SemanticTypeCode.goal.wireValue,
        authorityPrincipalId: principalId,
        authorityGeneration: generation,
        scoringTeamId: payload.scoringTeamId.value,
      );
    }
    if (payload is YellowCardPayload) {
      return _AuthoritativeCaptureIntent(
        captureIntentId: payload.captureIntentId,
        semanticTypeWire: V1SemanticTypeCode.yellowCard.wireValue,
        authorityPrincipalId: principalId,
        authorityGeneration: generation,
        participantId: payload.participantId.value,
        accountingScope: payload.accountingScope.wireValue,
        subjectKind: DisciplinarySubjectKind.participant.wireValue,
        subjectId: payload.participantId.value,
      );
    }
    if (payload is YellowCardPayloadV2) {
      final subject = payload.disciplinarySubject;
      return _AuthoritativeCaptureIntent(
        captureIntentId: payload.captureIntentId,
        semanticTypeWire: V1SemanticTypeCode.yellowCard.wireValue,
        authorityPrincipalId: principalId,
        authorityGeneration: generation,
        participantId: subject is ParticipantDisciplinarySubject
            ? subject.rawId
            : null,
        accountingScope: payload.accountingScope.wireValue,
        subjectKind: subject.kind.wireValue,
        subjectId: subject.rawId,
      );
    }
    if (payload is SendOffPayload) {
      final subject = payload.disciplinarySubject;
      return _AuthoritativeCaptureIntent(
        captureIntentId: payload.captureIntentId,
        semanticTypeWire: V1SemanticTypeCode.sendOff.wireValue,
        authorityPrincipalId: principalId,
        authorityGeneration: generation,
        participantId: subject is ParticipantDisciplinarySubject
            ? subject.rawId
            : null,
        accountingScope: payload.disciplinaryScope.wireValue,
        subjectKind: subject.kind.wireValue,
        subjectId: subject.rawId,
        pathway: payload.pathway.wireValue,
        firstCautionRecordId: payload.firstStandingCautionRecordId,
        secondCautionRecordId: payload.secondCautionRecordId,
      );
    }
    if (payload is SubstitutionPayload) {
      return _AuthoritativeCaptureIntent(
        captureIntentId: payload.captureIntentId,
        semanticTypeWire: V1SemanticTypeCode.substitution.wireValue,
        authorityPrincipalId: principalId,
        authorityGeneration: generation,
        outgoingParticipantId: payload.outgoingParticipantId.value,
        incomingParticipantId: payload.incomingParticipantId.value,
        substitutionTeamId: payload.teamId.value,
      );
    }
    if (payload is RefereeEnteredFieldPayload) {
      return _AuthoritativeCaptureIntent(
        captureIntentId: payload.captureIntentId,
        semanticTypeWire:
            V1SemanticTypeCode.refereeEnteredFieldForMatchStart.wireValue,
        authorityPrincipalId: principalId,
        authorityGeneration: generation,
      );
    }
    return null;
  }

  /// WAVE 1 admits a new Goal only under the generation-1 root.
  ///
  /// An already-bound capture intent is handled by the caller before this
  /// check, so a same-command retry still returns the existing outcome.
  DurableCommitResult? _rejectNewGoalAdmission({
    required String matchId,
    required String originDeviceId,
    required AuthorityContext? authorityContext,
    required String failureRecordId,
  }) {
    if (authorityContext?.generation?.value != 1) {
      _db.execute('ROLLBACK');
      return DurableCommitFailure(
        recordId: failureRecordId,
        reason: 'WAVE 1 Goal requires generation-1 capture authority',
      );
    }
    final root = _readGenerationOneAuthorityRoot(matchId);
    if (root == null) {
      _db.execute('ROLLBACK');
      return DurableCommitFailure(
        recordId: failureRecordId,
        reason: 'generation-1 authority root required before Goal admission',
      );
    }
    if (authorityContext?.principal?.principalId != root.principalId) {
      _db.execute('ROLLBACK');
      return DurableCommitFailure(
        recordId: failureRecordId,
        reason: 'Goal principal does not match generation-1 authority root',
      );
    }
    if (originDeviceId != root.deviceId) {
      _db.execute('ROLLBACK');
      return DurableCommitFailure(
        recordId: failureRecordId,
        reason: 'Goal origin device does not match generation-1 authority root',
      );
    }
    return null;
  }

  DurableCommitResult? _rejectSubstitutionWithoutTeamProof({
    required MatchRecordPayload payload,
    required String matchId,
    required String failureRecordId,
  }) {
    if (payload is! SubstitutionPayload) return null;
    final bindings = _readParticipantTeamBindings(matchId);
    final admission = evaluateSubstitutionAdmission(
      matchId: matchId,
      payload: payload,
      bindings: bindings,
    );
    if (admission is SubstitutionAdmitted) return null;
    _db.execute('ROLLBACK');
    return DurableCommitFailure(
      recordId: failureRecordId,
      reason: admission is SubstitutionRejected
          ? admission.reason
          : 'substitution rejected',
    );
  }

  List<MatchParticipantTeamBinding> _readParticipantTeamBindings(String matchId) {
    final rows = _db.select(
      '''
      SELECT participant_id, team_id FROM participant_team_bindings
      WHERE match_id = ?
      ''',
      [matchId],
    );
    return [
      for (final row in rows)
        MatchParticipantTeamBinding(
          matchId: matchId,
          participantId: MatchParticipantId(row.columnAt(0) as String),
          teamId: MatchTeamId(row.columnAt(1) as String),
        ),
    ];
  }

  void _insertCaptureIntentAdmissionLocked(MatchRecord record) {
    final intent = _authoritativeCaptureIntent(
      record.payload,
      record.authorityContext,
    );
    if (intent == null) {
      return;
    }
    final scope = record.authorityContext?.scope;
    if (scope is! MainRefereeScope) {
      throw StateError(
        'capture-intent admission requires MAIN_REFEREE authority scope',
      );
    }
    _db.execute(
      '''
      INSERT INTO capture_intent_admissions (
        match_id,
        authority_scope,
        capture_intent_id,
        committed_record_id,
        semantic_type_wire,
        authority_principal_id,
        authority_generation,
        scoring_team_id,
        participant_id,
        accounting_scope,
        subject_kind,
        subject_id,
        pathway,
        first_caution_record_id,
        second_caution_record_id,
        outgoing_participant_id,
        incoming_participant_id,
        substitution_team_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        record.matchId,
        _mainRefereeScopeWire,
        intent.captureIntentId,
        record.recordId,
        intent.semanticTypeWire,
        intent.authorityPrincipalId,
        intent.authorityGeneration,
        intent.scoringTeamId,
        intent.participantId,
        intent.accountingScope,
        intent.subjectKind,
        intent.subjectId,
        intent.pathway,
        intent.firstCautionRecordId,
        intent.secondCautionRecordId,
        intent.outgoingParticipantId,
        intent.incomingParticipantId,
        intent.substitutionTeamId,
      ],
    );
  }

  _StoredCaptureIntentAdmission? _readCaptureIntentAdmissionLocked({
    required String matchId,
    required String authorityScopeWire,
    required String captureIntentId,
  }) {
    final rows = _db.select(
      '''
      SELECT
        committed_record_id,
        semantic_type_wire,
        authority_principal_id,
        authority_generation,
        scoring_team_id,
        participant_id,
        accounting_scope,
        subject_kind,
        subject_id,
        pathway,
        first_caution_record_id,
        second_caution_record_id,
        outgoing_participant_id,
        incoming_participant_id,
        substitution_team_id
      FROM capture_intent_admissions
      WHERE match_id = ? AND authority_scope = ? AND capture_intent_id = ?
      ''',
      [matchId, authorityScopeWire, captureIntentId],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return _StoredCaptureIntentAdmission(
      committedRecordId: row.columnAt(0) as String,
      semanticTypeWire: row.columnAt(1) as String,
      authorityPrincipalId: row.columnAt(2) as String,
      authorityGeneration: row.columnAt(3) as int,
      scoringTeamId: row.columnAt(4) as String?,
      participantId: row.columnAt(5) as String?,
      accountingScope: row.columnAt(6) as String?,
      subjectKind: row.columnAt(7) as String?,
      subjectId: row.columnAt(8) as String?,
      pathway: row.columnAt(9) as String?,
      firstCautionRecordId: row.columnAt(10) as String?,
      secondCautionRecordId: row.columnAt(11) as String?,
      outgoingParticipantId: row.columnAt(12) as String?,
      incomingParticipantId: row.columnAt(13) as String?,
      substitutionTeamId: row.columnAt(14) as String?,
    );
  }

  bool _admissionMeaningMatches(
    _StoredCaptureIntentAdmission stored,
    _AuthoritativeCaptureIntent requested,
  ) {
    final storedSubject = _normalizedAdmissionSubject(
      semanticTypeWire: stored.semanticTypeWire,
      participantId: stored.participantId,
      subjectKind: stored.subjectKind,
      subjectId: stored.subjectId,
    );
    final requestedSubject = _normalizedAdmissionSubject(
      semanticTypeWire: requested.semanticTypeWire,
      participantId: requested.participantId,
      subjectKind: requested.subjectKind,
      subjectId: requested.subjectId,
    );
    return stored.semanticTypeWire == requested.semanticTypeWire &&
        stored.authorityPrincipalId == requested.authorityPrincipalId &&
        stored.authorityGeneration == requested.authorityGeneration &&
        stored.scoringTeamId == requested.scoringTeamId &&
        stored.accountingScope == requested.accountingScope &&
        storedSubject.kind == requestedSubject.kind &&
        storedSubject.id == requestedSubject.id &&
        stored.pathway == requested.pathway &&
        stored.firstCautionRecordId == requested.firstCautionRecordId &&
        stored.secondCautionRecordId == requested.secondCautionRecordId &&
        stored.outgoingParticipantId == requested.outgoingParticipantId &&
        stored.incomingParticipantId == requested.incomingParticipantId &&
        stored.substitutionTeamId == requested.substitutionTeamId;
  }

  ({String? kind, String? id}) _normalizedAdmissionSubject({
    required String semanticTypeWire,
    required String? participantId,
    required String? subjectKind,
    required String? subjectId,
  }) {
    if (subjectKind != null || subjectId != null) {
      return (kind: subjectKind, id: subjectId);
    }
    if (semanticTypeWire == V1SemanticTypeCode.yellowCard.wireValue &&
        participantId != null) {
      return (
        kind: DisciplinarySubjectKind.participant.wireValue,
        id: participantId,
      );
    }
    return (kind: null, id: null);
  }

  DurableCommitResult? _rejectTeamOfficialYellowWithoutBinding({
    required MatchRecordPayload payload,
    required String matchId,
    required String failureRecordId,
  }) {
    final DisciplinarySubjectRef? subject = switch (payload) {
      YellowCardPayloadV2() => payload.disciplinarySubject,
      SendOffPayload() => payload.disciplinarySubject,
      _ => null,
    };
    if (subject is! TeamOfficialDisciplinarySubject) return null;
    final rows = _db.select(
      '''
      SELECT team_id FROM team_official_team_bindings
      WHERE match_id = ? AND team_official_id = ?
      ''',
      [matchId, subject.teamOfficialId.value],
    );
    if (rows.length != 1) {
      _db.execute('ROLLBACK');
      return DurableCommitFailure(
        recordId: failureRecordId,
        reason: rows.isEmpty
            ? 'team-official team binding required'
            : 'team-official team binding is ambiguous',
      );
    }
    return null;
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
    final result = _queue.then((_) => action());
    _queue =
        result.then((_) {}, onError: (Object error, StackTrace stackTrace) {});
    return result;
  }

  Future<void> close() {
    return _serialized(() async {
      _db.close();
    });
  }

  /// Rows in [capture_intent_admissions] for tests and recovery checks.
  int captureIntentAdmissionCount({String? matchId}) {
    if (matchId == null) {
      final rows = _db.select('SELECT COUNT(*) FROM capture_intent_admissions');
      return rows.first.columnAt(0) as int;
    }
    final rows = _db.select(
      'SELECT COUNT(*) FROM capture_intent_admissions WHERE match_id = ?',
      [matchId],
    );
    return rows.first.columnAt(0) as int;
  }
}

final class _StoredCaptureIntentAdmission {
  const _StoredCaptureIntentAdmission({
    required this.committedRecordId,
    required this.semanticTypeWire,
    required this.authorityPrincipalId,
    required this.authorityGeneration,
    required this.scoringTeamId,
    required this.participantId,
    required this.accountingScope,
    required this.subjectKind,
    required this.subjectId,
    required this.pathway,
    required this.firstCautionRecordId,
    required this.secondCautionRecordId,
    required this.outgoingParticipantId,
    required this.incomingParticipantId,
    required this.substitutionTeamId,
  });

  final String committedRecordId;
  final String semanticTypeWire;
  final String authorityPrincipalId;
  final int authorityGeneration;
  final String? scoringTeamId;
  final String? participantId;
  final String? accountingScope;
  final String? subjectKind;
  final String? subjectId;
  final String? pathway;
  final String? firstCautionRecordId;
  final String? secondCautionRecordId;
  final String? outgoingParticipantId;
  final String? incomingParticipantId;
  final String? substitutionTeamId;
}

final class _AuthoritativeCaptureIntent {
  const _AuthoritativeCaptureIntent({
    required this.captureIntentId,
    required this.semanticTypeWire,
    required this.authorityPrincipalId,
    required this.authorityGeneration,
    this.scoringTeamId,
    this.participantId,
    this.accountingScope,
    this.subjectKind,
    this.subjectId,
    this.pathway,
    this.firstCautionRecordId,
    this.secondCautionRecordId,
    this.outgoingParticipantId,
    this.incomingParticipantId,
    this.substitutionTeamId,
  });

  final String captureIntentId;
  final String semanticTypeWire;
  final String authorityPrincipalId;
  final int authorityGeneration;
  final String? scoringTeamId;
  final String? participantId;
  final String? accountingScope;
  final String? subjectKind;
  final String? subjectId;
  final String? pathway;
  final String? firstCautionRecordId;
  final String? secondCautionRecordId;
  final String? outgoingParticipantId;
  final String? incomingParticipantId;
  final String? substitutionTeamId;
}

sealed class TeamBindingCommitResult {
  const TeamBindingCommitResult();
}

final class TeamBindingCommitSuccess extends TeamBindingCommitResult {
  const TeamBindingCommitSuccess({required this.idempotent});

  final bool idempotent;
}

final class TeamBindingCommitConflict extends TeamBindingCommitResult {
  const TeamBindingCommitConflict(this.reason);

  final String reason;
}
