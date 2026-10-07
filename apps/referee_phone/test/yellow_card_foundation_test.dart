import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/app.dart';
import 'package:referee_phone/infrastructure/competition_rules/match_competition_rules_store.dart';
import 'package:referee_phone/infrastructure/competition_rules/phone_match_capture_context.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/features/live_match/yellow_card_phone_read_model.dart';
import 'package:referee_phone/infrastructure/yellow_card/phone_match_foundation.dart';
import 'package:referee_phone/infrastructure/yellow_card/phone_participant_registry_store.dart';
import 'package:referee_phone/match/new_match.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late LocalMatchDatabase db;
  late MatchApplicationComposition composition;
  late PhoneCaptureIdentity identity;
  late PhoneMatchCaptureContext capture;
  late PhoneParticipantRegistryStore registry;
  late PhoneMatchFoundation foundation;
  late String matchId;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('yc_foundation_');
    db = LocalMatchDatabase.memory();
    composition = await MatchApplicationComposition.open(storageRoot: temp);
    identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    capture = PhoneMatchCaptureContext(
      identity: identity,
      rulesStore: MatchCompetitionRulesStore(temp),
    );
    registry = PhoneParticipantRegistryStore(temp);
    foundation = PhoneMatchFoundation(
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
              playerId: 'home-7',
              shirtNumber: 7,
              name: 'Home Seven',
              role: PlayerRole.starter,
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
    matchId = match.matchId;
    await db.upsertMatch(match);
    await capture.rulesStore.saveForMatch(
      matchId,
      const CompetitionRulesContext(
        rulesetId: 'ifab',
        disciplinarySystem: DisciplinarySystem.ordinaryIfab,
      ),
    );
  });

  tearDown(() async {
    await composition.close();
    await db.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('Go Live registration does not commit field entry', () async {
    final match = (await db.getMatch(matchId))!;
    final context = await capture.captureContextFor(matchId);

    await foundation.registerRosterFromMatch(context: context, match: match);

    final records =
        await composition.boundary.durableStore.readCommittedForMatch(matchId);
    expect(matchMemoryHasFieldEntry(records), isFalse);
    expect(matchMemoryHasParticipantRegistrations(records), isTrue);
    expect(records.where((r) => r.payload is ParticipantRegisteredPayload),
        hasLength(2));
  });

  test('explicit field entry opens card-display authority', () async {
    final match = (await db.getMatch(matchId))!;
    final context = await capture.captureContextFor(matchId);
    await foundation.registerRosterFromMatch(context: context, match: match);

    expect(
      await foundation.commitRefereeEnteredField(context),
      isA<FieldEntryCommitted>(),
    );
    expect(
      await foundation.commitRefereeEnteredField(context),
      isA<FieldEntryAlreadyCommitted>(),
    );

    final records =
        await composition.boundary.durableStore.readCommittedForMatch(matchId);
    expect(matchMemoryHasFieldEntry(records), isTrue);
    expect(
      records.where(
        (r) =>
            r.payload is TemporalTransitionPayload &&
            (r.payload as TemporalTransitionPayload).semanticType ==
                V1SemanticTypeCode.refereeEnteredFieldForMatchStart,
      ),
      hasLength(1),
    );
    final authority = DisciplinaryAuthorityProjection.derive(records: records);
    expect(authority.cardDisplayAuthorityOpen, isTrue);
  });

  testWidgets('selector receives participants without manual _seedFoundation',
      (tester) async {
    final match = (await db.getMatch(matchId))!;
    final context = await capture.captureContextFor(matchId);
    await foundation.registerRosterFromMatch(context: context, match: match);
    await foundation.commitRefereeEnteredField(context);

    await tester.pumpWidget(
      RefereeApp(
        database: db,
        matchApplication: composition.boundary,
        captureIdentity: identity,
        matchCaptureContext: capture,
        participantRegistry: registry,
        matchFoundation: foundation,
      ),
    );
    await tester.pump();

    final records =
        await composition.boundary.durableStore.readCommittedForMatch(matchId);
    final identities = ParticipantIdentityProjection.derive(records: records);
    final disciplinary = DisciplinaryMatchProjection.derive(
      records: records,
      evaluatedAuthorityGeneration: context.projectionAuthorityGeneration,
      competitionRules: context.competitionRulesContext,
    );
    final registryEntries = await registry.loadForMatch(matchId);

    final options = buildYellowParticipantOptions(
      match: match,
      identities: identities,
      disciplinary: disciplinary,
      homeLabel: 'HOME',
      awayLabel: 'AWAY',
      registryEntries: registryEntries,
    );
    expect(options, hasLength(2));
    expect(options.map((o) => o.shirtNumber).toList(), containsAll([7, 9]));
  });

  test('legacy match events do not influence Match Memory discipline', () async {
    final match = (await db.getMatch(matchId))!;
    final context = await capture.captureContextFor(matchId);
    await foundation.registerRosterFromMatch(context: context, match: match);
    await foundation.commitRefereeEnteredField(context);

    final now = DateTime.utc(2026, 10, 7, 12);
    final legacyYellow = match.copyWith(
      events: [
        MatchEvent(
          eventId: 'legacy-yc-1',
          matchId: matchId,
          type: EventType.yellowCard,
          status: EventStatus.complete,
          periodId: PeriodId.firstHalf,
          matchTime: 600,
          createdAt: now,
          updatedAt: now,
          data: const EventData(
            teamId: 'home',
            player: PlayerRef(
              playerId: 'home-7',
              shirtNumber: 7,
              isUnknown: false,
            ),
          ),
        ),
      ],
    );
    await db.upsertMatch(legacyYellow);

    final records =
        await composition.boundary.durableStore.readCommittedForMatch(matchId);
    final disciplinary = DisciplinaryMatchProjection.derive(
      records: records,
      evaluatedAuthorityGeneration: context.projectionAuthorityGeneration,
      competitionRules: context.competitionRulesContext,
    );
    final homeIdentity = ParticipantIdentityProjection.derive(records: records)
        .participantsByRegisteredId
        .values
        .firstWhere((p) => p.teamSide == ParticipantTeamSide.home);
    final prior = disciplinary.priorCautionStateFor(
      participantId: homeIdentity.canonicalId,
      accountingScope: DisciplinaryAccountingScope.match,
    );
    expect(prior.state, PriorCautionState.none);
    expect(records.where((r) => r.payload is YellowCardPayload), isEmpty);
  });

  test('legacy roster mutation does not change registered display snapshot',
      () async {
    final match = (await db.getMatch(matchId))!;
    final context = await capture.captureContextFor(matchId);
    await foundation.registerRosterFromMatch(context: context, match: match);

    final mutated = match.copyWith(
      squads: Squads(
        home: const TeamSquad(
          players: [
            Player(
              playerId: 'home-7',
              shirtNumber: 99,
              name: 'Wrong Name',
              role: PlayerRole.starter,
            ),
          ],
        ),
        away: match.squads.away,
      ),
    );
    await db.upsertMatch(mutated);

    final records =
        await composition.boundary.durableStore.readCommittedForMatch(matchId);
    final identities = ParticipantIdentityProjection.derive(records: records);
    final disciplinary = DisciplinaryMatchProjection.derive(
      records: records,
      evaluatedAuthorityGeneration: 1,
      competitionRules: context.competitionRulesContext,
    );
    final registryEntries = await registry.loadForMatch(matchId);
    final options = buildYellowParticipantOptions(
      match: mutated,
      identities: identities,
      disciplinary: disciplinary,
      homeLabel: 'HOME',
      awayLabel: 'AWAY',
      registryEntries: registryEntries,
    );
    final home = options.firstWhere(
      (option) => option.participantRef.teamSide == ParticipantTeamSide.home,
    );
    expect(home.shirtNumber, 7);
    expect(home.displayName, 'Home Seven');
  });
}

final class _DeterministicParticipantIds implements MatchParticipantIdGenerator {
  var _next = 0;

  @override
  MatchParticipantId newParticipantId() {
    _next += 1;
    return MatchParticipantId('mpid-test-$_next');
  }
}
