import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:test/test.dart';

const _matchId = 'match-hardening';
const _ordinaryRules = CompetitionRulesContext(
  rulesetId: 'ifab',
  disciplinarySystem: DisciplinarySystem.ordinaryIfab,
);
const _pensRules = CompetitionRulesContext(
  rulesetId: 'ifab-pens',
  disciplinarySystem: DisciplinarySystem.ordinaryIfab,
  penaltyShootOutAfterMatchEnd: true,
);

void main() {
  group('terminal referee leave', () {
    test('yellow commit stays rejected after terminal leave', () async {
      final temp = await Directory.systemTemp.createTemp('yc_terminal_leave_');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });
      final store = SqliteDurableMatchStore.open(File('${temp.path}/memory.sqlite'));
      addTearDown(store.close);
      final committer = YellowCardCommitter(
        originCommit: store,
        memory: store,
        recordBuilder: AuthoritativeRecordBuilder(
          identityGenerator: _SequentialIds(),
        ),
      );
      await _ready(store);
      final builder = AuthoritativeRecordBuilder(
        identityGenerator: _SequentialIds(start: 2),
      );
      for (final transition in [
        _transition(10, 'start', V1SemanticTypeCode.matchStarted),
        _transition(11, 'end', V1SemanticTypeCode.matchEnded),
        _transition(12, 'leave', V1SemanticTypeCode.refereeLeftFieldAfterMatch),
        _transition(13, 'enter-2', V1SemanticTypeCode.refereeEnteredFieldForMatchStart),
      ]) {
        final result = await store.commitAtNextOriginSequence(
          builder.build(
            context: _context(),
            recordKind: RecordKind.temporalFact,
            payload: transition.payload,
            integrity: const IntegrityMetadata(),
          ),
        );
        expect(result, isA<DurableCommitSuccess>());
      }
      final result = await committer.commitYellowCard(
        CommitYellowCardCommand(
          context: _context(),
          participantRef: _homePlayer,
          participantStatusAtDetermination:
              ParticipantStatusAtDetermination.onFieldPlayer,
          disciplinaryAccountingScope: DisciplinaryAccountingScope.match,
          captureIntentId: 'intent-after-leave',
        ),
      );
      expect(result, isA<YellowCardCommitRejected>());
      expect(
        (result as YellowCardCommitRejected).failure,
        YellowCardCommitFailure.cardAuthorityClosedOrNotOpen,
      );
    });

    test('later erroneous enter does not reopen card authority', () {
      final projection = DisciplinaryAuthorityProjection.derive(
        records: [
          _transition(1, 'enter-1', V1SemanticTypeCode.refereeEnteredFieldForMatchStart),
          _transition(2, 'start', V1SemanticTypeCode.matchStarted),
          _transition(3, 'end', V1SemanticTypeCode.matchEnded),
          _transition(4, 'leave', V1SemanticTypeCode.refereeLeftFieldAfterMatch),
          _transition(5, 'enter-2', V1SemanticTypeCode.refereeEnteredFieldForMatchStart),
        ],
      );
      expect(projection.refereeEnteredFieldCommitted, isTrue);
      expect(projection.refereeLeftFieldCommitted, isTrue);
      expect(projection.cardDisplayAuthorityOpen, isFalse);
    });
  });

  group('invalid capture intent', () {
    late Directory temp;
    late SqliteDurableMatchStore store;
    late YellowCardCommitter committer;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('yc_invalid_intent_');
      store = SqliteDurableMatchStore.open(File('${temp.path}/memory.sqlite'));
      committer = YellowCardCommitter(
        originCommit: store,
        memory: store,
        recordBuilder: AuthoritativeRecordBuilder(
          identityGenerator: _SequentialIds(),
        ),
      );
    });

    tearDown(() async {
      await store.close();
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    test('empty captureIntentId returns typed rejection', () async {
      await _ready(store);
      final result = await committer.commitYellowCard(
        CommitYellowCardCommand(
          context: _context(),
          participantRef: _homePlayer,
          participantStatusAtDetermination:
              ParticipantStatusAtDetermination.onFieldPlayer,
          disciplinaryAccountingScope: DisciplinaryAccountingScope.match,
          captureIntentId: '   ',
        ),
      );
      expect(result, isA<YellowCardCommitRejected>());
      expect(
        (result as YellowCardCommitRejected).failure,
        YellowCardCommitFailure.invalidCaptureIntent,
      );
      expect(result.ackEligible, isFalse);
    });
  });

  group('post-D1 getById recovery', () {
    test('retry after recovery does not allocate a second yellow card', () async {
      final temp = await Directory.systemTemp.createTemp('yc_post_d1_retry_');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });
      final inner = SqliteDurableMatchStore.open(File('${temp.path}/memory.sqlite'));
      addTearDown(inner.close);
      final memory = _MissOnceGetByIdMemory(inner);
      final ids = _SequentialIds();
      final committer = YellowCardCommitter(
        originCommit: inner,
        memory: memory,
        recordBuilder: AuthoritativeRecordBuilder(
          identityGenerator: ids,
        ),
      );
      await _ready(inner, ids);
      const intentId = 'intent-recover-retry';
      final command = CommitYellowCardCommand(
        context: _context(),
        participantRef: _homePlayer,
        participantStatusAtDetermination:
            ParticipantStatusAtDetermination.onFieldPlayer,
        disciplinaryAccountingScope: DisciplinaryAccountingScope.match,
        captureIntentId: intentId,
      );
      final first = await committer.commitYellowCard(command);
      expect(first, isA<YellowCardSaved>());
      final second = await committer.commitYellowCard(command);
      expect(second, isA<YellowCardSaved>());
      expect((second as YellowCardSaved).recoveredExisting, isTrue);
      final records = await inner.readCommittedForMatch(_matchId);
      expect(records.where((r) => r.payload is YellowCardPayload), hasLength(1));
    });

    test('recovers committed yellow via captureIntent when getById misses', () async {
      final temp = await Directory.systemTemp.createTemp('yc_post_d1_');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });
      final inner = SqliteDurableMatchStore.open(File('${temp.path}/memory.sqlite'));
      addTearDown(inner.close);
      final memory = _MissOnceGetByIdMemory(inner);
      final ids = _SequentialIds();
      final committer = YellowCardCommitter(
        originCommit: inner,
        memory: memory,
        recordBuilder: AuthoritativeRecordBuilder(
          identityGenerator: ids,
        ),
      );
      await _ready(inner, ids);
      final result = await committer.commitYellowCard(
        CommitYellowCardCommand(
          context: _context(),
          participantRef: _homePlayer,
          participantStatusAtDetermination:
              ParticipantStatusAtDetermination.onFieldPlayer,
          disciplinaryAccountingScope: DisciplinaryAccountingScope.match,
          captureIntentId: 'intent-recover',
        ),
      );
      expect(result, isA<YellowCardSaved>());
      expect(result.ackEligible, isTrue);
      final records = await inner.readCommittedForMatch(_matchId);
      expect(records.where((r) => r.payload is YellowCardPayload), hasLength(1));
    });
  });

  group('MATCH vs SHOOTOUT prior regression', () {
    final homeSeven = _participant('mpid-home-7');

    test('A: MATCH YC + MATCH scope → prior EXISTS', () {
      final projection = _project([
        _registered(1, homeSeven),
        _transition(2, 'enter', V1SemanticTypeCode.refereeEnteredFieldForMatchStart),
        _yellow(3, 'yc-match', homeSeven, scope: DisciplinaryAccountingScope.match),
      ]);
      final prior = projection.priorCautionStateFor(
        participantId: homeSeven.matchParticipantId,
        accountingScope: DisciplinaryAccountingScope.match,
      );
      expect(prior.state, PriorCautionState.standing);
      expect(prior.standingCautionCount, 1);
    });

    test('B: MATCH YC + SHOOTOUT scope + no shootout YC → SHOOTOUT prior NONE', () {
      final records = [
        _registered(1, homeSeven),
        _transition(2, 'enter', V1SemanticTypeCode.refereeEnteredFieldForMatchStart),
        _transition(3, 'start', V1SemanticTypeCode.matchStarted),
        _transition(4, 'end', V1SemanticTypeCode.matchEnded),
        _yellow(5, 'yc-match', homeSeven, scope: DisciplinaryAccountingScope.match),
      ];
      final projection = DisciplinaryMatchProjection.derive(
        records: records,
        evaluatedAuthorityGeneration: 1,
        competitionRules: _pensRules,
      );
      expect(projection.disciplinaryAccountingScope,
          DisciplinaryAccountingScope.shootout);
      final matchPrior = projection.priorCautionStateFor(
        participantId: homeSeven.matchParticipantId,
        accountingScope: DisciplinaryAccountingScope.match,
      );
      final shootoutPrior = projection.priorCautionStateFor(
        participantId: homeSeven.matchParticipantId,
        accountingScope: DisciplinaryAccountingScope.shootout,
      );
      expect(matchPrior.state, PriorCautionState.standing);
      expect(shootoutPrior.state, PriorCautionState.none);
    });

    test('C: SHOOTOUT YC + SHOOTOUT scope → prior EXISTS', () {
      final projection = _project([
        _registered(1, homeSeven),
        _transition(2, 'enter', V1SemanticTypeCode.refereeEnteredFieldForMatchStart),
        _yellow(
          3,
          'yc-shootout',
          homeSeven,
          scope: DisciplinaryAccountingScope.shootout,
        ),
      ], rules: _pensRules);
      final prior = projection.priorCautionStateFor(
        participantId: homeSeven.matchParticipantId,
        accountingScope: DisciplinaryAccountingScope.shootout,
      );
      expect(prior.state, PriorCautionState.standing);
    });

    test('D: SHOOTOUT YC does not alter MATCH standing count', () {
      final projection = _project([
        _registered(1, homeSeven),
        _transition(2, 'enter', V1SemanticTypeCode.refereeEnteredFieldForMatchStart),
        _yellow(3, 'yc-match', homeSeven, scope: DisciplinaryAccountingScope.match),
        _yellow(4, 'yc-shootout', homeSeven, scope: DisciplinaryAccountingScope.shootout),
      ]);
      final matchPrior = projection.priorCautionStateFor(
        participantId: homeSeven.matchParticipantId,
        accountingScope: DisciplinaryAccountingScope.match,
      );
      final shootoutPrior = projection.priorCautionStateFor(
        participantId: homeSeven.matchParticipantId,
        accountingScope: DisciplinaryAccountingScope.shootout,
      );
      expect(matchPrior.standingCautionCount, 1);
      expect(shootoutPrior.standingCautionCount, 1);
    });
  });
}

