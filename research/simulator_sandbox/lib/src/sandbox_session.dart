import 'dart:convert';
import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';

import 'event_journal.dart';
import 'sandbox_path.dart';

/// Desktop timing label. Not a watch performance certification.
const sandboxMeasurementLabel = 'DESKTOP SANDBOX MEASUREMENT';

const sandboxCommittedLabel = 'SANDBOX D1 COMMITTED';
const sandboxAlreadyCommittedLabel = 'SANDBOX D1 ALREADY COMMITTED';
const sandboxFailedLabel = 'SANDBOX COMMIT FAILED';

const sandboxMatchId = 'sim-sandbox-match';
const sandboxParticipantId = 'sim-p-14';
const sandboxPrincipalId = 'sim-ref';
const sandboxDeviceId = 'sim-device';

/// One isolated file-backed Match Memory plus an observer journal.
final class SandboxSession {
  SandboxSession._({
    required this.path,
    required this.store,
    required this.journal,
    required this.createdDatabase,
  });

  final SandboxDatabasePath path;
  final SqliteDurableMatchStore store;
  final EventJournal journal;
  final bool createdDatabase;
  String? journalFault;

  static Future<SandboxSession> open({
    required Directory simulatorRoot,
    required String sessionId,
    EventJournal? journal,
  }) async {
    final path = SandboxDatabasePath.resolve(
      simulatorRoot: simulatorRoot,
      sessionId: sessionId,
    );
    final existed = path.file.existsSync();
    path.ensureParent();
    final store = SqliteDurableMatchStore.open(path.file);
    if (!existed) {
      final root = await store.commitGenerationOneAuthorityRoot(
        const GenerationOneAuthorityRoot(
          matchId: sandboxMatchId,
          principalId: sandboxPrincipalId,
          deviceId: sandboxDeviceId,
        ),
      );
      if (root is! GenerationOneRootCommitSuccess) {
        await store.close();
        throw StateError('sandbox authority root was not committed');
      }
    }
    return SandboxSession._(
      path: path,
      store: store,
      journal: journal ?? EventJournal(),
      createdDatabase: !existed,
    );
  }

  Future<void> close() => store.close();

  Future<MatchRecord?> readBack(String recordId) => store.getById(recordId);

  Future<List<String>> rebuildProjection() async {
    final projection = await DeterministicMatchProjector(
      ProductionSemanticsResolver(),
    ).project(
      store,
      sandboxMatchId,
      const ProjectionContext(evaluatedAuthorityGeneration: 1),
    );
    return projection.committedRecordIds;
  }

  /// Makes the next store commit throw inside the durable transaction.
  void failNextCommit() {
    store.abortBeforeCommitForTest = () => throw StateError('sandbox commit abort');
  }

