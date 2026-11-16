import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/app.dart';
import 'package:referee_phone/app_scope.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/match/new_match.dart';
import 'package:referee_phone/match_application/kick_off_authority.dart';
import 'package:referee_phone/match_application/match_application_boundary.dart';
import 'package:referee_phone/match_application/match_read_path.dart';

/// Widget captures of the phone Match Report.
///
/// These PNGs are Flutter widget renders of [MatchReportPage] after real
/// SQLite commits. They are not device or emulator screenshots.
Future<void> loadCaptureFonts() async {
  Future<ByteData> bytes(String path) async {
    return ByteData.sublistView(File(path).readAsBytesSync());
  }

  final regular = FontLoader('Roboto')
    ..addFont(bytes('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'));
  await regular.load();
  final bold = FontLoader('Roboto')
    ..addFont(bytes('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'));
  await bold.load();
}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  late LocalMatchDatabase db;
  late Directory temp;
  late MatchApplicationComposition composition;
  late PhoneCaptureIdentity identity;

  var fontsReady = false;

  setUp(() async {
    if (!fontsReady) {
      await loadCaptureFonts();
      fontsReady = true;
    }
    db = LocalMatchDatabase.memory();
    temp = await Directory.systemTemp.createTemp('match_report_ui_');
    composition = await MatchApplicationComposition.open(storageRoot: temp);
    identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
  });

  tearDown(() async {
    await composition.close();
    await db.close();
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  RefereeApp testApp() {
    return RefereeApp(
      database: db,
      matchApplication: composition.boundary,
      captureIdentity: identity,
    );
  }

  Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    int maxPumps = 40,
  }) async {
    for (var i = 0; i < maxPumps; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.pump(const Duration(milliseconds: 50));
    }
    fail('Timed out waiting for $finder');
  }

  Future<void> tapReportBeside(WidgetTester tester, String title) async {
    final titleFinder = find.text(title);
    await tester.ensureVisible(titleFinder);
    await tester.pump();
    final titleTop = tester.getTopLeft(titleFinder).dy;
    final buttons = find.widgetWithText(TextButton, 'Match report');
    Finder? chosen;
    var best = double.infinity;
    for (var i = 0; i < buttons.evaluate().length; i++) {
      final finder = buttons.at(i);
      final dy = tester.getTopLeft(finder).dy;
      if (dy + 1 >= titleTop && dy < best) {
        best = dy;
        chosen = finder;
      }
    }
    expect(chosen, isNotNull, reason: 'Match report button for $title');
    await tester.ensureVisible(chosen!);
    await tester.pump();
    await tester.tap(chosen);
    await tester.pump();
  }

  Future<void> openReport(WidgetTester tester, String buttonLabel) async {
    await tester.pumpWidget(testApp());
    await tester.pump();
    final button = find.widgetWithText(TextButton, buttonLabel);
    await pumpUntilFound(tester, button);
    await tester.ensureVisible(button.first);
    await tester.pump();
    final hittable = button.hitTestable();
    await tester
        .tap(hittable.evaluate().isEmpty ? button.first : hittable.first);
    await tester.pump();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.pump();
    final element =
        tester.element(find.byKey(const Key('match-report-capture')));
    final renderObject = element.renderObject! as RenderRepaintBoundary;
    expect(renderObject.debugNeedsPaint, isFalse);
    final layer = renderObject.debugLayer! as OffsetLayer;
    final image = await layer.toImage(renderObject.paintBounds);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final bytes = data!.buffer.asUint8List();
    for (final directory in [
      '/opt/cursor/artifacts/match-report-ui-002',
      '/workspace/docs/forref-execution/evidence/match-report-ui-002',
    ]) {
      Directory(directory).createSync(recursive: true);
      File('$directory/$name.png').writeAsBytesSync(bytes);
    }
  }

  List<String> reportLines(WidgetTester tester) {
    final texts = tester.widgetList<Text>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('report-line-'),
      ),
    );
    return [for (final text in texts) text.data!];
  }

  Future<Match> seedMatch({
    MatchStatus status = MatchStatus.setup,
    String? homeName,
    String? awayName,
    List<MatchEvent> events = const [],
    Score? score,
  }) async {
    final match = newLocalMatch(DateTime.utc(2026, 10, 2, 12));
    final stored = match.copyWith(
      status: status,
      updatedAt: match.updatedAt,
      teams: Teams(
        home: Team(teamId: match.teams.home.teamId, name: homeName),
        away: Team(teamId: match.teams.away.teamId, name: awayName),
      ),
      events: events,
      score: score,
    );
    await db.upsertMatch(stored);
    return stored;
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

  MatchRecord rawRecord({
    required Match match,
    required String recordId,
    required int originSequence,
    required RecordKind recordKind,
    required MatchRecordPayload payload,
    List<RecordRelationship> relationships = const [],
  }) {
    return MatchRecord(
      recordId: recordId,
      matchId: match.matchId,
      recordKind: recordKind,
      schemaVersion: 1,
      recordedAt: DateTime.utc(2026, 10, 2, 15, originSequence),
      originDeviceId: identity.originDeviceId,
      originSequence: originSequence,
      authorityContext: AuthorityContext(
        scope: v1AuthorityScope,
        principal: AuthorityPrincipal(
          principalId: identity.authorityPrincipalId,
        ),
        activeCaptureDevice: ActiveCaptureDevice(
          deviceId: identity.originDeviceId,
        ),
        generation: const AuthorityGeneration(value: 1),
      ),
      payload: payload,
      integrity: IntegrityMetadata(evidenceRefs: [recordId]),
      relationships: relationships,
    );
  }

  test('read path does not treat a missing root as an empty report', () {
    expect(
      classifyMatchReadPath(
        evidence: const MatchMemoryEvidence(
          rootPresent: true,
          readable: true,
          committedCount: 0,
        ),
        legacyMatchPresent: true,
        legacySportingHistory: false,
      ),
      MatchReadPath.unknown,
    );
    expect(
      classifyMatchReadPath(
        evidence: const MatchMemoryEvidence(
          rootPresent: false,
          readable: true,
          committedCount: 0,
        ),
        legacyMatchPresent: true,
        legacySportingHistory: false,
      ),
      MatchReadPath.legacyOnly,
    );
    expect(
      classifyMatchReadPath(
        evidence: const MatchMemoryEvidence(
          rootPresent: true,
          readable: true,
          committedCount: 2,
        ),
        legacyMatchPresent: true,
        legacySportingHistory: false,
      ),
      MatchReadPath.matchMemory,
    );
    expect(
      classifyMatchReadPath(
        evidence: const MatchMemoryEvidence(
          rootPresent: true,
          readable: true,
          committedCount: 2,
        ),
        legacyMatchPresent: true,
        legacySportingHistory: true,
      ),
      MatchReadPath.ambiguous,
    );
    expect(
      classifyMatchReadPath(
        evidence: const MatchMemoryEvidence(
          rootPresent: false,
          readable: true,
          committedCount: 1,
        ),
        legacyMatchPresent: true,
        legacySportingHistory: false,
      ),
      MatchReadPath.ambiguous,
    );
    expect(
      classifyMatchReadPath(
        evidence: const MatchMemoryEvidence(
          rootPresent: true,
          readable: false,
          committedCount: 0,
        ),
        legacyMatchPresent: true,
        legacySportingHistory: true,
      ),
      MatchReadPath.unavailable,
    );
    expect(
      classifyMatchReadPath(
        evidence: null,
        legacyMatchPresent: true,
        legacySportingHistory: false,
      ),
      MatchReadPath.legacyOnly,
    );
  });

  testWidgets('MR02-01 02 04 05 known report opens from the match list', (
    tester,
  ) async {
    final match = await seedMatch();
    final context = identity.contextFor(match.matchId);
    await rootAndKickOff(match);
    expect(
      await composition.boundary.commitGoal(
        context,
        scoringTeamId: MatchTeamId(match.teams.home.teamId),
        captureIntentId: 'intent-goal',
      ),
      isA<DurableCommitSuccess>(),
    );
    expect(
      await composition.boundary.commitYellow(
        context,
        participantId: MatchParticipantId('person-1'),
        accountingScope: DisciplinaryAccountingScope.match,
        captureIntentId: 'intent-yellow',
      ),
      isA<DurableCommitSuccess>(),
    );

    await openReport(tester, 'Match report');
    await pumpUntilFound(tester, find.text('HOME 1 — 0 AWAY'));
    expect(find.text('Match report'), findsWidgets);
    expect(find.text('Time unavailable'), findsWidgets);
    expect(find.text('Score unavailable'), findsNothing);
    expect(find.text('00:00'), findsNothing);
    expect(find.textContaining(RegExp(r'\d{2}:\d{2}')), findsNothing);
    expect(find.textContaining('2026'), findsNothing);
    expect(
      reportLines(tester),
      [
        'Match started',
        'Period 1 started',
        'Goal',
        'Yellow card',
      ],
    );
    expect(find.text('Saved'), findsNothing);
    await capture(tester, 'mr02-known-score-en');
  });

  testWidgets('MR02-03 a goal outside the proof is not a 0-0 score', (
    tester,
  ) async {
    final match = await seedMatch();
    final context = identity.contextFor(match.matchId);
    expect(
      await composition.boundary.commitGoal(
        context,
        scoringTeamId: MatchTeamId('outside-team'),
        captureIntentId: 'intent-outside',
      ),
      isA<DurableCommitSuccess>(),
    );
    await openReport(tester, 'Match report');
    await pumpUntilFound(tester, find.text('Score unavailable'));
    expect(reportLines(tester), ['Goal']);
    expect(find.text('Team'), findsOneWidget);
    expect(find.text('HOME 0 — 0 AWAY'), findsNothing);
    expect(find.textContaining('0 — 0'), findsNothing);
    await capture(tester, 'mr02-score-unavailable-en');
  });

  testWidgets('MR02-06 two yellows do not become a send-off', (tester) async {
    final match = await seedMatch();
    final context = identity.contextFor(match.matchId);
    await rootAndKickOff(match);
    expect(
      await composition.boundary.commitYellow(
        context,
        participantId: MatchParticipantId('person-1'),
        accountingScope: DisciplinaryAccountingScope.match,
        captureIntentId: 'intent-yellow-1',
      ),
      isA<DurableCommitSuccess>(),
    );
    expect(
      await composition.boundary.commitYellow(
        context,
        participantId: MatchParticipantId('person-1'),
        accountingScope: DisciplinaryAccountingScope.match,
        captureIntentId: 'intent-yellow-2',
      ),
      isA<DurableCommitSuccess>(),
    );
    await openReport(tester, 'Match report');
    await pumpUntilFound(
        tester, find.text('Two yellow cards are not a send-off'));
    expect(
      reportLines(tester).where((line) => line == 'Yellow card'),
      hasLength(2),
    );
    expect(reportLines(tester), isNot(contains('Send-off')));
    expect(find.text('Red'), findsNothing);
    expect(find.text('Second caution'), findsNothing);
    await capture(tester, 'mr02-two-yellows-en');
  });

  testWidgets('MR02-06 second caution without yellows stays unavailable', (
    tester,
  ) async {
    final match = await seedMatch();
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
      await composition.boundary.commit(
        rawRecord(
          match: match,
          recordId: 'off-1',
          originSequence: 1,
          recordKind: RecordKind.humanDetermination,
          payload: SendOffPayload(
            disciplinarySubject: ParticipantDisciplinarySubject(
              MatchParticipantId('person-1'),
            ),
            disciplinaryScope: DisciplinaryAccountingScope.match,
            pathway: SendOffPathway.secondCaution,
            captureIntentId: 'intent-off',
            firstStandingCautionRecordId: 'yellow-1',
            secondCautionRecordId: 'yellow-2',
          ),
          relationships: const [
            CausalDependency(targetRecordId: 'yellow-1'),
            CausalDependency(targetRecordId: 'yellow-2'),
          ],
        ),
      ),
      isA<DurableCommitSuccess>(),
    );
    await openReport(tester, 'Match report');
    await pumpUntilFound(tester, find.text('Second caution'));
    expect(reportLines(tester), ['Send-off']);
    expect(find.text('Send-off dependencies unavailable'), findsOneWidget);
    expect(find.text('Unavailable'), findsWidgets);
    expect(find.text('Red'), findsNothing);
    await capture(tester, 'mr02-second-caution-unavailable-en');
  });

  testWidgets('MR02-07 conflicting corrections are a visible conflict', (
    tester,
  ) async {
    final match = await seedMatch();
    final context = identity.contextFor(match.matchId);
    await rootAndKickOff(match);
    final goal = await composition.boundary.commitGoal(
      context,
      scoringTeamId: MatchTeamId(match.teams.home.teamId),
      captureIntentId: 'intent-goal',
    );
    expect(goal, isA<DurableCommitSuccess>());
    final goalId = (goal as DurableCommitSuccess).committedRecordId;
    final committed =
        await composition.boundary.durableStore.readCommittedForMatch(
      match.matchId,
    );
    final next = committed
            .map((record) => record.originSequence)
            .reduce((a, b) => a > b ? a : b) +
        1;
    expect(
      await composition.boundary.commit(
        rawRecord(
          match: match,
          recordId: 'corr-a',
          originSequence: next,
          recordKind: RecordKind.correction,
          payload: CorrectionPayload(
            repairedScoringTeamId: MatchTeamId(match.teams.home.teamId),
          ),
          relationships: [CorrectionTarget(targetRecordId: goalId)],
        ),
      ),
      isA<DurableCommitSuccess>(),
    );
    expect(
      await composition.boundary.commit(
        rawRecord(
          match: match,
          recordId: 'corr-b',
          originSequence: next + 1,
          recordKind: RecordKind.correction,
          payload: CorrectionPayload(
            repairedScoringTeamId: MatchTeamId(match.teams.away.teamId),
          ),
          relationships: [CorrectionTarget(targetRecordId: goalId)],
        ),
      ),
      isA<DurableCommitSuccess>(),
    );
    await openReport(tester, 'Match report');
    await pumpUntilFound(tester, find.text('Goal: Conflict'));
    expect(find.text('Score conflict'), findsOneWidget);
    expect(reportLines(tester), isNot(contains('Goal')));
    expect(find.textContaining('0 — 0'), findsNothing);
    expect(find.text('HOME 1 — 0 AWAY'), findsNothing);
    await capture(tester, 'mr02-conflict-en');
  });

  testWidgets('MR02-07 an unsupported payload is not a goal', (tester) async {
    final match = await seedMatch();
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
      await composition.boundary.commit(
        rawRecord(
          match: match,
          recordId: 'blob-1',
          originSequence: 1,
          recordKind: RecordKind.occurrence,
          payload: StructuredPayload(const {'event': 'goal', 'minute': 12}),
        ),
      ),
      isA<DurableCommitSuccess>(),
    );
    await openReport(tester, 'Match report');
    await pumpUntilFound(tester, find.text('Unsupported record blob-1'));
    expect(reportLines(tester), isEmpty);
    expect(find.text('Score unavailable'), findsOneWidget);
    expect(find.textContaining('00:'), findsNothing);
    await capture(tester, 'mr02-unsupported-en');
  });

  testWidgets('MR02-08 quarantine does not fall back to the legacy summary', (
    tester,
  ) async {
    final match = await seedMatch(
      status: MatchStatus.completed,
      events: [
        MatchEvent(
          eventId: 'legacy-1',
          matchId: 'pending',
          type: EventType.goal,
          status: EventStatus.complete,
          periodId: PeriodId.firstHalf,
          matchTime: 754,
          createdAt: DateTime.utc(2026, 10, 2, 12),
          updatedAt: DateTime.utc(2026, 10, 2, 12),
          data: const EventData(),
        ),
      ],
    );
    final withId = match.copyWith(
      events: [
        MatchEvent(
          eventId: 'legacy-1',
          matchId: match.matchId,
          type: EventType.goal,
          status: EventStatus.complete,
          periodId: PeriodId.firstHalf,
          matchTime: 754,
          createdAt: DateTime.utc(2026, 10, 2, 12),
          updatedAt: DateTime.utc(2026, 10, 2, 12),
          data: const EventData(),
        ),
      ],
    );
    await db.upsertMatch(withId);
    final context = identity.contextFor(match.matchId);
    expect(
      await composition.boundary.commitGoal(
        context,
        scoringTeamId: MatchTeamId(match.teams.home.teamId),
        captureIntentId: 'intent-goal',
      ),
      isA<DurableCommitSuccess>(),
    );
    final databasePath = composition.databaseFile.path;
    await composition.close();
    final corrupt = await Process.run('python3', [
      '-c',
      "import sqlite3,sys; c=sqlite3.connect(sys.argv[1]); c.execute(\"UPDATE committed_match_records SET record_json='not-json'\"); c.commit()",
      databasePath,
    ]);
    expect(corrupt.exitCode, 0, reason: '${corrupt.stdout}${corrupt.stderr}');
    composition = await MatchApplicationComposition.open(storageRoot: temp);
    await openReport(tester, 'Match report');
    await pumpUntilFound(tester, find.text('Match report cannot be read'));
    expect(find.text('Summary'), findsNothing);
    expect(find.text('12:34'), findsNothing);
    expect(find.text('Goal'), findsNothing);
    expect(find.textContaining('0 — 0'), findsNothing);
    expect((await db.getMatch(match.matchId))!.events, hasLength(1));
    await capture(tester, 'mr02-unreadable-en');
  });

  testWidgets('MR02-09 a pre-D1 failure adds no line and no Saved', (
    tester,
  ) async {
    final match = await seedMatch();
    final context = identity.contextFor(match.matchId);
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
    await openReport(tester, 'Match report');
    await pumpUntilFound(tester, find.text('Match started'));
    expect(reportLines(tester), ['Match started', 'Period 1 started']);
    expect(find.text('Yellow card'), findsNothing);
    expect(find.textContaining('Saved'), findsNothing);
  });

  testWidgets('MR02-10 reopening the same SQLite file keeps the report', (
    tester,
  ) async {
    final match = await seedMatch();
    final context = identity.contextFor(match.matchId);
    await rootAndKickOff(match);
    expect(
      await composition.boundary.commitGoal(
        context,
        scoringTeamId: MatchTeamId(match.teams.home.teamId),
        captureIntentId: 'intent-goal',
      ),
      isA<DurableCommitSuccess>(),
    );
    await openReport(tester, 'Match report');
    await pumpUntilFound(tester, find.text('HOME 1 — 0 AWAY'));
    final before = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .toList();
    await composition.close();
    composition = await MatchApplicationComposition.open(storageRoot: temp);
    await openReport(tester, 'Match report');
    await pumpUntilFound(tester, find.text('HOME 1 — 0 AWAY'));
    final after = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .toList();
    expect(after, before);
    expect(reportLines(tester), ['Match started', 'Period 1 started', 'Goal']);
  });

  testWidgets('MR02-11 legacy summary stays and ambiguous mode fails closed', (
    tester,
  ) async {
    final legacy = await seedMatch(
      status: MatchStatus.completed,
      homeName: 'Legacy Home',
      awayName: 'Legacy Away',
    );
    await db.upsertMatch(
      legacy.copyWith(
        events: [
          MatchEvent(
            eventId: 'legacy-goal',
            matchId: legacy.matchId,
            type: EventType.goal,
            status: EventStatus.complete,
            periodId: PeriodId.firstHalf,
            matchTime: 754,
            createdAt: DateTime.utc(2026, 10, 2, 12),
            updatedAt: DateTime.utc(2026, 10, 2, 12),
            data: const EventData(),
          ),
        ],
      ),
    );
    final memory = await seedMatch(
      homeName: 'Memory Home',
      awayName: 'Memory Away',
    );
    final context = identity.contextFor(memory.matchId);
    expect(
      await composition.boundary.commitGoal(
        context,
        scoringTeamId: MatchTeamId(memory.teams.home.teamId),
        captureIntentId: 'intent-memory-goal',
      ),
      isA<DurableCommitSuccess>(),
    );
    await db.upsertMatch(
      (await db.getMatch(memory.matchId))!.copyWith(
        events: [
          MatchEvent(
            eventId: 'mixed-goal',
            matchId: memory.matchId,
            type: EventType.goal,
            status: EventStatus.complete,
            periodId: PeriodId.firstHalf,
            matchTime: 754,
            createdAt: DateTime.utc(2026, 10, 2, 12),
            updatedAt: DateTime.utc(2026, 10, 2, 12),
            data: const EventData(),
          ),
        ],
      ),
    );

    await tester.pumpWidget(testApp());
    await tester.pump();
    await pumpUntilFound(tester, find.text('Legacy Home – Legacy Away'));
    await tester.tap(find.text('Legacy Home – Legacy Away'));
    await tester.pump();
    await pumpUntilFound(tester, find.text('Summary'));
    expect(find.textContaining('12:34'), findsWidgets);
    await tester.pump();
    final summaryElement =
        tester.element(find.byKey(const Key('summary-capture')));
    final summaryObject = summaryElement.renderObject! as RenderRepaintBoundary;
    expect(summaryObject.debugNeedsPaint, isFalse);
    final summaryLayer = summaryObject.debugLayer! as OffsetLayer;
    final summaryImage = await summaryLayer.toImage(summaryObject.paintBounds);
    final summaryBytes = await summaryImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    summaryImage.dispose();
    for (final directory in [
      '/opt/cursor/artifacts/match-report-ui-002',
      '/workspace/docs/forref-execution/evidence/match-report-ui-002',
    ]) {
      File('$directory/mr02-legacy-summary-en.png').writeAsBytesSync(
        summaryBytes!.buffer.asUint8List(),
      );
    }
    await tester.pageBack();
    await pumpUntilFound(tester, find.text('Legacy Home – Legacy Away'));
    await tapReportBeside(tester, 'Legacy Home – Legacy Away');
    await tester.pump();
    await pumpUntilFound(
      tester,
      find.text('This match stays on the legacy summary'),
    );
    expect(find.textContaining('12:34'), findsNothing);
    expect(find.textContaining('0 — 0'), findsNothing);
    expect(find.text('No report lines'), findsNothing);
    await capture(tester, 'mr02-legacy-only-en');
    expect((await db.getMatch(legacy.matchId))!.events, hasLength(1));

    await tester.pageBack();
    await pumpUntilFound(tester, find.text('Memory Home – Memory Away'));
    await tapReportBeside(tester, 'Memory Home – Memory Away');
    await tester.pump();
    await pumpUntilFound(tester, find.text('Match authority is ambiguous'));
    expect(find.text('HOME 1 — 0 AWAY'), findsNothing);
    expect(find.text('Memory Home 1 — 0 Memory Away'), findsNothing);
    expect(find.textContaining('12:34'), findsNothing);
    expect(find.text('No report lines'), findsNothing);
    expect((await db.getMatch(memory.matchId))!.events, hasLength(1));
    final evidence = await composition.boundary.readMatchMemoryEvidence(
      memory.matchId,
    );
    expect(evidence.committedCount, greaterThan(0));
    await capture(tester, 'mr02-ambiguous-en');
  });

  testWidgets('MR02-12 Romanian labels wrap, refresh, and go back', (
    tester,
  ) async {
    final match = await seedMatch(
      homeName: 'Echipa gazdă cu un nume foarte lung pentru ecran îngust',
      awayName: 'Echipa oaspete cu un nume foarte lung pentru ecran îngust',
    );
    final context = identity.contextFor(match.matchId);
    expect(
      await composition.boundary.commitYellow(
        context,
        participantId: MatchParticipantId('person-1'),
        accountingScope: DisciplinaryAccountingScope.match,
        captureIntentId: 'intent-yellow-1',
      ),
      isA<DurableCommitSuccess>(),
    );
    await tester.pumpWidget(testApp());
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pump();
    await pumpUntilFound(tester, find.text('Matches'));
    AppScope.of(tester.element(find.text('Matches'))).locale.value =
        const Locale('ro');
    await tester.pump();
    await pumpUntilFound(tester, find.text('Raportul meciului'));
    final reportButton = find.widgetWithText(TextButton, 'Raportul meciului');
    await tester.ensureVisible(reportButton);
    await tester.tap(reportButton);
    await tester.pump();
    await pumpUntilFound(tester, find.text('Timp indisponibil'));
    expect(tester.takeException(), isNull);
    expect(
      find.text(
        'Numele echipelor sunt doar etichete de prezentare, nu o dovadă de completitudine',
      ),
      findsOneWidget,
    );
    expect(find.text('Participant fără nume confirmat'), findsOneWidget);
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel(RegExp('Timp indisponibil')), findsWidgets);
    handle.dispose();
    await capture(tester, 'mr02-ro-narrow');
    expect(
      await composition.boundary.commitYellow(
        context,
        participantId: MatchParticipantId('person-1'),
        accountingScope: DisciplinaryAccountingScope.match,
        captureIntentId: 'intent-yellow-2',
      ),
      isA<DurableCommitSuccess>(),
    );
    final refresh = find.text('Reîncarcă raportul meciului');
    await tester.ensureVisible(refresh);
    await tester.tap(refresh);
    await tester.pump();
    await pumpUntilFound(
      tester,
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == 'Cartonaș galben' &&
            widget.key is ValueKey<String>,
      ),
    );
    expect(
      tester
          .widgetList<Text>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Text &&
                  widget.data == 'Cartonaș galben' &&
                  widget.key is ValueKey<String>,
            ),
          )
          .length,
      2,
    );
    expect(tester.takeException(), isNull);
    final back = find.byTooltip('Înapoi');
    await tester.ensureVisible(back);
    await tester.tap(back);
    await tester.pump();
    await pumpUntilFound(tester, find.text('Meciuri'));
  });

  testWidgets('MR02-13 the report does not finish the match', (tester) async {
    final match = await seedMatch(status: MatchStatus.live);
    await rootAndKickOff(match);
    final before = await composition.boundary.readMatchMemoryEvidence(
      match.matchId,
    );
    final beforeReport = await composition.boundary.readMatchReport(
      matchId: match.matchId,
      evaluatedAuthorityGeneration:
          PhoneCaptureIdentity.initialAuthorityGeneration,
      homeTeamId: MatchTeamId(match.teams.home.teamId),
      awayTeamId: MatchTeamId(match.teams.away.teamId),
    );
    await tester.pumpWidget(testApp());
    await tester.pump();
    await pumpUntilFound(tester, find.text('HOME – AWAY'));
    await tester.ensureVisible(find.text('HOME – AWAY'));
    await tester.tap(find.text('HOME – AWAY'));
    await tester.pump();
    await pumpUntilFound(tester, find.text('Match report'));
    final reportButton = find.widgetWithText(TextButton, 'Match report');
    await tester.ensureVisible(reportButton);
    await tester.tap(reportButton);
    await tester.pump();
    await pumpUntilFound(tester, find.text('Match started'));
    expect(
      find.descendant(
        of: find.byKey(const Key('match-report-capture')),
        matching: find.text('Finish match'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('match-report-capture')),
        matching: find.text('Full time'),
      ),
      findsNothing,
    );
    expect(find.text('Saved'), findsNothing);
    await tester.pageBack();
    await tester.pump();
    expect((await db.getMatch(match.matchId))!.status, MatchStatus.live);
    final after = await composition.boundary.readMatchMemoryEvidence(
      match.matchId,
    );
    final afterReport = await composition.boundary.readMatchReport(
      matchId: match.matchId,
      evaluatedAuthorityGeneration:
          PhoneCaptureIdentity.initialAuthorityGeneration,
      homeTeamId: MatchTeamId(match.teams.home.teamId),
      awayTeamId: MatchTeamId(match.teams.away.teamId),
    );
    expect(after.committedCount, before.committedCount);
    expect(afterReport.temporal.matchNormallyEnded, isFalse);
    expect(
      beforeReport.temporal.matchNormallyEnded,
      afterReport.temporal.matchNormallyEnded,
    );
  });

  testWidgets('an empty readable report is not an unknown authority', (
    tester,
  ) async {
    final unknown =
        await seedMatch(homeName: 'Unknown Home', awayName: 'Unknown Away');
    final context = identity.contextFor(unknown.matchId);
    expect(
      await composition.boundary.durableStore.commitGenerationOneAuthorityRoot(
        GenerationOneAuthorityRoot(
          matchId: unknown.matchId,
          principalId: context.authorityPrincipalId,
          deviceId: context.originDeviceId,
        ),
      ),
      isA<GenerationOneRootCommitSuccess>(),
    );
    final empty =
        await seedMatch(homeName: 'Empty Home', awayName: 'Empty Away');
    final emptyContext = identity.contextFor(empty.matchId);
    expect(
      await composition.boundary.durableStore.commitGenerationOneAuthorityRoot(
        GenerationOneAuthorityRoot(
          matchId: empty.matchId,
          principalId: emptyContext.authorityPrincipalId,
          deviceId: emptyContext.originDeviceId,
        ),
      ),
      isA<GenerationOneRootCommitSuccess>(),
    );
    expect(
      await composition.boundary.commit(
        rawRecord(
          match: empty,
          recordId: 'entered-1',
          originSequence: 1,
          recordKind: RecordKind.temporalFact,
          payload: RefereeEnteredFieldPayload(captureIntentId: 'intent-enter'),
        ),
      ),
      isA<DurableCommitSuccess>(),
    );

    await tester.pumpWidget(testApp());
    await tester.pump();
    await pumpUntilFound(tester, find.text('Unknown Home – Unknown Away'));
    await tapReportBeside(tester, 'Unknown Home – Unknown Away');
    await pumpUntilFound(tester, find.text('Match authority is unknown'));
    expect(find.text('No report lines'), findsNothing);
    expect(find.textContaining('0 — 0'), findsNothing);
    await capture(tester, 'mr02-unknown-en');
    await tester.pageBack();
    await pumpUntilFound(tester, find.text('Empty Home – Empty Away'));
    await tapReportBeside(tester, 'Empty Home – Empty Away');
    await pumpUntilFound(tester, find.text('No report lines'));
    expect(find.text('Match authority is unknown'), findsNothing);
    expect(find.text('Score unavailable'), findsNothing);
    expect(find.text('Empty Home 0 — 0 Empty Away'), findsOneWidget);
    await capture(tester, 'mr02-empty-readable-en');
  });

  test('MR02-14 the report screen has no match writer', () {
    final source = File(
      'lib/features/match_report/match_report_page.dart',
    ).readAsStringSync();
    expect(source.contains('saveEvent'), isFalse);
    expect(source.contains('.finish('), isFalse);
    expect(source.contains('commitGoal'), isFalse);
    expect(source.contains('commitYellow'), isFalse);
    expect(source.contains('commitKickOff'), isFalse);
    expect(source.contains('readMatchReport'), isTrue);
  });
}
