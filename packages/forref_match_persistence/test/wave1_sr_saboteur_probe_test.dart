import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:test/test.dart';

/// Faithful WAVE 1-SR reproductions against the durable store.
/// Production behavior at 4e5fa663414b317f9bdfc05ccd7735bb07a71e90 fails them.
void main() {
  late Directory temp;
  final projector = DeterministicMatchProjector(ProductionSemanticsResolver());
  const matchId = 'match-1';
  const rootDevice = 'dev-root';
  const otherDevice = 'dev-other';
  const principalId = 'ref-1';
  final teamA = MatchTeamId('team-alpha');
  final teamB = MatchTeamId('team-beta');

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('wave1_sr_probe_');
  });

  tearDown(() async {
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  MatchRecord record({
    required String recordId,
    required RecordKind recordKind,
    required int originSequence,
    required MatchRecordPayload payload,
    String originDevice = rootDevice,
    int generation = 1,
  }) {
    return MatchRecord(
      recordId: recordId,
      matchId: matchId,
      recordKind: recordKind,
      schemaVersion: 1,
      recordedAt: DateTime.utc(2026, 10, 2, 12, originSequence),
      originDeviceId: originDevice,
      originSequence: originSequence,
      authorityContext: AuthorityContext(
        scope: const MainRefereeScope(),
        principal: const AuthorityPrincipal(principalId: principalId),
        activeCaptureDevice: ActiveCaptureDevice(deviceId: originDevice),
        generation: AuthorityGeneration(value: generation),
      ),
      payload: payload,
      integrity: const IntegrityMetadata(evidenceRefs: ['evidence-1']),
    );
  }

  ScoreProjection scoreOf(List<MatchRecord> records) {
    return projector
        .projectRecords(
          matchId: matchId,
          records: records,
          context: ProjectionContext(
            evaluatedAuthorityGeneration: 1,
            scoreCompletenessProof: ScoreCompletenessProof(
              matchAuthorityMode: MatchAuthorityMode.matchMemory,
              teamBindings: [
                MatchTeamBinding(matchId: matchId, teamId: teamA),
                MatchTeamBinding(matchId: matchId, teamId: teamB),
              ],
              generationOneRoot: const GenerationOneAuthorityRoot(
                matchId: matchId,
                principalId: principalId,
                deviceId: rootDevice,
              ),
            ),
          ),
        )
        .scoreProjection;
  }

  test('generation other than 1 cannot commit a Goal', () async {
    final store = SqliteDurableMatchStore.open(File('${temp.path}/gen.sqlite'));
    try {
      expect(
        await store.commitGenerationOneAuthorityRoot(
          const GenerationOneAuthorityRoot(
            matchId: matchId,
            principalId: principalId,
            deviceId: rootDevice,
          ),
        ),
        isA<GenerationOneRootCommitSuccess>(),
      );
      expect(
        await store.commit(
          record(
            recordId: 'started-1',
            recordKind: RecordKind.temporalFact,
            originSequence: 1,
            payload: TemporalTransitionPayload(
              semanticType: V1SemanticTypeCode.matchStarted,
            ),
          ),
        ),
        isA<DurableCommitSuccess>(),
      );
      final outcome = await store.commit(
        record(
          recordId: 'goal-gen2',
          recordKind: RecordKind.humanDetermination,
          originSequence: 2,
          generation: 2,
          payload: GoalPayload(
            scoringTeamId: teamA,
            captureIntentId: 'intent-gen2',
          ),
        ),
      );
      final records = await store.readCommittedForMatch(matchId);
      final score = scoreOf(records);
      expect(
        outcome,
        isA<DurableCommitFailure>(),
        reason:
            'goalIds=${records.where((item) => item.payload is GoalPayload).map((item) => item.recordId).toList()} '
            'score=${_describe(score)}',
      );
    } finally {
      await store.close();
    }
  });

  test('a stored sequence gap on a non-root origin does not yield KnownScore 0-0', () async {
    final store = SqliteDurableMatchStore.open(File('${temp.path}/gap.sqlite'));
    try {
      expect(
        await store.commitGenerationOneAuthorityRoot(
          const GenerationOneAuthorityRoot(
            matchId: matchId,
            principalId: principalId,
            deviceId: rootDevice,
          ),
        ),
        isA<GenerationOneRootCommitSuccess>(),
      );
      expect(
        await store.commit(
          record(
            recordId: 'started-1',
            recordKind: RecordKind.temporalFact,
            originSequence: 1,
            payload: TemporalTransitionPayload(
              semanticType: V1SemanticTypeCode.matchStarted,
            ),
          ),
        ),
        isA<DurableCommitSuccess>(),
      );
      expect(
        await store.commit(
          record(
            recordId: 'other-1',
            recordKind: RecordKind.temporalFact,
            originSequence: 1,
            originDevice: otherDevice,
            payload: TemporalTransitionPayload(
              semanticType: V1SemanticTypeCode.periodStarted,
              period: const PeriodIdentity(index: 1),
            ),
          ),
        ),
        isA<DurableCommitSuccess>(),
      );
      expect(
        await store.commit(
          record(
            recordId: 'other-3',
            recordKind: RecordKind.temporalFact,
            originSequence: 3,
            originDevice: otherDevice,
            payload: TemporalTransitionPayload(
              semanticType: V1SemanticTypeCode.periodEnded,
              period: const PeriodIdentity(index: 1),
            ),
          ),
        ),
        isA<DurableCommitSuccess>(),
      );
      final records = await store.readCommittedForMatch(matchId);
      final score = scoreOf(records);
      expect(score, isA<ScoreUnavailable>(), reason: _describe(score));
      expect(score, isNot(KnownScore({teamA: 0, teamB: 0})));
    } finally {
      await store.close();
    }
  });
}

String _describe(ScoreProjection score) {
  if (score is KnownScore) {
    final pairs = score.goalsByTeam.entries
        .map((entry) => '${entry.key.value}=${entry.value}')
        .join(',');
    return 'KnownScore($pairs)';
  }
  return score.runtimeType.toString();
}
