import '../disciplinary_subject.dart';
import '../match_participant.dart';
import '../match_record.dart';
import '../match_team.dart';
import '../record_kind.dart';
import '../semantics/match_record_semantic_type.dart';
import '../semantics/production_semantics_resolver.dart';
import '../semantics/v1_semantic_payload.dart';
import 'deterministic_match_projector.dart';
import 'effective_goal_resolver.dart';
import 'effective_send_off_resolver.dart';
import 'effective_yellow_resolver.dart';
import 'participant_status_projection.dart';
import 'projection_context.dart';
import 'projection_semantics_resolver.dart';
import 'projection_trust.dart';
import 'score_projection.dart';
import 'temporal_match_projection.dart';

/// Whether the committed history could be read.
enum MatchReportReadiness {
  readable,
  unreadable,
}

/// Report-line trust. These values are not a Saved acknowledgement.
enum MatchReportClassification {
  known,
  conflict,
  unavailable,
  unverified,
  incomplete,
}

/// Event and temporal lines do not carry a match minute.
///
/// Goal, Yellow, send-off, and substitution payloads have no authoritative
/// elapsed field. [recordedAt] and evidence ids are chronology, not the minute.
enum MatchReportTimeFact {
  exactMatchTimeUnavailable,
}

enum MatchReportFacetId {
  score,
  temporal,
  goal,
  yellow,
  sendOff,
  substitution,
}

enum MatchReportEntryKind {
  goal,
  yellow,
  sendOff,
  substitution,
  temporal,
}

/// One facet of the report. Empty known sets mean no effective records.
final class MatchReportFacet {
  const MatchReportFacet({
    required this.facetId,
    required this.classification,
  });

  final MatchReportFacetId facetId;
  final MatchReportClassification classification;

  @override
  bool operator ==(Object other) =>
      other is MatchReportFacet &&
      facetId == other.facetId &&
      classification == other.classification;

  @override
  int get hashCode => Object.hash(facetId, classification);
}

/// One report line rebuilt from a committed record.
sealed class MatchReportEntry {
  const MatchReportEntry({
    required this.classification,
    required this.recordId,
    required this.originDeviceId,
    required this.originSequence,
  });

  final MatchReportClassification classification;
  final String recordId;
  final String originDeviceId;
  final int originSequence;

  MatchReportEntryKind get kind;

  /// Always unavailable. This type has no minute field to fill in.
  MatchReportTimeFact get timeFact =>
      MatchReportTimeFact.exactMatchTimeUnavailable;

  @override
  bool operator ==(Object other) =>
      other is MatchReportEntry &&
      runtimeType == other.runtimeType &&
      classification == other.classification &&
      recordId == other.recordId &&
      originDeviceId == other.originDeviceId &&
      originSequence == other.originSequence &&
      _sameFacts(other);

  bool _sameFacts(MatchReportEntry other);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        classification,
        recordId,
        originDeviceId,
        originSequence,
        _factHash,
      );

  int get _factHash;
}

final class GoalReportEntry extends MatchReportEntry {
  const GoalReportEntry({
    required super.classification,
    required super.recordId,
    required super.originDeviceId,
    required super.originSequence,
    required this.scoringTeamId,
  });

  final MatchTeamId scoringTeamId;

  @override
  MatchReportEntryKind get kind => MatchReportEntryKind.goal;

  @override
  bool _sameFacts(MatchReportEntry other) =>
      other is GoalReportEntry && scoringTeamId == other.scoringTeamId;

  @override
  int get _factHash => scoringTeamId.hashCode;
}

final class YellowReportEntry extends MatchReportEntry {
  const YellowReportEntry({
    required super.classification,
    required super.recordId,
    required super.originDeviceId,
    required super.originSequence,
    required this.subject,
    required this.accountingScope,
    required this.standing,
    required this.yellowSchemaVersion,
  });

  final DisciplinarySubjectRef subject;
  final DisciplinaryAccountingScope accountingScope;
  final bool standing;
  final int yellowSchemaVersion;

