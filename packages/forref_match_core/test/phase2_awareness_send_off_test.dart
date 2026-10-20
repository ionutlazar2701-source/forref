import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

void main() {
  const matchId = 'match-1';
  final player = ParticipantDisciplinarySubject(MatchParticipantId('person-a'));

  ScoreCompletenessProof proof() => ScoreCompletenessProof(
        matchAuthorityMode: MatchAuthorityMode.matchMemory,
        teamBindings: [
          MatchTeamBinding(matchId: matchId, teamId: MatchTeamId('team-alpha')),
          MatchTeamBinding(matchId: matchId, teamId: MatchTeamId('team-beta')),
        ],
        generationOneRoot: const GenerationOneAuthorityRoot(
          matchId: matchId,
          principalId: 'ref-1',
          deviceId: 'dev-a',
        ),
      );

  MatchRecord record({
    required String recordId,
    required int originSequence,
    required RecordKind recordKind,
    required MatchRecordPayload payload,
    List<RecordRelationship> relationships = const [],
  }) {
    return MatchRecord(
      recordId: recordId,
      matchId: matchId,
      recordKind: recordKind,
      schemaVersion: 1,
      recordedAt: DateTime.utc(2026, 10, 2, 12, originSequence),
      originDeviceId: 'dev-a',
      originSequence: originSequence,
      authorityContext: const AuthorityContext(
        scope: MainRefereeScope(),
        principal: AuthorityPrincipal(principalId: 'ref-1'),
        generation: AuthorityGeneration(value: 1),
      ),
      payload: payload,
      integrity: IntegrityMetadata(evidenceRefs: [recordId]),
      relationships: relationships,
    );
  }

  MatchRecord yellow(String recordId, int sequence, String intent) {
    return record(
      recordId: recordId,
      originSequence: sequence,
      recordKind: RecordKind.humanDetermination,
      payload: YellowCardPayload(
        participantId: player.participantId,
        accountingScope: DisciplinaryAccountingScope.match,
        captureIntentId: intent,
      ),
    );
  }

  CautionAwareness awareness(List<MatchRecord> records) {
    final before = [
      for (final item in records) item.recordId,
    ];
    final answer = assessDisciplinaryAwareness(
      matchId: matchId,
      subject: player,
      accountingScope: DisciplinaryAccountingScope.match,
      records: records,
      proof: proof(),
      authorityConflict: false,
      correctionConflict: false,
      missingDependency: false,
      unsupportedSemanticRecordIds: const [],
      missingDependencyTargets: const [],
    );
    expect([for (final item in records) item.recordId], before);
    return answer;
  }

  List<MatchRecord> twoYellows() => [
        record(
          recordId: 'started-1',
          originSequence: 1,
          recordKind: RecordKind.temporalFact,
          payload: TemporalTransitionPayload(
            semanticType: V1SemanticTypeCode.matchStarted,
          ),
        ),
        yellow('y1', 2, 'intent-1'),
        yellow('y2', 3, 'intent-2'),
      ];

  test('two standing yellows do not commit SEND_OFF', () {
    final records = twoYellows();
    final answer = awareness(records) as KnownStandingCaution;
    expect(answer.standingCount, 2);
    expect(answer.secondCautionSituation, isTrue);
    expect(answer.activeCautionSurface, isTrue);
    expect(records.where((item) => item.payload is SendOffPayload), isEmpty);
  });

  test('explicit SEND_OFF keeps yellow history and leaves the active surface', () {
    final records = [
      ...twoYellows(),
      record(
        recordId: 'so-1',
        originSequence: 4,
        recordKind: RecordKind.humanDetermination,
        relationships: [
          const CausalDependency(targetRecordId: 'y1'),
          const CausalDependency(targetRecordId: 'y2'),
        ],
        payload: SendOffPayload(
          disciplinarySubject: player,
          disciplinaryScope: DisciplinaryAccountingScope.match,
          pathway: SendOffPathway.secondCaution,
          captureIntentId: 'intent-send',
          firstStandingCautionRecordId: 'y1',
          secondCautionRecordId: 'y2',
        ),
      ),
    ];
    final reversed = records.reversed.toList();
    final answer = awareness(records) as KnownStandingCaution;
    final permuted = awareness(reversed) as KnownStandingCaution;
    expect(answer.historicalYellowRecordIds, ['y1', 'y2']);
    expect(answer.standingYellowRecordIds, ['y1', 'y2']);
    expect(answer.activeCautionSurface, isFalse);
    expect(permuted.activeCautionSurface, isFalse);
    expect(permuted.historicalYellowRecordIds, answer.historicalYellowRecordIds);
    expect(records.where((item) => item.payload is SendOffPayload), hasLength(1));
  });

  test('superseding SEND_OFF restores active membership', () {
    final records = [
      ...twoYellows(),
      record(
        recordId: 'so-1',
        originSequence: 4,
        recordKind: RecordKind.humanDetermination,
        payload: SendOffPayload(
          disciplinarySubject: player,
          disciplinaryScope: DisciplinaryAccountingScope.match,
          pathway: SendOffPathway.direct,
          captureIntentId: 'intent-send',
        ),
      ),
      record(
        recordId: 'void-so',
        originSequence: 5,
        recordKind: RecordKind.legalSupersession,
        payload: const LegalSupersessionPayload(),
        relationships: [LegalSupersessionTarget(targetRecordId: 'so-1')],
      ),
    ];
    final answer = awareness(records) as KnownStandingCaution;
    expect(answer.activeCautionSurface, isTrue);
    expect(answer.historicalYellowRecordIds, ['y1', 'y2']);
    expect(records.where((item) => item.payload is SendOffPayload), hasLength(1));
  });

  test('a missing second-caution dependency is unavailable', () {
    final records = [
      ...twoYellows(),
      record(
        recordId: 'so-1',
        originSequence: 4,
        recordKind: RecordKind.humanDetermination,
        relationships: [
          const CausalDependency(targetRecordId: 'y1'),
          const CausalDependency(targetRecordId: 'missing-y'),
        ],
        payload: SendOffPayload(
          disciplinarySubject: player,
          disciplinaryScope: DisciplinaryAccountingScope.match,
          pathway: SendOffPathway.secondCaution,
          captureIntentId: 'intent-send',
          firstStandingCautionRecordId: 'y1',
          secondCautionRecordId: 'missing-y',
        ),
      ),
    ];
    expect(awareness(records), isA<CautionAwarenessUnavailable>());
  });
}
