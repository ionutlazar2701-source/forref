import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/app.dart';
import 'package:referee_phone/infrastructure/competition_rules/match_competition_rules_store.dart';
import 'package:referee_phone/infrastructure/competition_rules/phone_match_capture_context.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/infrastructure/temporal/phone_temporal_evidence_store.dart';
import 'package:referee_phone/infrastructure/yellow_card/phone_match_foundation.dart';
import 'package:referee_phone/infrastructure/yellow_card/phone_participant_registry_store.dart';
import 'package:referee_phone/match/new_match.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FieldEntryFixture fixture;

  setUp(() async {
    fixture = await _FieldEntryFixture.create();
  });

  tearDown(() => fixture.close());

  testWidgets('opening Live Match does not commit field entry', (tester) async {
    await fixture.openLive(tester);
    expect(await fixture.fieldEntryCount(), 0);
  });

  testWidgets('reopening Live Match does not commit field entry', (tester) async {
    await fixture.openLive(tester);
    await fixture.reopenLive(tester);
    expect(await fixture.fieldEntryCount(), 0);
  });

  testWidgets('explicit Enter field commits exactly one lifecycle fact',
      (tester) async {
    await fixture.openLive(tester);
    await fixture.tapEnterField(tester);
    await fixture.pumpUntil(tester, find.text('Entered field'));
    expect(await fixture.fieldEntryCount(), 1);
  });

  testWidgets('Enter field confirmation appears only after D1', (tester) async {
    await fixture.openLive(tester);
    fixture.composition.boundary.durableStore.abortBeforeCommitForTest = () {
      throw StateError('abort before commit');
    };
    await tester.tap(find.byKey(const Key('enter-field')));
    await tester.pump();
    await fixture.pumpUntil(tester, find.text('Field entry was not saved'));
    expect(find.text('Entered field'), findsNothing);
    expect(await fixture.fieldEntryCount(), 0);
    fixture.composition.boundary.durableStore.abortBeforeCommitForTest = null;
  });

  testWidgets('repeated Enter field does not duplicate authority', (tester) async {
    await fixture.openLive(tester);
    await fixture.tapEnterField(tester);
    await fixture.pumpUntil(tester, find.text('Entered field'));
    expect(find.byKey(const Key('enter-field')), findsNothing);
    expect(await fixture.fieldEntryCount(), 1);
  });

  testWidgets('close and reopen restores entered-field state', (tester) async {
    await fixture.openLive(tester);
    await fixture.tapEnterField(tester);
    await fixture.pumpUntil(tester, find.text('Entered field'));
    await fixture.reopenLive(tester);
    expect(find.byKey(const Key('enter-field')), findsNothing);
    expect(await fixture.fieldEntryCount(), 1);
  });

  testWidgets('Yellow before Enter field is disabled', (tester) async {
    await fixture.openLive(tester);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Yellow'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('Yellow after Enter field opens selector pre-kick-off',
      (tester) async {
    await fixture.openLive(tester);
    await fixture.tapEnterField(tester);
    await fixture.pumpUntil(tester, find.text('Entered field'));
    await tester.tap(find.text('Yellow'));
    await tester.pump();
    await fixture.pumpUntil(
      tester,
      find.byKey(const Key('yellow-option-mpid-test-1')),
    );
    expect(find.text('Kick-off'), findsOneWidget);
  });

  testWidgets('MATCH_STARTED alone does not fabricate field entry',
      (tester) async {
    await fixture.openLive(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Kick-off'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await fixture.pumpUntil(tester, find.text('Match started'));
    expect(await fixture.fieldEntryCount(), 0);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Yellow'))
          .onPressed,
      isNull,
    );
  });
}

final class _FieldEntryFixture {
  _FieldEntryFixture._({
    required this.db,
    required this.temp,
    required this.composition,
    required this.identity,
    required this.capture,
    required this.registry,
    required this.foundation,
    required this.matchId,
  });

  final LocalMatchDatabase db;
  final Directory temp;
  final MatchApplicationComposition composition;
  final PhoneCaptureIdentity identity;
  final PhoneMatchCaptureContext capture;
  final PhoneParticipantRegistryStore registry;
  final PhoneMatchFoundation foundation;
  final String matchId;

  static Future<_FieldEntryFixture> create() async {
    final db = LocalMatchDatabase.memory();
    final temp = await Directory.systemTemp.createTemp('field_entry_ui_');
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

    final fixture = _FieldEntryFixture._(
      db: db,
      temp: temp,
      composition: composition,
      identity: identity,
      capture: capture,
      registry: registry,
      foundation: foundation,
      matchId: match.matchId,
    );
    await fixture._registerRosterOnly();
    return fixture;
  }

  Future<void> _registerRosterOnly() async {
    final match = (await db.getMatch(matchId))!;
    final context = await capture.captureContextFor(matchId);
    await foundation.registerRosterFromMatch(context: context, match: match);
  }

  RefereeApp app() => RefereeApp(
        database: db,
        matchApplication: composition.boundary,
        captureIdentity: identity,
        matchCaptureContext: capture,
        temporalEvidence: PhoneTemporalEvidenceStore(storageRoot: temp),
        participantRegistry: registry,
        matchFoundation: foundation,
      );

  Future<void> openLive(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    await pumpUntil(tester, find.text('Matches'));
    await tester.tap(find.text('HOME 0 — 0 AWAY').first);
    await tester.pump();
    await pumpUntil(tester, find.text('Kick-off'));
  }

  Future<void> reopenLive(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await openLive(tester);
  }

  Future<void> tapEnterField(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('enter-field')));
    await tester.pump();
  }

  Future<int> fieldEntryCount() async {
    final records =
        await composition.boundary.durableStore.readCommittedForMatch(matchId);
    return records
        .where(
          (record) =>
              record.payload is TemporalTransitionPayload &&
              (record.payload as TemporalTransitionPayload).semanticType ==
                  V1SemanticTypeCode.refereeEnteredFieldForMatchStart,
        )
        .length;
  }

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