  @override
  MatchReportEntryKind get kind => MatchReportEntryKind.yellow;

  @override
  bool _sameFacts(MatchReportEntry other) =>
      other is YellowReportEntry &&
      subject == other.subject &&
      accountingScope == other.accountingScope &&
      standing == other.standing &&
      yellowSchemaVersion == other.yellowSchemaVersion;

  @override
  int get _factHash => Object.hash(
        subject,
        accountingScope,
        standing,
        yellowSchemaVersion,
      );
}

final class SendOffReportEntry extends MatchReportEntry {
  const SendOffReportEntry({
    required super.classification,
    required super.recordId,
    required super.originDeviceId,
    required super.originSequence,
    required this.subject,
    required this.accountingScope,
    required this.pathway,
    required this.legallyEffective,
    required this.dependencyStatus,
  });

  final DisciplinarySubjectRef subject;
  final DisciplinaryAccountingScope accountingScope;
  final SendOffPathway pathway;
  final bool legallyEffective;
  final SendOffDependencyStatus dependencyStatus;

  @override
  MatchReportEntryKind get kind => MatchReportEntryKind.sendOff;

  @override
  bool _sameFacts(MatchReportEntry other) =>
      other is SendOffReportEntry &&
      subject == other.subject &&
      accountingScope == other.accountingScope &&
      pathway == other.pathway &&
      legallyEffective == other.legallyEffective &&
      dependencyStatus == other.dependencyStatus;

  @override
  int get _factHash => Object.hash(
        subject,
        accountingScope,
        pathway,
        legallyEffective,
        dependencyStatus,
      );
}

final class SubstitutionReportEntry extends MatchReportEntry {
  const SubstitutionReportEntry({
    required super.classification,
    required super.recordId,
    required super.originDeviceId,
    required super.originSequence,
    required this.outgoingParticipantId,
    required this.incomingParticipantId,
    required this.teamId,
    required this.legallyEffective,
  });

  final MatchParticipantId outgoingParticipantId;
  final MatchParticipantId incomingParticipantId;
  final MatchTeamId teamId;
  final bool legallyEffective;

  @override
  MatchReportEntryKind get kind => MatchReportEntryKind.substitution;

  @override
  bool _sameFacts(MatchReportEntry other) =>
      other is SubstitutionReportEntry &&
      outgoingParticipantId == other.outgoingParticipantId &&
      incomingParticipantId == other.incomingParticipantId &&
      teamId == other.teamId &&
      legallyEffective == other.legallyEffective;

  @override
  int get _factHash => Object.hash(
        outgoingParticipantId,
        incomingParticipantId,
        teamId,
        legallyEffective,
      );
}

final class TemporalReportEntry extends MatchReportEntry {
  const TemporalReportEntry({
    required super.classification,
    required super.recordId,
    required super.originDeviceId,
    required super.originSequence,
    required this.semanticType,
    this.period,
  });

  final V1SemanticTypeCode semanticType;
  final PeriodIdentity? period;

  @override
  MatchReportEntryKind get kind => MatchReportEntryKind.temporal;

  @override
  bool _sameFacts(MatchReportEntry other) =>
      other is TemporalReportEntry &&
      semanticType == other.semanticType &&
      period == other.period;

  @override
  int get _factHash => Object.hash(semanticType, period);
}

/// Disposable match report. Rebuild it from committed records. Do not store it.
final class MatchReportProjection {
  MatchReportProjection({
    required this.matchId,
    required this.readiness,
    required this.score,
    required this.temporal,
    required List<MatchReportEntry> entries,
    required List<MatchReportFacet> facets,
    required List<String> unsupportedRecordIds,
  })  : entries = List.unmodifiable(entries),
        facets = List.unmodifiable(facets),
        unsupportedRecordIds = List.unmodifiable(unsupportedRecordIds);

  factory MatchReportProjection.unreadable(String matchId) {
    return MatchReportProjection(
      matchId: matchId,
      readiness: MatchReportReadiness.unreadable,
      score: const ScoreUnavailable(),
      temporal: TemporalMatchProjection.empty,
      entries: const [],
      facets: [
        for (final facetId in MatchReportFacetId.values)
          MatchReportFacet(
            facetId: facetId,
            classification: MatchReportClassification.unavailable,
          ),
      ],
      unsupportedRecordIds: const [],
    );
  }

