import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/match_application/authoritative_capture_command.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/match/new_match.dart';
import 'package:referee_phone/match_application/kick_off_authority.dart';

void main() {
  late Directory temp;
  late LocalMatchDatabase db;
  late MatchApplicationComposition composition;
  late PhoneCaptureIdentity identity;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('goal_cutover_');
    db = LocalMatchDatabase.memory();
    composition = await MatchApplicationComposition.open(storageRoot: temp);
    identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
  });

  tearDown(() async {
    await composition.close();
    await db.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<Match> seedMatch() async {
    final match = newLocalMatch(DateTime.utc(2026, 10, 2, 12));
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

  test('MATCH_MEMORY goal commit does not add a legacy goal event', () async {
    final match = await seedMatch();
    await ensureRootAndKickOff(match.matchId);
    final context = identity.contextFor(match.matchId);
    final homeTeam = MatchTeamId(match.teams.home.teamId);

    final result = await composition.boundary.commitGoal(
      context,
      scoringTeamId: homeTeam,
      captureIntentId: 'intent-goal-1',
    );
    expect(result, isA<DurableCommitSuccess>());

    final stored = await db.getMatch(match.matchId);
    expect(stored!.events, isEmpty);
    expect(stored.score.home, 0);
    expect(stored.score.away, 0);

    final records =
        await composition.boundary.durableStore.readCommittedForMatch(
      match.matchId,
    );
    expect(
      records.where((r) => r.payload is GoalPayload),
      hasLength(1),
    );
  });

  test('failed D1 goal commit does not add a legacy goal event', () async {
    final match = await seedMatch();
    await ensureRootAndKickOff(match.matchId);
    composition.boundary.durableStore.abortBeforeCommitForTest = () {
      throw StateError('abort before commit');
    };
    final context = identity.contextFor(match.matchId);

    final result = await composition.boundary.commitGoal(
      context,
      scoringTeamId: MatchTeamId(match.teams.away.teamId),
      captureIntentId: 'intent-fail',
    );
    expect(result, isA<DurableCommitFailure>());

    final stored = await db.getMatch(match.matchId);
    expect(stored!.events, isEmpty);
    expect(
      await composition.boundary.durableStore
          .readCommittedForMatch(match.matchId),
      hasLength(2),
    );
  });

  test('known score maps MatchTeamIds from team bindings', () async {
    final match = await seedMatch();
    final context = identity.contextFor(match.matchId);
    final homeTeam = MatchTeamId(match.teams.home.teamId);
    final awayTeam = MatchTeamId(match.teams.away.teamId);

    await composition.boundary.durableStore.commitGenerationOneAuthorityRoot(
      GenerationOneAuthorityRoot(
        matchId: match.matchId,
        principalId: context.authorityPrincipalId,
        deviceId: context.originDeviceId,
      ),
    );
    await composition.boundary.captureAndCommit(
      AuthoritativeCaptureCommand(
        context: context,
        recordKind: RecordKind.temporalFact,
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.matchStarted,
        ),
        integrity: const IntegrityMetadata(evidenceRefs: ['ev-bootstrap']),
      ),
    );
    await composition.boundary.commitGoal(
      context,
      scoringTeamId: homeTeam,
      captureIntentId: 'intent-home',
    );
    await composition.boundary.commitGoal(
      context,
      scoringTeamId: awayTeam,
      captureIntentId: 'intent-away',
    );
    await composition.boundary.commitGoal(
      context,
      scoringTeamId: awayTeam,
      captureIntentId: 'intent-away-2',
    );

    final projection = await composition.boundary.readScoreProjection(
      matchId: match.matchId,
      evaluatedAuthorityGeneration:
          PhoneCaptureIdentity.initialAuthorityGeneration,
      homeTeamId: homeTeam,
      awayTeamId: awayTeam,
    );
    expect(projection, isA<KnownScore>());
    final known = projection as KnownScore;
    expect(known.goalsByTeam[homeTeam], 1);
    expect(known.goalsByTeam[awayTeam], 2);
  });

  test('generation other than 1 cannot commit a Goal', () async {
    final match = await seedMatch();
    await ensureRootAndKickOff(match.matchId);
    final current = identity.contextFor(match.matchId);
    final stale = CaptureContext(
      matchId: current.matchId,
      originDeviceId: current.originDeviceId,
      authorityScope: const MainRefereeScope(),
      authorityPrincipalId: current.authorityPrincipalId,
      authorityGeneration: 2,
      projectionAuthorityGeneration: current.projectionAuthorityGeneration,
      activeCaptureDeviceId: current.activeCaptureDeviceId,
    );
    final result = await composition.boundary.commitGoal(
      stale,
      scoringTeamId: MatchTeamId(match.teams.home.teamId),
      captureIntentId: 'intent-stale-gen',
    );
    expect(result, isA<DurableCommitFailure>());
    final records =
        await composition.boundary.durableStore.readCommittedForMatch(
      match.matchId,
    );
    expect(records.where((record) => record.payload is GoalPayload), isEmpty);
  });

  test('Goal is denied when records exist without a generation-1 root',
      () async {
    final match = await seedMatch();
    final context = identity.contextFor(match.matchId);
    final homeTeam = MatchTeamId(match.teams.home.teamId);
    final direct = composition.boundary.recordBuilder.build(
      context: context,
      recordKind: RecordKind.humanDetermination,
      payload: GoalPayload(
        scoringTeamId: homeTeam,
        captureIntentId: 'intent-direct-store',
      ),
      integrity: const IntegrityMetadata(),
    );
    expect(
      await composition.boundary.durableStore
          .commitAtNextOriginSequence(direct),
      isA<DurableCommitSuccess>(),
    );

    final denied = await composition.boundary.commitGoal(
      context,
      scoringTeamId: homeTeam,
      captureIntentId: 'intent-after-missing-root',
    );
    expect(denied, isA<DurableCommitFailure>());
    expect(
      (denied as DurableCommitFailure).reason,
      contains('generation-1 authority root missing'),
    );
    final records =
        await composition.boundary.durableStore.readCommittedForMatch(
      match.matchId,
    );
    expect(
      records.where((record) => record.payload is GoalPayload),
      hasLength(1),
    );
    expect(
      await composition.boundary.durableStore
          .readGenerationOneAuthorityRoot(match.matchId),
      isNull,
    );
  });

  test(
      'Goal is denied when capture identity does not match the generation-1 root',
      () async {
    final match = await seedMatch();
    await ensureRootAndKickOff(match.matchId);
    final current = identity.contextFor(match.matchId);
    final mismatched = CaptureContext(
      matchId: current.matchId,
      originDeviceId: 'other-device',
      authorityScope: const MainRefereeScope(),
      authorityPrincipalId: 'other-principal',
      authorityGeneration: 1,
      projectionAuthorityGeneration: current.projectionAuthorityGeneration,
      activeCaptureDeviceId: 'other-device',
    );
    final denied = await composition.boundary.commitGoal(
      mismatched,
      scoringTeamId: MatchTeamId(match.teams.home.teamId),
      captureIntentId: 'intent-mismatched-root',
    );
    expect(denied, isA<DurableCommitFailure>());
    expect(
      (denied as DurableCommitFailure).reason,
      contains('generation-1 root does not match'),
    );
    final records =
        await composition.boundary.durableStore.readCommittedForMatch(
      match.matchId,
    );
    expect(records.where((record) => record.payload is GoalPayload), isEmpty);
  });

  test('kick-off with bound integrity and no goals is KnownScore 0-0',
      () async {
    final match = await seedMatch();
    await ensureRootAndKickOff(match.matchId);
    final homeTeam = MatchTeamId(match.teams.home.teamId);
    final awayTeam = MatchTeamId(match.teams.away.teamId);

    final projection = await composition.boundary.readScoreProjection(
      matchId: match.matchId,
      evaluatedAuthorityGeneration:
          PhoneCaptureIdentity.initialAuthorityGeneration,
      homeTeamId: homeTeam,
      awayTeamId: awayTeam,
    );
    expect(projection, isA<KnownScore>());
    final known = projection as KnownScore;
    expect(known.goalsByTeam[homeTeam], 0);
    expect(known.goalsByTeam[awayTeam], 0);
  });

  test('live match page fails closed if legacy 0-0 scoreLine returns', () {
    final page =
        File('lib/features/live_match/live_match_page.dart').readAsStringSync();
    expect(page, contains('readScoreProjection'));
    expect(page, contains('commitGoal'));
    expect(page, contains('projection is! KnownScore'));
    expect(page, contains('_scoreProjection = const ScoreUnavailable()'));
    expect(
      page,
      isNot(
        contains(
          'l10n.scoreLine(\n                  homeLabel(match, l10n),\n                  match.score.home',
        ),
      ),
    );
  });

  test('saved Goal stays saved when score refresh cannot be proven', () async {
    final match = await seedMatch();
    await ensureRootAndKickOff(match.matchId);
    final context = identity.contextFor(match.matchId);
    final homeTeam = MatchTeamId(match.teams.home.teamId);
    final awayTeam = MatchTeamId(match.teams.away.teamId);
    final saved = await composition.boundary.commitGoal(
      context,
      scoringTeamId: homeTeam,
      captureIntentId: 'intent-then-corrupt',
    );
    expect(saved, isA<DurableCommitSuccess>());
    final goalId = (saved as DurableCommitSuccess).committedRecordId;

    final before = await composition.boundary.readScoreProjection(
      matchId: match.matchId,
      evaluatedAuthorityGeneration:
          PhoneCaptureIdentity.initialAuthorityGeneration,
      homeTeamId: homeTeam,
      awayTeamId: awayTeam,
    );
    expect(before, isA<KnownScore>());

    final dbFile = File('${temp.path}/forref_match_memory/match_memory.sqlite');
    final corrupt = await Process.run('python3', [
      '-c',
      '''
import json, sqlite3, sys
path, record_id = sys.argv[1], sys.argv[2]
db = sqlite3.connect(path)
row = db.execute(
    "SELECT record_json FROM committed_match_records WHERE record_id = ?",
    (record_id,),
).fetchone()
payload = json.loads(row[0])
payload["payload"] = "not-an-object"
db.execute(
    "UPDATE committed_match_records SET record_json = ? WHERE record_id = ?",
    (json.dumps(payload), record_id),
)
db.commit()
print(db.execute(
    "SELECT COUNT(*) FROM committed_match_records WHERE record_id = ?",
    (record_id,),
).fetchone()[0])
''',
      dbFile.path,
      goalId,
    ]);
    expect(corrupt.exitCode, 0, reason: '${corrupt.stdout}${corrupt.stderr}');
    expect(corrupt.stdout.toString().trim(), '1');

    final after = await composition.boundary.readScoreProjection(
      matchId: match.matchId,
      evaluatedAuthorityGeneration:
          PhoneCaptureIdentity.initialAuthorityGeneration,
      homeTeamId: homeTeam,
      awayTeamId: awayTeam,
    );
    expect(after, isA<ScoreUnavailable>());
    expect(after, isNot(isA<KnownScore>()));

    final legacy = await db.getMatch(match.matchId);
    expect(
        legacy!.events.where((event) => event.type == EventType.goal), isEmpty);
    expect(legacy.score.home, 0);
    expect(legacy.score.away, 0);
  });
}
