import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide ActivateIntent;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_presentation/simulator_presentation.dart';
import 'package:watch_reference_ui/watch_reference_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    const regular = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';
    const bold = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf';
    if (!File(regular).existsSync() || !File(bold).existsSync()) return;
    Future<ByteData> bytes(String path) async {
      return ByteData.sublistView(File(path).readAsBytesSync());
    }

    final loader = FontLoader('Roboto')..addFont(bytes(regular));
    await loader.load();
    final boldLoader = FontLoader('Roboto')..addFont(bytes(bold));
    await boldLoader.load();
  });

  testWidgets(
      'ten cells plus unknown clock and score save reference screenshots',
      (tester) async {
    final shots = <String, Size>{};
    Future<void> cell({
      required String name,
      required Size size,
      required WatchFaceShape face,
      WatchLiveLayout layout = WatchLiveLayout.centered,
      WatchDesignFrame frame = WatchDesignFrame.flow,
      WatchPresentationState? state,
      bool beyond = false,
      Color? homeKit,
      Color? awayKit,
      WatchLanguage language = WatchLanguage.en,
    }) async {
      await tester.binding.setSurfaceSize(size + const Offset(40, 80));
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: const Key('shot'),
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: WatchReferenceApp(
                  state: state ?? _trusted(),
                  onIntent: _ignore,
                  face: face,
                  liveLayout: layout,
                  frame: frame,
                  showBeyondNominal: beyond,
                  homeKit: homeKit,
                  awayKit: awayKit,
                  language: language,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('shot')),
      );
      final recorded = await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final size = Size(image.width.toDouble(), image.height.toDouble());
        image.dispose();
        final file = File('/opt/cursor/artifacts/watch_design/app-$name.png');
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(data!.buffer.asUint8List());
        return size;
      });
      shots[name] = recorded!;
    }

    const round = Size(280, 300);
    const rect = Size(240, 320);
    final people = _people();
    final rosterState =
        _trusted(roster: people.players, officials: people.officials);

    await cell(
        name: 'L-A1-centered-round', size: round, face: WatchFaceShape.round);
    await cell(
        name: 'L-A2-centered-rect',
        size: rect,
        face: WatchFaceShape.rectangular);
    await cell(
      name: 'L-C1-score-side-round',
      size: round,
      face: WatchFaceShape.round,
      layout: WatchLiveLayout.scoreSide,
    );
    await cell(
      name: 'L-C2-score-side-rect',
      size: rect,
      face: WatchFaceShape.rectangular,
      layout: WatchLiveLayout.scoreSide,
    );
    await cell(
      name: 'C-R-capture-round',
      size: round,
      face: WatchFaceShape.round,
      state: _trusted(route: WatchRoute.captureMenu),
    );
    await cell(
      name: 'C-X-capture-rect',
      size: rect,
      face: WatchFaceShape.rectangular,
      state: _trusted(route: WatchRoute.captureMenu),
    );
    await cell(
      name: 'T-R-team-round',
      size: round,
      face: WatchFaceShape.round,
      frame: WatchDesignFrame.team,
    );
    await cell(
      name: 'T-X-team-rect',
      size: rect,
      face: WatchFaceShape.rectangular,
      frame: WatchDesignFrame.team,
      homeKit: const Color(0xFF1F4E79),
      awayKit: const Color(0xFF1F4E79),
    );
    await cell(
      name: 'P-R-participant-round',
      size: round,
      face: WatchFaceShape.round,
      frame: WatchDesignFrame.participant,
      state: rosterState,
    );
    await cell(
      name: 'P-X-participant-rect',
      size: rect,
      face: WatchFaceShape.rectangular,
      frame: WatchDesignFrame.participant,
      state: rosterState,
    );
    await cell(
      name: 'unknown-score',
      size: rect,
      face: WatchFaceShape.rectangular,
      state: _trusted(score: ScorePresentation.unavailable),
    );
    await cell(
      name: 'unknown-time',
      size: round,
      face: WatchFaceShape.round,
      state: _trusted(clock: ClockPresentation.unavailable),
    );
    await cell(
      name: 'beyond-nominal',
      size: round,
      face: WatchFaceShape.round,
      beyond: true,
      state: _trusted(
        clock: const ClockPresentation(
          available: true,
          label: '03:24',
          phaseLabel: '2ND HALF',
        ),
      ),
    );
    await cell(
      name: 'conflicted-score',
      size: rect,
      face: WatchFaceShape.rectangular,
      layout: WatchLiveLayout.scoreSide,
      state: _trusted(
        score: const ScorePresentation(
          available: false,
          label: 'Score conflicted',
        ),
      ),
    );

    final manifest = shots.entries
        .map((entry) =>
            '${entry.key} ${entry.value.width.toInt()}x${entry.value.height.toInt()}')
        .join('\n');
    File('/opt/cursor/artifacts/watch_design/app-dimensions.txt')
        .writeAsStringSync('$manifest\n');
    expect(shots, hasLength(14));
  });

  testWidgets(
      'capture navigation does not activate and blocks an unsupported family',
      (tester) async {
    final intents = <WatchIntent>[];
    await _pump(
      tester,
      state: _trusted(route: WatchRoute.captureMenu),
      face: WatchFaceShape.round,
      onIntent: intents.add,
      blocked: const {WatchCaptureFamily.goal},
    );
    expect(find.text('Capture Event'), findsNothing);
    expect(find.text('Blocked'), findsOneWidget);
    expect(find.byKey(const Key('watch-family-glyph-yellow')), findsOneWidget);
    expect(find.byKey(const Key('watch-family-glyph-red')), findsOneWidget);
    expect(find.byKey(const Key('watch-family-glyph-goal')), findsOneWidget);
    expect(find.byKey(const Key('watch-family-glyph-substitution')),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('watch-capture-center')));
    await tester.pump();
    expect(intents, isEmpty);

    await tester.tap(find.byKey(const Key('watch-capture-goal')));
    await tester.pump();
    expect(intents, isEmpty);

    final yellow =
        tester.getRect(find.byKey(const Key('watch-capture-yellow')));
    final red = tester.getRect(find.byKey(const Key('watch-capture-red')));
    final sub = tester.getRect(find.byKey(const Key('watch-capture-sub')));
    expect(yellow.overlaps(red), isFalse);
    expect(yellow.overlaps(sub), isFalse);
    expect(red.overlaps(sub), isFalse);

    final gesture = await tester.startGesture(yellow.center);
    await gesture.moveBy(const Offset(0, 240));
    await gesture.up();
    await tester.pump();
    expect(intents, isEmpty);

    await tester.tap(find.byKey(const Key('watch-capture-yellow')));
    await tester.pump();
    expect(intents, isEmpty);
    expect(find.byKey(const Key('watch-design-team')), findsOneWidget);
    expect(intents.whereType<ActivateIntent>(), isEmpty);

    intents.clear();
    await tester.tap(find.byKey(const Key('watch-team-back')));
    await tester.pump();
    expect(intents, isEmpty);
    expect(find.byKey(const Key('watch-design-capture')), findsOneWidget);

    await tester.tap(find.byKey(const Key('watch-capture-back')));
    await tester.pump();
    final back = intents.single as OpenRouteIntent;
    expect(back.route, WatchRoute.liveCore);
    expect(intents.whereType<ActivateIntent>(), isEmpty);
  });

  testWidgets(
      'rectangular capture keeps the diagonal and Live Match returns without a record',
      (tester) async {
    final intents = <WatchIntent>[];
    await _pump(
      tester,
      state: _trusted(route: WatchRoute.captureMenu),
      face: WatchFaceShape.rectangular,
      onIntent: intents.add,
    );
    expect(find.text('Live Match'), findsOneWidget);
    final yellow =
        tester.getRect(find.byKey(const Key('watch-capture-yellow')));
    final sub = tester.getRect(find.byKey(const Key('watch-capture-sub')));
    final goal = tester.getRect(find.byKey(const Key('watch-capture-goal')));
    final red = tester.getRect(find.byKey(const Key('watch-capture-red')));
    expect(yellow.center.dx, lessThan(sub.center.dx));
    expect(yellow.center.dy, lessThan(goal.center.dy));
    expect(goal.center.dx, lessThan(red.center.dx));
    expect(sub.center.dy, lessThan(red.center.dy));
    await tester.tap(find.byKey(const Key('watch-capture-live-match')));
    await tester.pump();
    expect((intents.single as OpenRouteIntent).route, WatchRoute.liveCore);
    expect(intents.whereType<ActivateIntent>(), isEmpty);
  });

  testWidgets(
      'team selection changes context only and missing kit stays neutral',
      (tester) async {
    final intents = <WatchIntent>[];
    await _pump(
      tester,
      frame: WatchDesignFrame.team,
      face: WatchFaceShape.round,
      onIntent: intents.add,
    );
    expect(find.text('No kit color'), findsOneWidget);
    await tester.tap(find.byKey(const Key('watch-team-gap')));
    await tester.pump();
    expect(intents, isEmpty);
    await tester.tap(find.byKey(const Key('watch-team-home')));
    await tester.pump();
    final team = intents.single as SetTeamIntent;
    expect(team.team, PresentationTeam.home);
    expect(intents.whereType<ActivateIntent>(), isEmpty);
  });

  testWidgets('equal kit colors stay neutral and labeled', (tester) async {
    await _pump(
      tester,
      frame: WatchDesignFrame.team,
      face: WatchFaceShape.rectangular,
      homeKit: const Color(0xFF123456),
      awayKit: const Color(0xFF123456),
    );
    expect(find.text('Kit colors match'), findsOneWidget);
  });

  testWidgets(
      'participant tap carries the id and a second page keeps the overflow visible',
      (tester) async {
    final intents = <WatchIntent>[];
    final people = _people();
    await _pump(
      tester,
      frame: WatchDesignFrame.participant,
      face: WatchFaceShape.round,
      state: _trusted(
        roster: people.players,
        officials: people.officials,
        team: PresentationTeamContext.absent,
      ),
      onIntent: intents.add,
    );
    expect(find.text('71'), findsNWidgets(2));
    expect(find.text('80'), findsOneWidget);
    expect(find.textContaining('Players 1/'), findsOneWidget);
    await tester.tap(find.byKey(const Key('watch-participant-home-71')));
    await tester.pump();
    expect(intents.single, isA<SelectParticipantIntent>());
    expect(
        (intents.single as SelectParticipantIntent).participantId, 'home-71');
    expect(intents.whereType<ActivateIntent>(), isEmpty);

    intents.clear();
    await tester.drag(find.byKey(const Key('watch-participant-pager')),
        const Offset(-280, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('More players'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);

    await tester.drag(find.byKey(const Key('watch-participant-pager')),
        const Offset(-280, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Team Officials'), findsOneWidget);
    await tester.tap(find.byKey(const Key('watch-official-coach-home')));
    await tester.pump();
    expect((intents.single as SelectOfficialIntent).officialId, 'coach-home');
    expect(intents.whereType<ActivateIntent>(), isEmpty);
  });

  testWidgets('disabled authority does not emit a selection', (tester) async {
    final intents = <WatchIntent>[];
    final people = _people();
    await _pump(
      tester,
      frame: WatchDesignFrame.participant,
      state: _trusted(roster: people.players, officials: people.officials),
      onIntent: intents.add,
      selectionEnabled: false,
    );
    await tester.tap(find.byKey(const Key('watch-participant-home-71')));
    await tester.pump();
    expect(intents, isEmpty);
    expect(find.text('Blocked'), findsWidgets);
  });

  testWidgets(
      'unknown clock does not show a boundary and conflicted score is not a numeral',
      (tester) async {
    await _pump(
      tester,
      beyond: true,
      state: _trusted(clock: ClockPresentation.unavailable),
    );
    expect(find.text('BEYOND 90:00'), findsNothing);
    expect(find.text('Clock unavailable'), findsOneWidget);
    expect(find.text('00:00'), findsNothing);

    await _pump(
      tester,
      layout: WatchLiveLayout.scoreSide,
      state: _trusted(
        score: const ScorePresentation(
            available: false, label: 'Score conflicted'),
      ),
    );
    expect(find.text('Score conflicted'), findsOneWidget);
    expect(find.byKey(const Key('watch-score-home')), findsNothing);
    expect(find.text('0'), findsNothing);
    final clock = tester.widget<Text>(find.byKey(const Key('watch-clock')));
    expect(clock.style!.fontSize!, greaterThan(18));
  });

  testWidgets('Romanian chrome and text scale do not throw', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: SizedBox(
            width: 280,
            height: 320,
            child: WatchReferenceApp(
              state: _trusted(),
              onIntent: _ignore,
              language: WatchLanguage.ro,
              showBeyondNominal: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('AVERTISMENTE'), findsOneWidget);
    expect(find.text('DUPĂ 90:00'), findsOneWidget);
    expect(find.text('LISTĂ'), findsOneWidget);
  });

  testWidgets('an older input epoch does not commit the capture family',
      (tester) async {
    final intents = <WatchIntent>[];
    Future<void> pump(int epoch) {
      return tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 280,
            height: 320,
            child: WatchReferenceApp(
              state: _trusted(route: WatchRoute.captureMenu),
              onIntent: intents.add,
              inputEpoch: epoch,
            ),
          ),
        ),
      );
    }

    await pump(1);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('watch-capture-red'))),
    );
    await pump(2);
    await gesture.up();
    await tester.pump();
    expect(intents, isEmpty);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  WatchPresentationState? state,
  WatchFaceShape face = WatchFaceShape.rectangular,
  WatchLiveLayout layout = WatchLiveLayout.centered,
  WatchDesignFrame frame = WatchDesignFrame.flow,
  void Function(WatchIntent intent)? onIntent,
  Set<WatchCaptureFamily> blocked = const {},
  bool selectionEnabled = true,
  bool beyond = false,
  Color? homeKit,
  Color? awayKit,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: SizedBox(
        width: 300,
        height: 360,
        child: WatchReferenceApp(
          state: state ?? _trusted(),
          onIntent: onIntent ?? _ignore,
          face: face,
          liveLayout: layout,
          frame: frame,
          blockedFamilies: blocked,
          selectionEnabled: selectionEnabled,
          showBeyondNominal: beyond,
          homeKit: homeKit,
          awayKit: awayKit,
        ),
      ),
    ),
  );
}