  final String matchId;
  final MatchReportReadiness readiness;
  final ScoreProjection score;
  final TemporalMatchProjection temporal;
  final List<MatchReportEntry> entries;
  final List<MatchReportFacet> facets;
  final List<String> unsupportedRecordIds;

  MatchReportFacet facet(MatchReportFacetId facetId) =>
      facets.firstWhere((facet) => facet.facetId == facetId);

  @override
  bool operator ==(Object other) {
    return other is MatchReportProjection &&
        matchId == other.matchId &&
        readiness == other.readiness &&
        score == other.score &&
        _temporalEquals(temporal, other.temporal) &&
        _listEquals(entries, other.entries) &&
        _listEquals(facets, other.facets) &&
        _listEquals(unsupportedRecordIds, other.unsupportedRecordIds);
  }

  @override
  int get hashCode => Object.hash(
        matchId,
        readiness,
        score,
        Object.hashAll(entries),
        Object.hashAll(facets),
        Object.hashAll(unsupportedRecordIds),
        temporal.matchStarted,
        temporal.activePeriod,
        temporal.endedPeriod,
      );
}

/// Rebuilds a match report from committed records and the existing projectors.
///
/// Score numerals come only from [DeterministicMatchProjector]. This function
/// does not count goals into a score and does not invent a match minute.
MatchReportProjection projectMatchReport({
  required String matchId,
  required List<MatchRecord> records,
  required ProjectionContext context,
  ProjectionSemanticsResolver? semanticsResolver,
}) {
  final owned = [
    for (final record in records)
      if (record.matchId == matchId) record,
  ];
  final state = DeterministicMatchProjector(
    semanticsResolver ?? ProductionSemanticsResolver(),
  ).projectRecords(
    matchId: matchId,
    records: owned,
    context: context,
  );
  final temporal = TemporalMatchProjection.derive(
    projection: state,
    records: owned,
  );
  final byId = {for (final record in owned) record.recordId: record};
  final goals = resolveEffectiveGoals(recordsById: byId);
  final yellows = resolveEffectiveYellows(recordsById: byId);
  final sendOffs = resolveEffectiveSendOffs(recordsById: byId);
  final substitutions = resolveEffectiveSubstitutions(recordsById: byId);

  final entries = <MatchReportEntry>[
    ..._goalEntries(goals, byId),
    ..._yellowEntries(yellows, byId),
    ..._sendOffEntries(sendOffs, byId),
    ..._substitutionEntries(substitutions, byId),
    ..._temporalEntries(
      owned,
      _classificationForTrust(state.trustFor(ProjectionFacet.temporal)),
    ),
  ]..sort((a, b) {
      final left = byId[a.recordId]!;
      final right = byId[b.recordId]!;
      return deterministicRecordOrder(left, right);
    });

  final unsupported = [...state.unsupportedSemanticRecordIds]..sort();
  return MatchReportProjection(
    matchId: matchId,
    readiness: MatchReportReadiness.readable,
    score: state.scoreProjection,
    temporal: temporal,
    entries: entries,
    facets: [
      MatchReportFacet(
        facetId: MatchReportFacetId.score,
        classification: _scoreClassification(state.scoreProjection),
      ),
      MatchReportFacet(
        facetId: MatchReportFacetId.temporal,
        classification:
            _classificationForTrust(state.trustFor(ProjectionFacet.temporal)),
      ),
      MatchReportFacet(
        facetId: MatchReportFacetId.goal,
        classification: _goalFacet(goals, entries),
      ),
      MatchReportFacet(
        facetId: MatchReportFacetId.yellow,
        classification: _yellowFacet(yellows, entries),
      ),
      MatchReportFacet(
        facetId: MatchReportFacetId.sendOff,
        classification: _sendOffFacet(sendOffs, entries),
      ),
      MatchReportFacet(
        facetId: MatchReportFacetId.substitution,
        classification: _substitutionFacet(substitutions, entries),
      ),
    ],
    unsupportedRecordIds: unsupported,
  );
}

