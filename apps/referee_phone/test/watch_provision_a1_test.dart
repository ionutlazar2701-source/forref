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

  test('preparation stores the stage and does not create an authority root',
      () async {
    final prepared = await composition.boundary.prepareWatchOperatedMatch(
      canonicalMessage: canonical,
      phoneOriginDeviceId: identity.originDeviceId,
    );
    expect(prepared.state, WatchProvisionState.configPrepared);
    expect(prepared.reason, 'phone-prepared');
    expect(prepared.mayAppendSportingRecords, isFalse);
    expect(prepared.saved, isFalse);
    expect(prepared.d1Certified, isFalse);

    final root =
        await composition.boundary.durableStore.readGenerationOneAuthorityRoot(
      'match-watch-001',
    );
    expect(root, isNull);
    final stage =
        await composition.boundary.durableStore.readWatchProvisionStage(
      'match-watch-001',
    );
    expect(stage?.stage, 'CONFIG_PREPARED');
    expect(stage?.writerDeviceId, fixture['localInstallationId']);

    final denied = await composition.boundary.commitGoal(
      identity.contextFor('match-watch-001'),
      scoringTeamId: MatchTeamId('team-alpha-001'),
      captureIntentId: 'intent-phone-goal',
    );
    expect(denied, isA<DurableCommitFailure>());
    expect((denied as DurableCommitFailure).reason,
        contains('watch provision reserves'));
    final period = await composition.boundary.commitPeriodStarted(
      identity.contextFor('match-watch-001'),
      period: const PeriodIdentity(index: 1),
      matchStartedRecordId: 'not-committed',
    );
    expect(period, isA<DurableCommitFailure>());
    expect((period as DurableCommitFailure).reason,
        contains('watch provision reserves'));
    final records =
        await composition.boundary.durableStore.readCommittedForMatch(
      'match-watch-001',
    );
    expect(records, isEmpty);
  });

  test('transport unavailable before the lock writes no authority root',
      () async {
    await composition.boundary.prepareWatchOperatedMatch(
      canonicalMessage: canonical,
      phoneOriginDeviceId: identity.originDeviceId,
    );
    final blocked = await composition.boundary.lockWatchAuthority(
      canonicalMessage: canonical,
      phoneOriginDeviceId: identity.originDeviceId,
      receipt: null,
      transportAvailable: false,
    );
    expect(blocked.state, WatchProvisionState.configPrepared);
    expect(blocked.reason, 'transport-unavailable');
    final root =
        await composition.boundary.durableStore.readGenerationOneAuthorityRoot(
      'match-watch-001',
    );
    expect(root, isNull);
  });

  test('a crash after the lock keeps the watch writer and refuses the phone',
      () async {
    await composition.boundary.prepareWatchOperatedMatch(
      canonicalMessage: canonical,
      phoneOriginDeviceId: identity.originDeviceId,
    );
    final locked = await composition.boundary.lockWatchAuthority(
      canonicalMessage: canonical,
      phoneOriginDeviceId: identity.originDeviceId,
      receipt: WatchConfigVerifiedReceipt(
        contentHash: fixture['contentHash']! as String,
        writerDeviceId: fixture['localInstallationId']! as String,
        generation: 1,
        readBack: true,
      ),
      transportAvailable: true,
    );
    expect(locked.state, WatchProvisionState.phoneAuthorityLocked);
    expect(locked.saved, isFalse);
    expect(locked.d1Certified, isFalse);
    await composition.close();
    composition = await MatchApplicationComposition.open(storageRoot: temp);
    final root =
        await composition.boundary.durableStore.readGenerationOneAuthorityRoot(
      'match-watch-001',
    );
    expect(root?.deviceId, fixture['localInstallationId']);
    final stage =
        await composition.boundary.durableStore.readWatchProvisionStage(
      'match-watch-001',
    );
    expect(stage?.stage, 'PHONE_AUTHORITY_LOCKED');
    final denied = await composition.boundary.commitGoal(
      identity.contextFor('match-watch-001'),
      scoringTeamId: MatchTeamId('team-alpha-001'),
      captureIntentId: 'intent-after-crash',
    );
    expect(denied, isA<DurableCommitFailure>());
    final records =
        await composition.boundary.durableStore.readCommittedForMatch(
      'match-watch-001',
    );
    expect(records, isEmpty);
    final repeated = await composition.boundary.lockWatchAuthority(
      canonicalMessage: canonical,
      phoneOriginDeviceId: identity.originDeviceId,
      receipt: WatchConfigVerifiedReceipt(
        contentHash: fixture['contentHash']! as String,
        writerDeviceId: fixture['localInstallationId']! as String,
        generation: 1,
        readBack: true,
      ),
      transportAvailable: true,
    );
    expect(repeated.state, WatchProvisionState.phoneAuthorityLocked);
    expect(repeated.rootToCommit, isNull);
  });

  test('an existing phone goal blocks watch provisioning', () async {
    final context = identity.contextFor('match-phone-history');
    final goal = await composition.boundary.commitGoal(
      context,
      scoringTeamId: MatchTeamId('team-alpha-001'),
      captureIntentId: 'intent-existing',
    );
    expect(goal, isA<DurableCommitSuccess>());
    final message =
        canonical.replaceFirst('match-watch-001', 'match-phone-history');
    final refused = await composition.boundary.prepareWatchOperatedMatch(
      canonicalMessage: message,
      phoneOriginDeviceId: identity.originDeviceId,
    );
    expect(refused.state, WatchProvisionState.authorityConflict);
    expect(refused.reason, 'existing phone-authoritative history');
    final root =
        await composition.boundary.durableStore.readGenerationOneAuthorityRoot(
      'match-phone-history',
    );
    expect(root?.deviceId, identity.originDeviceId);
  });

  test('cancellation before the lock removes the reservation only', () async {
    await composition.boundary.prepareWatchOperatedMatch(
      canonicalMessage: canonical,
      phoneOriginDeviceId: identity.originDeviceId,
    );
    final stored = await composition.boundary.durableStore
        .readWatchProvisionStage('match-watch-001');
    final inspection = await composition.boundary.inspectWatchProvision(
      matchId: 'match-watch-001',
      requestedContentHash: stored!.contentHash,
      requestedWriterDeviceId: stored.writerDeviceId,
      requestedPrincipalId: 'other-principal',
    );
    expect(inspection.changed, ['principal']);
    expect(inspection.rootPresent, isFalse);
    expect(inspection.sportingRecords, isFalse);
    expect(inspection.line.contains(stored.canonical), isFalse);
    final wrong = await composition.boundary.cancelPreparedWatchMatch(
      matchId: 'match-watch-001',
      contentHash: 'not-the-hash',
    );
    expect(wrong.reason, 'hash');
    final cancelled = await composition.boundary.cancelPreparedWatchMatch(
      matchId: 'match-watch-001',
      contentHash: fixture['contentHash']! as String,
    );
    expect(cancelled.state, WatchProvisionState.unprovisioned);
    expect(cancelled.reason, 'cancelled');
    expect(
      await composition.boundary.durableStore.readWatchProvisionStage(
        'match-watch-001',
      ),
      isNull,
    );
    expect(
      await composition.boundary.durableStore.readGenerationOneAuthorityRoot(
        'match-watch-001',
      ),
      isNull,
    );
  });
}