WatchPresentationState _trusted({
  ClockPresentation? clock,
  ScorePresentation? score,
  WatchRoute route = WatchRoute.liveCore,
  List<PresentationParticipant> roster = const [],
  List<PresentationOfficial> officials = const [],
  PresentationTeamContext team = PresentationTeamContext.home,
}) {
  final base = WatchPresentationState.empty;
  return WatchPresentationState(
    scenarioId: 'design',
    profileId: null,
    header: MatchHeaderPresentation(
      scenarioId: 'design',
      teamContext: team,
      scope: PresentationScope.match,
      identityLabel: 'Design',
    ),
    clock: clock ??
        const ClockPresentation(
          available: true,
          label: '67:12',
          phaseLabel: '2ND HALF',
        ),
    score: score ??
        const ScorePresentation(
          available: true,
          label: '1 – 0',
          homeGoals: 1,
          awayGoals: 0,
        ),
    selection: base.selection,
    discipline: base.discipline,
    substitution: base.substitution,
    frozenCommand: null,
    commit: base.commit,
    navigation: NavigationPresentation(route: route, canOpenCapture: true),
    roster: roster,
    officials: officials,
    recoveryLabel: null,
    lastRejection: null,
    goalFlow: GoalFlowPresentation.inactive,
    matchReport: MatchReportPresentation.empty,
    homeTeamLabel: 'Home',
    awayTeamLabel: 'Away',
  );
}