List<GoalReportEntry> _goalEntries(
  EffectiveGoalResolution resolution,
  Map<String, MatchRecord> byId,
) {
  if (resolution is! EffectiveGoalSet) return const [];
  return [
    for (final goal in resolution.goals)
      GoalReportEntry(
        classification: MatchReportClassification.known,
        recordId: goal.goalRecordId,
        originDeviceId: byId[goal.goalRecordId]!.originDeviceId,
        originSequence: byId[goal.goalRecordId]!.originSequence,
        scoringTeamId: goal.scoringTeamId,
      ),
  ];
}

List<YellowReportEntry> _yellowEntries(
  EffectiveYellowResolution resolution,
  Map<String, MatchRecord> byId,
) {
  if (resolution is! EffectiveYellowSet) return const [];
  return [
    for (final yellow in resolution.yellows)
      YellowReportEntry(
        classification: MatchReportClassification.known,
        recordId: yellow.yellowRecordId,
        originDeviceId: byId[yellow.yellowRecordId]!.originDeviceId,
        originSequence: byId[yellow.yellowRecordId]!.originSequence,
        subject: yellow.subject,
        accountingScope: yellow.accountingScope,
        standing: yellow.standing,
        yellowSchemaVersion: yellow.yellowSchemaVersion,
      ),
  ];
}

List<SendOffReportEntry> _sendOffEntries(
  EffectiveSendOffResolution resolution,
  Map<String, MatchRecord> byId,
) {
  if (resolution is! EffectiveSendOffSet) return const [];
  return [
    for (final sendOff in resolution.sendOffs)
      SendOffReportEntry(
        classification: switch (sendOff.dependencyStatus) {
          SendOffDependencyStatus.ready => MatchReportClassification.known,
          SendOffDependencyStatus.conflicted =>
            MatchReportClassification.conflict,
          SendOffDependencyStatus.unavailable =>
            MatchReportClassification.unavailable,
        },
        recordId: sendOff.sendOffRecordId,
        originDeviceId: byId[sendOff.sendOffRecordId]!.originDeviceId,
        originSequence: byId[sendOff.sendOffRecordId]!.originSequence,
        subject: sendOff.subject,
        accountingScope: sendOff.scope,
        pathway: sendOff.pathway,
        legallyEffective: sendOff.legallyEffective,
        dependencyStatus: sendOff.dependencyStatus,
      ),
  ];
}

List<SubstitutionReportEntry> _substitutionEntries(
  EffectiveSubstitutionResolution resolution,
  Map<String, MatchRecord> byId,
) {
  if (resolution is! EffectiveSubstitutionSet) return const [];
  return [
    for (final substitution in resolution.substitutions)
      SubstitutionReportEntry(
        classification: MatchReportClassification.known,
        recordId: substitution.substitutionRecordId,
        originDeviceId: substitution.originDeviceId,
        originSequence: substitution.originSequence,
        outgoingParticipantId: substitution.outgoingParticipantId,
        incomingParticipantId: substitution.incomingParticipantId,
        teamId: substitution.teamId,
        legallyEffective: substitution.legallyEffective,
      ),
  ];
}

List<TemporalReportEntry> _temporalEntries(
  List<MatchRecord> records,
  MatchReportClassification classification,
) {
  final entries = <TemporalReportEntry>[];
  for (final record in records) {
    final payload = record.payload;
    if (payload is! TemporalTransitionPayload) continue;
    if (record.recordKind != RecordKind.temporalFact) continue;
    entries.add(
      TemporalReportEntry(
        classification: classification,
        recordId: record.recordId,
        originDeviceId: record.originDeviceId,
        originSequence: record.originSequence,
        semanticType: payload.semanticType,
        period: payload.period,
      ),
    );
  }
  return entries;
}