final _homePlayer = ParticipantRef(
  matchParticipantId: MatchParticipantId('mpid-home-7'),
  teamSide: ParticipantTeamSide.home,
  binding: const RosterLinkedBinding(rosterParticipantId: 'home-7'),
);

Future<void> _ready(MatchMemory store, [_SequentialIds? ids]) async {
  final builder = AuthoritativeRecordBuilder(
    identityGenerator: ids ?? _SequentialIds(),
  );
  Future<void> append(RecordKind kind, MatchRecordPayload payload) async {
    final result = await (store as AuthoritativeOriginCommitPort)
        .commitAtNextOriginSequence(
      builder.build(
        context: _context(),
        recordKind: kind,
        payload: payload,
        integrity: const IntegrityMetadata(),
      ),
    );
    expect(result, isA<DurableCommitSuccess>());
  }

  await append(
    RecordKind.temporalFact,
    TemporalTransitionPayload(
      semanticType: V1SemanticTypeCode.refereeEnteredFieldForMatchStart,
    ),
  );
  await append(
    RecordKind.action,
    ParticipantRegisteredPayload(
      matchParticipantId: _homePlayer.matchParticipantId,
      teamSide: _homePlayer.teamSide,
      binding: _homePlayer.binding,
    ),
  );
}

CaptureContext _context() {
  return CaptureContext(
    matchId: _matchId,
    originDeviceId: 'device-a',
    authorityScope: const MainRefereeScope(),
    authorityPrincipalId: 'ref-main',
    authorityGeneration: 1,
    projectionAuthorityGeneration: 1,
    activeCaptureDeviceId: 'device-a',
    domainContractVersion: const DomainContractVersion('domain-clock-v1'),
    competitionRulesContext: _ordinaryRules,
  );
}

