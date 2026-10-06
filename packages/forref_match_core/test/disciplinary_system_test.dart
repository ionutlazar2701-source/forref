import 'dart:convert';
import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:test/test.dart';

void main() {
  group('CompetitionRulesContext disciplinary system', () {
    test('explicitly carries disciplinary system', () {
      const rules = CompetitionRulesContext(
        rulesetId: 'ifab',
        disciplinarySystem: DisciplinarySystem.ordinaryIfab,
      );
      expect(rules.disciplinarySystem, DisciplinarySystem.ordinaryIfab);
    });

    test('ordinary IFAB round-trips through record storage encoding', () {
      const rules = CompetitionRulesContext(
        rulesetId: 'ifab',
        disciplinarySystem: DisciplinarySystem.ordinaryIfab,
      );
      final roundTripped = _roundTripRulesOnRecord(rules);
      expect(roundTripped.disciplinarySystem, DisciplinarySystem.ordinaryIfab);
    });

    test('temporary dismissal round-trips through record storage encoding', () {
      const rules = CompetitionRulesContext(
        rulesetId: 'youth-league',
        disciplinarySystem: DisciplinarySystem.temporaryDismissal,
      );
      final roundTripped = _roundTripRulesOnRecord(rules);
      expect(
        roundTripped.disciplinarySystem,
        DisciplinarySystem.temporaryDismissal,
      );
    });

    test('unresolved round-trips through record storage encoding', () {
      const rules = CompetitionRulesContext(
        rulesetId: 'ifab',
        disciplinarySystem: DisciplinarySystem.unresolved,
      );
      final roundTripped = _roundTripRulesOnRecord(rules);
      expect(roundTripped.disciplinarySystem, DisciplinarySystem.unresolved);
    });

    test('missing legacy field does not silently become ordinary IFAB', () {
      final decoded = decodeMatchRecordFromStorage(jsonEncode({
        'storageEncoding': adapterLocalStorageEncoding,
        'recordId': 'start-legacy',
        'matchId': 'match-1',
        'recordKind': 'temporalFact',
        'schemaVersion': 1,
        'recordedAt': '2026-10-06T12:00:00.000Z',
        'originDeviceId': 'device-1',
        'originSequence': 1,
        'relationships': <Object?>[],
        'payload': {
          'type': 'v1-temporal-transition',
          'semanticType': 'MATCH_STARTED',
          'competitionRulesContext': {
            'rulesetId': 'ifab',
            'additionalPlayingPhase': 'NONE_REQUIRED',
          },
        },
        'integrity': {'evidenceRefs': <Object?>[]},
      }));
      final payload = decoded.payload as TemporalTransitionPayload;
      expect(payload.competitionRulesContext?.disciplinarySystem,
          DisciplinarySystem.unresolved);
    });

    test('additional playing phase remains independent', () {
      const rules = CompetitionRulesContext(
        rulesetId: 'ifab',
        additionalPlayingPhase: AdditionalPlayingPhaseDisposition.noneRequired,
        disciplinarySystem: DisciplinarySystem.unresolved,
      );
      expect(rules.additionalPlayingPhase,
          AdditionalPlayingPhaseDisposition.noneRequired);
      expect(rules.disciplinarySystem, DisciplinarySystem.unresolved);
    });

    test('penalty shoot-out flag remains independent', () {
      const rules = CompetitionRulesContext(
        rulesetId: 'cup',
        penaltyShootOutAfterMatchEnd: true,
        disciplinarySystem: DisciplinarySystem.ordinaryIfab,
      );
      expect(rules.penaltyShootOutAfterMatchEnd, isTrue);
      expect(rules.disciplinarySystem, DisciplinarySystem.ordinaryIfab);
    });
  });

  group('YellowCardDisciplinarySystemSupportGate', () {
    test('ordinary IFAB reports Yellow Card V1 supported', () {
      expect(
        YellowCardDisciplinarySystemSupportGate.assess(
          const CompetitionRulesContext(
            rulesetId: 'ifab',
            disciplinarySystem: DisciplinarySystem.ordinaryIfab,
          ),
        ),
        YellowCardDisciplinarySystemSupport.supported,
      );
    });

    test('temporary dismissal reports unsupported fail-closed', () {
      expect(
        YellowCardDisciplinarySystemSupportGate.assess(
          const CompetitionRulesContext(
            rulesetId: 'youth',
            disciplinarySystem: DisciplinarySystem.temporaryDismissal,
          ),
        ),
        YellowCardDisciplinarySystemSupport.unsupportedModifiedSystem,
      );
    });

    test('unresolved reports unresolved fail-closed', () {
      expect(
        YellowCardDisciplinarySystemSupportGate.assess(
          const CompetitionRulesContext(rulesetId: 'ifab'),
        ),
        YellowCardDisciplinarySystemSupport.unresolved,
      );
      expect(
        YellowCardDisciplinarySystemSupportGate.assess(null),
        YellowCardDisciplinarySystemSupport.unresolved,
      );
    });

    test('rulesetId alone does not imply ordinary IFAB support', () {
      expect(
        YellowCardDisciplinarySystemSupportGate.assess(
          const CompetitionRulesContext(rulesetId: 'ifab'),
        ),
        isNot(YellowCardDisciplinarySystemSupport.supported),
      );
    });
  });

  group('Persistence on Match Records', () {
    test('disciplinary system round-trips on typed record payload', () async {
      const rules = CompetitionRulesContext(
        rulesetId: 'ifab',
        disciplinarySystem: DisciplinarySystem.ordinaryIfab,
      );
      final temp = await Directory.systemTemp.createTemp('disc_sys_record_');
      final file = File('${temp.path}/memory.sqlite');
      final store = SqliteDurableMatchStore.open(file);
      expect(
        await store.commit(_recordWithRules(rules)),
        isA<DurableCommitSuccess>(),
      );
      await store.close();
      final reopened = SqliteDurableMatchStore.open(file);
      final loaded = await reopened.readCommittedForMatch('match-1');
      await reopened.close();
      temp.deleteSync(recursive: true);
      final payload = loaded.single.payload as TemporalTransitionPayload;
      expect(payload.competitionRulesContext?.disciplinarySystem,
          DisciplinarySystem.ordinaryIfab);
    });
  });

  group('Regression guards', () {
    test('Goal semantics remain unchanged', () {
      final resolver = ProductionSemanticsResolver();
      final contribution = resolver.resolve(
        MatchRecord(
          recordId: 'goal-1',
          matchId: 'match-1',
          recordKind: RecordKind.humanDetermination,
          schemaVersion: 1,
          recordedAt: DateTime.utc(2026, 10, 6),
          originDeviceId: 'device-1',
          originSequence: 1,
          payload: GoalPayload(
            creditedSide: CreditedSide.home,
            captureIntentId: 'intent-goal-1',
          ),
          integrity: const IntegrityMetadata(),
        ),
      );
      expect(contribution.supportedFacets, [ProjectionFacet.score]);
    });

    test('temporal lifecycle remains unchanged', () {
      final resolver = ProductionSemanticsResolver();
      final contribution = resolver.resolve(
        MatchRecord(
          recordId: 'start-1',
          matchId: 'match-1',
          recordKind: RecordKind.temporalFact,
          schemaVersion: 1,
          recordedAt: DateTime.utc(2026, 10, 6),
          originDeviceId: 'device-1',
          originSequence: 1,
          payload: TemporalTransitionPayload(
            semanticType: V1SemanticTypeCode.matchStarted,
          ),
          integrity: const IntegrityMetadata(),
        ),
      );
      expect(contribution.supportedFacets, [ProjectionFacet.temporal]);
    });
  });
}

CompetitionRulesContext _roundTripRulesOnRecord(CompetitionRulesContext rules) {
  final json = encodeMatchRecordJson(_recordWithRules(rules));
  final decoded = decodeMatchRecordFromStorage(json);
  return (decoded.payload as TemporalTransitionPayload).competitionRulesContext!;
}

MatchRecord _recordWithRules(CompetitionRulesContext rules) {
  return MatchRecord(
    recordId: 'start-1',
    matchId: 'match-1',
    recordKind: RecordKind.temporalFact,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 6, 12),
    originDeviceId: 'device-1',
    originSequence: 1,
    payload: TemporalTransitionPayload(
      semanticType: V1SemanticTypeCode.matchStarted,
      competitionRulesContext: rules,
    ),
    integrity: const IntegrityMetadata(),
  );
}