({List<PresentationParticipant> players, List<PresentationOfficial> officials})
    _people() {
  final players = <PresentationParticipant>[
    const PresentationParticipant(
      id: 'home-71',
      team: PresentationTeam.home,
      shirtLabel: '71',
      name: 'Home seventy one',
    ),
    const PresentationParticipant(
      id: 'away-71',
      team: PresentationTeam.away,
      shirtLabel: '71',
      name: 'Away seventy one',
    ),
    const PresentationParticipant(
      id: 'home-80',
      team: PresentationTeam.home,
      shirtLabel: '80',
      name: 'Home eighty',
    ),
    for (var n = 1; n <= 5; n++)
      PresentationParticipant(
        id: 'home-$n',
        team: PresentationTeam.home,
        shirtLabel: '$n',
        name: 'Player $n',
      ),
  ];
  final officials = <PresentationOfficial>[
    const PresentationOfficial(
      id: 'coach-home',
      team: PresentationTeam.home,
      name: 'Home coach',
      roleLabel: 'Head coach',
    ),
    const PresentationOfficial(
      id: 'coach-away',
      team: PresentationTeam.away,
      name: 'Away coach',
      roleLabel: 'Head coach',
    ),
  ];
  return (players: players, officials: officials);
}

void _ignore(WatchIntent intent) {}