DisciplinaryMatchProjection _project(
  List<MatchRecord> records, {
  CompetitionRulesContext rules = _ordinaryRules,
}) {
  return DisciplinaryMatchProjection.derive(
    records: records,
    evaluatedAuthorityGeneration: 1,
    competitionRules: rules,
  );
}

ParticipantRef _participant(String id) => ParticipantRef(
      matchParticipantId: MatchParticipantId(id),
      teamSide: ParticipantTeamSide.home,
      binding: RosterLinkedBinding(rosterParticipantId: id),
    );

MatchRecord _registered(int sequence, ParticipantRef participant) => _record(
      sequence,
      'register-${participant.matchParticipantId.value}',
      RecordKind.action,
      ParticipantRegisteredPayload(
        matchParticipantId: participant.matchParticipantId,
        teamSide: participant.teamSide,
        binding: participant.binding,
      ),
    );

MatchRecord _yellow(
  int sequence,
  String recordId,
  ParticipantRef participant, {
  DisciplinaryAccountingScope scope = DisciplinaryAccountingScope.match,
}) =>
    _record(
      sequence,
      recordId,
      RecordKind.humanDetermination,
      YellowCardPayload(
        participantRef: participant,
        participantStatusAtDetermination:
            ParticipantStatusAtDetermination.onFieldPlayer,
        disciplinaryAccountingScope: scope,
        captureIntentId: 'intent-$recordId',
        competitionRulesContext: _ordinaryRules,
      ),
    );

