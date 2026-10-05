import 'package:forref_match_core/forref_match_core.dart';

/// Isolated synthetic Match Records compatible with production V1 contracts.
abstract final class MatchRecordFixtures {
  static const matchId = 'bench-match-1';
  static const originDeviceId = 'bench-device-a';
  static const authorityGeneration = 1;

  /// Scenario A — normal match timeline (~12 records).
  static List<MatchRecord> scenarioANormalTimeline() {
    final records = <MatchRecord>[];
    var seq = 1;
    records.add(_temporal(
      recordId: 'a-match-started',
      originSequence: seq++,
      semanticType: V1SemanticTypeCode.matchStarted,
    ));
    records.add(_temporal(
      recordId: 'a-period-1-started',
      originSequence: seq++,
      semanticType: V1SemanticTypeCode.periodStarted,
      period: const PeriodIdentity(index: 1),
      relationships: [CausalDependency(targetRecordId: 'a-match-started')],
    ));
    for (var goal = 1; goal <= 3; goal++) {
      records.add(_structured(
        recordId: 'a-goal-$goal',
        originSequence: seq++,
        fields: {'event': 'goal', 'team': goal.isOdd ? 'home' : 'away'},
      ));
    }
    records.add(_temporal(
      recordId: 'a-period-1-ended',
      originSequence: seq++,
      semanticType: V1SemanticTypeCode.periodEnded,
      period: const PeriodIdentity(index: 1),
      relationships: [CausalDependency(targetRecordId: 'a-period-1-started')],
    ));
    records.add(_temporal(
      recordId: 'a-period-2-started',
      originSequence: seq++,
      semanticType: V1SemanticTypeCode.periodStarted,
      period: const PeriodIdentity(index: 2),
      relationships: [CausalDependency(targetRecordId: 'a-period-1-ended')],
    ));
    for (var card = 1; card <= 2; card++) {
      records.add(_structured(
        recordId: 'a-card-$card',
        originSequence: seq++,
        fields: {'event': 'card', 'color': card == 1 ? 'yellow' : 'red'},
      ));
    }
    records.add(_temporal(
      recordId: 'a-period-2-ended',
      originSequence: seq++,
      semanticType: V1SemanticTypeCode.periodEnded,
      period: const PeriodIdentity(index: 2),
      relationships: [CausalDependency(targetRecordId: 'a-period-2-started')],
    ));
    records.add(_temporal(
      recordId: 'a-match-ended',
      originSequence: seq++,
      semanticType: V1SemanticTypeCode.matchEnded,
      relationships: [CausalDependency(targetRecordId: 'a-period-2-ended')],
    ));
    return records;
  }

  /// Scenario B — suspension-heavy timeline.
  static List<MatchRecord> scenarioBSuspensionHeavy() {
    final records = <MatchRecord>[];
    var seq = 1;
    records.add(_temporal(
      recordId: 'b-match-started',
      originSequence: seq++,
      semanticType: V1SemanticTypeCode.matchStarted,
    ));
    records.add(_temporal(
      recordId: 'b-period-1-started',
      originSequence: seq++,
      semanticType: V1SemanticTypeCode.periodStarted,
      period: const PeriodIdentity(index: 1),
      relationships: [CausalDependency(targetRecordId: 'b-match-started')],
    ));
    var periodStartId = 'b-period-1-started';
    for (var cycle = 1; cycle <= 8; cycle++) {
      records.add(_temporal(
        recordId: 'b-susp-$cycle-start',
        originSequence: seq++,
        semanticType: V1SemanticTypeCode.temporarySuspensionStarted,
        period: const PeriodIdentity(index: 1),
        relationships: [CausalDependency(targetRecordId: periodStartId)],
      ));
      records.add(_temporal(
        recordId: 'b-susp-$cycle-end',
        originSequence: seq++,
        semanticType: V1SemanticTypeCode.temporarySuspensionEnded,
        period: const PeriodIdentity(index: 1),
        relationships: [CausalDependency(targetRecordId: 'b-susp-$cycle-start')],
      ));
    }
    records.add(_temporal(
      recordId: 'b-period-1-ended',
      originSequence: seq++,
      semanticType: V1SemanticTypeCode.periodEnded,
      period: const PeriodIdentity(index: 1),
      relationships: [CausalDependency(targetRecordId: periodStartId)],
    ));
    return records;
  }

