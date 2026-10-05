import 'dart:convert';
import 'dart:io';

import 'package:forref_match_core/canonical_record_form.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('forref_typed_v1_');
  });

  tearDown(() async {
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  test('every production typed V1 payload survives close and reopen', () async {
    final file = File('${temp.path}/memory.sqlite');
    final records = [
      _typed(
        recordId: 'start-1',
        originSequence: 1,
        recordKind: RecordKind.temporalFact,
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.matchStarted,
          domainContractVersion: const DomainContractVersion('domain-clock-v1'),
          competitionRulesContext: const CompetitionRulesContext(rulesetId: 'ifab'),
        ),
      ),
      _typed(
        recordId: 'period-1',
        originSequence: 2,
        recordKind: RecordKind.temporalFact,
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.periodEnded,
          period: const PeriodIdentity(index: 1),
        ),
      ),
      _typed(
        recordId: 'susp-end-1',
        originSequence: 3,
        recordKind: RecordKind.temporalFact,
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.temporarySuspensionEnded,
          period: const PeriodIdentity(index: 1),
        ),
      ),
      _typed(
        recordId: 'tcorr-1',
        originSequence: 4,
        recordKind: RecordKind.correction,
        payload: const TemporalCorrectionPayload(
          domainContractVersion: DomainContractVersion('domain-clock-v1'),
        ),
        relationships: [CorrectionTarget(targetRecordId: 'start-1')],
      ),
      _typed(
        recordId: 'corr-1',
        originSequence: 5,
        recordKind: RecordKind.correction,
        payload: const CorrectionPayload(
          competitionRulesContext: CompetitionRulesContext(rulesetId: 'ifab'),
        ),
        relationships: [CorrectionTarget(targetRecordId: 'start-1')],
      ),
      _typed(
        recordId: 'super-1',
        originSequence: 6,
        recordKind: RecordKind.legalSupersession,
        payload: const LegalSupersessionPayload(),
        relationships: [LegalSupersessionTarget(targetRecordId: 'start-1')],
      ),
      _typed(
        recordId: 'goal-1',
        originSequence: 7,
        recordKind: RecordKind.action,
        payload: GoalPayload(
          scoringSide: GoalScoringSide.home,
          period: const PeriodIdentity(index: 1),
          playerNumber: '9',
        ),
        relationships: [CausalDependency(targetRecordId: 'period-1')],
      ),
    ];

    final store = SqliteDurableMatchStore.open(file);
    for (final record in records) {
      expect(await store.commit(record), isA<DurableCommitSuccess>());
    }
    await store.close();

    final reopened = SqliteDurableMatchStore.open(file);
    final loaded = await reopened.readCommittedForMatch('match-1');
    expect(loaded, hasLength(records.length));

    final byId = {for (final record in loaded) record.recordId: record};
    expect(byId['start-1']!.payload, isA<TemporalTransitionPayload>());
    expect(byId['period-1']!.payload, isA<TemporalTransitionPayload>());
    expect(byId['susp-end-1']!.payload, isA<TemporalTransitionPayload>());
    expect(byId['tcorr-1']!.payload, isA<TemporalCorrectionPayload>());
    expect(byId['corr-1']!.payload, isA<CorrectionPayload>());
    expect(byId['super-1']!.payload, isA<LegalSupersessionPayload>());
    final goal = byId['goal-1']!.payload as GoalPayload;
    expect(goal.scoringSide, GoalScoringSide.home);
    expect(goal.period, const PeriodIdentity(index: 1));
    expect(goal.playerNumber, '9');
    expect(goal.playerId, isNull);
    final storedGoal = encodeMatchRecordForStorage(byId['goal-1']!);
    final storedText = jsonEncode(storedGoal);
    expect(storedText, isNot(contains('elapsedSeconds')));
    expect(storedText, isNot(contains('scoreHome')));
    expect(storedText, isNot(contains('scoreAway')));

    expect(
      (byId['start-1']!.payload as TemporalTransitionPayload).semanticType,
      V1SemanticTypeCode.matchStarted,
    );
    expect(
      (byId['susp-end-1']!.payload as TemporalTransitionPayload).semanticType,
      V1SemanticTypeCode.temporarySuspensionEnded,
    );
    expect(
      (byId['start-1']!.payload as TemporalTransitionPayload).domainContractVersion,
      const DomainContractVersion('domain-clock-v1'),
    );
    expect(
      (byId['start-1']!.payload as TemporalTransitionPayload).competitionRulesContext,
      const CompetitionRulesContext(rulesetId: 'ifab'),
    );
    expect(
      (byId['corr-1']!.payload as CorrectionPayload).competitionRulesContext,
      const CompetitionRulesContext(rulesetId: 'ifab'),
    );
    expect(
      byId['tcorr-1']!.relationships.single,
      isA<CorrectionTarget>().having(
        (link) => link.targetRecordId,
        'targetRecordId',
        'start-1',
      ),
    );
    expect(
      byId['super-1']!.relationships.single,
      isA<LegalSupersessionTarget>().having(
        (link) => link.targetRecordId,
        'targetRecordId',
        'start-1',
      ),
    );

    for (final original in records) {
      final recovered = byId[original.recordId]!;
      expect(identicalCanonicalRecordContent(recovered, original), isTrue);
      expect(recovered.payload.runtimeType, original.payload.runtimeType);
      expect(recovered.schemaVersion, 1);
      expect(recovered.recordKind, original.recordKind);
    }
    await reopened.close();
  });

  test('recovered record resolves and projects identically', () async {
    final file = File('${temp.path}/memory.sqlite');
    final records = [
      _typed(
        recordId: 'start-1',
        originSequence: 1,
        recordKind: RecordKind.temporalFact,
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.matchStarted,
          domainContractVersion: const DomainContractVersion('domain-clock-v1'),
          competitionRulesContext: const CompetitionRulesContext(rulesetId: 'ifab'),
        ),
      ),
      _typed(
        recordId: 'corr-1',
        originSequence: 2,
        recordKind: RecordKind.correction,
        payload: const CorrectionPayload(),
        relationships: [CorrectionTarget(targetRecordId: 'start-1')],
      ),
    ];
    final resolver = ProductionSemanticsResolver();
    final projector = DeterministicMatchProjector(resolver);
    const context = ProjectionContext(evaluatedAuthorityGeneration: 1);
    final before = projector.projectRecords(
      matchId: 'match-1',
      records: records,
      context: context,
    );

    final store = SqliteDurableMatchStore.open(file);
    for (final record in records) {
      expect(await store.commit(record), isA<DurableCommitSuccess>());
    }
    await store.close();

    final reopened = SqliteDurableMatchStore.open(file);
    final recovered = await reopened.readCommittedForMatch('match-1');
    final after = projector.projectRecords(
      matchId: 'match-1',
      records: recovered,
      context: context,
    );

    expect(after, equals(before));
    for (final record in recovered) {
      final original = records.singleWhere((item) => item.recordId == record.recordId);
      expect(resolver.resolve(record), resolver.resolve(original));
    }
    await reopened.close();
  });

  test('malformed typed storage fails closed without synthesizing a record', () async {
    final file = File('${temp.path}/memory.sqlite');
    final valid = _typed(
      recordId: 'start-1',
      originSequence: 1,
      recordKind: RecordKind.temporalFact,
      payload: TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.periodStarted,
        period: const PeriodIdentity(index: 1),
      ),
    );
    final store = SqliteDurableMatchStore.open(file);
    expect(await store.commit(valid), isA<DurableCommitSuccess>());
    await store.close();

    _rewritePayload(file, 'start-1', (payload) {
      payload['unexpectedField'] = 'kept-only-if-guessed';
    });

    final reopened = SqliteDurableMatchStore.open(file);
    expect(
      reopened.getById('start-1'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Unknown'),
        ),
      ),
    );
    await reopened.close();

    _rewritePayload(file, 'start-1', (payload) {
      payload.remove('unexpectedField');
      payload['type'] = 'v1-goal';
    });
    final unsupported = SqliteDurableMatchStore.open(file);
    expect(
      unsupported.getById('start-1'),
      throwsA(isA<FormatException>()),
    );
    await unsupported.close();
  });

  test('unknown schema version for a typed payload fails closed', () async {
    final file = File('${temp.path}/memory.sqlite');
    final store = SqliteDurableMatchStore.open(file);
    expect(
      await store.commit(
        _typed(
          recordId: 'start-1',
          originSequence: 1,
          recordKind: RecordKind.temporalFact,
          payload: TemporalTransitionPayload(
            semanticType: V1SemanticTypeCode.matchAbandoned,
          ),
        ),
      ),
      isA<DurableCommitSuccess>(),
    );
    await store.close();

    final db = sqlite3.open(file.path);
    final raw = db.select(
      'SELECT record_json FROM committed_match_records WHERE record_id = ?',
      ['start-1'],
    ).single.columnAt(0) as String;
    final json = jsonDecode(raw) as Map<String, Object?>;
    json['schemaVersion'] = 2;
    db.execute(
      'UPDATE committed_match_records SET record_json = ? WHERE record_id = ?',
      [jsonEncode(json), 'start-1'],
    );
    db.close();

    final reopened = SqliteDurableMatchStore.open(file);
    expect(reopened.getById('start-1'), throwsA(isA<FormatException>()));
    await reopened.close();
  });

  test('failed encoding writes no authoritative row', () async {
    final file = File('${temp.path}/memory.sqlite');
    final store = SqliteDurableMatchStore.open(file);
    final outcome = await store.commit(
      _typed(
        recordId: 'opaque-1',
        originSequence: 1,
        recordKind: RecordKind.occurrence,
        payload: const _UnencodablePayload(),
      ),
    );

    expect(outcome, isA<DurableCommitFailure>());
    expect(
      (outcome as DurableCommitFailure).reason,
      contains('cannot encode authoritative record'),
    );
    expect(await store.getById('opaque-1'), isNull);
    await store.close();

    final db = sqlite3.open(file.path);
    final count = db.select('SELECT COUNT(*) FROM committed_match_records');
    expect(count.single.columnAt(0), 0);
    db.close();
  });

  test('idempotent duplicate still works after reopen', () async {
    final file = File('${temp.path}/memory.sqlite');
    final record = _typed(
      recordId: 'start-1',
      originSequence: 1,
      recordKind: RecordKind.temporalFact,
      payload: TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.matchStarted,
        domainContractVersion: const DomainContractVersion('domain-clock-v1'),
      ),
      relationships: [CausalDependency(targetRecordId: 'cause-1')],
    );

    final store = SqliteDurableMatchStore.open(file);
    expect(await store.commit(record), isA<DurableCommitSuccess>());
    await store.close();

    final reopened = SqliteDurableMatchStore.open(file);
    final replay = await reopened.commit(record);
    expect(replay, isA<DurableCommitSuccess>());
    expect((replay as DurableCommitSuccess).diagnostics, contains('idempotent-no-op'));
    expect(await reopened.readCommittedForMatch('match-1'), hasLength(1));
    await reopened.close();
  });

  test('structured payload is not upgraded from record kind', () async {
    final file = File('${temp.path}/memory.sqlite');
    final record = MatchRecord(
      recordId: 'legacy-shape',
      matchId: 'match-1',
      recordKind: RecordKind.temporalFact,
      schemaVersion: 1,
      recordedAt: DateTime.utc(2026, 10, 2, 12),
      originDeviceId: 'dev-a',
      originSequence: 1,
      payload: StructuredPayload({
        'semanticType': 'MATCH_STARTED',
      }),
      integrity: const IntegrityMetadata(evidenceRefs: ['evidence-1']),
    );

    final store = SqliteDurableMatchStore.open(file);
    expect(await store.commit(record), isA<DurableCommitSuccess>());
    await store.close();

    final reopened = SqliteDurableMatchStore.open(file);
    final loaded = await reopened.getById('legacy-shape');
    expect(loaded!.payload, isA<StructuredPayload>());
    expect(
      (loaded.payload as StructuredPayload).fields['semanticType'],
      'MATCH_STARTED',
    );
    await reopened.close();
  });

  test('PERIOD_STARTED period index survives close and reopen', () async {
    final file = File('${temp.path}/memory.sqlite');
    final record = _typed(
      recordId: 'period-1',
      originSequence: 1,
      recordKind: RecordKind.temporalFact,
      payload: TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.periodStarted,
        period: const PeriodIdentity(index: 1),
        competitionRulesContext: const CompetitionRulesContext(rulesetId: 'ifab'),
      ),
      relationships: [CausalDependency(targetRecordId: 'start-1')],
    );
    final store = SqliteDurableMatchStore.open(file);
    expect(await store.commit(record), isA<DurableCommitSuccess>());
    await store.close();

    final reopened = SqliteDurableMatchStore.open(file);
    final loaded = (await reopened.readCommittedForMatch('match-1')).single;
    final payload = loaded.payload as TemporalTransitionPayload;
    expect(payload.semanticType, V1SemanticTypeCode.periodStarted);
    expect(payload.period, const PeriodIdentity(index: 1));
    expect(loaded.relationships.single, isA<CausalDependency>());
    expect(
      (loaded.relationships.single as CausalDependency).targetRecordId,
      'start-1',
    );
    expect(identicalCanonicalRecordContent(loaded, record), isTrue);
    await reopened.close();
  });

  test('TEMPORARY_SUSPENSION_STARTED keeps its period and fails without it', () async {
    final file = File('${temp.path}/memory.sqlite');
    final record = _typed(
      recordId: 'susp-1',
      originSequence: 1,
      recordKind: RecordKind.temporalFact,
      payload: TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.temporarySuspensionStarted,
        period: const PeriodIdentity(index: 1),
      ),
      relationships: [CausalDependency(targetRecordId: 'period-1')],
    );
    final store = SqliteDurableMatchStore.open(file);
    expect(await store.commit(record), isA<DurableCommitSuccess>());
    await store.close();

    final reopened = SqliteDurableMatchStore.open(file);
    final loaded = (await reopened.readCommittedForMatch('match-1')).single;
    final payload = loaded.payload as TemporalTransitionPayload;
    expect(payload.semanticType, V1SemanticTypeCode.temporarySuspensionStarted);
    expect(payload.period, const PeriodIdentity(index: 1));
    expect(
      (loaded.relationships.single as CausalDependency).targetRecordId,
      'period-1',
    );
    expect(identicalCanonicalRecordContent(loaded, record), isTrue);
    await reopened.close();

    _rewritePayload(file, 'susp-1', (stored) {
      stored.remove('periodIndex');
    });
    final broken = SqliteDurableMatchStore.open(file);
    expect(broken.getById('susp-1'), throwsA(isA<FormatException>()));
    await broken.close();
  });

  test('MATCH_ENDED and explicit phase disposition survive without schema v2', () async {
    final file = File('${temp.path}/memory.sqlite');
    final record = _typed(
      recordId: 'end-match',
      originSequence: 1,
      recordKind: RecordKind.temporalFact,
      payload: TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.matchEnded,
        competitionRulesContext: const CompetitionRulesContext(
          rulesetId: 'cup',
          additionalPlayingPhase: AdditionalPlayingPhaseDisposition.noneRequired,
          penaltyShootOutAfterMatchEnd: true,
        ),
      ),
      relationships: [CausalDependency(targetRecordId: 'period-end')],
    );
    final store = SqliteDurableMatchStore.open(file);
    expect(await store.commit(record), isA<DurableCommitSuccess>());
    await store.close();

    final reopened = SqliteDurableMatchStore.open(file);
    final loaded = (await reopened.readCommittedForMatch('match-1')).single;
    final payload = loaded.payload as TemporalTransitionPayload;
    expect(payload.semanticType, V1SemanticTypeCode.matchEnded);
    expect(payload.period, isNull);
    expect(loaded.schemaVersion, 1);
    expect(
      payload.competitionRulesContext,
      const CompetitionRulesContext(
        rulesetId: 'cup',
        additionalPlayingPhase: AdditionalPlayingPhaseDisposition.noneRequired,
        penaltyShootOutAfterMatchEnd: true,
      ),
    );
    expect(identicalCanonicalRecordContent(loaded, record), isTrue);
    await reopened.close();
  });
}

