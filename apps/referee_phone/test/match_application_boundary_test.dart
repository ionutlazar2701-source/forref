import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:test/test.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/match_application/match_application_boundary.dart';
import 'package:referee_phone/match_application/match_commit_port.dart';
import 'package:referee_phone/match_application/match_projection_read_port.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('referee_phone_boundary_');
  });

  tearDown(() async {
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  group('MatchApplicationBoundary', () {
    test('commit sends exactly one record to the durable store', () async {
      final composition = await MatchApplicationComposition.open(
        storageRoot: temp,
      );
      addTearDown(composition.close);

      final record = _sampleRecord(recordId: 'rec-1');
      final outcome = await composition.boundary.commit(record);

      expect(outcome, isA<DurableCommitSuccess>());
      final stored = await composition.boundary.durableStore.readCommittedForMatch(
        'match-1',
      );
      expect(stored, hasLength(1));
      expect(stored.single.recordId, 'rec-1');
    });

    test('DurableCommitFailure is propagated as failure', () async {
      final composition = await MatchApplicationComposition.open(
        storageRoot: temp,
      );
      addTearDown(composition.close);

      final first = _sampleRecord(recordId: 'rec-1', payload: {'v': 1});
      final conflict = _sampleRecord(recordId: 'rec-1', payload: {'v': 2});

      expect(await composition.boundary.commit(first), isA<DurableCommitSuccess>());
      final outcome = await composition.boundary.commit(conflict);

      expect(outcome, isA<DurableCommitFailure>());
      expect(outcome, isNot(isA<DurableCommitSuccess>()));
    });

    test('projection read is rebuilt through production projector', () async {
      final composition = await MatchApplicationComposition.open(
        storageRoot: temp,
      );
      addTearDown(composition.close);

      final record = _typedRecord(
        recordId: 'start-1',
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.matchStarted,
        ),
      );
      expect(await composition.boundary.commit(record), isA<DurableCommitSuccess>());

      final projection = await composition.boundary.project(
        'match-1',
        evaluatedAuthorityGeneration: 1,
      );

      expect(projection.matchId, 'match-1');
      expect(projection.trustFor(ProjectionFacet.temporal), ProjectionTrust.trusted);
      expect(projection.trustFor(ProjectionFacet.score), ProjectionTrust.untrusted);
    });

    test('close reopen yields equivalent projection', () async {
      final databaseFile = File('${temp.path}/forref_match_memory/match_memory.sqlite');
      final record = _typedRecord(
        recordId: 'start-1',
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.periodStarted,
          period: const PeriodIdentity(index: 1),
        ),
      );

      final firstComposition = await MatchApplicationComposition.open(
        storageRoot: temp,
      );
      expect(await firstComposition.boundary.commit(record), isA<DurableCommitSuccess>());
      final before = await firstComposition.boundary.project(
        'match-1',
        evaluatedAuthorityGeneration: 1,
      );
      await firstComposition.close();

      final reopened = MatchApplicationBoundary(
        store: SqliteDurableMatchStore.open(databaseFile),
      );
      addTearDown(reopened.close);
      final after = await reopened.project(
        'match-1',
        evaluatedAuthorityGeneration: 1,
      );

      expect(after, equals(before));
    });

    test('boundary API uses new-core contracts only', () {
      expect(MatchCommitPort, isNotNull);
      expect(MatchProjectionReadPort, isNotNull);

      final commitSource = File(
        'lib/match_application/match_commit_port.dart',
      ).readAsStringSync();
      final projectionSource = File(
        'lib/match_application/match_projection_read_port.dart',
      ).readAsStringSync();
      final boundarySource = File(
        'lib/match_application/match_application_boundary.dart',
      ).readAsStringSync();

      for (final source in [commitSource, projectionSource, boundarySource]) {
        expect(source, isNot(contains('package:match_core/')));
        expect(source, isNot(contains('MatchSession')));
        expect(source, isNot(contains('upsertMatch')));
        expect(source, isNot(contains('LocalMatchDatabase')));
        expect(source, isNot(contains('MatchState')));
        expect(source, isNot(contains('MatchEvent')));
      }
    });

    test('composition root keeps storage separate from legacy Drift path', () async {
      final composition = await MatchApplicationComposition.open(
        storageRoot: temp,
      );
      addTearDown(composition.close);

      expect(composition.databaseFile.path, contains('forref_match_memory'));
      expect(composition.databaseFile.path, isNot(contains('local_match')));
    });
  });

  group('Dual-write safety', () {
    test('feature pages do not reference the new application boundary', () {
      final featureFiles = Directory('lib/features')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      for (final file in featureFiles) {
        final text = file.readAsStringSync();
        expect(text, isNot(contains('MatchApplicationBoundary')));
        expect(text, isNot(contains('MatchApplicationComposition')));
        expect(text, isNot(contains('MatchCommitPort')));
      }
    });

    test('match session remains legacy-only writer path', () {
      final sessionSource = File('lib/match/match_session.dart').readAsStringSync();
      expect(sessionSource, isNot(contains('MatchApplicationBoundary')));
      expect(sessionSource, isNot(contains('forref_match_core')));
      expect(sessionSource, contains('upsertMatch'));
    });
  });
}

MatchRecord _sampleRecord({
  required String recordId,
  Map<String, Object?> payload = const {'kind': 'sample'},
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: 'match-1',
    recordKind: RecordKind.action,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 2, 12),
    originDeviceId: 'dev-a',
    originSequence: 1,
    payload: StructuredPayload(payload),
    integrity: const IntegrityMetadata(),
  );
}

MatchRecord _typedRecord({
  required String recordId,
  required TemporalTransitionPayload payload,
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: 'match-1',
    recordKind: RecordKind.temporalFact,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 2, 12),
    originDeviceId: 'dev-a',
    originSequence: 1,
    payload: payload,
    integrity: const IntegrityMetadata(),
  );
}