  /// Scenario C — synthetic Match Memory of [count] records.
  static List<MatchRecord> scenarioCSynthetic({required int count}) {
    if (count < 2) {
      throw ArgumentError.value(count, 'count', 'must be >= 2');
    }
    final records = <MatchRecord>[];
    records.add(_temporal(
      recordId: 'c-match-started',
      originSequence: 1,
      semanticType: V1SemanticTypeCode.matchStarted,
    ));
    records.add(_temporal(
      recordId: 'c-period-1-started',
      originSequence: 2,
      semanticType: V1SemanticTypeCode.periodStarted,
      period: const PeriodIdentity(index: 1),
      relationships: [CausalDependency(targetRecordId: 'c-match-started')],
    ));
    for (var i = 3; i <= count; i++) {
      final isSuspension = i.isOdd;
      records.add(_temporal(
        recordId: 'c-rec-$i',
        originSequence: i,
        semanticType: isSuspension
            ? V1SemanticTypeCode.temporarySuspensionStarted
            : V1SemanticTypeCode.temporarySuspensionEnded,
        period: const PeriodIdentity(index: 1),
        relationships: [
          CausalDependency(
            targetRecordId: isSuspension ? 'c-period-1-started' : 'c-rec-${i - 1}',
          ),
        ],
      ));
    }
    return records;
  }

  /// Representative production record for encoding microbenchmark.
  static MatchRecord representativeProductionRecord() {
    return _temporal(
      recordId: 'enc-representative',
      originSequence: 42,
      semanticType: V1SemanticTypeCode.periodStarted,
      period: const PeriodIdentity(index: 1),
      relationships: [CausalDependency(targetRecordId: 'enc-match-started')],
    );
  }

  static AuthoritativeRecordCommitRequest commitRequest({
    required String recordId,
    MatchRecordPayload? payload,
  }) {
    return AuthoritativeRecordCommitRequest(
      recordId: recordId,
      matchId: matchId,
      originDeviceId: originDeviceId,
      recordKind: RecordKind.temporalFact,
      schemaVersion: 1,
      recordedAt: DateTime.utc(2026, 10, 4, 12),
      payload: payload ??
          TemporalTransitionPayload(
            semanticType: V1SemanticTypeCode.matchStarted,
            domainContractVersion: const DomainContractVersion('domain-clock-v1'),
            competitionRulesContext: const CompetitionRulesContext(rulesetId: 'ifab'),
          ),
      integrity: const IntegrityMetadata(evidenceRefs: ['evidence-1']),
      temporalContext: const TemporalContext(
        evidenceIds: ['clock-1'],
        domainClockPolicyVersion: 'domain-clock-v1',
      ),
      authorityContext: const AuthorityContext(
        scope: v1AuthorityScope,
        principal: AuthorityPrincipal(principalId: 'ref-bench'),
        activeCaptureDevice: ActiveCaptureDevice(deviceId: originDeviceId),
        generation: AuthorityGeneration(value: authorityGeneration),
      ),
    );
  }

  static MatchRecord _temporal({
    required String recordId,
    required int originSequence,
    required V1SemanticTypeCode semanticType,
    PeriodIdentity? period,
    List<RecordRelationship> relationships = const [],
  }) {
    return MatchRecord(
      recordId: recordId,
      matchId: matchId,
      recordKind: RecordKind.temporalFact,
      schemaVersion: 1,
      recordedAt: DateTime.utc(2026, 10, 4, 12, originSequence),
      originDeviceId: originDeviceId,
      originSequence: originSequence,
      payload: TemporalTransitionPayload(
        semanticType: semanticType,
        period: period,
        domainContractVersion: const DomainContractVersion('domain-clock-v1'),
        competitionRulesContext: const CompetitionRulesContext(rulesetId: 'ifab'),
      ),
      integrity: const IntegrityMetadata(evidenceRefs: ['evidence-1']),
      temporalContext: const TemporalContext(
        evidenceIds: ['clock-1'],
        domainClockPolicyVersion: 'domain-clock-v1',
      ),
      authorityContext: const AuthorityContext(
        scope: v1AuthorityScope,
        principal: AuthorityPrincipal(principalId: 'ref-bench'),
        activeCaptureDevice: ActiveCaptureDevice(deviceId: originDeviceId),
        generation: AuthorityGeneration(value: authorityGeneration),
      ),
      relationships: relationships,
    );
  }

  static MatchRecord _structured({
    required String recordId,
    required int originSequence,
    required Map<String, Object?> fields,
  }) {
    return MatchRecord(
      recordId: recordId,
      matchId: matchId,
      recordKind: RecordKind.occurrence,
      schemaVersion: 1,
      recordedAt: DateTime.utc(2026, 10, 4, 12, originSequence),
      originDeviceId: originDeviceId,
      originSequence: originSequence,
      payload: StructuredPayload(fields),
      integrity: const IntegrityMetadata(evidenceRefs: ['evidence-1']),
      authorityContext: const AuthorityContext(
        scope: v1AuthorityScope,
        principal: AuthorityPrincipal(principalId: 'ref-bench'),
        activeCaptureDevice: ActiveCaptureDevice(deviceId: originDeviceId),
        generation: AuthorityGeneration(value: authorityGeneration),
      ),
    );
  }
}