void _rewritePayload(
  File file,
  String recordId,
  void Function(Map<String, Object?> payload) mutate,
) {
  final db = sqlite3.open(file.path);
  final raw = db.select(
    'SELECT record_json FROM committed_match_records WHERE record_id = ?',
    [recordId],
  ).single.columnAt(0) as String;
  final json = jsonDecode(raw) as Map<String, Object?>;
  final payload = Map<String, Object?>.from(json['payload']! as Map);
  mutate(payload);
  json['payload'] = payload;
  db.execute(
    'UPDATE committed_match_records SET record_json = ? WHERE record_id = ?',
    [jsonEncode(json), recordId],
  );
  db.close();
}

MatchRecord _typed({
  required String recordId,
  required int originSequence,
  required RecordKind recordKind,
  required MatchRecordPayload payload,
  List<RecordRelationship> relationships = const [],
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: 'match-1',
    recordKind: recordKind,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 2, 12, originSequence),
    originDeviceId: 'dev-a',
    originSequence: originSequence,
    payload: payload,
    integrity: const IntegrityMetadata(evidenceRefs: ['evidence-1']),
    temporalContext: const TemporalContext(
      evidenceIds: ['clock-1'],
      domainClockPolicyVersion: 'domain-clock-v1',
    ),
    authorityContext: const AuthorityContext(
      scope: v1AuthorityScope,
      principal: AuthorityPrincipal(principalId: 'ref-1'),
      activeCaptureDevice: ActiveCaptureDevice(deviceId: 'phone-a'),
      generation: AuthorityGeneration(value: 1),
    ),
    relationships: relationships,
  );
}

final class _UnencodablePayload extends MatchRecordPayload {
  const _UnencodablePayload();
}
