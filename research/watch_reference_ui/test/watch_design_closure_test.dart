import 'package:flutter/material.dart' hide ActivateIntent;
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_presentation/simulator_presentation.dart';
import 'package:watch_reference_ui/watch_reference_ui.dart';

void main() {
  testWidgets(
      'yellow then team then participant offers yellow and does not activate',
      (tester) async {
    final intents = <WatchIntent>[];
    final people = _people();
    await _pump(
      tester,
      state: _state(
        route: WatchRoute.captureMenu,
        roster: people.players,
        officials: people.officials,
        team: PresentationTeamContext.absent,
      ),
      onIntent: intents.add,
    );
    await tester.tap(find.byKey(const Key('watch-capture-yellow')));
    await tester.pump();
    expect(intents, isEmpty);
    expect(find.byKey(const Key('watch-team-context')), findsOneWidget);

    await tester.tap(find.byKey(const Key('watch-team-home')));
    await tester.pump();
    expect(intents.single, isA<SetTeamIntent>());
    expect((intents.single as SetTeamIntent).team, PresentationTeam.home);
    expect(find.byKey(const Key('watch-participant-home-71')), findsOneWidget);
    expect(find.byKey(const Key('watch-participant-away-71')), findsNothing);

    intents.clear();
    await tester.tap(find.byKey(const Key('watch-participant-back')));
    await tester.pump();
    expect(intents, isEmpty);
    expect(find.byKey(const Key('watch-design-team')), findsOneWidget);
    expect(find.byKey(const Key('watch-team-context')), findsOneWidget);

    await tester.tap(find.byKey(const Key('watch-team-home')));
    await tester.pump();
    intents.clear();
    await tester.tap(find.byKey(const Key('watch-participant-home-71')));
    await tester.pump();
    expect(intents.whereType<ActivateIntent>(), isEmpty);
    expect(intents[0], isA<SelectParticipantIntent>());
    expect((intents[0] as SelectParticipantIntent).participantId, 'home-71');
    expect(intents[1], isA<OfferYellowIntent>());
  });

  testWidgets('goal reapplies team and participant and ignores an official',
      (tester) async {
    final intents = <WatchIntent>[];
    final people = _people();
    await _pump(
      tester,
      state: _state(
        route: WatchRoute.captureMenu,
        roster: people.players,
        officials: people.officials,
      ),
      onIntent: intents.add,
    );
    await tester.tap(find.byKey(const Key('watch-capture-goal')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('watch-team-away')));
    await tester.pump();
    await tester.drag(
      find.byKey(const Key('watch-participant-pager')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();
    final before = intents.length;
    await tester.tap(find.byKey(const Key('watch-official-coach-away')));
    await tester.pump();
    expect(intents, hasLength(before));
    expect(find.text('Not this event'), findsWidgets);

    await tester.drag(
      find.byKey(const Key('watch-participant-pager')),
      const Offset(400, 0),
    );
    await tester.pumpAndSettle();
    intents.clear();
    await tester.tap(find.byKey(const Key('watch-participant-away-71')));
    await tester.pump();
    expect(intents.map((intent) => intent.runtimeType).toList(), [
      OfferGoalIntent,
      SetTeamIntent,
      SelectParticipantIntent,
    ]);
    expect((intents[1] as SetTeamIntent).team, PresentationTeam.away);
    expect((intents[2] as SelectParticipantIntent).participantId, 'away-71');
    expect(intents.whereType<ActivateIntent>(), isEmpty);
  });

  testWidgets('red opens send-off without offering a record', (tester) async {
    final intents = <WatchIntent>[];
    final people = _people();
    await _pump(
      tester,
      state: _state(
        route: WatchRoute.captureMenu,
        roster: people.players,
      ),
      onIntent: intents.add,
    );
    await tester.tap(find.byKey(const Key('watch-capture-red')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('watch-team-home')));
    await tester.pump();
    intents.clear();
    await tester.tap(find.byKey(const Key('watch-participant-home-80')));
    await tester.pump();
    expect(intents[0], isA<SelectParticipantIntent>());
    expect((intents[0] as SelectParticipantIntent).participantId, 'home-80');
    expect((intents[1] as OpenRouteIntent).route, WatchRoute.sendOffFlow);
    expect(intents.whereType<OfferDirectSendOffIntent>(), isEmpty);
    expect(intents.whereType<ActivateIntent>(), isEmpty);
  });

  testWidgets('substitution keeps OUT and IN on the existing research route',
      (tester) async {
    final intents = <WatchIntent>[];
    await _pump(
      tester,
      state: _state(route: WatchRoute.captureMenu),
      onIntent: intents.add,
    );
    await tester.tap(find.byKey(const Key('watch-capture-sub')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('watch-team-away')));
    await tester.pump();
    expect(intents.whereType<SelectOutIntent>(), isEmpty);
    expect(intents.whereType<SelectInIntent>(), isEmpty);
    expect(intents.whereType<ActivateIntent>(), isEmpty);
    expect(
      intents.whereType<OpenRouteIntent>().single.route,
      WatchRoute.substitutionFlow,
    );
  });

  testWidgets('a closed capture flag still navigates and does not activate',
      (tester) async {
    final intents = <WatchIntent>[];
    final base = _state();
    await _pump(
      tester,
      state: WatchPresentationState(
        scenarioId: base.scenarioId,
        profileId: base.profileId,
        header: base.header,
        clock: base.clock,
        score: base.score,
        selection: base.selection,
        discipline: base.discipline,
        substitution: base.substitution,
        frozenCommand: base.frozenCommand,
        commit: base.commit,
        navigation: const NavigationPresentation(
          route: WatchRoute.liveCore,
          canOpenCapture: false,
        ),
        roster: base.roster,
        officials: base.officials,
        recoveryLabel: base.recoveryLabel,
        lastRejection: base.lastRejection,
        goalFlow: base.goalFlow,
        matchReport: base.matchReport,
        homeTeamLabel: base.homeTeamLabel,
        awayTeamLabel: base.awayTeamLabel,
      ),
      onIntent: intents.add,
    );
    expect(find.text('Capture unavailable'), findsNothing);
    expect(find.byKey(const Key('watch-capture-ring')), findsOneWidget);
    await tester.tap(find.byKey(const Key('watch-capture-ring')));
    await tester.pump();
    expect(intents.single, isA<OpenRouteIntent>());
    expect((intents.single as OpenRouteIntent).route, WatchRoute.captureMenu);
    expect(intents.whereType<ActivateIntent>(), isEmpty);
  });

  testWidgets('a short aperture holds instead of shrinking capture',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            height: 190,
            child: WatchReferenceApp(
              state: _state(),
              onIntent: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('watch-aperture-hold')), findsOneWidget);
    expect(find.byKey(const Key('watch-capture-ring')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('simulated viewports keep family and capture targets apart',
      (tester) async {
    Future<void> measure(Size size, WatchFaceShape face) async {
      await tester.binding.setSurfaceSize(size + const Offset(20, 20));
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: WatchReferenceApp(
                state: _state(route: WatchRoute.captureMenu),
                onIntent: (_) {},
                face: face,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('watch-aperture-hold')), findsNothing);
      final yellow =
          tester.getRect(find.byKey(const Key('watch-capture-yellow')));
      final red = tester.getRect(find.byKey(const Key('watch-capture-red')));
      final goal = tester.getRect(find.byKey(const Key('watch-capture-goal')));
      final sub = tester.getRect(find.byKey(const Key('watch-capture-sub')));
      final center =
          tester.getRect(find.byKey(const Key('watch-capture-center')));
      final back = tester.getRect(find.byKey(const Key('watch-capture-back')));
      for (final rect in [yellow, red, goal, sub]) {
        expect(rect.shortestSide,
            greaterThanOrEqualTo(WatchApertureLimits.family));
        expect(rect.overlaps(center), isFalse);
        expect(rect.overlaps(back), isFalse);
      }
      expect(yellow.overlaps(red), isFalse);
      expect(yellow.overlaps(goal), isFalse);
      expect(yellow.overlaps(sub), isFalse);
      expect(red.overlaps(goal), isFalse);
      expect(red.overlaps(sub), isFalse);
      expect(goal.overlaps(sub), isFalse);
      expect(back.height, greaterThanOrEqualTo(WatchApertureLimits.back));
    }

    await measure(const Size(466, 466), WatchFaceShape.round);
    await measure(const Size(390, 450), WatchFaceShape.rectangular);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'live capture and cautions keep their floors and ornaments are inert',
      (tester) async {
    final intents = <WatchIntent>[];
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: SizedBox(
            width: 390,
            height: 450,
            child: WatchReferenceApp(
              state: _state(),
              onIntent: intents.add,
              face: WatchFaceShape.rectangular,
              showBeyondNominal: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('watch-capture-glyph')), findsOneWidget);
    final ring = tester.getRect(find.byKey(const Key('watch-capture-ring')));
    final cautions = tester.getRect(find.byKey(const Key('watch-cautions')));
    final left =
        tester.getRect(find.byKey(const Key('watch-capture-ornament-left')));
    expect(
        ring.shortestSide, greaterThanOrEqualTo(WatchApertureLimits.capture));
    expect(cautions.height, greaterThanOrEqualTo(WatchApertureLimits.footer));
    expect(ring.overlaps(cautions), isFalse);
    expect(left.overlaps(ring), isFalse);
    await tester.tap(
      find.byKey(const Key('watch-capture-ornament-left')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(intents, isEmpty);
    expect(
      find.ancestor(
        of: find.byKey(const Key('watch-capture-ornament-left')),
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );
  });

  testWidgets('officials use two columns and the last odd chip is centered',
      (tester) async {
    final officials = [
      for (var i = 0; i < 5; i++)
        PresentationOfficial(
          id: 'official-$i',
          team: PresentationTeam.home,
          name: 'Official $i',
          roleLabel: 'Role $i',
        ),
    ];
    await _pump(
      tester,
      frame: WatchDesignFrame.participant,
      face: WatchFaceShape.rectangular,
      state: _state(
        roster: const [
          PresentationParticipant(
            id: 'p1',
            team: PresentationTeam.home,
            shirtLabel: '71',
            name: 'One',
          ),
          PresentationParticipant(
            id: 'p2',
            team: PresentationTeam.home,
            shirtLabel: '80',
            name: 'Two',
          ),
          PresentationParticipant(
            id: 'p3',
            team: PresentationTeam.home,
            shirtLabel: '3',
            name: 'Three',
          ),
          PresentationParticipant(
            id: 'p4',
            team: PresentationTeam.home,
            shirtLabel: '4',
            name: 'Four',
          ),
          PresentationParticipant(
            id: 'p5',
            team: PresentationTeam.home,
            shirtLabel: '5',
            name: 'Five',
          ),
          PresentationParticipant(
            id: 'p6',
            team: PresentationTeam.home,
            shirtLabel: '6',
            name: 'Six',
          ),
          PresentationParticipant(
            id: 'p7',
            team: PresentationTeam.home,
            shirtLabel: '7',
            name: 'Seven',
          ),
        ],
        officials: officials,
        team: PresentationTeamContext.home,
      ),
    );
    final leftPlayer =
        tester.getRect(find.byKey(const Key('watch-participant-p1')));
    final rightPlayer =
        tester.getRect(find.byKey(const Key('watch-participant-p3')));
    final lastPlayer =
        tester.getRect(find.byKey(const Key('watch-participant-p7')));
    final rowMid = (leftPlayer.center.dx + rightPlayer.center.dx) / 2;
    expect((lastPlayer.center.dx - rowMid).abs(), lessThan(12));
    expect(lastPlayer.center.dy, greaterThan(rightPlayer.center.dy));

    await tester.drag(
      find.byKey(const Key('watch-participant-pager')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Role 0'), findsOneWidget);
    expect(find.text('Role 4'), findsOneWidget);
    final left =
        tester.getRect(find.byKey(const Key('watch-official-official-0')));
    final right =
        tester.getRect(find.byKey(const Key('watch-official-official-1')));
    final last =
        tester.getRect(find.byKey(const Key('watch-official-official-4')));
    expect(left.center.dx, lessThan(right.center.dx));
    expect(left.center.dy, closeTo(right.center.dy, 4));
    final officialMid = (left.center.dx + right.center.dx) / 2;
    expect((last.center.dx - officialMid).abs(), lessThan(12));
    expect(last.center.dy, greaterThan(left.center.dy));
    expect(
        left.shortestSide, greaterThanOrEqualTo(WatchApertureLimits.chip - 8));
  });
}

Future<void> _pump(
  WidgetTester tester, {
  WatchPresentationState? state,
  WatchFaceShape face = WatchFaceShape.rectangular,
  WatchDesignFrame frame = WatchDesignFrame.flow,
  void Function(WatchIntent intent)? onIntent,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: SizedBox(
        width: 390,
        height: 450,
        child: WatchReferenceApp(
          state: state ?? _state(),
          onIntent: onIntent ?? (_) {},
          face: face,
          frame: frame,
        ),
      ),
    ),
  );
}

WatchPresentationState _state({
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
    clock: const ClockPresentation(
      available: true,
      label: '67:12',
      phaseLabel: '2ND HALF',
    ),
    score: const ScorePresentation(
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
  return (
    players: const [
      PresentationParticipant(
        id: 'home-71',
        team: PresentationTeam.home,
        shirtLabel: '71',
        name: 'Home seventy one',
      ),
      PresentationParticipant(
        id: 'away-71',
        team: PresentationTeam.away,
        shirtLabel: '71',
        name: 'Away seventy one',
      ),
      PresentationParticipant(
        id: 'home-80',
        team: PresentationTeam.home,
        shirtLabel: '80',
        name: 'Home eighty',
      ),
    ],
    officials: const [
      PresentationOfficial(
        id: 'coach-home',
        team: PresentationTeam.home,
        name: 'Home coach',
        roleLabel: 'Head coach',
      ),
      PresentationOfficial(
        id: 'coach-away',
        team: PresentationTeam.away,
        name: 'Away coach',
        roleLabel: 'Head coach',
      ),
    ],
  );
}
