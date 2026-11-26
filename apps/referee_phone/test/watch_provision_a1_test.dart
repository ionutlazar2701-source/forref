import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';

void main() {
  late Directory temp;
  late MatchApplicationComposition composition;
  late PhoneCaptureIdentity identity;
  late Map<String, Object?> fixture;
  late String canonical;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('watch_provision_a1_');
    composition = await MatchApplicationComposition.open(storageRoot: temp);
    identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    fixture = jsonDecode(
      File('../../packages/forref_match_core/test/fixtures/watch_provision_v1.json')
          .readAsStringSync(),
    ) as Map<String, Object?>;
    canonical = fixture['canonical']! as String;
  });

  tearDown(() async {
    await composition.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('phone preparation locks the watch writer and appends no sporting record', () async {
    final prepared = await composition.boundary.prepareWatchOperatedMatch(
      canonicalMessage: canonical,
      phoneOriginDeviceId: identity.originDeviceId,
    );
    expect(prepared.state, WatchProvisionState.configReceived);
    expect(prepared.reason, 'phone-prepared');
    expect(prepared.matchReady, isFalse);
    expect(prepared.saved, isFalse);
    expect(prepared.d1Certified, isFalse);

    final root = await composition.boundary.durableStore.readGenerationOneAuthorityRoot(
      'match-watch-001',
    );
    expect(root?.deviceId, fixture['localInstallationId']);
    expect(root?.generation, 1);

    final denied = await composition.boundary.commitGoal(
      identity.contextFor('match-watch-001'),
      scoringTeamId: MatchTeamId('team-alpha-001'),
      captureIntentId: 'intent-phone-goal',
    );
    expect(denied, isA<DurableCommitFailure>());
    final records = await composition.boundary.durableStore.readCommittedForMatch(
      'match-watch-001',
    );
    expect(records, isEmpty);
  });

  test('an existing phone goal blocks watch provisioning', () async {
    final context = identity.contextFor('match-phone-history');
    final goal = await composition.boundary.commitGoal(
      context,
      scoringTeamId: MatchTeamId('team-alpha-001'),
      captureIntentId: 'intent-existing',
    );
    expect(goal, isA<DurableCommitSuccess>());
    final message = canonical.replaceFirst('match-watch-001', 'match-phone-history');
    final refused = await composition.boundary.prepareWatchOperatedMatch(
      canonicalMessage: message,
      phoneOriginDeviceId: identity.originDeviceId,
    );
    expect(refused.state, WatchProvisionState.authorityConflict);
    expect(refused.reason, 'existing phone-authoritative history');
    final root = await composition.boundary.durableStore.readGenerationOneAuthorityRoot(
      'match-phone-history',
    );
    expect(root?.deviceId, identity.originDeviceId);
  });
}
