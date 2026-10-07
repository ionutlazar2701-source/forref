import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/app.dart';
import 'package:referee_phone/features/live_match/yellow_card_capture_overlay.dart';
import 'package:referee_phone/infrastructure/competition_rules/match_competition_rules_store.dart';
import 'package:referee_phone/infrastructure/competition_rules/phone_match_capture_context.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/infrastructure/yellow_card/phone_match_foundation.dart';
import 'package:referee_phone/infrastructure/yellow_card/phone_participant_registry_store.dart';
import 'package:referee_phone/infrastructure/yellow_card/phone_yellow_card_draft_store.dart';
import 'package:referee_phone/match/new_match.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _HardeningFixture fixture;

  setUp(() async {
    fixture = await _HardeningFixture.create();
  });

  tearDown(() => fixture.close());

  testWidgets('rapid double tap creates one yellow card', (tester) async {
    await fixture.openYellow(tester);
    await tester.tap(find.byKey(const Key('yellow-option-mpid-test-1')));
    await tester.pump();

    final commit = tester
        .widget<FilledButton>(find.byKey(const Key('yellow-commit')))
        .onPressed!;
    commit();
    commit();
    await tester.pump();
    await fixture.pumpUntil(tester, find.textContaining('Yellow saved'));

    final yellows = (await fixture.records())
        .where((record) => record.payload is YellowCardPayload);
    expect(yellows, hasLength(1));
  });

  testWidgets('reconcile read failure converges to Retry', (tester) async {
    await fixture.openYellow(tester);
    await tester.tap(find.byKey(const Key('yellow-option-mpid-test-1')));
    await tester.pump();

    fixture.composition.boundary.durableStore.abortBeforeReadForTest = () {
      throw StateError('read failed');
    };

    await tester.runAsync(
      tester
          .widget<YellowCardCaptureOverlay>(
            find.byType(YellowCardCaptureOverlay),
          )
          .onCommit,
    );
    await tester.pump();
    await fixture.pumpUntil(tester, find.text('Not saved'));
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Checking save status'), findsNothing);

    fixture.composition.boundary.durableStore.abortBeforeReadForTest = null;
  });

  testWidgets('second-caution acknowledgement uses post-commit projection',
      (tester) async {
    await fixture.seedPriorCaution();
    await fixture.openYellow(tester);
    await tester.tap(find.byKey(const Key('yellow-option-mpid-test-1')));
    await tester.pump();

    await tester.runAsync(
      tester
          .widget<YellowCardCaptureOverlay>(
            find.byType(YellowCardCaptureOverlay),
          )
          .onCommit,
    );
    await tester.pump();
    await fixture.pumpUntil(tester, find.text('SECOND CAUTION RECORDED'));
    expect(find.text('No red card has been recorded'), findsOneWidget);
  });

  testWidgets('interleaved caution while selector open revalidates at commit',
      (tester) async {
    await fixture.openYellow(tester);
    await tester.tap(find.byKey(const Key('yellow-option-mpid-test-2')));
    await tester.pump();
    expect(find.text('Record Yellow'), findsOneWidget);

    await fixture.commitYellowFor(
      MatchParticipantId('mpid-test-2'),
      captureIntentId: 'intent-interleaved',
    );

    await tester.runAsync(
      tester
          .widget<YellowCardCaptureOverlay>(
            find.byType(YellowCardCaptureOverlay),
          )
          .onCommit,
    );
    await tester.pump();
    await fixture.pumpUntil(tester, find.text('SECOND CAUTION RECORDED'));

    final yellows = (await fixture.records())
        .where((record) => record.payload is YellowCardPayload);
    expect(yellows, hasLength(2));
  });
}

final class _HardeningFixture {
  _HardeningFixture._({
    required this.db,
    required this.temp,
    required this.composition,
    required this.identity,
    required this.capture,
    required this.registry,
    required this.foundation,
    required this.draftStore,
    required this.matchId,
    required this.homeOne,
    required this.homeTwo,
  });

  final LocalMatchDatabase db;
  final Directory temp;
  final MatchApplicationComposition composition;
  final PhoneCaptureIdentity identity;
  final PhoneMatchCaptureContext capture;
  final PhoneParticipantRegistryStore registry;
  final PhoneMatchFoundation foundation;
  final PhoneYellowCardDraftStore draftStore;
  final String matchId;
  final ParticipantRef homeOne;
  final ParticipantRef homeTwo;

