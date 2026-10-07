import 'package:flutter_test/flutter_test.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/features/live_match/goal_time_label.dart';
import 'package:referee_phone/features/live_match/yellow_card_read_surface.dart';
import 'package:referee_phone/features/match_summary/match_summary_read_surface.dart';
import 'package:referee_phone/l10n/app_localizations_en.dart';
void main() {
  final l10n = AppLocalizationsEn();
  const rules = CompetitionRulesContext(
    rulesetId: 'ifab',
    disciplinarySystem: DisciplinarySystem.ordinaryIfab,
  );
  final homeSeven = _participant(
    'mpid-home-7',
    ParticipantTeamSide.home,
    const RosterLinkedBinding(rosterParticipantId: 'home-7'),
  );

  test('legacy yellow policy distinguishes authority, legacy-only, and mixed', () {
    final disciplinary = DisciplinaryMatchProjection.derive(
      records: [
        _registered(1, homeSeven),
        _yellow(2, 'yc-1', homeSeven, intent: 'i1'),
      ],
      evaluatedAuthorityGeneration: 1,
      competitionRules: rules,
    );
    expect(
      legacyYellowDataPolicy(legacyEvents: const [], disciplinary: disciplinary),
      LegacyYellowDataPolicy.authorityOnly,
    );
    final legacyEvent = MatchEvent(
      eventId: 'legacy',
      matchId: 'm1',
      type: EventType.yellowCard,
      status: EventStatus.complete,
      periodId: PeriodId.firstHalf,
      matchTime: 100,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      data: const EventData(),
    );
    expect(
      legacyYellowDataPolicy(
        legacyEvents: [legacyEvent],
        disciplinary: disciplinary,
      ),
      LegacyYellowDataPolicy.mixedWithheldLegacy,
    );
    final emptyDisciplinary = DisciplinaryMatchProjection.derive(
      records: [_registered(1, homeSeven)],
      evaluatedAuthorityGeneration: 1,
      competitionRules: rules,
    );
    expect(
      legacyYellowDataPolicy(
        legacyEvents: [legacyEvent],
        disciplinary: emptyDisciplinary,
      ),
      LegacyYellowDataPolicy.legacyOnly,
    );
  });

  test('standing caution count matches projection and prior awareness', () {
    final records = [
      _registered(1, homeSeven),
      _yellow(2, 'yc-1', homeSeven, intent: 'i1'),
      _yellow(3, 'yc-2', homeSeven, intent: 'i2'),
    ];
    final disciplinary = _project(records);
    final standingRows = buildYellowCardHistoryRows(
      match: _emptyMatch(),
      disciplinary: disciplinary,
      identities: ParticipantIdentityProjection.derive(records: records),
      records: records,
      evidenceById: const {},
      l10n: l10n,
      standingOnly: true,
    );
    expect(standingRows, hasLength(2));
    expect(standingRows.every((row) => row.countsAsStanding), isTrue);
    final prior = disciplinary.priorCautionStateFor(
      participantId: homeSeven.matchParticipantId,
      accountingScope: DisciplinaryAccountingScope.match,
    );
    expect(prior.standingCautionCount, standingRows.length);
  });

  test('superseded caution stays historical but not standing', () {
    final records = [
      _registered(1, homeSeven),
      _yellow(2, 'yc-1', homeSeven, intent: 'i1'),
      _legalSupersession(3, 'sup-1', 'yc-1'),
    ];
    final disciplinary = _project(records);
    final historical = buildYellowCardHistoryRows(
      match: _emptyMatch(),
      disciplinary: disciplinary,
      identities: ParticipantIdentityProjection.derive(records: records),
      records: records,
      evidenceById: const {},
      l10n: l10n,
    );
    final standing = buildYellowCardHistoryRows(
      match: _emptyMatch(),
      disciplinary: disciplinary,
      identities: ParticipantIdentityProjection.derive(records: records),
      records: records,
      evidenceById: const {},
      l10n: l10n,
      standingOnly: true,
    );
    expect(historical, hasLength(1));
    expect(historical.single.detailLine, contains('Superseded'));
    expect(standing, isEmpty);
  });

  test('MATCH and SHOOTOUT cautions stay separate in standing rows', () {
    final records = [
      _registered(1, homeSeven),
      _yellow(2, 'yc-match', homeSeven, intent: 'm', scope: DisciplinaryAccountingScope.match),
      _yellow(
        3,
        'yc-shootout',
        homeSeven,
        intent: 's',
        scope: DisciplinaryAccountingScope.shootout,
      ),
    ];
    final disciplinary = _project(records);
    final matchStanding = disciplinary.standingCautions
        .where((c) => c.accountingScope == DisciplinaryAccountingScope.match);
    final shootoutStanding = disciplinary.standingCautions
        .where((c) => c.accountingScope == DisciplinaryAccountingScope.shootout);
    expect(matchStanding, hasLength(1));
    expect(shootoutStanding, hasLength(1));
    final rows = buildYellowCardHistoryRows(
      match: _emptyMatch(),
      disciplinary: disciplinary,
      identities: ParticipantIdentityProjection.derive(records: records),
      records: records,
      evidenceById: const {},
      l10n: l10n,
    );
    expect(
      rows.where((r) => r.detailLine.contains('Shoot-out')),
      hasLength(1),
    );
  });

  test('summary rows use authority yellow and omit legacy duplicate', () {
    final records = [
      _registered(1, homeSeven),
      _yellow(2, 'yc-1', homeSeven, intent: 'i1'),
    ];
    final disciplinary = _project(records);
    final goalProjection = GoalMatchProjection.derive(
      records: records,
      evidence: const [],
    );
    final match = _emptyMatch().copyWith(
      events: [
        MatchEvent(
          eventId: 'legacy-yc',
          matchId: 'match-disciplinary',
          type: EventType.yellowCard,
          status: EventStatus.complete,
          periodId: PeriodId.firstHalf,
          matchTime: 500,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          data: const EventData(teamId: 'home'),
        ),
        MatchEvent(
          eventId: 'legacy-red',
          matchId: 'match-disciplinary',
          type: EventType.redCard,
          status: EventStatus.complete,
          periodId: PeriodId.firstHalf,
          matchTime: 600,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          data: const EventData(teamId: 'home'),
        ),
      ],
    );
    final rows = buildMatchSummaryRows(
      match: match,
      goalProjection: goalProjection,
      disciplinary: disciplinary,
      identities: ParticipantIdentityProjection.derive(records: records),
      records: records,
      evidenceById: const {},
      l10n: l10n,
    );
    final yellowRows =
        rows.where((r) => r.kind == MatchSummaryRowKind.yellowAuthority);
    final legacyYellow = rows.where(
      (r) =>
          r.kind == MatchSummaryRowKind.legacyEvent &&
          r.title.contains('Yellow'),
    );
    expect(yellowRows, hasLength(1));
    expect(legacyYellow, isEmpty);
    expect(
      rows.any((r) => r.kind == MatchSummaryRowKind.legacyEvent && r.title.contains('Red')),
      isTrue,
    );
  });

  test('yellow temporal labels follow goal formatting semantics', () {
    expect(
      formatProjectedGoalTime(
        const ProjectedGoalTemporal(
          continuity: TemporalContinuityStatus.exactContinuity,
          exactPlayingTime: Duration(minutes: 12),
          playingTimeLowerBound: null,
          playingTimeUpperBound: null,
          period: PeriodIdentity(index: 1),
        ),
        l10n,
      ),
      '12:00',
    );
    expect(
      formatProjectedGoalTime(ProjectedGoalTemporal.unresolved, l10n),
      isNot('00:00'),
    );
    expect(
      formatProjectedGoalTime(
        const ProjectedGoalTemporal(
          continuity: TemporalContinuityStatus.boundedContinuity,
          exactPlayingTime: null,
          playingTimeLowerBound: Duration(minutes: 10),
          playingTimeUpperBound: Duration(minutes: 14),
          period: PeriodIdentity(index: 1),
        ),
        l10n,
      ),
      '10:00–14:00',
    );
  });

  test('status-at-determination label preserved on historical row', () {
    final records = [
      _registered(1, homeSeven),
      _yellow(
        2,
        'yc-sub',
        homeSeven,
        intent: 'i1',
        status: ParticipantStatusAtDetermination.substitute,
      ),
    ];
    final disciplinary = _project(records);
    final rows = buildYellowCardHistoryRows(
      match: _emptyMatch(),
      disciplinary: disciplinary,
      identities: ParticipantIdentityProjection.derive(records: records),
      records: records,
      evidenceById: const {},
      l10n: l10n,
    );
    expect(rows.single.detailLine, contains('Substitute'));
  });
}

