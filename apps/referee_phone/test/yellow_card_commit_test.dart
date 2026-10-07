import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/match_application/authoritative_capture_command.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late MatchApplicationComposition composition;

  final participant = ParticipantRef(
    matchParticipantId: MatchParticipantId('mpid-phone-7'),
    teamSide: ParticipantTeamSide.home,
    binding: const RosterLinkedBinding(rosterParticipantId: 'home-7'),
  );

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('phone_yellow_card_');
    composition = await MatchApplicationComposition.open(storageRoot: temp);
  });

  tearDown(() async {
    await composition.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  CaptureContext context() {
    return const CaptureContext(
      matchId: 'match-phone-yc',
      originDeviceId: 'phone-device',
      authorityScope: MainRefereeScope(),
      authorityPrincipalId: 'ref-phone',
      authorityGeneration: 1,
      projectionAuthorityGeneration: 1,
      activeCaptureDeviceId: 'phone-device',
      domainContractVersion: DomainContractVersion('domain-clock-v1'),
      competitionRulesContext: CompetitionRulesContext(
        rulesetId: 'ifab',
        disciplinarySystem: DisciplinarySystem.ordinaryIfab,
      ),
    );
  }

  Future<void> prepare() async {
    final entered = await composition.boundary.captureAndCommit(
      AuthoritativeCaptureCommand(
        context: context(),
        recordKind: RecordKind.temporalFact,
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.refereeEnteredFieldForMatchStart,
        ),
        integrity: const IntegrityMetadata(),
      ),
    );
    expect(entered, isA<DurableCommitSuccess>());
    final registered = await composition.boundary.captureAndCommit(
      AuthoritativeCaptureCommand(
        context: context(),
        recordKind: RecordKind.action,
        payload: ParticipantRegisteredPayload(
          matchParticipantId: participant.matchParticipantId,
          teamSide: participant.teamSide,
          binding: participant.binding,
        ),
        integrity: const IntegrityMetadata(),
      ),
    );
    expect(registered, isA<DurableCommitSuccess>());
  }

  test(
      'commitYellowCard is the phone command and generic capture cannot bypass it',
      () async {
    await prepare();
    final bypass = await composition.boundary.captureAndCommit(
      AuthoritativeCaptureCommand(
        context: context(),
        recordKind: RecordKind.humanDetermination,
        payload: YellowCardPayload(
          participantRef: participant,
          participantStatusAtDetermination:
              ParticipantStatusAtDetermination.onFieldPlayer,
          disciplinaryAccountingScope: DisciplinaryAccountingScope.match,
          captureIntentId: 'intent-bypass',
        ),
        integrity: const IntegrityMetadata(),
      ),
    );
    expect(bypass, isA<DurableCommitFailure>());
    final before =
        await composition.boundary.durableStore.readCommittedForMatch(
      'match-phone-yc',
    );
    expect(
        before.where((record) => record.payload is YellowCardPayload), isEmpty);

    final saved = await composition.boundary.commitYellowCard(
      CommitYellowCardCommand(
        context: context(),
        participantRef: participant,
        participantStatusAtDetermination:
            ParticipantStatusAtDetermination.onFieldPlayer,
        disciplinaryAccountingScope: DisciplinaryAccountingScope.match,
        captureIntentId: 'intent-phone-1',
      ),
    );
    expect(saved, isA<YellowCardSaved>());
    expect(saved.ackEligible, isTrue);
    final yellows =
        (await composition.boundary.durableStore.readCommittedForMatch(
      'match-phone-yc',
    ))
            .where((record) => record.payload is YellowCardPayload);
    expect(yellows, hasLength(1));
    expect(yellows.single.recordKind, RecordKind.humanDetermination);
  });

  test('empty captureIntentId returns typed rejection through phone boundary',
      () async {
    await prepare();
    final result = await composition.boundary.commitYellowCard(
      CommitYellowCardCommand(
        context: context(),
        participantRef: participant,
        participantStatusAtDetermination:
            ParticipantStatusAtDetermination.onFieldPlayer,
        disciplinaryAccountingScope: DisciplinaryAccountingScope.match,
        captureIntentId: '',
      ),
    );
    expect(result, isA<YellowCardCommitRejected>());
    expect(
      (result as YellowCardCommitRejected).failure,
      YellowCardCommitFailure.invalidCaptureIntent,
    );
  });

  test('phone Yellow UI is isolated from legacy MatchSession authority', () {
    final session = File('lib/match/match_session.dart').readAsStringSync();
    expect(session, isNot(contains('commitYellowCard')));
    expect(session, contains('upsertMatch'));

    final boundary = File(
      'lib/match_application/match_application_boundary.dart',
    ).readAsStringSync();
    expect(boundary, isNot(contains('package:match_core')));
    expect(boundary, isNot(contains('EventType.yellowCard')));

    final legacyOverlay =
        File('lib/features/live_match/capture_overlay.dart').readAsStringSync();
    expect(legacyOverlay, isNot(contains('commitYellowCard')));
    final livePage =
        File('lib/features/live_match/live_match_page.dart').readAsStringSync();
    expect(livePage, contains('commitYellowCard'));
    expect(livePage, contains('YellowCardCaptureOverlay'));

    expect(
      Directory(temp.path).listSync(recursive: true).whereType<File>().map(
            (file) => file.path,
          ),
      isNot(anyElement(contains('local_match'))),
    );
  });
}
