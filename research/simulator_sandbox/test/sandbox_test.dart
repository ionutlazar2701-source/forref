import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:simulator_sandbox/simulator_sandbox.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('forref-sim-root-');
  });

  tearDown(() async {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('ambiguous and in-memory paths are refused', () {
    expect(
      () => SandboxDatabasePath.resolve(
        simulatorRoot: Directory('relative'),
        sessionId: 'session01',
      ),
      throwsA(isA<SandboxPathRejected>()),
    );
    expect(
      () => SandboxDatabasePath.resolve(
        simulatorRoot: root,
        sessionId: '../escape1',
      ),
      throwsA(isA<SandboxPathRejected>()),
    );
    expect(
      () => SandboxDatabasePath.resolve(
        simulatorRoot: root,
        sessionId: ':memory:',
      ),
      throwsA(isA<SandboxPathRejected>()),
    );
    final path = SandboxDatabasePath.resolve(
      simulatorRoot: root,
      sessionId: 'session01',
    );
    expect(path.file.path, contains('forref-simulator'));
    expect(path.file.path, endsWith('match-memory.sqlite'));
    expect(path.file.path, isNot(contains(':memory:')));
  });

  test('a yellow commit is durable success only after readback', () async {
    final session = await SandboxSession.open(
      simulatorRoot: root,
      sessionId: 'session01',
    );
    final report = await session.commitYellow(
      captureIntentId: 'sim-intent-yellow-14',
      participantId: sandboxParticipantId,
    );
    expect(report.sandboxD1Committed, isTrue);
    expect(report.label, sandboxCommittedLabel);
    expect(report.recordId, isNotNull);
    final stored = await session.store.getById(report.recordId!);
    expect(stored, isNotNull);
    expect(stored!.payload, isA<YellowCardPayload>());
    expect(report.projectedRecordIds, contains(report.recordId));
    expect(report.measurementLabel, sandboxMeasurementLabel);
    expect(report.fileBytesAfter, greaterThan(0));
    expect(report.encodedBytes, greaterThan(0));
    expect(session.journal.entries.map((entry) => entry.kind), [
      JournalEventKind.intentReceived,
      JournalEventKind.commandFrozen,
      JournalEventKind.captureAdmissionStarted,
      JournalEventKind.commitRequested,
      JournalEventKind.commitReturned,
      JournalEventKind.recordReadBack,
      JournalEventKind.projectionRebuilt,
      JournalEventKind.presentationUpdated,
    ]);
    await session.close();
  });

  test('a duplicate capture intent does not add a record', () async {
    final session = await SandboxSession.open(
      simulatorRoot: root,
      sessionId: 'session02',
    );
    final first = await session.commitYellow(
      captureIntentId: 'sim-intent-yellow-14',
      participantId: sandboxParticipantId,
    );
    final count = first.recordCount;
    final second = await session.commitYellow(
      captureIntentId: 'sim-intent-yellow-14',
      participantId: sandboxParticipantId,
    );
    expect(second.idempotent, isTrue);
    expect(second.label, sandboxAlreadyCommittedLabel);
    expect(second.recordId, first.recordId);
    expect(second.recordCount, count);
    expect(second.sandboxD1Committed, isFalse);
    await session.close();
  });

  test('an abort before commit is not sandbox D1', () async {
    final session = await SandboxSession.open(
      simulatorRoot: root,
      sessionId: 'session03',
    );
    session.failNextCommit();
    final report = await session.commitYellow(
      captureIntentId: 'sim-intent-abort',
      participantId: sandboxParticipantId,
    );
    expect(report.label, sandboxFailedLabel);
    expect(report.sandboxD1Committed, isFalse);
    expect(report.recordId, isNull);
    final records = await session.store.readCommittedForMatch(sandboxMatchId);
    expect(
      records.where((record) => record.payload is YellowCardPayload),
      isEmpty,
    );
    await session.close();
  });

  test('journal failure and deletion do not change match memory', () async {
    final session = await SandboxSession.open(
      simulatorRoot: root,
      sessionId: 'session04',
    );
    session.journal.failOn = JournalEventKind.commitReturned;
    final report = await session.commitYellow(
      captureIntentId: 'sim-intent-journal',
      participantId: sandboxParticipantId,
    );
    expect(report.journalFault, contains('journal failed'));
    expect(report.sandboxD1Committed, isTrue);
    final recordId = report.recordId!;
    session.journal.clear();
    expect(session.journal.entries, isEmpty);
    final stored = await session.store.getById(recordId);
    expect(stored, isNotNull);
    await session.close();
  });

  test('reopen rebuilds the projection from the same file', () async {
    final first = await SandboxSession.open(
      simulatorRoot: root,
      sessionId: 'session05',
    );
    final report = await first.commitYellow(
      captureIntentId: 'sim-intent-reopen',
      participantId: sandboxParticipantId,
    );
    final path = first.path.file.path;
    await first.close();
    final second = await SandboxSession.open(
      simulatorRoot: root,
      sessionId: 'session05',
    );
    expect(second.createdDatabase, isFalse);
    expect(second.path.file.path, path);
    expect(second.journal.entries, isEmpty);
    final stored = await second.store.getById(report.recordId!);
    expect(stored, isNotNull);
    final projection = await DeterministicMatchProjector(
      ProductionSemanticsResolver(),
    ).project(
      second.store,
      sandboxMatchId,
      const ProjectionContext(evaluatedAuthorityGeneration: 1),
    );
    expect(projection.committedRecordIds, contains(report.recordId));
    await second.close();
  });

  test('the phone app does not import the sandbox', () {
    final phone = Directory('../../apps/referee_phone');
    final hits = <String>[];
    for (final entity in phone.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.readAsStringSync().contains('simulator_sandbox')) {
        hits.add(entity.path);
      }
    }
    expect(hits, isEmpty);
    final core = File('../../packages/forref_match_core/pubspec.yaml').readAsStringSync();
    final persistence = File(
      '../../packages/forref_match_persistence/pubspec.yaml',
    ).readAsStringSync();
    expect(core, isNot(contains('simulator_sandbox')));
    expect(persistence, isNot(contains('simulator_sandbox')));
  });
}