MatchRecord _transition(int sequence, String recordId, V1SemanticTypeCode type) =>
    _record(
      sequence,
      recordId,
      RecordKind.temporalFact,
      TemporalTransitionPayload(semanticType: type),
    );

const _authority = AuthorityContext(
  scope: MainRefereeScope(),
  principal: AuthorityPrincipal(principalId: 'ref-main'),
  activeCaptureDevice: ActiveCaptureDevice(deviceId: 'device-a'),
  generation: AuthorityGeneration(value: 1),
);

MatchRecord _record(
  int sequence,
  String recordId,
  RecordKind recordKind,
  MatchRecordPayload payload,
) =>
    MatchRecord(
      recordId: recordId,
      matchId: _matchId,
      recordKind: recordKind,
      schemaVersion: 1,
      recordedAt: DateTime.utc(2026, 10, 6, 12, 0, sequence),
      originDeviceId: 'device-a',
      originSequence: sequence,
      payload: payload,
      integrity: const IntegrityMetadata(),
      authorityContext: _authority,
    );

final class _SequentialIds implements RecordIdentityGenerator {
  _SequentialIds({this.start = 0});

  final int start;
  var _next = 0;

  @override
  String newRecordId() {
    _next += 1;
    return 'record-${start + _next}';
  }
}

final class _MissOnceGetByIdMemory implements MatchMemory {
  _MissOnceGetByIdMemory(this._inner);

  final SqliteDurableMatchStore _inner;
  var _missNext = true;

  @override
  Future<MatchRecord?> getById(String recordId) async {
    if (_missNext) {
      _missNext = false;
      return null;
    }
    return _inner.getById(recordId);
  }

  @override
  Future<List<MatchRecord>> readCommittedForMatch(String matchId) =>
      _inner.readCommittedForMatch(matchId);
}
