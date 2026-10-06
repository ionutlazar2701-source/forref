import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/app_scope.dart';
import 'package:referee_phone/features/live_match/goal_time_label.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/infrastructure/temporal/phone_temporal_evidence_store.dart';
import 'package:referee_phone/l10n/app_localizations_en.dart';
import 'package:referee_phone/match/new_match.dart';
import 'package:referee_phone/match_application/goal_match_read_model.dart';
import 'package:referee_phone/match_application/kick_off_authority.dart';
import 'package:referee_phone/match_application/match_application_boundary.dart';

void main() {
  group('buildSummaryHistory', () {
    test('shows memory goals once and keeps legacy non-goal events', () {
      const goal = ProjectedGoal(
        recordId: 'goal-1',
        creditedSide: CreditedSide.home,
        temporal: ProjectedGoalTemporal(
          continuity: TemporalContinuityStatus.exactContinuity,
          exactPlayingTime: Duration(minutes: 8),
          playingTimeLowerBound: null,
          playingTimeUpperBound: null,
          period: PeriodIdentity(index: 1),
        ),
        legallySuperseded: false,
      );
      final projection = GoalMatchProjection(
        homeScore: 1,
        awayScore: 0,
        goals: [goal],
      );
      final legacyEvents = [
        MatchEvent(
          eventId: 'legacy-goal',
          matchId: 'm1',
          type: EventType.goal,
          periodId: PeriodId.firstHalf,
          matchTime: 0,
          status: EventStatus.complete,
          createdAt: DateTime.utc(2026, 10, 6),
          updatedAt: DateTime.utc(2026, 10, 6),
          data: const EventData(teamId: 'h'),
        ),
        MatchEvent(
          eventId: 'legacy-yellow',
          matchId: 'm1',
          type: EventType.yellowCard,
          periodId: PeriodId.firstHalf,
          matchTime: 600,
          status: EventStatus.complete,
          createdAt: DateTime.utc(2026, 10, 6),
          updatedAt: DateTime.utc(2026, 10, 6),
          data: const EventData(teamId: 'h'),
        ),
      ];

      final entries = buildSummaryHistory(
        projection: projection,
        legacyEvents: legacyEvents,
      );

      expect(entries.where((entry) => entry.goal != null), hasLength(1));
      expect(
        entries.where((entry) => entry.legacyEvent?.type == EventType.goal),
        isEmpty,
      );
      expect(
        entries.where((entry) => entry.legacyEvent?.type == EventType.yellowCard),
        hasLength(1),
      );
    });

    test('home and away goals both appear from projection', () {
      const homeGoal = ProjectedGoal(
        recordId: 'goal-home',
        creditedSide: CreditedSide.home,
        temporal: ProjectedGoalTemporal(
          continuity: TemporalContinuityStatus.exactContinuity,
          exactPlayingTime: Duration(minutes: 12),
          playingTimeLowerBound: null,
          playingTimeUpperBound: null,
          period: PeriodIdentity(index: 1),
        ),
        legallySuperseded: false,
      );
      const awayGoal = ProjectedGoal(
        recordId: 'goal-away',
        creditedSide: CreditedSide.away,
        temporal: ProjectedGoalTemporal(
          continuity: TemporalContinuityStatus.exactContinuity,
          exactPlayingTime: Duration(minutes: 20),
          playingTimeLowerBound: null,
          playingTimeUpperBound: null,
          period: PeriodIdentity(index: 1),
        ),
        legallySuperseded: false,
      );
      final projection = GoalMatchProjection(
        homeScore: 1,
        awayScore: 1,
        goals: [homeGoal, awayGoal],
      );

      final entries = buildSummaryHistory(
        projection: projection,
        legacyEvents: const [],
      );

      expect(entries.where((entry) => entry.goal != null), hasLength(2));
      expect(projection.homeScore, 1);
      expect(projection.awayScore, 1);
    });

    test('unresolved goal time is not formatted as 00:00', () {
      const goal = ProjectedGoal(
        recordId: 'goal-unresolved',
        creditedSide: CreditedSide.home,
        temporal: ProjectedGoalTemporal.unresolved,
        legallySuperseded: false,
      );
      final label = formatProjectedGoalTime(
        goal.temporal,
        AppLocalizationsEn(),
      );
      expect(label, 'Elapsed unavailable');
      expect(label, isNot('00:00'));
    });
  });

  group('loadGoalMatchReadModel', () {
    late Directory temp;
    late MatchApplicationComposition composition;
    late PhoneCaptureIdentity identity;
    late PhoneTemporalEvidenceStore evidence;
    late _ManualClock clock;
    late LocalMatchDatabase scopeDb;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('goal_read_surface_');
      composition = await MatchApplicationComposition.open(storageRoot: temp);
      identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
      clock = _ManualClock();
      evidence = PhoneTemporalEvidenceStore(storageRoot: temp, clock: clock);
      scopeDb = LocalMatchDatabase.memory();
    });

    tearDown(() async {
      await composition.close();
      await scopeDb.close();
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    Future<void> kickOff() async {
      final context = identity.contextFor('match-read');
      final result = await composition.boundary.commitKickOff(
        context,
        period: const PeriodIdentity(index: 1),
        periodAnchor: () async {
          final captured = await evidence.captureAnchor();
          return TemporalContext(
            evidenceIds: [captured.evidenceId],
            domainClockPolicyVersion:
                PhoneCaptureIdentity.domainClockContract.value,
          );
        },
      );
      expect(result, isA<KickOffAuthorityCommitted>());
    }

    test('superseded goal stays in history and does not score', () async {
      await kickOff();
      clock.elapsed = const Duration(minutes: 8);
      final context = identity.contextFor('match-read');
      final captured = await evidence.captureAnchor();
      final goalResult = await composition.boundary.commitGoal(
        context,
        creditedSide: CreditedSide.home,
        captureIntentId: 'read-home',
        temporalContext: TemporalContext(
          evidenceIds: [captured.evidenceId],
          domainClockPolicyVersion:
              PhoneCaptureIdentity.domainClockContract.value,
        ),
      );
      expect(goalResult, isA<DurableCommitSuccess>());
      final goalId = (goalResult as DurableCommitSuccess).committedRecordId;
      final supersede = composition.boundary.recordBuilder.build(
        context: context,
        recordKind: RecordKind.legalSupersession,
        payload: const LegalSupersessionPayload(),
        integrity: const IntegrityMetadata(),
        relationships: [LegalSupersessionTarget(targetRecordId: goalId)],
      );
      expect(
        await composition.boundary.durableStore.commitAtNextOriginSequence(
          supersede,
        ),
        isA<DurableCommitSuccess>(),
      );

      final legacyMatch = Match(
        matchId: 'match-read',
        status: MatchStatus.fullTime,
        createdAt: DateTime.utc(2026, 10, 6),
        updatedAt: DateTime.utc(2026, 10, 6),
        date: '2026-10-06',
        teams: Teams(
          home: Team(teamId: 'h'),
          away: Team(teamId: 'a'),
        ),
        settings: const MatchSettings(halfDurationSeconds: 2700),
        periods: defaultMatchPeriods(),
        currentState: const MatchState(
          periodId: PeriodId.firstHalf,
          clockRunning: false,
          elapsedSeconds: 0,
        ),
        score: const Score(home: 0, away: 0),
      );

      final read = await loadGoalMatchReadModel(
        _FakeScope(
          database: scopeDb,
          boundary: composition.boundary,
          identity: identity,
          evidence: evidence,
        ),
        'match-read',
        legacyMatch: legacyMatch,
      );

      expect(read!.homeScore, 0);
      expect(read.awayScore, 0);
      expect(read.projection.goals.single.legallySuperseded, isTrue);
    });

    test('reopen rebuilds the same summary score', () async {
      await kickOff();
      clock.elapsed = const Duration(minutes: 3);
      final context = identity.contextFor('match-read');
      final captured = await evidence.captureAnchor();
      expect(
        await composition.boundary.commitGoal(
          context,
          creditedSide: CreditedSide.away,
          captureIntentId: 'read-away',
          temporalContext: TemporalContext(
            evidenceIds: [captured.evidenceId],
            domainClockPolicyVersion:
                PhoneCaptureIdentity.domainClockContract.value,
          ),
        ),
        isA<DurableCommitSuccess>(),
      );

      final legacyMatch = Match(
        matchId: 'match-read',
        status: MatchStatus.fullTime,
        createdAt: DateTime.utc(2026, 10, 6),
        updatedAt: DateTime.utc(2026, 10, 6),
        date: '2026-10-06',
        teams: Teams(
          home: Team(teamId: 'h'),
          away: Team(teamId: 'a'),
        ),
        settings: const MatchSettings(halfDurationSeconds: 2700),
        periods: defaultMatchPeriods(),
        currentState: const MatchState(
          periodId: PeriodId.firstHalf,
          clockRunning: false,
          elapsedSeconds: 0,
        ),
        score: const Score(home: 0, away: 0),
      );
      final before = await loadGoalMatchReadModel(
        _FakeScope(
          database: scopeDb,
          boundary: composition.boundary,
          identity: identity,
          evidence: evidence,
        ),
        'match-read',
        legacyMatch: legacyMatch,
      );
      await composition.close();
      composition = await MatchApplicationComposition.open(storageRoot: temp);
      final after = await loadGoalMatchReadModel(
        _FakeScope(
          database: scopeDb,
          boundary: composition.boundary,
          identity: identity,
          evidence: evidence,
        ),
        'match-read',
        legacyMatch: legacyMatch,
      );
      expect(after!.homeScore, before!.homeScore);
      expect(after.awayScore, before.awayScore);
      expect(after.projection.goals.length, before.projection.goals.length);
    });
  });

  group('summary read model', () {
    late LocalMatchDatabase db;
    late Directory temp;
    late MatchApplicationComposition composition;
    late PhoneCaptureIdentity identity;
    late PhoneTemporalEvidenceStore evidence;
    late _ManualClock clock;

    setUp(() async {
      db = LocalMatchDatabase.memory();
      temp = await Directory.systemTemp.createTemp('goal_read_summary_');
      composition = await MatchApplicationComposition.open(storageRoot: temp);
      identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
      clock = _ManualClock();
      evidence = PhoneTemporalEvidenceStore(storageRoot: temp, clock: clock);
    });

    tearDown(() async {
      await composition.close();
      await db.close();
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    _FakeScope scope() => _FakeScope(
          database: db,
          boundary: composition.boundary,
          identity: identity,
          evidence: evidence,
        );

    Future<String> seedMatchWithGoal({
      required CreditedSide side,
      Duration elapsed = const Duration(minutes: 8),
    }) async {
      final match = newLocalMatch(DateTime.utc(2026, 10, 6));
      await db.upsertMatch(match);
      final context = identity.contextFor(match.matchId);
      expect(
        await composition.boundary.commitKickOff(
          context,
          period: const PeriodIdentity(index: 1),
          periodAnchor: () async {
            clock.elapsed = Duration.zero;
            final captured = await evidence.captureAnchor();
            return TemporalContext(
              evidenceIds: [captured.evidenceId],
              domainClockPolicyVersion:
                  PhoneCaptureIdentity.domainClockContract.value,
            );
          },
        ),
        isA<KickOffAuthorityCommitted>(),
      );
      clock.elapsed = elapsed;
      final captured = await evidence.captureAnchor();
      expect(
        await composition.boundary.commitGoal(
          context,
          creditedSide: side,
          captureIntentId: 'read-${side.name}',
          temporalContext: TemporalContext(
            evidenceIds: [captured.evidenceId],
            domainClockPolicyVersion:
                PhoneCaptureIdentity.domainClockContract.value,
          ),
        ),
        isA<DurableCommitSuccess>(),
      );
      return match.matchId;
    }

    test('summary score matches GoalMatchProjection for the same match', () async {
      final matchId = await seedMatchWithGoal(side: CreditedSide.home);
      final match = (await db.getMatch(matchId))!;
      final read = await loadGoalMatchReadModel(
        scope(),
        matchId,
        legacyMatch: match,
      );
      expect(read!.homeScore, 1);
      expect(read.awayScore, 0);
      expect(read.projection.homeScore, read.homeScore);
      expect(read.projection.awayScore, read.awayScore);
    });

    test('eight minute goal uses projected temporal in summary history', () async {
      final matchId = await seedMatchWithGoal(side: CreditedSide.home);
      final match = (await db.getMatch(matchId))!;
      final read = await loadGoalMatchReadModel(
        scope(),
        matchId,
        legacyMatch: match,
      );
      final history = buildSummaryHistory(
        projection: read!.projection,
        legacyEvents: match.events,
      );
      final label = formatProjectedGoalTime(
        history.single.goal!.temporal,
        AppLocalizationsEn(),
      );
      expect(label, '08:00');
      expect(label, isNot('00:00'));
    });

    test('legacy-only goals are not imported into summary score', () async {
      final match = newLocalMatch(DateTime.utc(2026, 10, 6));
      const factory = EventFactory();
      const reducer = EventReducer();
      final legacyGoal = factory.create(
        eventId: 'legacy-g',
        matchId: match.matchId,
        type: EventType.goal,
        periodId: PeriodId.firstHalf,
        matchTime: 480,
        now: DateTime.utc(2026, 10, 6),
        data: EventData(teamId: match.teams.home.teamId),
      );
      final withGoal = reducer.applyNewEvent(match, legacyGoal);
      await db.upsertMatch(withGoal);
      expect(withGoal.score.home, 1);

      final read = await loadGoalMatchReadModel(
        scope(),
        match.matchId,
        legacyMatch: withGoal,
      );
      expect(read!.legacyGoalsOnly, isTrue);
      expect(read.homeScore, 0);
      expect(read.awayScore, 0);
      expect(
        buildSummaryHistory(
          projection: read.projection,
          legacyEvents: withGoal.events,
        ).where((entry) => entry.goal != null),
        isEmpty,
      );
    });

    test('mixed summary keeps yellow legacy and memory goal once', () async {
      final matchId = await seedMatchWithGoal(side: CreditedSide.away);
      const factory = EventFactory();
      const reducer = EventReducer();
      final match = (await db.getMatch(matchId))!;
      final yellow = factory.create(
        eventId: 'legacy-yellow',
        matchId: matchId,
        type: EventType.yellowCard,
        periodId: PeriodId.firstHalf,
        matchTime: 600,
        now: DateTime.utc(2026, 10, 6),
        data: EventData(teamId: match.teams.home.teamId),
      );
      final updated = reducer.applyNewEvent(match, yellow);
      await db.upsertMatch(updated);

      final read = await loadGoalMatchReadModel(
        scope(),
        matchId,
        legacyMatch: updated,
      );
      final history = buildSummaryHistory(
        projection: read!.projection,
        legacyEvents: updated.events,
      );
      expect(read.homeScore, 0);
      expect(read.awayScore, 1);
      expect(history.where((entry) => entry.goal != null), hasLength(1));
      expect(
        history.where((entry) => entry.legacyEvent?.type == EventType.yellowCard),
        hasLength(1),
      );
    });
  });
}

final class _ManualClock implements MonotonicContinuityClock {
  Duration elapsed = Duration.zero;

  @override
  String get continuityDomainId => 'domain-read';

  @override
  Duration get monotonicElapsed => elapsed;

  @override
  DateTime get chronology => DateTime.utc(2026, 10, 6, 12);
}

final class _FakeScope extends AppScope {
  _FakeScope({
    required super.database,
    required MatchApplicationBoundary boundary,
    required PhoneCaptureIdentity identity,
    required PhoneTemporalEvidenceStore evidence,
  }) : super(
          locale: ValueNotifier(null),
          matchApplication: boundary,
          captureIdentity: identity,
          temporalEvidence: evidence,
          child: const SizedBox.shrink(),
        );
}
