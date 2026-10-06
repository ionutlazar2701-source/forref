import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:test/test.dart';

const _matchId = 'match-participant-foundation';

void main() {
  const generator = SecureMatchParticipantIdGenerator();

  group('ParticipantIdentityProjection', () {
    test('roster-linked participant gets stable MatchParticipantId', () {
      final id = MatchParticipantId('mpid-roster-1');
      final projection = ParticipantIdentityProjection.derive(
        records: [
          _registered(
            recordId: 'reg-1',
            originSequence: 1,
            participantId: id,
            teamSide: ParticipantTeamSide.home,
            binding: const RosterLinkedBinding(rosterParticipantId: 'home-9'),
          ),
        ],
      );
      expect(projection[id]!.registeredId, id);
      expect(projection[id]!.canonicalId, id);
      expect(projection.confidenceFor(id), IdentityConfidence.resolved);
    });

    test('same ID survives SUBSTITUTE to ON_FIELD status contexts', () {
      final id = MatchParticipantId('mpid-sub-flow');
      final projection = ParticipantIdentityProjection.derive(
        records: [
          _registered(
            recordId: 'reg-sub',
            originSequence: 1,
            participantId: id,
            teamSide: ParticipantTeamSide.home,
            binding: const TeamScopedNumberBinding(shirtNumber: 11),
            initialStatus: ParticipantStatusAtDetermination.substitute,
          ),
        ],
      );
      expect(projection.resolveCanonical(id), id);
      final onFieldRef = ParticipantRef(
        matchParticipantId: id,
        teamSide: ParticipantTeamSide.home,
        binding: const TeamScopedNumberBinding(shirtNumber: 11),
      );
      expect(projection.resolveCanonical(onFieldRef.matchParticipantId), id);
      expect(projection[id]!.initialStatus,
          ParticipantStatusAtDetermination.substitute);
    });

    test('same ID survives ON_FIELD to SUBSTITUTED status contexts', () {
      final id = MatchParticipantId('mpid-subbed-flow');
      final projection = ParticipantIdentityProjection.derive(
        records: [
          _registered(
            recordId: 'reg-player',
            originSequence: 1,
            participantId: id,
            teamSide: ParticipantTeamSide.away,
            binding: const RosterLinkedBinding(rosterParticipantId: 'away-7'),
            initialStatus: ParticipantStatusAtDetermination.onFieldPlayer,
          ),
        ],
      );
      expect(projection.resolveCanonical(id), id);
    });

    test('eligible re-entry keeps same MatchParticipantId', () {
      final id = MatchParticipantId('mpid-reentry');
      final projection = ParticipantIdentityProjection.derive(
        records: [
          _registered(
            recordId: 'reg-reentry',
            originSequence: 1,
            participantId: id,
            teamSide: ParticipantTeamSide.home,
            binding: const RosterLinkedBinding(rosterParticipantId: 'home-14'),
          ),
        ],
      );
      expect(projection[id]!.canonicalId, id);
    });

    test('Team A #8 is distinct from Team B #8', () {
      final homeEight = MatchParticipantId('mpid-home-8');
      final awayEight = MatchParticipantId('mpid-away-8');
      final projection = ParticipantIdentityProjection.derive(
        records: [
          _registered(
            recordId: 'reg-home-8',
            originSequence: 1,
            participantId: homeEight,
            teamSide: ParticipantTeamSide.home,
            binding: const TeamScopedNumberBinding(shirtNumber: 8),
          ),
          _registered(
            recordId: 'reg-away-8',
            originSequence: 2,
            participantId: awayEight,
            teamSide: ParticipantTeamSide.away,
            binding: const TeamScopedNumberBinding(shirtNumber: 8),
          ),
        ],
      );
      expect(projection.resolveCanonical(homeEight), homeEight);
      expect(projection.resolveCanonical(awayEight), awayEight);
      expect(projection.confidenceFor(homeEight), IdentityConfidence.resolved);
      expect(projection.confidenceFor(awayEight), IdentityConfidence.resolved);
    });

    test('duplicate Team A #8 identities never auto-merge', () {
      final first = MatchParticipantId('mpid-home-8-a');
      final second = MatchParticipantId('mpid-home-8-b');
      final projection = ParticipantIdentityProjection.derive(
        records: [
          _registered(
            recordId: 'reg-a',
            originSequence: 1,
            participantId: first,
            teamSide: ParticipantTeamSide.home,
            binding: const TeamScopedNumberBinding(shirtNumber: 8),
          ),
          _registered(
            recordId: 'reg-b',
            originSequence: 2,
            participantId: second,
            teamSide: ParticipantTeamSide.home,
            binding: const TeamScopedNumberBinding(shirtNumber: 8),
          ),
        ],
      );
      expect(projection.confidenceFor(first), IdentityConfidence.ambiguous);
      expect(projection.confidenceFor(second), IdentityConfidence.ambiguous);
      expect(projection.resolveCanonical(first), first);
      expect(projection.resolveCanonical(second), second);
    });

    test('provisional identity survives reopen via persistence', () async {
      final id = MatchParticipantId('mpid-provisional');
      final record = _registered(
        recordId: 'reg-prov',
        originSequence: 1,
        participantId: id,
        teamSide: ParticipantTeamSide.home,
        binding: const FreeformDescriptorBinding(descriptor: 'unknown home #7'),
      );
      final temp = await Directory.systemTemp
          .createTemp('participant_identity_reopen_');
      final file = File('${temp.path}/memory.sqlite');
      final store = SqliteDurableMatchStore.open(file);
      expect(await store.commit(record), isA<DurableCommitSuccess>());
      await store.close();

      final reopened = SqliteDurableMatchStore.open(file);
      final loaded = await reopened.readCommittedForMatch(_matchId);
      await reopened.close();
      temp.deleteSync(recursive: true);

      final projection = ParticipantIdentityProjection.derive(records: loaded);
      expect(projection[id]!.binding, isA<FreeformDescriptorBinding>());
      expect(projection.confidenceFor(id), IdentityConfidence.provisional);
    });

    test('two provisional IDs do not silently merge', () {
      final first = MatchParticipantId('mpid-prov-a');
      final second = MatchParticipantId('mpid-prov-b');
      final projection = ParticipantIdentityProjection.derive(
        records: [
          _registered(
            recordId: 'reg-pa',
            originSequence: 1,
            participantId: first,
            teamSide: ParticipantTeamSide.home,
            binding: const FreeformDescriptorBinding(descriptor: 'unknown #7'),
          ),
          _registered(
            recordId: 'reg-pb',
            originSequence: 2,
            participantId: second,
            teamSide: ParticipantTeamSide.home,
            binding: const FreeformDescriptorBinding(descriptor: 'unknown #7'),
          ),
        ],
      );
      expect(projection.resolveCanonical(first), first);
      expect(projection.resolveCanonical(second), second);
    });

    test('reconciliation maps old identity to canonical without rewriting records',
        () {
      final provisional = MatchParticipantId('mpid-prov-old');
      final canonical = MatchParticipantId('mpid-canonical');
      final records = [
        _registered(
          recordId: 'reg-old',
          originSequence: 1,
          participantId: provisional,
          teamSide: ParticipantTeamSide.home,
          binding: const FreeformDescriptorBinding(descriptor: 'unknown #7'),
        ),
        _registered(
          recordId: 'reg-new',
          originSequence: 2,
          participantId: canonical,
          teamSide: ParticipantTeamSide.home,
          binding: const RosterLinkedBinding(rosterParticipantId: 'home-7'),
        ),
        _reconciliation(
          recordId: 'recon-1',
          originSequence: 3,
          fromId: provisional,
          toId: canonical,
        ),
      ];
      final projection = ParticipantIdentityProjection.derive(records: records);
      expect(records[0].payload, isA<ParticipantRegisteredPayload>());
      expect(projection.resolveCanonical(provisional), canonical);
      expect(projection[provisional]!.registrationRecordId, 'reg-old');
    });

    test('conflicting reconciliation produces conflict state', () {
      final a = MatchParticipantId('mpid-a');
      final b = MatchParticipantId('mpid-b');
      final c = MatchParticipantId('mpid-c');
      final projection = ParticipantIdentityProjection.derive(
        records: [
          _registered(
            recordId: 'reg-a',
            originSequence: 1,
            participantId: a,
            teamSide: ParticipantTeamSide.home,
            binding: const TeamScopedNumberBinding(shirtNumber: 3),
          ),
          _registered(
            recordId: 'reg-b',
            originSequence: 2,
            participantId: b,
            teamSide: ParticipantTeamSide.home,
            binding: const TeamScopedNumberBinding(shirtNumber: 4),
          ),
          _registered(
            recordId: 'reg-c',
            originSequence: 3,
            participantId: c,
            teamSide: ParticipantTeamSide.home,
            binding: const TeamScopedNumberBinding(shirtNumber: 5),
          ),
          _reconciliation(
            recordId: 'recon-ab',
            originSequence: 4,
            fromId: a,
            toId: b,
          ),
          _reconciliation(
            recordId: 'recon-bc',
            originSequence: 5,
            fromId: b,
            toId: c,
          ),
          _reconciliation(
            recordId: 'recon-ca',
            originSequence: 6,
            fromId: c,
            toId: a,
          ),
        ],
      );
      expect(projection.confidenceFor(a), IdentityConfidence.conflicted);
    });

    test('shirt-number correction keeps participant identity', () {
      final id = MatchParticipantId('mpid-number-fix');
      final projection = ParticipantIdentityProjection.derive(
        records: [
          _registered(
            recordId: 'reg-num',
            originSequence: 1,
            participantId: id,
            teamSide: ParticipantTeamSide.home,
            binding: const TeamScopedNumberBinding(shirtNumber: 7),
          ),
          _bindingCorrection(
            recordId: 'corr-num',
            originSequence: 2,
            participantId: id,
            binding: const TeamScopedNumberBinding(shirtNumber: 17),
          ),
        ],
      );
      expect(projection.resolveCanonical(id), id);
      expect(
        projection[id]!.binding,
        const TeamScopedNumberBinding(shirtNumber: 17),
      );
    });

    test('team official can have stable identity', () {
      final id = MatchParticipantId('mpid-official');
      final projection = ParticipantIdentityProjection.derive(
        records: [
          _registered(
            recordId: 'reg-official',
            originSequence: 1,
            participantId: id,
            teamSide: ParticipantTeamSide.away,
            binding: const IdentifiedOfficialBinding(displayName: 'Assistant coach'),
            initialStatus: ParticipantStatusAtDetermination.teamOfficial,
          ),
        ],
      );
      expect(projection[id]!.canonicalId, id);
      expect(projection.confidenceFor(id), IdentityConfidence.resolved);
    });

    test('SENIOR_COACH_PRESENT role slot without invented person data', () {
      final id = MatchParticipantId('mpid-senior-coach-slot');
      final projection = ParticipantIdentityProjection.derive(
        records: [
          _registered(
            recordId: 'reg-coach-slot',
            originSequence: 1,
            participantId: id,
            teamSide: ParticipantTeamSide.home,
            binding: const SeniorCoachPresentBinding(),
            initialStatus: ParticipantStatusAtDetermination.seniorCoachPresent,
          ),
        ],
      );
      expect(projection[id]!.binding, isA<SeniorCoachPresentBinding>());
      expect(projection.confidenceFor(id), IdentityConfidence.resolved);
    });

    test('identity confidence is derived not stored on records', () {
      final id = MatchParticipantId('mpid-derived-confidence');
      final record = _registered(
        recordId: 'reg-derived',
        originSequence: 1,
        participantId: id,
        teamSide: ParticipantTeamSide.home,
        binding: const FreeformDescriptorBinding(descriptor: 'unknown #9'),
      );
      expect(record.payload, isA<ParticipantRegisteredPayload>());
      final payload = record.payload as ParticipantRegisteredPayload;
      expect(payload.toString(), isNot(contains('confidence')));
      final projection = ParticipantIdentityProjection.derive(records: [record]);
      expect(projection.confidenceFor(id), IdentityConfidence.provisional);
    });

    test('reopen rebuilds identical identity projection', () async {
      final id = MatchParticipantId('mpid-reopen');
      final records = [
        _registered(
          recordId: 'reg-reopen',
          originSequence: 1,
          participantId: id,
          teamSide: ParticipantTeamSide.home,
          binding: const RosterLinkedBinding(rosterParticipantId: 'home-2'),
        ),
      ];
      final before = ParticipantIdentityProjection.derive(records: records);

      final temp = await Directory.systemTemp.createTemp('participant_reopen_');
      final file = File('${temp.path}/memory.sqlite');
      final store = SqliteDurableMatchStore.open(file);
      for (final record in records) {
        expect(await store.commit(record), isA<DurableCommitSuccess>());
      }
      await store.close();
      final reopened = SqliteDurableMatchStore.open(file);
      final loaded = await reopened.readCommittedForMatch(_matchId);
      await reopened.close();
      temp.deleteSync(recursive: true);

      final after = ParticipantIdentityProjection.derive(records: loaded);
      expect(after.participantsByRegisteredId.keys,
          before.participantsByRegisteredId.keys);
      expect(after[id], equals(before[id]));
    });
  });

  group('DisciplinaryAuthorityProjection', () {
    test('REFEREE_ENTERED_FIELD_FOR_MATCH_START is distinct from MATCH_STARTED',
        () {
      final records = [
        _cardAuthority(
          recordId: 'entered-1',
          originSequence: 1,
          type: V1SemanticTypeCode.refereeEnteredFieldForMatchStart,
        ),
        _transition(
          recordId: 'start-1',
          originSequence: 2,
          type: V1SemanticTypeCode.matchStarted,
        ),
      ];
      final projection = DisciplinaryAuthorityProjection.derive(records: records);
      expect(projection.refereeEnteredFieldCommitted, isTrue);
      expect(projection.matchStarted, isTrue);
      expect(
        (records[0].payload as TemporalTransitionPayload).semanticType,
        V1SemanticTypeCode.refereeEnteredFieldForMatchStart,
      );
      expect(
        (records[1].payload as TemporalTransitionPayload).semanticType,
        V1SemanticTypeCode.matchStarted,
      );
    });

    test('card authority can be open before kick-off', () {
      final projection = DisciplinaryAuthorityProjection.derive(
        records: [
          _cardAuthority(
            recordId: 'entered-1',
            originSequence: 1,
            type: V1SemanticTypeCode.refereeEnteredFieldForMatchStart,
          ),
        ],
      );
      expect(projection.cardDisplayAuthorityOpen, isTrue);
      expect(projection.matchStarted, isFalse);
      expect(projection.accountingScope, DisciplinaryAccountingScope.match);
    });

    test('MATCH_ENDED does not close card authority', () {
      final projection = DisciplinaryAuthorityProjection.derive(
        records: [
          _cardAuthority(
            recordId: 'entered-1',
            originSequence: 1,
            type: V1SemanticTypeCode.refereeEnteredFieldForMatchStart,
          ),
          _transition(
            recordId: 'start-1',
            originSequence: 2,
            type: V1SemanticTypeCode.matchStarted,
          ),
          _transition(
            recordId: 'end-1',
            originSequence: 3,
            type: V1SemanticTypeCode.matchEnded,
            period: const PeriodIdentity(index: 2),
          ),
        ],
      );
      expect(projection.matchEnded, isTrue);
      expect(projection.cardDisplayAuthorityOpen, isTrue);
    });

    test('REFEREE_LEFT_FIELD_AFTER_MATCH closes card authority', () {
      final projection = DisciplinaryAuthorityProjection.derive(
        records: [
          _cardAuthority(
            recordId: 'entered-1',
            originSequence: 1,
            type: V1SemanticTypeCode.refereeEnteredFieldForMatchStart,
          ),
          _transition(
            recordId: 'start-1',
            originSequence: 2,
            type: V1SemanticTypeCode.matchStarted,
          ),
          _transition(
            recordId: 'end-1',
            originSequence: 3,
            type: V1SemanticTypeCode.matchEnded,
            period: const PeriodIdentity(index: 2),
          ),
          _cardAuthority(
            recordId: 'left-1',
            originSequence: 4,
            type: V1SemanticTypeCode.refereeLeftFieldAfterMatch,
          ),
        ],
      );
      expect(projection.refereeLeftFieldCommitted, isTrue);
      expect(projection.cardDisplayAuthorityOpen, isFalse);
      expect(projection.accountingScope,
          DisciplinaryAccountingScope.unresolved);
    });

    test('MATCH and SHOOTOUT accounting scopes remain distinct', () {
      final inMatch = DisciplinaryAuthorityProjection.derive(
        records: [
          _cardAuthority(
            recordId: 'entered-1',
            originSequence: 1,
            type: V1SemanticTypeCode.refereeEnteredFieldForMatchStart,
          ),
          _transition(
            recordId: 'start-1',
            originSequence: 2,
            type: V1SemanticTypeCode.matchStarted,
          ),
        ],
      );
      final shootout = DisciplinaryAuthorityProjection.derive(
        records: [
          _cardAuthority(
            recordId: 'entered-1',
            originSequence: 1,
            type: V1SemanticTypeCode.refereeEnteredFieldForMatchStart,
          ),
          _transition(
            recordId: 'start-1',
            originSequence: 2,
            type: V1SemanticTypeCode.matchStarted,
          ),
          _transition(
            recordId: 'end-1',
            originSequence: 3,
            type: V1SemanticTypeCode.matchEnded,
            period: const PeriodIdentity(index: 2),
          ),
        ],
        competitionRules: const CompetitionRulesContext(
          rulesetId: 'ifab',
          penaltyShootOutAfterMatchEnd: true,
        ),
      );
      expect(inMatch.accountingScope, DisciplinaryAccountingScope.match);
      expect(shootout.accountingScope, DisciplinaryAccountingScope.shootout);
    });

    test('reopen rebuilds identical authority projection', () async {
      final records = [
        _cardAuthority(
          recordId: 'entered-1',
          originSequence: 1,
          type: V1SemanticTypeCode.refereeEnteredFieldForMatchStart,
        ),
        _transition(
          recordId: 'start-1',
          originSequence: 2,
          type: V1SemanticTypeCode.matchStarted,
        ),
      ];
      final before = DisciplinaryAuthorityProjection.derive(records: records);
      final temp = await Directory.systemTemp.createTemp('authority_reopen_');
      final file = File('${temp.path}/memory.sqlite');
      final store = SqliteDurableMatchStore.open(file);
      for (final record in records) {
        expect(await store.commit(record), isA<DurableCommitSuccess>());
      }
      await store.close();
      final reopened = SqliteDurableMatchStore.open(file);
      final loaded = await reopened.readCommittedForMatch(_matchId);
      await reopened.close();
      temp.deleteSync(recursive: true);

      final after = DisciplinaryAuthorityProjection.derive(records: loaded);
      expect(after.cardDisplayAuthorityOpen, before.cardDisplayAuthorityOpen);
      expect(after.accountingScope, before.accountingScope);
    });
  });

  test('MatchParticipantId generator produces opaque ids', () {
    final first = generator.newParticipantId();
    final second = generator.newParticipantId();
    expect(first.value, startsWith('mpid-'));
    expect(first.value, isNot(second.value));
  });
}

