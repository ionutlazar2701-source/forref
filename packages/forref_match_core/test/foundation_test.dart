import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

void main() {
  group('MatchRecord immutability', () {
    test('fields and relationship list are fixed at construction', () {
      final record = _sampleRecord(
        recordId: 'rec-1',
        relationships: [CausalDependency(targetRecordId: 'rec-0')],
      );

      expect(record.recordId, 'rec-1');
      expect(record.relationships, hasLength(1));
      expect(record.relationships.first, isA<CausalDependency>());

      expect(
        () => (record.relationships as List).add(
          RelatesTo(targetRecordId: 'rec-x'),
        ),
        throwsUnsupportedError,
      );
    });

    test('structured payload map is unmodifiable', () {
      final payload = StructuredPayload({'teamId': 'home'});
      expect(
        () => payload.fields['teamId'] = 'away',
        throwsUnsupportedError,
      );
    });
  });

  group('stable identity', () {
    test('recordId is assigned independently from recordedAt', () {
      final recordedAt = DateTime.utc(2026, 10, 2, 12, 30);
      const recordId = '7b7d6f7a-5a9d-4c4e-9c1f-2c7a7e0b1234';

      final record = _sampleRecord(
        recordId: recordId,
        recordedAt: recordedAt,
      );

      expect(record.recordId, recordId);
      expect(record.recordedAt, recordedAt);
      expect(record.recordId, isNot(contains(recordedAt.toIso8601String())));
    });

    test('matchId and recordId are separate stable identities', () {
      final record = _sampleRecord(recordId: 'rec-1', matchId: 'match-1');
      expect(record.recordId, 'rec-1');
      expect(record.matchId, 'match-1');
      expect(record.recordId, isNot(equals(record.matchId)));
    });
  });

  group('authority generation', () {
    test('generation is explicit on authority context', () {
      const generation = AuthorityGeneration(value: 3);
      const ctx = AuthorityContext(
        scope: v1AuthorityScope,
        principal: AuthorityPrincipal(principalId: 'ref-1'),
        activeCaptureDevice: ActiveCaptureDevice(deviceId: 'phone-a'),
        generation: generation,
      );

      expect(ctx.scope, isA<MainRefereeScope>());
      expect(ctx.generation!.value, 3);
      expect(ctx.activeCaptureDevice!.deviceId, 'phone-a');
    });

    test('V1 usable authority scope is MAIN_REFEREE only', () {
      expect(v1AuthorityScope, isA<MainRefereeScope>());
      expect(identical(v1AuthorityScope, const MainRefereeScope()), isTrue);

      final libSources = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final file in libSources) {
        expect(file.readAsStringSync(), isNot(contains('NamedAuthorityScope')));
        expect(file.readAsStringSync(), isNot(contains('ASSISTANT')));
      }
    });
  });

  group('integrity metadata', () {
    test('no required signature or hash algorithm fields', () {
      const metadata = IntegrityMetadata();
      expect(metadata.evidenceRefs, isEmpty);

      // Foundation boundary only — no algorithm/digest/signature API.
      expect(IntegrityMetadata.new, returnsNormally);
    });
  });

  group('DurableCommitPort contract', () {
    test('commit accepts one immutable record', () async {
      final record = _sampleRecord(recordId: 'rec-commit');
      final port = ReferenceTestOnlyCommitPort();

      final outcome = await port.commit(record);

      expect(port.lastRecord, same(record));
      expect(outcome, isA<DurableCommitFailure>());
    });

    test('reference implementation cannot return adapter D1 success', () async {
      final port = ReferenceTestOnlyCommitPort();
      final outcome = await port.commit(_sampleRecord(recordId: 'rec-x'));

      expect(outcome, isNot(isA<DurableCommitSuccess>()));
      expect(outcome, isA<DurableCommitFailure>());
      expect(
        (outcome as DurableCommitFailure).reason,
        contains('cannot satisfy D1'),
      );
    });
  });

  group('correction and supersession via relationships', () {
    test('correction is a new record linked to the prior record', () {
      const originalId = 'goal-1';
      final correction = MatchRecord(
        recordId: 'corr-1',
        matchId: 'match-1',
        recordKind: RecordKind.correction,
        schemaVersion: 1,
        recordedAt: DateTime.utc(2026, 10, 2, 12, 5),
        originDeviceId: 'dev-1',
        originSequence: 2,
        payload: StructuredPayload({'reason': 'wrong team'}),
        integrity: _integrity,
        relationships: [CorrectionTarget(targetRecordId: originalId)],
      );

      expect(correction.recordKind, RecordKind.correction);
      expect(correction.relationships.single, isA<CorrectionTarget>());
      expect(
        (correction.relationships.single as CorrectionTarget).targetRecordId,
        originalId,
      );
    });

    test('legal supersession links forward without mutating the prior record',
        () {
      const priorId = 'determination-1';
      final supersession = MatchRecord(
        recordId: 'super-1',
        matchId: 'match-1',
        recordKind: RecordKind.legalSupersession,
        schemaVersion: 1,
        recordedAt: DateTime.utc(2026, 10, 2, 12, 10),
        originDeviceId: 'dev-1',
        originSequence: 3,
        payload: StructuredPayload({'basis': 'VAR'}),
        integrity: _integrity,
        relationships: [LegalSupersessionTarget(targetRecordId: priorId)],
      );

      expect(supersession.recordKind, RecordKind.legalSupersession);
      expect(supersession.relationships.single, isA<LegalSupersessionTarget>());
    });
  });

  group('relationship typing', () {
    test('RelatesTo is distinct from CausalDependency in the type system', () {
      const target = 'rec-a';
      const causal = CausalDependency(targetRecordId: target);
      const relates = RelatesTo(targetRecordId: target);

      expect(causal, isA<RecordRelationship>());
      expect(relates, isA<RecordRelationship>());
      expect(causal.runtimeType, isNot(equals(relates.runtimeType)));
      expect(causal, isNot(isA<RelatesTo>()));
      expect(relates, isNot(isA<CausalDependency>()));
    });
  });

  group('MatchProjector contract', () {
    test('projector consumes MatchMemory, not mutable current state', () async {
      final memory = ReferenceOnlyMatchMemory()
        ..appendRecord(
          _sampleRecord(recordId: 'rec-1', matchId: 'm-1', originSequence: 1),
        )
        ..appendRecord(
          _sampleRecord(recordId: 'rec-2', matchId: 'm-1', originSequence: 2),
        );
      const projector = _CountingProjector();

      final projection = await projector.project(memory, 'm-1');

      expect(projection.matchId, 'm-1');
      expect(projection.committedRecordCount, 2);
    });
  });

  group('dependency guard', () {
    test('pubspec excludes Flutter, Firebase, and legacy match_core', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, isNot(contains('match_core:')));
      expect(pubspec, isNot(contains('flutter:')));
      expect(pubspec, isNot(contains('firebase')));
    });

    test('library sources do not import forbidden packages', () {
      final libDir = Directory('lib');
      final files = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final file in files) {
        final content = file.readAsStringSync();
        expect(content, isNot(contains("import 'package:match_core/")));
        expect(content, isNot(contains("import 'package:flutter/")));
        expect(content, isNot(contains("import 'package:firebase_")));
      }
    });
  });
}

