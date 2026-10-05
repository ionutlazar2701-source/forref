import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:sqlite3/sqlite3.dart';

import '../fixtures/match_record_fixtures.dart';
import '../stats.dart';

/// D1 authoritative commit path benchmarks.
final class D1CommitBenchmark {
  D1CommitBenchmark({
    this.warmUp = 10,
    this.samples = 100,
  });

  final int warmUp;
  final int samples;

  Future<Map<String, Object?>> run(Directory tempRoot) async {
    final file = File('${tempRoot.path}/d1_commit.sqlite');
    final store = SqliteDurableMatchStore.open(file);
    final builder = AuthoritativeRecordBuilder(
      identityGenerator: _SequentialIdentityGenerator(startAt: 0),
    );
    final context = CaptureContext(
      matchId: MatchRecordFixtures.matchId,
      originDeviceId: MatchRecordFixtures.originDeviceId,
      authorityScope: v1AuthorityScope,
      authorityPrincipalId: 'ref-bench',
      authorityGeneration: MatchRecordFixtures.authorityGeneration,
      schemaVersion: 1,
      activeCaptureDeviceId: MatchRecordFixtures.originDeviceId,
      projectionAuthorityGeneration: MatchRecordFixtures.authorityGeneration,
    );

    // Seed one record so sequence allocation is non-trivial.
    await store.commitAtNextOriginSequence(
      MatchRecordFixtures.commitRequest(recordId: 'seed-0'),
    );

    final construction = benchmarkVoid(
      warmUp: warmUp,
      samples: samples,
      action: () {
        builder.build(
          context: context,
          recordKind: RecordKind.temporalFact,
          payload: TemporalTransitionPayload(
            semanticType: V1SemanticTypeCode.periodStarted,
            period: const PeriodIdentity(index: 1),
          ),
          integrity: const IntegrityMetadata(evidenceRefs: ['evidence-1']),
          recordId: 'bench-construct-${DateTime.now().microsecondsSinceEpoch}',
        );
      },
    );

    final encodingRecord = MatchRecordFixtures.representativeProductionRecord();
    final encoding = benchmarkVoid(
      warmUp: warmUp,
      samples: samples,
      action: () {
        encodeMatchRecordJson(encodingRecord);
      },
    );

    final sequenceAllocation = benchmarkVoid(
      warmUp: warmUp,
      samples: samples,
      action: () {
        final db = sqlite3.open(file.path);
        db.select(
          '''
          SELECT COALESCE(MAX(origin_sequence), 0) + 1 AS next_sequence
          FROM committed_match_records
          WHERE match_id = ? AND origin_device_id = ?
          ''',
          [MatchRecordFixtures.matchId, MatchRecordFixtures.originDeviceId],
        );
        db.close();
      },
    );

    var commitCounter = 0;
    final endToEnd = await benchmarkAsync(
      warmUp: warmUp,
      samples: samples,
      action: () async {
        commitCounter++;
        final outcome = await store.commitAtNextOriginSequence(
          MatchRecordFixtures.commitRequest(
            recordId: 'bench-e2e-$commitCounter',
          ),
        );
        if (outcome is! DurableCommitSuccess) {
          throw StateError('Expected DurableCommitSuccess: $outcome');
        }
      },
    );

    // Approximate sqlite transaction phase: end-to-end minus encoding (measured separately).
    final sqliteTransactionApprox = LatencyStats(
      endToEnd.samplesMicros
          .map((total) => (total - encoding.p50).clamp(0, total))
          .toList(),
    );

    await store.close();

    return {
      'warmUpCount': warmUp,
      'sampleCount': samples,
      'databasePath': file.path,
      'durabilityPreserved': true,
      'pragmaNote': 'Store PRAGMAs unchanged (journal_mode=DELETE, synchronous=FULL)',
      'recordConstruction': construction.toJson(),
      'sequenceAllocation': sequenceAllocation.toJson(),
      'encoding': encoding.toJson(),
      'sqliteTransactionApproxMinusMedianEncoding': sqliteTransactionApprox.toJson(),
      'endToEndCommitAtNextOriginSequence': endToEnd.toJson(),
      'phaseNote':
          'sqliteTransactionApprox subtracts encoding p50 from each end-to-end sample; COMMIT/D1 boundary is inside endToEnd',
    };
  }
}

final class _SequentialIdentityGenerator implements RecordIdentityGenerator {
  _SequentialIdentityGenerator({required this.startAt});

  int startAt;

  @override
  String newRecordId() => 'bench-id-${++startAt}';
}
