import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:test/test.dart';

void main() {
  final resolver = ProductionSemanticsResolver();
  final projector = DeterministicMatchProjector(ProductionSemanticsResolver());

  final participantId = MatchParticipantId('mpid-yellow-1');
  final participantRef = ParticipantRef(
    matchParticipantId: participantId,
    teamSide: ParticipantTeamSide.home,
    binding: const RosterLinkedBinding(rosterParticipantId: 'home-7'),
  );

  group('YELLOW_CARD semantic identity', () {
    test('YELLOW_CARD resolves only with RecordKind.humanDetermination', () {
      final contribution = resolver.resolve(
        _yellowCard(recordId: 'yc-1', originSequence: 1),
      );
      expect(contribution.status, SemanticSupportStatus.supported);
      expect(
        contribution.supportedFacets,
        [
          ProjectionFacet.disciplinaryState,
          ProjectionFacet.identity,
          ProjectionFacet.disciplinaryAccountingScope,
        ],
      );
      expect(
        V1SemanticContract.byCode[V1SemanticTypeCode.yellowCard]!
            .requiredRecordKind,
        RecordKind.humanDetermination,
      );
    });

    test('RecordKind.action with YELLOW_CARD is unsupported', () {
      final contribution = resolver.resolve(
        _yellowCard(
          recordId: 'yc-bad-kind',
          recordKind: RecordKind.action,
        ),
      );
      expect(contribution.status, SemanticSupportStatus.unsupported);
    });

    test('generic HUMAN_DETERMINATION without typed Yellow Card is unsupported',
        () {
      final contribution = resolver.resolve(
        _record(
          recordId: 'hd-generic',
          recordKind: RecordKind.humanDetermination,
          payload: StructuredPayload({}),
        ),
      );
      expect(contribution.status, SemanticSupportStatus.unsupported);

      final wireOnly = resolver.resolve(
        _record(
          recordId: 'hd-wire-only',
          recordKind: RecordKind.humanDetermination,
          payload: StructuredPayload({
            ProductionPayloadContract.semanticType: 'YELLOW_CARD',
          }),
        ),
      );
      expect(wireOnly.status, SemanticSupportStatus.unsupported);
    });

    test('canonical meaning documents administered caution', () {
      expect(
        YellowCardSemantic.canonicalMeaning,
        contains('authoritatively administered a caution'),
      );
      expect(YellowCardSemantic.canonicalMeaning, isNot(contains('decision')));
      expect(YellowCardSemantic.canonicalMeaning, isNot(contains('pending')));
    });

    test('no pending-caution semantic is introduced', () {
      expect(V1SemanticTypeCodeWire.parseWire('PENDING_CAUTION'), isNull);
      expect(V1SemanticTypeCodeWire.parseWire('DECISION_TO_CAUTION'), isNull);
      expect(V1SemanticTypeCodeWire.parseWire('CAUTION_INTENT'), isNull);
    });

    test('no RED_CARD semantic is introduced', () {
      expect(V1SemanticTypeCodeWire.parseWire('RED_CARD'), isNull);
    });
  });

  group('YellowCardPayload participant identity', () {
    test('stable MatchParticipantId is required in typed participant ref', () {
      final payload = YellowCardPayload(
        participantRef: participantRef,
        participantStatusAtDetermination:
            ParticipantStatusAtDetermination.onFieldPlayer,
        disciplinaryAccountingScope: DisciplinaryAccountingScope.match,
        captureIntentId: 'intent-yc-1',
      );
      expect(payload.participantRef.matchParticipantId, participantId);
    });

    test('team-scoped shirt number is not treated as canonical identity', () {
      expect(
        () => ParticipantRefWire.decode({
          'teamSide': 'HOME',
          'binding': {
            'kind': 'TEAM_SCOPED_NUMBER',
            'shirtNumber': 8,
          },
        }),
        throwsFormatException,
      );
    });

    test('status-at-determination round-trips independently from identity',
        () async {
      final record = _yellowCard(
        recordId: 'yc-status',
        status: ParticipantStatusAtDetermination.substitute,
      );
      final roundTripped = await _persistRoundTrip(record);
      final payload = roundTripped.payload as YellowCardPayload;
      expect(payload.participantRef.matchParticipantId, participantId);
      expect(
        payload.participantStatusAtDetermination,
        ParticipantStatusAtDetermination.substitute,
      );
    });

    test('same participant ID can appear with different statuses', () {
      final onField = _yellowCard(
        recordId: 'yc-on-field',
        originSequence: 1,
        status: ParticipantStatusAtDetermination.onFieldPlayer,
        captureIntentId: 'intent-on-field',
      );
      final substitute = _yellowCard(
        recordId: 'yc-sub',
        originSequence: 2,
        status: ParticipantStatusAtDetermination.substitute,
        captureIntentId: 'intent-sub',
      );
      final first = onField.payload as YellowCardPayload;
      final second = substitute.payload as YellowCardPayload;
      expect(first.participantRef.matchParticipantId,
          second.participantRef.matchParticipantId);
      expect(first.participantStatusAtDetermination,
          isNot(second.participantStatusAtDetermination));
    });
  });

  group('YellowCardPayload disciplinary accounting scope', () {
    test('MATCH accounting scope round-trips', () async {
      final record = _yellowCard(
        recordId: 'yc-match',
        scope: DisciplinaryAccountingScope.match,
      );
      final loaded = await _persistRoundTrip(record);
      expect(
        (loaded.payload as YellowCardPayload).disciplinaryAccountingScope,
        DisciplinaryAccountingScope.match,
      );
    });

    test('SHOOTOUT accounting scope remains distinct', () async {
      final record = _yellowCard(
        recordId: 'yc-shootout',
        scope: DisciplinaryAccountingScope.shootout,
      );
      final loaded = await _persistRoundTrip(record);
      expect(
        (loaded.payload as YellowCardPayload).disciplinaryAccountingScope,
        DisciplinaryAccountingScope.shootout,
      );
      expect(
        DisciplinaryAccountingScope.shootout,
        isNot(DisciplinaryAccountingScope.match),
      );
    });

    test('UNRESOLVED does not produce trusted ordinary standing-effect semantics',
        () {
      final contribution = resolver.resolve(
        _yellowCard(
          recordId: 'yc-unresolved',
          scope: DisciplinaryAccountingScope.unresolved,
        ),
      );
      expect(contribution.isSupported, isTrue);
      expect(contribution.missingRequiredRelationship, isTrue);

      final projection = projector.projectRecords(
        matchId: 'match-1',
        records: [
          _yellowCard(
            recordId: 'yc-unresolved',
            scope: DisciplinaryAccountingScope.unresolved,
          ),
        ],
        context: ProjectionContext(
          evaluatedAuthorityGeneration: 1,
          trackedFacets: [
            ProjectionFacet.disciplinaryState,
            ProjectionFacet.disciplinaryAccountingScope,
          ],
        ),
      );
      expect(
        projection.trustFor(ProjectionFacet.disciplinaryState),
        ProjectionTrust.incomplete,
      );
    });
  });

  group('YellowCardPayload team officials and reason', () {
    test('team official payload is valid', () {
      final contribution = resolver.resolve(
        _yellowCard(
          recordId: 'yc-official',
          participantRef: ParticipantRef(
            matchParticipantId: MatchParticipantId('mpid-official'),
            teamSide: ParticipantTeamSide.away,
            binding: IdentifiedOfficialBinding(displayName: 'Assistant coach'),
          ),
          status: ParticipantStatusAtDetermination.teamOfficial,
        ),
      );
      expect(contribution.isSupported, isTrue);
    });

    test('senior-coach-present role slot payload is valid', () async {
      final record = _yellowCard(
        recordId: 'yc-coach-slot',
        participantRef: ParticipantRef(
          matchParticipantId: MatchParticipantId('mpid-coach-slot'),
          teamSide: ParticipantTeamSide.home,
          binding: SeniorCoachPresentBinding(),
        ),
        status: ParticipantStatusAtDetermination.seniorCoachPresent,
      );
      final loaded = await _persistRoundTrip(record);
      final payload = loaded.payload as YellowCardPayload;
      expect(payload.participantRef.binding, isA<SeniorCoachPresentBinding>());
    });

    test('reason absent remains semantically valid', () {
      final contribution = resolver.resolve(_yellowCard(recordId: 'yc-no-reason'));
      expect(contribution.isSupported, isTrue);
      final payload = _yellowCard(recordId: 'yc-no-reason').payload
          as YellowCardPayload;
      expect(payload.reason, isNull);
    });

    test('reason present round-trips', () async {
      final record = _yellowCard(
        recordId: 'yc-reason',
        reason: '  unsporting behaviour  ',
      );
      final loaded = await _persistRoundTrip(record);
      expect(
        (loaded.payload as YellowCardPayload).reason,
        'unsporting behaviour',
      );
    });

    test('blank reason normalizes to absent', () {
      final payload = YellowCardPayload(
        participantRef: participantRef,
        participantStatusAtDetermination:
            ParticipantStatusAtDetermination.onFieldPlayer,
        disciplinaryAccountingScope: DisciplinaryAccountingScope.match,
        captureIntentId: 'intent-blank-reason',
        reason: '   ',
      );
      expect(payload.reason, isNull);
    });
  });

  group('YellowCardPayload authority fields absent', () {
    test('no yellowCount/isSecondYellow/redRequired fields exist as authority',
        () {
      final payload = _yellowCard(recordId: 'yc-fields').payload;
      final encoded = encodeMatchRecordForStorage(
        _yellowCard(recordId: 'yc-fields'),
      );
      final payloadJson = encoded['payload'] as Map<String, Object?>;
      expect(payloadJson.keys, isNot(contains('yellowCount')));
      expect(payloadJson.keys, isNot(contains('isSecondYellow')));
      expect(payloadJson.keys, isNot(contains('redRequired')));
      expect(payloadJson.keys, isNot(contains('sentOff')));
      expect(payload.toString(), isNot(contains('yellowCount')));
    });
  });

  group('Regression guards', () {
    test('Goal semantics remain unchanged', () {
      final contribution = resolver.resolve(
        _record(
          recordId: 'goal-1',
          recordKind: RecordKind.humanDetermination,
          payload: GoalPayload(
            creditedSide: CreditedSide.home,
            captureIntentId: 'intent-goal-1',
          ),
        ),
      );
      expect(contribution.supportedFacets, [ProjectionFacet.score]);
    });

    test('temporal lifecycle remains unchanged', () {
      final contribution = resolver.resolve(
        _record(
          recordId: 'start-1',
          payload: TemporalTransitionPayload(
            semanticType: V1SemanticTypeCode.matchStarted,
          ),
        ),
      );
      expect(contribution.supportedFacets, [ProjectionFacet.temporal]);
    });

    test('persistence reopen preserves identical typed Yellow Card semantics',
        () async {
      final original = _yellowCard(
        recordId: 'yc-reopen',
        originSequence: 3,
        status: ParticipantStatusAtDetermination.onFieldPlayer,
        scope: DisciplinaryAccountingScope.match,
        reason: 'dissent',
        captureIntentId: 'intent-reopen',
      );
      final loaded = await _persistRoundTrip(original);
      expect(loaded.recordKind, RecordKind.humanDetermination);
      final loadedPayload = loaded.payload as YellowCardPayload;
      final originalPayload = original.payload as YellowCardPayload;
      expect(loadedPayload.participantRef, originalPayload.participantRef);
      expect(
        loadedPayload.participantStatusAtDetermination,
        originalPayload.participantStatusAtDetermination,
      );
      expect(
        loadedPayload.disciplinaryAccountingScope,
        originalPayload.disciplinaryAccountingScope,
      );
      expect(loadedPayload.captureIntentId, originalPayload.captureIntentId);
      expect(loadedPayload.reason, originalPayload.reason);
      expect(resolver.resolve(loaded), equals(resolver.resolve(original)));
    });
  });
}

