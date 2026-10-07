import 'dart:async';
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
import 'package:referee_phone/infrastructure/yellow_card/phone_yellow_card_draft_store.dart';
import 'package:referee_phone/l10n/app_localizations.dart';
import 'package:referee_phone/match/new_match.dart';
import 'package:referee_phone/match_application/authoritative_capture_command.dart';

void main() {
  late _YellowUiFixture fixture;

  setUp(() async {
    fixture = await _YellowUiFixture.create();
  });

  tearDown(() => fixture.close());

  testWidgets(
    'Yellow opens both teams and selection remains non-authoritative until Record Yellow',
    (tester) async {
      await fixture.openLive(tester);

      final selectorWatch = Stopwatch()..start();
      await tester.tap(find.text('Yellow'));
      await tester.pump();
      await fixture.pumpUntil(
        tester,
        find.byKey(const Key('yellow-option-mpid-home-7')),
      );
      selectorWatch.stop();

      expect(find.text('HOME'), findsWidgets);
      expect(find.text('AWAY'), findsWidgets);
      expect(find.byKey(const Key('yellow-selected')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('yellow-commit')))
            .onPressed,
        isNull,
      );

      final selectionWatch = Stopwatch()..start();
      await tester.tap(find.byKey(const Key('yellow-option-mpid-home-7')));
      await tester.pump();
      selectionWatch.stop();
      expect(find.byKey(const Key('yellow-selected')), findsOneWidget);
      expect(find.textContaining('#7'), findsWidgets);
      expect(find.text('Record Yellow'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      var records = await fixture.records(tester);
      expect(records.where((r) => r.payload is YellowCardPayload), isEmpty);

      final awayNine = find.byKey(const Key('yellow-option-mpid-away-9'));
      tester.widget<InkWell>(awayNine).onTap!();
      await tester.pump();
      expect(find.textContaining('#9'), findsWidgets);
      records = await fixture.records(tester);
      expect(records.where((r) => r.payload is YellowCardPayload), isEmpty);

      // Engineering observation only; widget-test timing is not a phone budget.
      // ignore: avoid_print
      print(
        'yellow_ui_cloud_timing selector_us=${selectorWatch.elapsedMicroseconds} '
        'selection_us=${selectionWatch.elapsedMicroseconds}',
      );
    },
  );

  testWidgets(
    'D1 in-flight freezes selection and one deliberate intent saves once',
    (tester) async {
      await fixture.openYellow(tester);
      await tester.tap(find.byKey(const Key('yellow-option-mpid-home-7')));
      await tester.pump();

      final gate = Completer<void>();
      fixture.evidence.beforeAnchorForTest = () => gate.future;
      final commitWatch = Stopwatch()..start();
      tester
          .widget<FilledButton>(find.byKey(const Key('yellow-commit')))
          .onPressed!();
      await fixture.pumpUntil(tester, find.text('Saving…'));
      expect(find.textContaining('Yellow saved'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('yellow-commit')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<InkWell>(
              find.byKey(const Key('yellow-option-mpid-away-9')),
            )
            .onTap,
        isNull,
      );

      await tester.tap(find.byKey(const Key('yellow-commit')));
      gate.complete();
      fixture.evidence.beforeAnchorForTest = null;
      await fixture.pumpUntil(tester, find.textContaining('Yellow saved'));
      commitWatch.stop();

      expect(find.byKey(const Key('yellow-selected')), findsNothing);
      final records = await fixture.records(tester);
      final yellows =
          records.where((record) => record.payload is YellowCardPayload);
      expect(yellows, hasLength(1));
      expect((yellows.single.payload as YellowCardPayload).reason, isNull);
      expect(
        records.where(
          (record) =>
              record.payload is YellowCardPayload &&
              record.recordKind == RecordKind.humanDetermination,
        ),
        hasLength(1),
      );
      final stored = await fixture.legacyMatch(tester);
      expect(stored.events, isEmpty);

      // ignore: avoid_print
      print(
        'yellow_ui_cloud_timing record_to_ack_us='
        '${commitWatch.elapsedMicroseconds} '
        'cloud_timing_is_not_phone_d1_certification=true',
      );
    },
  );

  testWidgets(
    'definite D1 failure retains participant and Retry reuses the capture intent',
    (tester) async {
      await fixture.openYellow(tester);
      await tester.tap(find.byKey(const Key('yellow-option-mpid-home-7')));
      await tester.pump();
      fixture.composition.boundary.durableStore.abortBeforeCommitForTest =
          () => throw StateError('abort Yellow D1');

      await tester.runAsync(
        tester
            .widget<YellowCardCaptureOverlay>(
              find.byType(YellowCardCaptureOverlay),
            )
            .onCommit,
      );
      await tester.pump();
      await fixture.pumpUntil(tester, find.text('Not saved'));
      expect(find.byKey(const Key('yellow-selected')), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('Yellow saved'), findsNothing);
      final failedDraft = await fixture.draftStore.load(fixture.matchId);
      expect(failedDraft?.phase, YellowCardDraftPhase.retryable);
      expect(failedDraft?.captureIntentId, isNotNull);
      expect(
        (await fixture.records(tester))
            .where((record) => record.payload is YellowCardPayload),
        isEmpty,
      );

      fixture.composition.boundary.durableStore.abortBeforeCommitForTest = null;
      await tester.runAsync(
        tester
            .widget<YellowCardCaptureOverlay>(
              find.byType(YellowCardCaptureOverlay),
            )
            .onCommit,
      );
      await tester.pump();
      await fixture.pumpUntil(tester, find.textContaining('Yellow saved'));
      final yellows = (await fixture.records(tester))
          .where((record) => record.payload is YellowCardPayload)
          .toList();
      expect(yellows, hasLength(1));
      expect(
        (yellows.single.payload as YellowCardPayload).captureIntentId,
        failedDraft!.captureIntentId,
      );
    },
  );

  testWidgets(
    'standing prior caution changes CTA and success shows factual persistent warning',
    (tester) async {
      await fixture.seedPriorCaution();
      await fixture.openYellow(tester);

      expect(find.byKey(const Key('prior-caution-marker')), findsWidgets);
      await tester.tap(find.byKey(const Key('yellow-option-mpid-home-7')));
      await tester.pump();
      expect(find.text('PRIOR CAUTION RECORDED'), findsOneWidget);
      expect(find.text('Record second caution'), findsOneWidget);

      await tester.tap(find.byKey(const Key('yellow-commit')));
      await fixture.pumpUntil(
        tester,
        find.text('SECOND CAUTION RECORDED'),
      );
      expect(find.text('No red card has been recorded'), findsOneWidget);
      expect(find.textContaining('#7'), findsWidgets);
      final records = await fixture.records(tester);
      expect(
        records.where((record) => record.payload is YellowCardPayload),
        hasLength(2),
      );
      expect(
        records.where(
          (record) => record.payload.runtimeType.toString().contains('RedCard'),
        ),
        isEmpty,
      );

      await tester.pumpWidget(fixture.app());
      await tester.pump();
      await fixture.pumpUntil(tester, find.text('Matches'));
      await tester.tap(find.text('HOME 0 — 0 AWAY').first);
      await fixture.pumpUntil(
        tester,
        find.text('SECOND CAUTION RECORDED'),
      );
      await tester.tap(find.text('Dismiss'));
      await tester.pump();
      expect(find.text('SECOND CAUTION RECORDED'), findsNothing);
    },
  );

  testWidgets(
    'uncertain reentry reconciles committed intent before exposing Retry',
    (tester) async {
      const intent = 'intent-committed-before-ack';
      final result = await fixture.composition.boundary.commitYellowCard(
        CommitYellowCardCommand(
          context: await fixture.captureContext(),
          participantRef: fixture.homeSeven,
          participantStatusAtDetermination:
              ParticipantStatusAtDetermination.onFieldPlayer,
          disciplinaryAccountingScope: DisciplinaryAccountingScope.match,
          captureIntentId: intent,
        ),
      );
      expect(result, isA<YellowCardSaved>());
      await fixture.draftStore.save(
        PhoneYellowCardDraft(
          matchId: fixture.matchId,
          phase: YellowCardDraftPhase.checking,
          participantId: fixture.homeSeven.matchParticipantId,
          participantStatus: ParticipantStatusAtDetermination.onFieldPlayer,
          captureIntentId: intent,
        ),
      );

      await fixture.openLive(tester);
      await fixture.pumpUntil(tester, find.textContaining('Yellow saved'));
      expect(find.text('Retry'), findsNothing);
      expect(
        (await fixture.records(tester))
            .where((record) => record.payload is YellowCardPayload),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'Bench and Officials are bounded secondary paths including senior coach slot',
    (tester) async {
      await fixture.openYellow(tester);
      expect(find.text('Bench'), findsOneWidget);
      expect(find.text('Officials'), findsOneWidget);
      expect(find.text('Sub Twelve'), findsNothing);

      await tester.tap(find.text('Bench'));
      await tester.pump();
      expect(find.text('Sub Twelve'), findsOneWidget);
      expect(find.text('Substitute'), findsOneWidget);
      expect(find.text('Substituted player'), findsOneWidget);

      await tester.tap(find.text('Officials'));
      await tester.pump();
      expect(find.text('Coach Ionescu'), findsOneWidget);
      expect(find.textContaining('Team official'), findsOneWidget);
      expect(find.textContaining('Senior coach present'), findsOneWidget);
    },
  );

  testWidgets(
    'identity and history trust treatments never become confident no-prior state',
    (tester) async {
      var committed = 0;
      YellowParticipantOption option({
        required String id,
        required IdentityConfidence confidence,
        required YellowPriorAwareness awareness,
        ParticipantStatusAtDetermination status =
            ParticipantStatusAtDetermination.onFieldPlayer,
      }) {
        return YellowParticipantOption(
          participantRef: ParticipantRef(
            matchParticipantId: MatchParticipantId(id),
            teamSide: ParticipantTeamSide.home,
            binding: RosterLinkedBinding(rosterParticipantId: id),
          ),
          status: status,
          identityConfidence: confidence,
          priorAwareness: awareness,
          teamLabel: 'HOME',
          shirtNumber: 4,
          displayName: id,
        );
      }

      final options = [
        option(
          id: 'unknown-identity',
          confidence: IdentityConfidence.resolved,
          awareness: YellowPriorAwareness.unknownIdentity,
        ),
        option(
          id: 'unknown-history',
          confidence: IdentityConfidence.resolved,
          awareness: YellowPriorAwareness.unknownHistory,
        ),
        option(
          id: 'ambiguous',
          confidence: IdentityConfidence.ambiguous,
          awareness: YellowPriorAwareness.unknownIdentity,
        ),
        option(
          id: 'conflicted',
          confidence: IdentityConfidence.conflicted,
          awareness: YellowPriorAwareness.conflicted,
        ),
        option(
          id: 'provisional',
          confidence: IdentityConfidence.provisional,
          awareness: YellowPriorAwareness.noneConfirmed,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: YellowCardCaptureOverlay(
              homePlayers: options,
              awayPlayers: const [],
              bench: const [],
              officials: const [],
              selected: null,
              loading: false,
              saving: false,
              checking: false,
              failed: false,
              onSelect: (_) {},
              onCommit: () async {
                committed++;
              },
              onCancel: () {},
            ),
          ),
        ),
      );

      // Re-pump with each option selected to exercise exact trust rendering.
      for (final current in options) {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: YellowCardCaptureOverlay(
                homePlayers: options,
                awayPlayers: const [],
                bench: const [],
                officials: const [],
                selected: current,
                loading: false,
                saving: false,
                checking: false,
                failed: false,
                onSelect: (_) {},
                onCommit: () async {
                  committed++;
                },
                onCancel: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        if (current.participantKey == 'unknown-identity') {
          expect(
            find.text('Cannot identify participant reliably'),
            findsOneWidget,
          );
        } else if (current.participantKey == 'unknown-history') {
          expect(
            find.text('Caution history cannot be confirmed'),
            findsOneWidget,
          );
        } else if (current.participantKey == 'ambiguous') {
          expect(
            tester
                .widget<FilledButton>(
                  find.byKey(const Key('yellow-commit')),
                )
                .onPressed,
            isNull,
          );
        } else if (current.participantKey == 'conflicted') {
          expect(find.text('Participant details conflict'), findsWidgets);
          expect(
            tester
                .widget<FilledButton>(
                  find.byKey(const Key('yellow-commit')),
                )
                .onPressed,
            isNull,
          );
        } else if (current.participantKey == 'provisional') {
          expect(find.text('Identity provisional'), findsOneWidget);
          expect(
            tester
                .widget<FilledButton>(
                  find.byKey(const Key('yellow-commit')),
                )
                .onPressed,
            isNotNull,
          );
        }
      }
      expect(committed, 0);
    },
  );
}

final class _YellowUiFixture {
  _YellowUiFixture._({
    required this.db,
    required this.temp,
    required this.composition,
    required this.identity,
    required this.capture,
    required this.evidence,
    required this.draftStore,
    required this.matchId,
    required this.homeSeven,
  });

  final LocalMatchDatabase db;
  final Directory temp;
  final MatchApplicationComposition composition;
  final PhoneCaptureIdentity identity;
  final PhoneMatchCaptureContext capture;
  final PhoneTemporalEvidenceStore evidence;
  final PhoneYellowCardDraftStore draftStore;
  final String matchId;
  final ParticipantRef homeSeven;

  static Future<_YellowUiFixture> create() async {
    final db = LocalMatchDatabase.memory();
    final temp = await Directory.systemTemp.createTemp('yellow_ui_');
    final composition =
        await MatchApplicationComposition.open(storageRoot: temp);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final capture = PhoneMatchCaptureContext(
      identity: identity,
      rulesStore: MatchCompetitionRulesStore(temp),
    );
    final evidence = PhoneTemporalEvidenceStore(storageRoot: temp);
    final draftStore = PhoneYellowCardDraftStore(temp);
    final match = newLocalMatch(DateTime.utc(2026, 10, 7)).copyWith(
      status: MatchStatus.ready,
      squads: const Squads(
        home: TeamSquad(
          players: [
            Player(
              playerId: 'home-7',
              shirtNumber: 7,
              name: 'Home Seven',
              role: PlayerRole.starter,
            ),
            Player(
              playerId: 'home-12',
              shirtNumber: 12,
              name: 'Sub Twelve',
              role: PlayerRole.substitute,
            ),
            Player(
              playerId: 'home-13',
              shirtNumber: 13,
              name: 'Former Thirteen',
              role: PlayerRole.substitute,
            ),
          ],
        ),
        away: TeamSquad(
          players: [
            Player(
              playerId: 'away-9',
              shirtNumber: 9,
              name: 'Away Nine',
              role: PlayerRole.starter,
            ),
          ],
        ),
      ),
    );
    await db.upsertMatch(match);
    await capture.rulesStore.saveForMatch(
      match.matchId,
      const CompetitionRulesContext(
        rulesetId: 'ordinary-ifab-test',
        disciplinarySystem: DisciplinarySystem.ordinaryIfab,
      ),
    );
    final fixture = _YellowUiFixture._(
      db: db,
      temp: temp,
      composition: composition,
      identity: identity,
      capture: capture,
      evidence: evidence,
      draftStore: draftStore,
      matchId: match.matchId,
      homeSeven: ParticipantRef(
        matchParticipantId: MatchParticipantId('mpid-home-7'),
        teamSide: ParticipantTeamSide.home,
        binding: const RosterLinkedBinding(rosterParticipantId: 'home-7'),
      ),
    );
    await fixture._seedFoundation();
    return fixture;
  }

  RefereeApp app() => RefereeApp(
        database: db,
        matchApplication: composition.boundary,
        captureIdentity: identity,
        matchCaptureContext: capture,
        temporalEvidence: evidence,
        yellowCardDraftStore: draftStore,
      );

  Future<CaptureContext> captureContext() => capture.captureContextFor(matchId);

  Future<void> _seedFoundation() async {
    final context = await captureContext();
    await _commit(
      context,
      RecordKind.temporalFact,
      TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.refereeEnteredFieldForMatchStart,
      ),
    );
    await _register(
      context,
      homeSeven,
      ParticipantStatusAtDetermination.onFieldPlayer,
    );
    await _register(
      context,
      ParticipantRef(
        matchParticipantId: MatchParticipantId('mpid-away-9'),
        teamSide: ParticipantTeamSide.away,
        binding: const RosterLinkedBinding(rosterParticipantId: 'away-9'),
      ),
      ParticipantStatusAtDetermination.onFieldPlayer,
    );
    await _register(
      context,
      ParticipantRef(
        matchParticipantId: MatchParticipantId('mpid-home-12'),
        teamSide: ParticipantTeamSide.home,
        binding: const RosterLinkedBinding(rosterParticipantId: 'home-12'),
      ),
      ParticipantStatusAtDetermination.substitute,
    );
    await _register(
      context,
      ParticipantRef(
        matchParticipantId: MatchParticipantId('mpid-home-13'),
        teamSide: ParticipantTeamSide.home,
        binding: const RosterLinkedBinding(rosterParticipantId: 'home-13'),
      ),
      ParticipantStatusAtDetermination.substitutedPlayer,
    );
    await _register(
      context,
      ParticipantRef(
        matchParticipantId: MatchParticipantId('mpid-home-official'),
        teamSide: ParticipantTeamSide.home,
        binding: const IdentifiedOfficialBinding(displayName: 'Coach Ionescu'),
      ),
      ParticipantStatusAtDetermination.teamOfficial,
    );
    await _register(
      context,
      ParticipantRef(
        matchParticipantId: MatchParticipantId('mpid-away-coach-slot'),
        teamSide: ParticipantTeamSide.away,
        binding: const SeniorCoachPresentBinding(),
      ),
      ParticipantStatusAtDetermination.seniorCoachPresent,
    );
    await _register(
      context,
      ParticipantRef(
        matchParticipantId: MatchParticipantId('mpid-provisional'),
        teamSide: ParticipantTeamSide.away,
        binding:
            const FreeformDescriptorBinding(descriptor: 'Provisional player'),
      ),
      ParticipantStatusAtDetermination.onFieldPlayer,
    );
  }

  Future<void> _register(
    CaptureContext context,
    ParticipantRef participant,
    ParticipantStatusAtDetermination status,
  ) {
    return _commit(
      context,
      RecordKind.action,
      ParticipantRegisteredPayload(
        matchParticipantId: participant.matchParticipantId,
        teamSide: participant.teamSide,
        binding: participant.binding,
        initialStatus: status,
      ),
    );
  }

  Future<void> _commit(
    CaptureContext context,
    RecordKind kind,
    MatchRecordPayload payload,
  ) async {
    final result = await composition.boundary.captureAndCommit(
      AuthoritativeCaptureCommand(
        context: context,
        recordKind: kind,
        payload: payload,
        integrity: const IntegrityMetadata(),
      ),
    );
    expect(result, isA<DurableCommitSuccess>());
  }

  Future<void> seedPriorCaution() async {
    final result = await composition.boundary.commitYellowCard(
      CommitYellowCardCommand(
        context: await captureContext(),
        participantRef: homeSeven,
        participantStatusAtDetermination:
            ParticipantStatusAtDetermination.onFieldPlayer,
        disciplinaryAccountingScope: DisciplinaryAccountingScope.match,
        captureIntentId: 'intent-prior',
      ),
    );
    expect(result, isA<YellowCardSaved>());
  }

  Future<void> openLive(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    await pumpUntil(tester, find.text('Matches'));
    await tester.tap(find.text('HOME 0 — 0 AWAY').first);
    await tester.pump();
    await pumpUntil(tester, find.text('Yellow'));
  }

  Future<void> openYellow(WidgetTester tester) async {
    await openLive(tester);
    await tester.tap(find.text('Yellow'));
    await tester.pump();
    await pumpUntil(
      tester,
      find.byKey(const Key('yellow-option-mpid-home-7')),
    );
  }

  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    int maxPumps = 100,
  }) async {
    for (var i = 0; i < maxPumps; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.runAsync(() => Future<void>(() {}));
      await tester.pump(const Duration(milliseconds: 50));
    }
    fail('Timed out waiting for $finder');
  }

  Future<List<MatchRecord>> records(WidgetTester tester) async {
    late List<MatchRecord> result;
    await tester.runAsync(() async {
      result = await composition.boundary.durableStore
          .readCommittedForMatch(matchId);
    });
    return result;
  }

  Future<Match> legacyMatch(WidgetTester tester) async {
    late Match result;
    await tester.runAsync(() async {
      result = (await db.getMatch(matchId))!;
    });
    return result;
  }

  Future<void> close() async {
    await composition.close();
    await db.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  }
}