  static Future<_HardeningFixture> create() async {
    final db = LocalMatchDatabase.memory();
    final temp = await Directory.systemTemp.createTemp('yc_hardening_ui_');
    final composition =
        await MatchApplicationComposition.open(storageRoot: temp);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final capture = PhoneMatchCaptureContext(
      identity: identity,
      rulesStore: MatchCompetitionRulesStore(temp),
    );
    final registry = PhoneParticipantRegistryStore(temp);
    final foundation = PhoneMatchFoundation(
      boundary: composition.boundary,
      registry: registry,
      participantIdGenerator: _DeterministicParticipantIds(),
    );
    final draftStore = PhoneYellowCardDraftStore(temp);

    final match = newLocalMatch(DateTime.utc(2026, 10, 7)).copyWith(
      status: MatchStatus.ready,
      squads: const Squads(
        home: TeamSquad(
          players: [
            Player(
              playerId: 'home-1',
              shirtNumber: 1,
              name: 'Home One',
              role: PlayerRole.starter,
            ),
            Player(
              playerId: 'home-2',
              shirtNumber: 2,
              name: 'Home Two',
              role: PlayerRole.starter,
            ),
          ],
        ),
        away: TeamSquad(players: []),
      ),
    );
    await db.upsertMatch(match);
    await capture.rulesStore.saveForMatch(
      match.matchId,
      const CompetitionRulesContext(
        rulesetId: 'ifab',
        disciplinarySystem: DisciplinarySystem.ordinaryIfab,
      ),
    );

    final homeOne = ParticipantRef(
      matchParticipantId: MatchParticipantId('mpid-test-1'),
      teamSide: ParticipantTeamSide.home,
      binding: const RosterLinkedBinding(rosterParticipantId: 'home-1'),
    );
    final homeTwo = ParticipantRef(
      matchParticipantId: MatchParticipantId('mpid-test-2'),
      teamSide: ParticipantTeamSide.home,
      binding: const RosterLinkedBinding(rosterParticipantId: 'home-2'),
    );

    final fixture = _HardeningFixture._(
      db: db,
      temp: temp,
      composition: composition,
      identity: identity,
      capture: capture,
      registry: registry,
      foundation: foundation,
      draftStore: draftStore,
      matchId: match.matchId,
      homeOne: homeOne,
      homeTwo: homeTwo,
    );
    await fixture._bootstrapProductionFoundation();
    return fixture;
  }

  Future<void> _bootstrapProductionFoundation() async {
    final match = (await db.getMatch(matchId))!;
    final context = await capture.captureContextFor(matchId);
    await foundation.registerRosterFromMatch(context: context, match: match);
  }

  RefereeApp app() => RefereeApp(
        database: db,
        matchApplication: composition.boundary,
        captureIdentity: identity,
        matchCaptureContext: capture,
        participantRegistry: registry,
        matchFoundation: foundation,
        yellowCardDraftStore: draftStore,
      );

  Future<void> seedPriorCaution() async {
    final context = await capture.captureContextFor(matchId);
    await foundation.commitRefereeEnteredField(context);
    await commitYellowFor(
      homeOne.matchParticipantId,
      captureIntentId: 'intent-prior',
    );
  }

  Future<void> commitYellowFor(
    MatchParticipantId participantId, {
    required String captureIntentId,
  }) async {
    final ref = participantId == homeOne.matchParticipantId ? homeOne : homeTwo;
    final result = await composition.boundary.commitYellowCard(
      CommitYellowCardCommand(
        context: await capture.captureContextFor(matchId),
        participantRef: ref,
        participantStatusAtDetermination:
            ParticipantStatusAtDetermination.onFieldPlayer,
        disciplinaryAccountingScope: DisciplinaryAccountingScope.match,
        captureIntentId: captureIntentId,
      ),
    );
    expect(result, isA<YellowCardSaved>());
  }

  Future<void> openYellow(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    await pumpUntil(tester, find.text('Matches'));
    await tester.tap(find.text('HOME 0 — 0 AWAY').first);
    await tester.pump();
    await pumpUntil(tester, find.text('Kick-off'));
    if (find.byKey(const Key('enter-field')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('enter-field')));
      await tester.pump();
      await pumpUntil(tester, find.text('Entered field'));
    }
    await tester.tap(find.widgetWithText(FilledButton, 'Yellow'));
    await tester.pump();
    await pumpUntil(tester, find.byKey(const Key('yellow-option-mpid-test-1')));
  }

  Future<List<MatchRecord>> records() =>
      composition.boundary.durableStore.readCommittedForMatch(matchId);

  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.runAsync(() => Future<void>.value());
      await tester.pump(const Duration(milliseconds: 50));
    }
    fail('Timed out waiting for $finder');
  }

  Future<void> close() async {
    await composition.close();
    await db.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  }
}

final class _DeterministicParticipantIds implements MatchParticipantIdGenerator {
  var _next = 0;

  @override
  MatchParticipantId newParticipantId() {
    _next += 1;
    return MatchParticipantId('mpid-test-$_next');
  }
}
