import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

void main() {
  const matchId = 'match-1';
  final teamA = MatchTeamId('team-alpha');
  final teamB = MatchTeamId('team-beta');
  final outId = MatchParticipantId('out-1');
  final inId = MatchParticipantId('in-1');
  final returning = MatchParticipantId('return-1');

  List<MatchParticipantTeamBinding> sameTeam() => [
        MatchParticipantTeamBinding(
          matchId: matchId,
          participantId: outId,
          teamId: teamA,
        ),
        MatchParticipantTeamBinding(
          matchId: matchId,
          participantId: inId,
          teamId: teamA,
        ),
        MatchParticipantTeamBinding(
          matchId: matchId,
          participantId: returning,
          teamId: teamA,
        ),
      ];

  SubstitutionPayload payload({
    MatchParticipantId? outgoing,
    MatchParticipantId? incoming,
    MatchTeamId? team,
  }) {
    return SubstitutionPayload(
      outgoingParticipantId: outgoing ?? outId,
      incomingParticipantId: incoming ?? inId,
      teamId: team ?? teamA,
      captureIntentId: 'intent-sub',
    );
  }

  MatchRecord substitution({
    required String recordId,
    required int originSequence,
    MatchParticipantId? outgoing,
    MatchParticipantId? incoming,
    String originDeviceId = 'dev-a',
  }) {
    return MatchRecord(
      recordId: recordId,
      matchId: matchId,
      recordKind: RecordKind.humanDetermination,
      schemaVersion: 1,
      recordedAt: DateTime.utc(2026, 10, 2, 12, originSequence),
      originDeviceId: originDeviceId,
      originSequence: originSequence,
      payload: SubstitutionPayload(
        outgoingParticipantId: outgoing ?? outId,
        incomingParticipantId: incoming ?? inId,
        teamId: teamA,
        captureIntentId: 'intent-$recordId',
      ),
      integrity: IntegrityMetadata(evidenceRefs: [recordId]),
      authorityContext: const AuthorityContext(
        scope: MainRefereeScope(),
        principal: AuthorityPrincipal(principalId: 'ref-1'),
        generation: AuthorityGeneration(value: 1),
      ),
    );
  }

  test('same identity is rejected before a competition profile exists', () {
    expect(
      () => SubstitutionPayload(
        outgoingParticipantId: outId,
        incomingParticipantId: outId,
        teamId: teamA,
        captureIntentId: 'intent-sub',
      ),
      throwsA(isA<AssertionError>()),
    );
    final admitted = evaluateSubstitutionAdmission(
      matchId: matchId,
      payload: payload(),
      bindings: sameTeam(),
    );
    expect(admitted, isA<SubstitutionAdmitted>());
  });

  test('cross-team and missing bindings are rejected', () {
    expect(
      evaluateSubstitutionAdmission(
        matchId: matchId,
        payload: payload(),
        bindings: [
          MatchParticipantTeamBinding(
            matchId: matchId,
            participantId: outId,
            teamId: teamA,
          ),
          MatchParticipantTeamBinding(
            matchId: matchId,
            participantId: inId,
            teamId: teamB,
          ),
        ],
      ),
      isA<SubstitutionRejected>(),
    );
    expect(
      evaluateSubstitutionAdmission(
        matchId: matchId,
        payload: payload(),
        bindings: [
          MatchParticipantTeamBinding(
            matchId: matchId,
            participantId: outId,
            teamId: teamA,
          ),
        ],
      ),
      isA<SubstitutionRejected>(),
    );
  });

  test('ambiguous binding is rejected', () {
    final assessment = assessParticipantTeamBinding(
      matchId: matchId,
      participantId: outId,
      bindings: [
        MatchParticipantTeamBinding(
          matchId: matchId,
          participantId: outId,
          teamId: teamA,
        ),
        MatchParticipantTeamBinding(
          matchId: matchId,
          participantId: outId,
          teamId: teamB,
        ),
      ],
    );
    expect(assessment, isA<AmbiguousParticipantTeamBinding>());
  });

  test('completed substitution projects OUT substituted and IN on field', () {
    final records = [substitution(recordId: 'sub-1', originSequence: 1)];
    final status = projectParticipantStatus(
      recordsById: {for (final item in records) item.recordId: item},
    ) as ProjectedParticipantStatus;
    expect(status.statusByParticipant[outId], ParticipantSituation.substituted);
    expect(status.statusByParticipant[inId], ParticipantSituation.onField);
    expect(outId, MatchParticipantId('out-1'));
  });

  test('a later entry restores on-field for the same id', () {
    final records = [
      substitution(
        recordId: 'sub-1',
        originSequence: 1,
        outgoing: outId,
        incoming: inId,
      ),
      substitution(
        recordId: 'sub-2',
        originSequence: 2,
        outgoing: inId,
        incoming: outId,
      ),
    ];
    final reversed = [records[1], records[0]];
    final first = projectParticipantStatus(
      recordsById: {for (final item in records) item.recordId: item},
    ) as ProjectedParticipantStatus;
    final second = projectParticipantStatus(
      recordsById: {for (final item in reversed) item.recordId: item},
    ) as ProjectedParticipantStatus;
    expect(first.statusByParticipant[outId], ParticipantSituation.onField);
    expect(first.statusByParticipant[inId], ParticipantSituation.substituted);
    expect(second.statusByParticipant, first.statusByParticipant);
  });

  test('two origins cannot order a status', () {
    final records = [
      substitution(recordId: 'sub-1', originSequence: 1),
      substitution(
        recordId: 'sub-2',
        originSequence: 1,
        originDeviceId: 'dev-b',
        outgoing: inId,
        incoming: returning,
      ),
    ];
    expect(
      projectParticipantStatus(
        recordsById: {for (final item in records) item.recordId: item},
      ),
      isA<ParticipantStatusUnavailable>(),
    );
  });

  test('superseding the substitution removes its status effect', () {
    final records = [
      substitution(recordId: 'sub-1', originSequence: 1),
      MatchRecord(
        recordId: 'void-sub',
        matchId: matchId,
        recordKind: RecordKind.legalSupersession,
        schemaVersion: 1,
        recordedAt: DateTime.utc(2026, 10, 2, 12, 2),
        originDeviceId: 'dev-a',
        originSequence: 2,
        payload: const LegalSupersessionPayload(),
        relationships: [LegalSupersessionTarget(targetRecordId: 'sub-1')],
        integrity: const IntegrityMetadata(evidenceRefs: ['void-sub']),
      ),
    ];
    final status = projectParticipantStatus(
      recordsById: {for (final item in records) item.recordId: item},
    ) as ProjectedParticipantStatus;
    expect(status.statusByParticipant, isEmpty);
    expect(records.where((item) => item.payload is SubstitutionPayload), hasLength(1));
  });

  test('a yellow stays on the same id after substitution projection', () {
    final yellow = MatchRecord(
      recordId: 'y-1',
      matchId: matchId,
      recordKind: RecordKind.humanDetermination,
      schemaVersion: 1,
      recordedAt: DateTime.utc(2026, 10, 2, 12, 1),
      originDeviceId: 'dev-a',
      originSequence: 1,
      payload: YellowCardPayload(
        participantId: outId,
        accountingScope: DisciplinaryAccountingScope.match,
        captureIntentId: 'intent-y',
        situationAtDetermination: ParticipantSituation.onField,
      ),
      integrity: const IntegrityMetadata(evidenceRefs: ['y-1']),
      authorityContext: const AuthorityContext(
        scope: MainRefereeScope(),
        principal: AuthorityPrincipal(principalId: 'ref-1'),
        generation: AuthorityGeneration(value: 1),
      ),
    );
    final records = [
      yellow,
      substitution(recordId: 'sub-1', originSequence: 2),
    ];
    final status = projectParticipantStatus(
      recordsById: {for (final item in records) item.recordId: item},
    ) as ProjectedParticipantStatus;
    expect(status.statusByParticipant[outId], ParticipantSituation.substituted);
    expect(
      (records.first.payload as YellowCardPayload).participantId,
      outId,
    );
  });
}
