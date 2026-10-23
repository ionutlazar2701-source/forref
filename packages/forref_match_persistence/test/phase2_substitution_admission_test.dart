import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('forref_phase2_sub_');
  });

  tearDown(() async {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<SqliteDurableMatchStore> open() async {
    final store = SqliteDurableMatchStore.open(File('${temp.path}/memory.sqlite'));
    expect(
      await store.commitGenerationOneAuthorityRoot(
        const GenerationOneAuthorityRoot(
          matchId: 'match-1',
          principalId: 'ref-1',
          deviceId: 'dev-a',
        ),
      ),
      isA<GenerationOneRootCommitSuccess>(),
    );
    return store;
  }

  Future<void> bind(
    SqliteDurableMatchStore store,
    String participantId,
    String teamId,
  ) async {
    expect(
      await store.commitParticipantTeamBinding(
        MatchParticipantTeamBinding(
          matchId: 'match-1',
          participantId: MatchParticipantId(participantId),
          teamId: MatchTeamId(teamId),
        ),
      ),
      isA<TeamBindingCommitSuccess>(),
    );
  }

  test('completed substitution commits without a competition profile', () async {
    final store = await open();
    await bind(store, 'out-1', 'team-alpha');
    await bind(store, 'in-1', 'team-alpha');
    expect(await store.commit(_sub()), isA<DurableCommitSuccess>());
    final stored = await store.getById('sub-1');
    final payload = stored!.payload as SubstitutionPayload;
    expect(payload.outgoingParticipantId, MatchParticipantId('out-1'));
    expect(payload.incomingParticipantId, MatchParticipantId('in-1'));
    expect(payload.competitionRulesContext, isNull);
    await store.close();
  });

  test('missing binding is not saved', () async {
    final store = await open();
    await bind(store, 'out-1', 'team-alpha');
    expect(await store.commit(_sub()), isA<DurableCommitFailure>());
    expect(await store.getById('sub-1'), isNull);
    await store.close();
  });

  test('cross-team substitution is not saved', () async {
    final store = await open();
    await bind(store, 'out-1', 'team-alpha');
    await bind(store, 'in-1', 'team-beta');
    final outcome = await store.commit(_sub());
    expect(outcome, isA<DurableCommitFailure>());
    expect((outcome as DurableCommitFailure).reason, contains('cross-team'));
    await store.close();
  });

  test('same intent retries and a different incoming participant conflicts', () async {
    final store = await open();
    await bind(store, 'out-1', 'team-alpha');
    await bind(store, 'in-1', 'team-alpha');
    await bind(store, 'in-2', 'team-alpha');
    expect(await store.commit(_sub()), isA<DurableCommitSuccess>());
    final retry = await store.commit(_sub(recordId: 'sub-2', sequence: 2));
    expect((retry as DurableCommitSuccess).committedRecordId, 'sub-1');
    final rebound = await store.commit(
      _sub(recordId: 'sub-3', sequence: 3, incoming: 'in-2'),
    );
    expect(rebound, isA<DurableCommitFailure>());
    expect(await store.readCommittedForMatch('match-1'), hasLength(1));
    await store.close();
  });

  test('a different outgoing participant conflicts', () async {
    final store = await open();
    await bind(store, 'out-1', 'team-alpha');
    await bind(store, 'out-2', 'team-alpha');
    await bind(store, 'in-1', 'team-alpha');
    expect(await store.commit(_sub()), isA<DurableCommitSuccess>());
    final rebound = await store.commit(
      _sub(recordId: 'sub-2', sequence: 2, outgoing: 'out-2'),
    );
    expect(rebound, isA<DurableCommitFailure>());
    await store.close();
  });

  test('generation other than 1 and failed D1 store nothing', () async {
    final store = await open();
    await bind(store, 'out-1', 'team-alpha');
    await bind(store, 'in-1', 'team-alpha');
    expect(await store.commit(_sub(generation: 2)), isA<DurableCommitFailure>());
    store.abortBeforeCommitForTest = () => throw StateError('abort');
    expect(await store.commit(_sub()), isA<DurableCommitFailure>());
    expect(await store.getById('sub-1'), isNull);
    expect(store.captureIntentAdmissionCount(matchId: 'match-1'), 0);
    await store.close();
  });

  test('a second team for one participant conflicts', () async {
    final store = await open();
    await bind(store, 'out-1', 'team-alpha');
    final wrong = await store.commitParticipantTeamBinding(
      MatchParticipantTeamBinding(
        matchId: 'match-1',
        participantId: MatchParticipantId('out-1'),
        teamId: MatchTeamId('team-beta'),
      ),
    );
    expect(wrong, isA<TeamBindingCommitConflict>());
    await store.close();
  });
}

MatchRecord _sub({
  String recordId = 'sub-1',
  int sequence = 1,
  String outgoing = 'out-1',
  String incoming = 'in-1',
  int generation = 1,
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: 'match-1',
    recordKind: RecordKind.humanDetermination,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 2, 12, sequence),
    originDeviceId: 'dev-a',
    originSequence: sequence,
    payload: SubstitutionPayload(
      outgoingParticipantId: MatchParticipantId(outgoing),
      incomingParticipantId: MatchParticipantId(incoming),
      teamId: MatchTeamId('team-alpha'),
      captureIntentId: 'intent-sub',
    ),
    integrity: const IntegrityMetadata(evidenceRefs: ['evidence-1']),
    authorityContext: AuthorityContext(
      scope: v1AuthorityScope,
      principal: const AuthorityPrincipal(principalId: 'ref-1'),
      generation: AuthorityGeneration(value: generation),
    ),
  );
}