Future<MatchRecord> _persistRoundTrip(MatchRecord record) async {
  final temp = await Directory.systemTemp.createTemp('yellow_card_semantic_');
  final file = File('${temp.path}/memory.sqlite');
  final store = SqliteDurableMatchStore.open(file);
  expect(await store.commit(record), isA<DurableCommitSuccess>());
  await store.close();
  final reopened = SqliteDurableMatchStore.open(file);
  final loaded = await reopened.readCommittedForMatch(record.matchId);
  await reopened.close();
  temp.deleteSync(recursive: true);
  return loaded.single;
}

MatchRecord _yellowCard({
  required String recordId,
  int originSequence = 1,
  RecordKind recordKind = RecordKind.humanDetermination,
  ParticipantRef? participantRef,
  ParticipantStatusAtDetermination status =
      ParticipantStatusAtDetermination.onFieldPlayer,
  DisciplinaryAccountingScope scope = DisciplinaryAccountingScope.match,
  String captureIntentId = 'intent-yc-default',
  String? reason,
}) {
  return _record(
    recordId: recordId,
    originSequence: originSequence,
    recordKind: recordKind,
    payload: YellowCardPayload(
      participantRef: participantRef ??
          ParticipantRef(
            matchParticipantId: MatchParticipantId('mpid-yellow-1'),
            teamSide: ParticipantTeamSide.home,
            binding: const RosterLinkedBinding(rosterParticipantId: 'home-7'),
          ),
      participantStatusAtDetermination: status,
      disciplinaryAccountingScope: scope,
      captureIntentId: captureIntentId,
      reason: reason,
    ),
    authorityContext: const AuthorityContext(
      scope: MainRefereeScope(),
      principal: AuthorityPrincipal(principalId: 'ref-1'),
    ),
  );
}

MatchRecord _record({
  required String recordId,
  required MatchRecordPayload payload,
  String matchId = 'match-1',
  RecordKind recordKind = RecordKind.temporalFact,
  int originSequence = 1,
  AuthorityContext? authorityContext,
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: matchId,
    recordKind: recordKind,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 6, 12, originSequence),
    originDeviceId: 'device-1',
    originSequence: originSequence,
    authorityContext: authorityContext,
    payload: payload,
    integrity: const IntegrityMetadata(),
  );
}
