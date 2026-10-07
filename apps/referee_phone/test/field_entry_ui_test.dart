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

  testWidgets('READY without field entry keeps Kick-off disabled', (tester) async {
    await fixture.openLive(tester);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('kick-off'))).onPressed,
      isNull,
    );
  });

  testWidgets('opening Live Match alone does not unlock Kick-off', (tester) async {
    await fixture.openLive(tester);
    await fixture.reopenLive(tester);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('kick-off'))).onPressed,
      isNull,
    );
  });

  testWidgets('successful Enter field unlocks Kick-off', (tester) async {
    await fixture.openLive(tester);
    await fixture.tapEnterField(tester);
    await fixture.pumpUntil(tester, find.text('Entered field'));
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('kick-off'))).onPressed,
      isNotNull,
    );
  });

  testWidgets('failed Enter field D1 keeps Kick-off disabled', (tester) async {
    await fixture.openLive(tester);
    fixture.composition.boundary.durableStore.abortBeforeCommitForTest = () {
      throw StateError('abort before commit');
    };
    await tester.tap(find.byKey(const Key('enter-field')));
    await tester.pump();
    await fixture.pumpUntil(tester, find.text('Field entry was not saved'));
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('kick-off'))).onPressed,
      isNull,
    );
    fixture.composition.boundary.durableStore.abortBeforeCommitForTest = null;
  });

  testWidgets('reopen after field entry restores Kick-off availability',
      (tester) async {
    await fixture.openLive(tester);
    await fixture.tapEnterField(tester);
    await fixture.pumpUntil(tester, find.text('Entered field'));
    await fixture.reopenLive(tester);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('kick-off'))).onPressed,
      isNotNull,
    );
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

  testWidgets('Enter field then Yellow then Kick-off is valid', (tester) async {
    await fixture.openLive(tester);
    await fixture.tapEnterField(tester);
    await fixture.pumpUntil(tester, find.text('Entered field'));
    await tester.tap(find.text('Yellow'));
    await tester.pump();
    await fixture.pumpUntil(
      tester,
      find.byKey(const Key('yellow-option-mpid-test-1')),
    );
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('kick-off'))).onPressed,
      isNotNull,
    );
    tester
        .widget<YellowCardCaptureOverlay>(
          find.byType(YellowCardCaptureOverlay),
        )
        .onCancel
        .call();
    await tester.pump();
    await tester.runAsync(() async {
      tester
          .widget<FilledButton>(find.byKey(const Key('kick-off')))
          .onPressed!
          .call();
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    await fixture.pumpUntil(tester, find.text('Match started'));
    expect(await fixture.fieldEntryCount(), 1);
  });

  testWidgets('MATCH_STARTED without field entry is lifecycle-incomplete',
      (tester) async {
    await fixture.openLive(tester);
    await tester.runAsync(() async {
      await fixture.seedMatchStartedWithoutFieldEntry();
    });
    await fixture.reopenLive(tester);
    await fixture.pumpUntil(
      tester,
      find.text('Field entry was not recorded before the match started'),
    );
    expect(await fixture.fieldEntryCount(), 0);
    expect(
      find.text('Field entry was not recorded before the match started'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Yellow'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('MATCH_STARTED alone does not fabricate field entry',
      (tester) async {
    await fixture.openLive(tester);
    await tester.runAsync(() async {
      await fixture.seedMatchStartedWithoutFieldEntry();
    });
    await fixture.reopenLive(tester);
    await fixture.pumpUntil(tester, find.text('Complete period start'));
    expect(await fixture.fieldEntryCount(), 0);
    expect(find.text('Match started'), findsOneWidget);
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
    required this.evidence,
    required this.matchId,
  });

  final LocalMatchDatabase db;
  final Directory temp;
  final MatchApplicationComposition composition;
  final PhoneCaptureIdentity identity;
  final PhoneMatchCaptureContext capture;
  final PhoneParticipantRegistryStore registry;
  final PhoneMatchFoundation foundation;
  final PhoneTemporalEvidenceStore evidence;
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
    final evidence = PhoneTemporalEvidenceStore(storageRoot: temp);
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
      evidence: evidence,
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
        temporalEvidence: evidence,
        participantRegistry: registry,
        matchFoundation: foundation,
      );

  Future<void> openLive(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    await pumpUntil(tester, find.text('Matches'));
    await tester.tap(find.text('HOME 0 — 0 AWAY').first);
    await tester.pump();
    await pumpUntilLiveMatchSettled(tester);
  }

  Future<void> pumpUntilLiveMatchSettled(WidgetTester tester) async {
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(() => Future<void>.value());
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('Match started').evaluate().isNotEmpty) return;
      if (find.text('Complete period start').evaluate().isNotEmpty) return;
      if (find.text('Field entry was not recorded before the match started')
          .evaluate()
          .isNotEmpty) {
        return;
      }
      if (find.byKey(const Key('enter-field')).evaluate().isNotEmpty) return;
      final kickOff = find.byKey(const Key('kick-off'));
      if (kickOff.evaluate().isNotEmpty &&
          find.byKey(const Key('enter-field')).evaluate().isEmpty) {
        return;
      }
    }
    fail('Timed out waiting for Live Match to settle');
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

  Future<void> seedMatchStartedWithoutFieldEntry() async {
    final context = await capture.captureContextFor(matchId);
    final result = await composition.boundary.commitMatchStarted(context);
    expect(result, isA<DurableCommitSuccess>());
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