  Future<SandboxCaptureReport> commitYellow({
    required String captureIntentId,
    required String participantId,
  }) async {
    if (!captureIntentId.startsWith('sim-intent-')) {
      throw StateError('capture intent id must be synthetic');
    }
    if (!participantId.startsWith('sim-')) {
      throw StateError('participant id must be synthetic');
    }
    journalFault = null;
    final sizeBefore = path.file.existsSync() ? path.file.lengthSync() : 0;
    _note(
      JournalEventKind.intentReceived,
      'yellow $participantId intent $captureIntentId',
    );
    final meaning = YellowCaptureIntentMeaning(
      participantId: MatchParticipantId(participantId),
      accountingScope: DisciplinaryAccountingScope.match,
      authorityPrincipalId: sandboxPrincipalId,
      authorityGeneration: 1,
    );
    _note(
      JournalEventKind.commandFrozen,
      'yellow ${meaning.disciplinarySubject} ${meaning.accountingScope.name}',
    );
    final committed = await store.readCommittedForMatch(sandboxMatchId);
    final admission = evaluateYellowCaptureIntentAdmission(
      key: CaptureIntentKey(
        matchId: sandboxMatchId,
        authorityScope: v1AuthorityScope,
        captureIntentId: captureIntentId,
      ),
      requestedMeaning: meaning,
      committedForMatch: committed,
    );
    _note(JournalEventKind.captureAdmissionStarted, admission.runtimeType.toString());
    if (admission is YellowCaptureIntentConflict) {
      return _failed(
        captureIntentId: captureIntentId,
        reason: 'capture intent conflict ${admission.existingRecordId}',
        sizeBefore: sizeBefore,
      );
    }
    final recordId = admission is YellowCaptureIntentIdempotent
        ? admission.existingRecordId
        : 'sim-yellow-${_safe(captureIntentId)}';
    final sequence = committed.length + 1;
    final record = MatchRecord(
      recordId: recordId,
      matchId: sandboxMatchId,
      recordKind: RecordKind.humanDetermination,
      schemaVersion: 1,
      recordedAt: DateTime.utc(2026, 10, 20, 12, sequence),
      originDeviceId: sandboxDeviceId,
      originSequence: sequence,
      payload: YellowCardPayload(
        participantId: MatchParticipantId(participantId),
        accountingScope: DisciplinaryAccountingScope.match,
        captureIntentId: captureIntentId,
      ),
      integrity: const IntegrityMetadata(evidenceRefs: ['sim-evidence']),
      authorityContext: AuthorityContext(
        scope: v1AuthorityScope,
        principal: const AuthorityPrincipal(principalId: sandboxPrincipalId),
        generation: AuthorityGeneration(value: 1),
      ),
    );
    final encoded = utf8.encode(encodeMatchRecordJson(record));
    _note(JournalEventKind.commitRequested, record.recordId);
    final started = Stopwatch()..start();
    final DurableCommitResult result;
    try {
      result = await store.commit(record);
    } finally {
      store.abortBeforeCommitForTest = null;
    }
    final commitElapsed = started.elapsed;
    _note(
      JournalEventKind.commitReturned,
      '${result.runtimeType} ${result is DurableCommitSuccess ? result.committedRecordId : (result as DurableCommitFailure).reason}',
    );
    if (result is! DurableCommitSuccess) {
      final failure = result as DurableCommitFailure;
      return _failed(
        captureIntentId: captureIntentId,
        reason: failure.reason,
        sizeBefore: sizeBefore,
        commitElapsed: commitElapsed,
        encodedBytes: encoded.length,
      );
    }
    final readStarted = Stopwatch()..start();
    final stored = await store.getById(result.committedRecordId);
    final readElapsed = readStarted.elapsed;
    final readbackOk = stored != null &&
        stored.recordId == result.committedRecordId &&
        stored.payload is YellowCardPayload;
    _note(
      JournalEventKind.recordReadBack,
      readbackOk ? stored.recordId : 'missing',
    );
    final projectStarted = Stopwatch()..start();
    final projection = await DeterministicMatchProjector(
      ProductionSemanticsResolver(),
    ).project(
      store,
      sandboxMatchId,
      const ProjectionContext(evaluatedAuthorityGeneration: 1),
    );
    final projectElapsed = projectStarted.elapsed;
    final projected = projection.committedRecordIds.contains(result.committedRecordId);
    _note(
      JournalEventKind.projectionRebuilt,
      projected ? result.committedRecordId : 'record absent from projection',
    );
    final idempotent = result.diagnostics?.contains('idempotent') ?? false;
    final label = readbackOk && projected
        ? (idempotent ? sandboxAlreadyCommittedLabel : sandboxCommittedLabel)
        : sandboxFailedLabel;
    _note(JournalEventKind.presentationUpdated, label);
    final records = await store.readCommittedForMatch(sandboxMatchId);
    return SandboxCaptureReport(
      label: label,
      captureIntentId: captureIntentId,
      recordId: readbackOk ? result.committedRecordId : null,
      commitDiagnostics: result.diagnostics,
      idempotent: idempotent,
      encodedBytes: encoded.length,
      fileBytesBefore: sizeBefore,
      fileBytesAfter: path.file.lengthSync(),
      commitElapsed: commitElapsed,
      readbackElapsed: readElapsed,
      projectionElapsed: projectElapsed,
      recordCount: records.length,
      projectedRecordIds: projection.committedRecordIds,
      measurementLabel: sandboxMeasurementLabel,
      journalFault: journalFault,
    );
  }

  SandboxCaptureReport _failed({
    required String captureIntentId,
    required String reason,
    required int sizeBefore,
    Duration? commitElapsed,
    int? encodedBytes,
  }) {
    _note(JournalEventKind.presentationUpdated, sandboxFailedLabel);
    return SandboxCaptureReport(
      label: sandboxFailedLabel,
      captureIntentId: captureIntentId,
      recordId: null,
      commitDiagnostics: reason,
      idempotent: false,
      encodedBytes: encodedBytes ?? 0,
      fileBytesBefore: sizeBefore,
      fileBytesAfter: path.file.existsSync() ? path.file.lengthSync() : 0,
      commitElapsed: commitElapsed ?? Duration.zero,
      readbackElapsed: Duration.zero,
      projectionElapsed: Duration.zero,
      recordCount: 0,
      projectedRecordIds: const [],
      measurementLabel: sandboxMeasurementLabel,
      journalFault: journalFault,
    );
  }

  void _note(JournalEventKind kind, String detail) {
    try {
      journal.observe(kind, detail);
    } catch (error) {
      journalFault = error.toString();
    }
  }

  String _safe(String intent) {
    return intent.replaceAll(RegExp(r'[^a-z0-9-]'), '-');
  }
}

final class SandboxCaptureReport {
  const SandboxCaptureReport({
    required this.label,
    required this.captureIntentId,
    required this.recordId,
    required this.commitDiagnostics,
    required this.idempotent,
    required this.encodedBytes,
    required this.fileBytesBefore,
    required this.fileBytesAfter,
    required this.commitElapsed,
    required this.readbackElapsed,
    required this.projectionElapsed,
    required this.recordCount,
    required this.projectedRecordIds,
    required this.measurementLabel,
    required this.journalFault,
  });

  final String label;
  final String captureIntentId;
  final String? recordId;
  final String? commitDiagnostics;
  final bool idempotent;
  final int encodedBytes;
  final int fileBytesBefore;
  final int fileBytesAfter;
  final Duration commitElapsed;
  final Duration readbackElapsed;
  final Duration projectionElapsed;
  final int recordCount;
  final List<String> projectedRecordIds;
  final String measurementLabel;
  final String? journalFault;

  bool get sandboxD1Committed => label == sandboxCommittedLabel;
}