DisciplinaryMatchProjection _project(List<MatchRecord> records) {
  return DisciplinaryMatchProjection.derive(
    records: records,
    evaluatedAuthorityGeneration: 1,
    competitionRules: const CompetitionRulesContext(
      rulesetId: 'ifab',
      disciplinarySystem: DisciplinarySystem.ordinaryIfab,
    ),
  );
}

Match _emptyMatch() {
  return Match(
    matchId: 'match-disciplinary',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    date: '2026-10-07',
    status: MatchStatus.live,
    teams: Teams(
      home: Team(teamId: 'home'),
      away: Team(teamId: 'away'),
    ),
    settings: const MatchSettings(halfDurationSeconds: 2700),
    score: const Score(home: 0, away: 0),
    currentState: const MatchState(
      periodId: PeriodId.firstHalf,
      clockRunning: false,
      elapsedSeconds: 0,
    ),
    events: const [],
  );
}

ParticipantRef _participant(
  String id,
  ParticipantTeamSide side,
  ParticipantBinding binding,
) {
  return ParticipantRef(
    matchParticipantId: MatchParticipantId(id),
    teamSide: side,
    binding: binding,
  );
}

MatchRecord _registered(int sequence, ParticipantRef participant) {
  return _record(
    sequence,
    'register-${participant.matchParticipantId.value}',
    RecordKind.action,
    ParticipantRegisteredPayload(
      matchParticipantId: participant.matchParticipantId,
      teamSide: participant.teamSide,
      binding: participant.binding,
    ),
  );
}

