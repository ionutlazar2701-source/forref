import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/match/new_match.dart';
import 'package:referee_phone/match_application/kick_off_authority.dart';

void main() {
  late Directory temp;
  late LocalMatchDatabase legacy;
  late MatchApplicationComposition composition;
  late PhoneCaptureIdentity identity;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('match_report_bridge_');
    legacy = LocalMatchDatabase.memory();
    composition = await MatchApplicationComposition.open(storageRoot: temp);
    identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
  });

  tearDown(() async {
    await composition.close();
    await legacy.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<Match> seedMatch() async {
    final match = newLocalMatch(DateTime.utc(2026, 10, 2, 12));
    await legacy.upsertMatch(match);
    return match;
  }

  Future<void> rootAndKickOff(Match match) async {
    final context = identity.contextFor(match.matchId);
    expect(
      await composition.boundary.durableStore.commitGenerationOneAuthorityRoot(
        GenerationOneAuthorityRoot(
          matchId: match.matchId,
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

  test('append, D1 success, report, restart, and rebuild agree', () async {
    final match = await seedMatch();
    final context = identity.contextFor(match.matchId);
    final home = MatchTeamId(match.teams.home.teamId);
    final away = MatchTeamId(match.teams.away.teamId);
    final outgoing = MatchParticipantId('out-1');
    final incoming = MatchParticipantId('in-1');
    await rootAndKickOff(match);
    expect(
      await composition.boundary.durableStore.commitParticipantTeamBinding(
        MatchParticipantTeamBinding(
          matchId: match.matchId,
          participantId: outgoing,
          teamId: home,
        ),
      ),
      isA<TeamBindingCommitSuccess>(),
    );
    expect(
      await composition.boundary.durableStore.commitParticipantTeamBinding(
        MatchParticipantTeamBinding(
          matchId: match.matchId,
          participantId: incoming,
          teamId: home,
        ),
      ),
      isA<TeamBindingCommitSuccess>(),
    );

    final goal = await composition.boundary.commitGoal(
      context,
      scoringTeamId: home,
      captureIntentId: 'intent-goal',
    );
    final yellow = await composition.boundary.commitYellow(
      context,
      participantId: outgoing,
      accountingScope: DisciplinaryAccountingScope.match,
      captureIntentId: 'intent-yellow-1',
    );
    final secondYellow = await composition.boundary.commitYellow(
      context,
      participantId: outgoing,
      accountingScope: DisciplinaryAccountingScope.match,
      captureIntentId: 'intent-yellow-2',
    );
    expect(goal, isA<DurableCommitSuccess>());
    expect(yellow, isA<DurableCommitSuccess>());
    expect(secondYellow, isA<DurableCommitSuccess>());
    final sendOff = await composition.boundary.commitSecondCautionSendOff(
      context,
      subject: ParticipantDisciplinarySubject(outgoing),
      accountingScope: DisciplinaryAccountingScope.match,
      captureIntentId: 'intent-send-off',
      firstYellowRecordId: (yellow as DurableCommitSuccess).committedRecordId,
      secondYellowRecordId:
          (secondYellow as DurableCommitSuccess).committedRecordId,
    );
    final substitution = await composition.boundary.commitSubstitution(
      context,
      outgoingParticipantId: outgoing,
      incomingParticipantId: incoming,
      teamId: home,
      captureIntentId: 'intent-sub',
    );
    final direct = await composition.boundary.commitDirectSendOff(
      context,
      subject: ParticipantDisciplinarySubject(incoming),
      accountingScope: DisciplinaryAccountingScope.match,
      captureIntentId: 'intent-direct',
    );
    expect(sendOff, isA<DurableCommitSuccess>());
    expect(substitution, isA<DurableCommitSuccess>());
    expect(direct, isA<DurableCommitSuccess>());

    final report = await composition.boundary.readMatchReport(
      matchId: match.matchId,
      evaluatedAuthorityGeneration: context.projectionAuthorityGeneration,
      homeTeamId: home,
      awayTeamId: away,
    );
    expect(report.readiness, MatchReportReadiness.readable);
    expect((report.score as KnownScore).goalsByTeam[home], 1);
    expect((report.score as KnownScore).goalsByTeam[away], 0);
    expect(
      report.entries.whereType<GoalReportEntry>().single.recordId,
      (goal as DurableCommitSuccess).committedRecordId,
    );
    expect(report.entries.whereType<YellowReportEntry>(), hasLength(2));
    final secondCaution =
        report.entries.whereType<SendOffReportEntry>().singleWhere(
              (entry) => entry.pathway == SendOffPathway.secondCaution,
            );
    expect(secondCaution.classification, MatchReportClassification.known);
    expect(secondCaution.dependencyStatus, SendOffDependencyStatus.ready);
    expect(report.entries.whereType<SubstitutionReportEntry>(), hasLength(1));
    for (final entry in report.entries) {
      expect(entry.timeFact, MatchReportTimeFact.exactMatchTimeUnavailable);
    }

    final legacyMatch = await legacy.getMatch(match.matchId);
    expect(legacyMatch!.events, isEmpty);
    expect(legacyMatch.score.home, 0);
    expect(legacyMatch.score.away, 0);

    await composition.close();
    composition = await MatchApplicationComposition.open(storageRoot: temp);
    final rebuilt = await composition.boundary.readMatchReport(
      matchId: match.matchId,
      evaluatedAuthorityGeneration: context.projectionAuthorityGeneration,
      homeTeamId: home,
      awayTeamId: away,
    );
    expect(rebuilt, report);
  });

  test('a failed D1 commit is absent from the rebuilt report', () async {
    final match = await seedMatch();
    final context = identity.contextFor(match.matchId);
    final home = MatchTeamId(match.teams.home.teamId);
    final away = MatchTeamId(match.teams.away.teamId);
    await rootAndKickOff(match);
    composition.boundary.durableStore.abortBeforeCommitForTest = () {
      throw StateError('abort before commit');
    };
    final failed = await composition.boundary.commitYellow(
      context,
      participantId: MatchParticipantId('person-x'),
      accountingScope: DisciplinaryAccountingScope.match,
      captureIntentId: 'intent-fail',
    );
    expect(failed, isA<DurableCommitFailure>());

    final report = await composition.boundary.readMatchReport(
      matchId: match.matchId,
      evaluatedAuthorityGeneration: context.projectionAuthorityGeneration,
      homeTeamId: home,
      awayTeamId: away,
    );
    expect(report.entries.whereType<YellowReportEntry>(), isEmpty);
    expect(report.entries.whereType<TemporalReportEntry>(), hasLength(2));
    expect((await legacy.getMatch(match.matchId))!.events, isEmpty);
  });

  test('a substitution without team evidence is not saved', () async {
    final match = await seedMatch();
    final context = identity.contextFor(match.matchId);
    await rootAndKickOff(match);
    final result = await composition.boundary.commitSubstitution(
      context,
      outgoingParticipantId: MatchParticipantId('out-1'),
      incomingParticipantId: MatchParticipantId('in-1'),
      teamId: MatchTeamId(match.teams.home.teamId),
      captureIntentId: 'intent-sub',
    );
    expect(result, isA<DurableCommitFailure>());
    final report = await composition.boundary.readMatchReport(
      matchId: match.matchId,
      evaluatedAuthorityGeneration: context.projectionAuthorityGeneration,
      homeTeamId: MatchTeamId(match.teams.home.teamId),
      awayTeamId: MatchTeamId(match.teams.away.teamId),
    );
    expect(report.entries.whereType<SubstitutionReportEntry>(), isEmpty);
  });
}