MatchRecord _registered({
  required String recordId,
  required int originSequence,
  required MatchParticipantId participantId,
  required ParticipantTeamSide teamSide,
  required ParticipantBinding binding,
  ParticipantStatusAtDetermination? initialStatus,
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: _matchId,
    recordKind: RecordKind.action,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 6, 12, originSequence),
    originDeviceId: 'device-1',
    originSequence: originSequence,
    payload: ParticipantRegisteredPayload(
      matchParticipantId: participantId,
      teamSide: teamSide,
      binding: binding,
      initialStatus: initialStatus,
    ),
    integrity: const IntegrityMetadata(),
  );
}

MatchRecord _bindingCorrection({
  required String recordId,
  required int originSequence,
  required MatchParticipantId participantId,
  required ParticipantBinding binding,
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: _matchId,
    recordKind: RecordKind.correction,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 6, 12, originSequence),
    originDeviceId: 'device-1',
    originSequence: originSequence,
    relationships: [CorrectionTarget(targetRecordId: 'reg-num')],
    payload: ParticipantBindingCorrectionPayload(
      matchParticipantId: participantId,
      correctedBinding: binding,
    ),
    integrity: const IntegrityMetadata(),
  );
}

MatchRecord _reconciliation({
  required String recordId,
  required int originSequence,
  required MatchParticipantId fromId,
  required MatchParticipantId toId,
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: _matchId,
    recordKind: RecordKind.action,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 6, 12, originSequence),
    originDeviceId: 'device-1',
    originSequence: originSequence,
    payload: ParticipantIdentityReconciliationPayload(
      fromParticipantId: fromId,
      toParticipantId: toId,
    ),
    integrity: const IntegrityMetadata(),
  );
}

MatchRecord _cardAuthority({
  required String recordId,
  required int originSequence,
  required V1SemanticTypeCode type,
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: _matchId,
    recordKind: RecordKind.temporalFact,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 6, 12, originSequence),
    originDeviceId: 'device-1',
    originSequence: originSequence,
    payload: TemporalTransitionPayload(semanticType: type),
    integrity: const IntegrityMetadata(),
  );
}

MatchRecord _transition({
  required String recordId,
  required int originSequence,
  required V1SemanticTypeCode type,
  PeriodIdentity? period,
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: _matchId,
    recordKind: RecordKind.temporalFact,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 6, 12, originSequence),
    originDeviceId: 'device-1',
    originSequence: originSequence,
    payload: TemporalTransitionPayload(
      semanticType: type,
      period: period,
    ),
    integrity: const IntegrityMetadata(),
  );
}