MatchRecord _yellow(
  int sequence,
  String recordId,
  ParticipantRef participant, {
  required String intent,
  ParticipantStatusAtDetermination status =
      ParticipantStatusAtDetermination.onFieldPlayer,
  DisciplinaryAccountingScope scope = DisciplinaryAccountingScope.match,
}) {
  return _record(
    sequence,
    recordId,
    RecordKind.humanDetermination,
    YellowCardPayload(
      participantRef: participant,
      participantStatusAtDetermination: status,
      disciplinaryAccountingScope: scope,
      captureIntentId: intent,
      competitionRulesContext: const CompetitionRulesContext(
        rulesetId: 'ifab',
        disciplinarySystem: DisciplinarySystem.ordinaryIfab,
      ),
    ),
  );
}

MatchRecord _legalSupersession(
  int sequence,
  String recordId,
  String targetRecordId,
) {
  return _record(
    sequence,
    recordId,
    RecordKind.legalSupersession,
    const LegalSupersessionPayload(),
    relationships: [LegalSupersessionTarget(targetRecordId: targetRecordId)],
  );
}

MatchRecord _record(
  int sequence,
  String recordId,
  RecordKind recordKind,
  MatchRecordPayload payload, {
  List<RecordRelationship> relationships = const [],
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: 'match-disciplinary',
    recordKind: recordKind,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 7, 12, 0, sequence),
    originDeviceId: 'device-a',
    originSequence: sequence,
    payload: payload,
    integrity: const IntegrityMetadata(),
    authorityContext: const AuthorityContext(
      scope: MainRefereeScope(),
      principal: AuthorityPrincipal(principalId: 'ref-main'),
      activeCaptureDevice: ActiveCaptureDevice(deviceId: 'device-a'),
      generation: AuthorityGeneration(value: 1),
    ),
    relationships: relationships,
  );
}
