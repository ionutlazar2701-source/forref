import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/app.dart';
import 'package:referee_phone/infrastructure/competition_rules/match_competition_rules_store.dart';
import 'package:referee_phone/infrastructure/competition_rules/phone_match_capture_context.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/infrastructure/temporal/phone_temporal_evidence_store.dart';
import 'package:referee_phone/match/new_match.dart';
import 'package:referee_phone/match_application/authoritative_capture_command.dart';
import 'package:referee_phone/match_application/kick_off_authority.dart';
import 'package:referee_phone/officiate/match_record_view.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory temp;
  late LocalMatchDatabase db;
  late MatchApplicationComposition composition;
  late PhoneCaptureIdentity identity;
  late PhoneMatchCaptureContext matchCaptureContext;
  late PhoneTemporalEvidenceStore evidence;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('match_record_view_');
    db = LocalMatchDatabase.memory();
    composition = await MatchApplicationComposition.open(storageRoot: temp);
    identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    matchCaptureContext = PhoneMatchCaptureContext(
      identity: identity,
      rulesStore: MatchCompetitionRulesStore(temp),
    );
    evidence = PhoneTemporalEvidenceStore(storageRoot: temp);
  });

  tearDown(() async {
    await composition.close();
    await db.close();
    if (temp.existsSync()) {
      try {
        temp.deleteSync(recursive: true);
      } on FileSystemException {
        // The store may release the directory a moment later.
      }
    }
  });

  Future<Match> seedMatch({MatchStatus status = MatchStatus.setup}) async {
    final match = newLocalMatch(DateTime.utc(2026, 10, 25, 12)).copyWith(
      status: status,
    );
    await db.upsertMatch(match);
    return match;
  }

  Future<void> ensureRootAndKickOff(String matchId) async {
    final context = identity.contextFor(matchId);
    expect(
      await composition.boundary.durableStore.commitGenerationOneAuthorityRoot(
        GenerationOneAuthorityRoot(
          matchId: matchId,
          principalId: context.authorityPrincipalId,
          deviceId: context.originDeviceId,
        ),
      ),
      isA<GenerationOneRootCommitSuccess>(),
    );
    expect(
      await composition.boundary.commitKickOff(
        context,
        period: const PeriodIdentity(index: 1),
      ),
      isA<KickOffAuthorityCommitted>(),
    );
  }

  Future<MatchRecordView> load(Match match) {
    return loadMatchRecordView(
      boundary: composition.boundary,
      matchId: match.matchId,
      legacyStatus: match.status,
      homeTeamId: match.teams.home.teamId,
      awayTeamId: match.teams.away.teamId,
    );
  }

  Future<int> committedCount(String matchId) async {
    final records =
        await composition.boundary.durableStore.readCommittedForMatch(matchId);
    return records.length;
  }

  int sqliteRowCount(String matchId) {
    final database = sqlite3.open(composition.databaseFile.path);
    final rows = database.select(
      'SELECT COUNT(*) FROM committed_match_records WHERE match_id = ?',
      [matchId],
    );
    final count = rows.single.columnAt(0) as int;
    database.close();
    return count;
  }

  test('empty Match Memory is not a numeral score', () async {
    final match = await seedMatch();
    final view = await load(match);
    expect(view.availability, MatchRecordAvailability.noCommittedRecords);
    expect(view.scoreKind, MatchRecordScoreKind.unavailable);
    expect(view.homeGoals, isNull);
    expect(view.awayGoals, isNull);
    expect(view.facts, isEmpty);
    expect(view.committedCount, 0);
    expect(view.phaseUnavailable, isFalse);
    expect(view.matchNormallyEnded, isFalse);
    expect(await committedCount(match.matchId), 0);
  });

  test('one confirmed goal keeps score and chronology across reopen', () async {
    final match = await seedMatch(status: MatchStatus.live);
    await ensureRootAndKickOff(match.matchId);
    final context = identity.contextFor(match.matchId);
    expect(
      await composition.boundary.commitGoal(
        context,
        scoringTeamId: MatchTeamId(match.teams.home.teamId),
        captureIntentId: 'intent-goal-1',
      ),
      isA<DurableCommitSuccess>(),
    );

    final before = await committedCount(match.matchId);
    expect(before, 3);
    final view = await load(match);
    expect(view.availability, MatchRecordAvailability.readable);
    expect(view.scoreKind, MatchRecordScoreKind.known);
    expect(view.homeGoals, 1);
    expect(view.awayGoals, 0);
    expect(view.committedCount, before);
    expect(view.phaseUnavailable, isFalse);
    expect(view.matchStarted, isTrue);
    expect(
      view.facts.map((fact) => fact.kind).toList(),
      [
        MatchRecordFactKind.matchStarted,
        MatchRecordFactKind.periodStarted,
        MatchRecordFactKind.goal,
      ],
    );
    expect(view.facts.last.teamId, match.teams.home.teamId);

    final again = await load(match);
    expect(again.committedCount, before);
    expect(await committedCount(match.matchId), before);

    await composition.close();
    composition = await MatchApplicationComposition.open(storageRoot: temp);
    final reopened = await load(match);
    expect(reopened.homeGoals, 1);
    expect(reopened.awayGoals, 0);
    expect(reopened.committedCount, before);
    expect(
      reopened.facts.map((fact) => fact.kind).toList(),
      [
        MatchRecordFactKind.matchStarted,
        MatchRecordFactKind.periodStarted,
        MatchRecordFactKind.goal,
      ],
    );
    expect(await committedCount(match.matchId), before);
  });

  test('a corrupt committed row is unavailable, not an empty history',
      () async {
    final match = await seedMatch(status: MatchStatus.live);
    await ensureRootAndKickOff(match.matchId);
    final context = identity.contextFor(match.matchId);
    expect(
      await composition.boundary.commitGoal(
        context,
        scoringTeamId: MatchTeamId(match.teams.home.teamId),
        captureIntentId: 'intent-goal-corrupt',
      ),
      isA<DurableCommitSuccess>(),
    );
    final records =
        await composition.boundary.durableStore.readCommittedForMatch(
      match.matchId,
    );
    final goalId = records
        .where((record) => record.payload is GoalPayload)
        .single
        .recordId;
    final before = records.length;
    await composition.close();

    final database = sqlite3.open(composition.databaseFile.path);
    final raw = database
        .select(
          'SELECT record_json FROM committed_match_records WHERE record_id = ?',
          [goalId],
        )
        .single
        .columnAt(0) as String;
    final json = jsonDecode(raw) as Map<String, Object?>;
    json['payload'] = 'not-an-object';
    database.execute(
      'UPDATE committed_match_records SET record_json = ? WHERE record_id = ?',
      [jsonEncode(json), goalId],
    );
    database.close();
    expect(sqliteRowCount(match.matchId), before);

    composition = await MatchApplicationComposition.open(storageRoot: temp);
    final view = await load(match);
    expect(view.availability, MatchRecordAvailability.unavailable);
    expect(
        view.availability, isNot(MatchRecordAvailability.noCommittedRecords));
    expect(view.scoreKind, MatchRecordScoreKind.unavailable);
    expect(view.homeGoals, isNull);
    expect(view.facts, isEmpty);
    expect(view.committedCount, isNull);
    expect(sqliteRowCount(match.matchId), before);
    expect(
      composition.boundary.durableStore.readCommittedForMatch(match.matchId),
      throwsA(isA<CommittedRecordQuarantineException>()),
    );
  });

  test('legacy full time without MATCH_ENDED is not completion', () async {
    final match = await seedMatch(status: MatchStatus.fullTime);
    await ensureRootAndKickOff(match.matchId);
    final before = await committedCount(match.matchId);
    final view = await load(match);
    expect(view.legacyFullTime, isTrue);
    expect(view.matchNormallyEnded, isFalse);
    expect(view.availability, MatchRecordAvailability.readable);
    expect(view.facts.map((fact) => fact.kind),
        isNot(contains(MatchRecordFactKind.matchEnded)));
    expect(await committedCount(match.matchId), before);
  });

  test('a second MATCH_STARTED makes the phase unavailable', () async {
    final match = await seedMatch(status: MatchStatus.live);
    await ensureRootAndKickOff(match.matchId);
    final context = identity.contextFor(match.matchId);
    final second = await composition.boundary.captureAndCommit(
      AuthoritativeCaptureCommand(
        context: context,
        recordKind: RecordKind.temporalFact,
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.matchStarted,
        ),
        integrity: const IntegrityMetadata(evidenceRefs: ['ev-second-start']),
      ),
    );
    expect(second, isA<DurableCommitSuccess>());
    final before = await committedCount(match.matchId);
    expect(before, 3);
    final view = await load(match);
    expect(view.availability, MatchRecordAvailability.readable);
    expect(view.phaseUnavailable, isTrue);
    expect(view.matchStarted, isFalse);
    expect(view.matchNormallyEnded, isFalse);
    expect(
      view.facts.where((fact) => fact.kind == MatchRecordFactKind.matchStarted),
      isEmpty,
    );
    expect(await committedCount(match.matchId), before);
    final again = await load(match);
    expect(again.committedCount, before);
  });

  test('assemble keeps a conflicted score off the numeral', () {
    final view = assembleMatchRecordView(
      records: [
        _record(
          id: 'start',
          sequence: 1,
          kind: RecordKind.temporalFact,
          payload: TemporalTransitionPayload(
            semanticType: V1SemanticTypeCode.matchStarted,
          ),
        ),
      ],
      projection: _projection(temporal: ProjectionTrust.trusted),
      score: const ScoreConflicted(),
      legacyStatus: MatchStatus.live,
      homeTeamId: 'home-1',
      awayTeamId: 'away-1',
    );
    expect(view.scoreKind, MatchRecordScoreKind.conflicted);
    expect(view.homeGoals, isNull);
    expect(view.awayGoals, isNull);
  });

  test('assemble does not guess a phase from two match starts', () {
    final view = assembleMatchRecordView(
      records: [
        _record(
          id: 'start-1',
          sequence: 1,
          kind: RecordKind.temporalFact,
          payload: TemporalTransitionPayload(
            semanticType: V1SemanticTypeCode.matchStarted,
          ),
        ),
        _record(
          id: 'start-2',
          sequence: 2,
          kind: RecordKind.temporalFact,
          payload: TemporalTransitionPayload(
            semanticType: V1SemanticTypeCode.matchStarted,
          ),
        ),
      ],
      projection: _projection(temporal: ProjectionTrust.trusted),
      score: const ScoreUnavailable(),
      legacyStatus: MatchStatus.live,
      homeTeamId: 'home-1',
      awayTeamId: 'away-1',
    );
    expect(view.phaseUnavailable, isTrue);
    expect(view.matchStarted, isFalse);
    expect(view.facts, isEmpty);
    expect(view.availability, MatchRecordAvailability.readable);
  });

  test('a sanction payload stays an unnamed committed record', () {
    final view = assembleMatchRecordView(
      records: [
        _record(
          id: 'start',
          sequence: 1,
          kind: RecordKind.temporalFact,
          payload: TemporalTransitionPayload(
            semanticType: V1SemanticTypeCode.matchStarted,
          ),
        ),
        _record(
          id: 'yellow',
          sequence: 2,
          kind: RecordKind.humanDetermination,
          payload: YellowCardPayload(
            participantId: MatchParticipantId('player-1'),
            accountingScope: DisciplinaryAccountingScope.match,
            captureIntentId: 'intent-yellow',
          ),
        ),
      ],
      projection: _projection(temporal: ProjectionTrust.trusted),
      score: const ScoreUnavailable(),
      legacyStatus: MatchStatus.live,
      homeTeamId: 'home-1',
      awayTeamId: 'away-1',
    );
    expect(
      view.facts.map((fact) => fact.kind).toList(),
      [MatchRecordFactKind.matchStarted, MatchRecordFactKind.other],
    );
  });

  RefereeApp testApp() {
    return RefereeApp(
      database: db,
      matchApplication: composition.boundary,
      captureIdentity: identity,
      matchCaptureContext: matchCaptureContext,
      temporalEvidence: evidence,
    );
  }

  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 40; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }
    fail('Timed out waiting for $finder');
  }

  Future<void> openMatches(WidgetTester tester) async {
    await tester.pumpWidget(testApp());
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }
    fail('Matches did not finish loading');
  }

  testWidgets('current fixture record opens read-only and live still opens', (
    tester,
  ) async {
    final match = newLocalMatch(DateTime.now()).copyWith(
      status: MatchStatus.live,
      teams: Teams(
        home: Team(teamId: 'home-current', name: 'Current Home'),
        away: Team(teamId: 'away-current', name: 'Current Away'),
      ),
    );
    await db.upsertMatch(match);
    await tester.runAsync(() async {
      expect(await committedCount(match.matchId), 0);
    });

    await openMatches(tester);
    final recordButton = find.byKey(Key('open-match-record-${match.matchId}'));
    expect(recordButton, findsOneWidget);
    await tester.tap(recordButton);
    await tester.pump();
    await pumpUntilFound(tester, find.text('No authoritative events'));
    expect(find.text('Score unavailable'), findsOneWidget);
    expect(
      find.text('Read only. Opening this screen does not save a record.'),
      findsOneWidget,
    );
    expect(find.textContaining('0 —'), findsNothing);
    expect(
      find.ancestor(of: recordButton, matching: find.byType(InkWell)),
      findsNothing,
    );
    await tester.runAsync(() async {
      expect(await committedCount(match.matchId), 0);
    });

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );

    await tester.tap(find.text('Current Home — Current Away'));
    await tester.pump();
    await pumpUntilFound(tester, find.text('Pause'));
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.runAsync(() async {
      expect(await committedCount(match.matchId), 0);
    });
  });

  testWidgets('preparation and summary show the record action', (tester) async {
    final preparation = newLocalMatch(DateTime.now()).copyWith(
      teams: Teams(
        home: Team(teamId: 'home-prep', name: 'Prep Home'),
        away: Team(teamId: 'away-prep', name: 'Prep Away'),
      ),
    );
    final completed = newLocalMatch(DateTime.now()).copyWith(
      status: MatchStatus.completed,
      teams: Teams(
        home: Team(teamId: 'home-done', name: 'Done Home'),
        away: Team(teamId: 'away-done', name: 'Done Away'),
      ),
    );
    await db.upsertMatch(preparation);
    await db.upsertMatch(completed);
    await openMatches(tester);

    await tester.tap(find.text('Prep Home — Prep Away'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(find.byKey(const Key('open-match-record')), findsOneWidget);
    expect(find.text('Kick-off'), findsNothing);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Done Home — Done Away'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    expect(find.text('Summary'), findsOneWidget);
    expect(find.byKey(const Key('open-match-record')), findsOneWidget);
    await tester.runAsync(() async {
      expect(await committedCount(preparation.matchId), 0);
      expect(await committedCount(completed.matchId), 0);
    });
  });
}

MatchRecord _record({
  required String id,
  required int sequence,
  required RecordKind kind,
  required MatchRecordPayload payload,
}) {
  return MatchRecord(
    recordId: id,
    matchId: 'm',
    recordKind: kind,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 25),
    originDeviceId: 'device',
    originSequence: sequence,
    payload: payload,
    integrity: const IntegrityMetadata(),
  );
}

MatchProjectionState _projection({required ProjectionTrust temporal}) {
  return MatchProjectionState(
    matchId: 'm',
    evaluatedAuthorityGeneration: 1,
    facetTrust: {
      ProjectionFacet.temporal: FacetTrust(
        facetId: ProjectionFacet.temporal,
        trust: temporal,
      ),
    },
    scoreProjection: const ScoreUnavailable(),
    committedRecordIds: const [],
    missingDependencyTargets: const [],
    conflictNotes: const [],
    unsupportedSemanticRecordIds: const [],
  );
}