const _integrity = IntegrityMetadata();

MatchRecord _sampleRecord({
  required String recordId,
  String matchId = 'match-1',
  DateTime? recordedAt,
  int originSequence = 1,
  List<RecordRelationship> relationships = const [],
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: matchId,
    recordKind: RecordKind.occurrence,
    schemaVersion: 1,
    recordedAt: recordedAt ?? DateTime.utc(2026, 10, 2, 12),
    originDeviceId: 'dev-1',
    originSequence: originSequence,
    payload: StructuredPayload(const {'kind': 'sample'}),
    integrity: _integrity,
    relationships: relationships,
  );
}

/// Reference/test [DurableCommitPort] only. Must never return [DurableCommitSuccess].
final class ReferenceTestOnlyCommitPort implements DurableCommitPort {
  MatchRecord? lastRecord;

  @override
  Future<DurableCommitResult> commit(MatchRecord record) async {
    lastRecord = record;
    return DurableCommitFailure(
      recordId: record.recordId,
      reason: 'Reference/test only: volatile memory cannot satisfy D1',
    );
  }
}

final class _RecordCountProjection implements MatchProjection {
  const _RecordCountProjection({
    required this.matchId,
    required this.committedRecordCount,
  });

  @override
  final String matchId;
  final int committedRecordCount;
}

final class _CountingProjector
    implements MatchProjector<_RecordCountProjection> {
  const _CountingProjector();

  @override
  Future<_RecordCountProjection> project(
    MatchMemory memory,
    String matchId,
  ) async {
    final records = await memory.readCommittedForMatch(matchId);
    return _RecordCountProjection(
      matchId: matchId,
      committedRecordCount: records.length,
    );
  }
}