MatchReportClassification _scoreClassification(ScoreProjection score) {
  return switch (score) {
    KnownScore() => MatchReportClassification.known,
    ScoreConflicted() => MatchReportClassification.conflict,
    ScoreUnavailable() => MatchReportClassification.unavailable,
  };
}

MatchReportClassification _classificationForTrust(ProjectionTrust trust) {
  return switch (trust) {
    ProjectionTrust.trusted => MatchReportClassification.known,
    ProjectionTrust.conflicted => MatchReportClassification.conflict,
    ProjectionTrust.incomplete => MatchReportClassification.incomplete,
    ProjectionTrust.untrusted => MatchReportClassification.unverified,
  };
}

MatchReportClassification _goalFacet(
  EffectiveGoalResolution resolution,
  List<MatchReportEntry> entries,
) {
  return switch (resolution) {
    EffectiveGoalConflicted() => MatchReportClassification.conflict,
    EffectiveGoalUnavailable() => MatchReportClassification.unavailable,
    EffectiveGoalSet() => _strictest(
        entries.where((entry) => entry.kind == MatchReportEntryKind.goal),
      ),
  };
}

MatchReportClassification _yellowFacet(
  EffectiveYellowResolution resolution,
  List<MatchReportEntry> entries,
) {
  return switch (resolution) {
    EffectiveYellowConflicted() => MatchReportClassification.conflict,
    EffectiveYellowUnavailable() => MatchReportClassification.unavailable,
    EffectiveYellowSet() => _strictest(
        entries.where((entry) => entry.kind == MatchReportEntryKind.yellow),
      ),
  };
}

MatchReportClassification _sendOffFacet(
  EffectiveSendOffResolution resolution,
  List<MatchReportEntry> entries,
) {
  return switch (resolution) {
    EffectiveSendOffConflicted() => MatchReportClassification.conflict,
    EffectiveSendOffUnavailable() => MatchReportClassification.unavailable,
    EffectiveSendOffSet() => _strictest(
        entries.where((entry) => entry.kind == MatchReportEntryKind.sendOff),
      ),
  };
}

MatchReportClassification _substitutionFacet(
  EffectiveSubstitutionResolution resolution,
  List<MatchReportEntry> entries,
) {
  return switch (resolution) {
    EffectiveSubstitutionConflicted() => MatchReportClassification.conflict,
    EffectiveSubstitutionUnavailable() => MatchReportClassification.unavailable,
    EffectiveSubstitutionSet() => _strictest(
        entries
            .where((entry) => entry.kind == MatchReportEntryKind.substitution),
      ),
  };
}

MatchReportClassification _strictest(Iterable<MatchReportEntry> entries) {
  var sawUnavailable = false;
  var sawIncomplete = false;
  var sawUnverified = false;
  for (final entry in entries) {
    switch (entry.classification) {
      case MatchReportClassification.conflict:
        return MatchReportClassification.conflict;
      case MatchReportClassification.unavailable:
        sawUnavailable = true;
      case MatchReportClassification.incomplete:
        sawIncomplete = true;
      case MatchReportClassification.unverified:
        sawUnverified = true;
      case MatchReportClassification.known:
        break;
    }
  }
  if (sawUnavailable) return MatchReportClassification.unavailable;
  if (sawIncomplete) return MatchReportClassification.incomplete;
  if (sawUnverified) return MatchReportClassification.unverified;
  return MatchReportClassification.known;
}

bool _temporalEquals(TemporalMatchProjection a, TemporalMatchProjection b) {
  return a.matchStarted == b.matchStarted &&
      a.activePeriod == b.activePeriod &&
      a.endedPeriod == b.endedPeriod &&
      a.periodEndAmbiguous == b.periodEndAmbiguous &&
      a.intervalActive == b.intervalActive &&
      a.temporallyIncomplete == b.temporallyIncomplete &&
      a.formallySuspended == b.formallySuspended &&
      a.bothOrdinaryPeriodsEnded == b.bothOrdinaryPeriodsEnded &&
      a.matchNormallyEnded == b.matchNormallyEnded &&
      _listEquals(a.endedPeriods, b.endedPeriods);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
