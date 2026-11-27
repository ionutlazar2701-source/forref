import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('forref_watch_n1_');
  });

  tearDown(() async {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('preparation and a phone root cannot both commit', () async {
    final store =
        SqliteDurableMatchStore.open(File('${temp.path}/race.sqlite'));
    final prepared = store.saveWatchProvisionPrepared(_stage());
    final phoneRoot = store.commitGenerationOneAuthorityRoot(
      const GenerationOneAuthorityRoot(
        matchId: 'match-1',
        principalId: 'ref-1',
        deviceId: 'phone-a',
      ),
    );
    final results = await Future.wait([prepared, phoneRoot]);
    final stageWrite = results[0] as WatchProvisionStageWrite;
    final rootWrite = results[1] as GenerationOneRootCommitResult;
    final stage = await store.readWatchProvisionStage('match-1');
    final root = await store.readGenerationOneAuthorityRoot('match-1');
    final preparedWon = stageWrite is WatchProvisionStageSaved;
    final rootWon = rootWrite is GenerationOneRootCommitSuccess;
    expect(preparedWon && rootWon, isFalse);
    if (preparedWon) {
      expect(stage?.stage, 'CONFIG_PREPARED');
      expect(root, isNull);
      expect((rootWrite as GenerationOneRootCommitFailure).reason,
          contains('watch provision reserves'));
    } else {
      expect(stage, isNull);
      expect(root?.deviceId, 'phone-a');
      expect(
          (stageWrite as WatchProvisionStageRefused).reason, 'root-conflict');
    }
    await store.close();
  });

  test('an existing sporting history blocks preparation inside the transaction',
      () async {
    final store =
        SqliteDurableMatchStore.open(File('${temp.path}/history.sqlite'));
    expect(
      await store.commitGenerationOneAuthorityRoot(
        const GenerationOneAuthorityRoot(
          matchId: 'match-1',
          principalId: 'ref-1',
          deviceId: 'phone-a',
        ),
      ),
      isA<GenerationOneRootCommitSuccess>(),
    );
    expect(await store.commit(_goal()), isA<DurableCommitSuccess>());
    final refused = await store.saveWatchProvisionPrepared(
      _stage(writer: 'phone-a', principal: 'ref-1'),
    );
    expect(refused, isA<WatchProvisionStageRefused>());
    expect(
      (refused as WatchProvisionStageRefused).reason,
      'existing phone-authoritative history',
    );
    expect(await store.readWatchProvisionStage('match-1'), isNull);
    expect(
      (await store.readGenerationOneAuthorityRoot('match-1'))?.deviceId,
      'phone-a',
    );
    await store.close();
  });

  test('the same preparation retries and a conflicting document is kept out',
      () async {
    final store =
        SqliteDurableMatchStore.open(File('${temp.path}/retry.sqlite'));
    expect(
      await store.saveWatchProvisionPrepared(_stage()),
      isA<WatchProvisionStageSaved>(),
    );
    final again = await store.saveWatchProvisionPrepared(_stage());
    expect(again, isA<WatchProvisionStageSaved>());
    expect((again as WatchProvisionStageSaved).stage.contentHash, 'hash-1');
    final conflict =
        await store.saveWatchProvisionPrepared(_stage(hash: 'hash-2'));
    expect(conflict, isA<WatchProvisionStageRefused>());
    expect(
        (conflict as WatchProvisionStageRefused).reason, 'prepared-conflict');
    expect((await store.readWatchProvisionStage('match-1'))?.contentHash,
        'hash-1');
    await store.close();
  });

  test('a generic root commit cannot occupy a reserved match', () async {
    final store =
        SqliteDurableMatchStore.open(File('${temp.path}/root.sqlite'));
    await store.saveWatchProvisionPrepared(_stage());
    final phone = await store.commitGenerationOneAuthorityRoot(
      const GenerationOneAuthorityRoot(
        matchId: 'match-1',
        principalId: 'ref-1',
        deviceId: 'phone-a',
      ),
    );
    final forgedWatch = await store.commitGenerationOneAuthorityRoot(
      const GenerationOneAuthorityRoot(
        matchId: 'match-1',
        principalId: 'ref-1',
        deviceId: 'watch-1',
      ),
    );
    expect((phone as GenerationOneRootCommitFailure).reason,
        contains('watch provision reserves'));
    expect((forgedWatch as GenerationOneRootCommitFailure).reason,
        contains('watch provision reserves'));
    expect(await store.readGenerationOneAuthorityRoot('match-1'), isNull);
    await store.close();
  });

  test('close and reopen keeps the prepared stage and the later lock',
      () async {
    final file = File('${temp.path}/reopen.sqlite');
    final store = SqliteDurableMatchStore.open(file);
    await store.saveWatchProvisionPrepared(_stage());
    await store.close();
    final reopened = SqliteDurableMatchStore.open(file);
    expect((await reopened.readWatchProvisionStage('match-1'))?.stage,
        'CONFIG_PREPARED');
    expect(await reopened.readGenerationOneAuthorityRoot('match-1'), isNull);
    expect(
      await reopened.lockPreparedWatchAuthority(
        matchId: 'match-1',
        contentHash: 'hash-1',
        writerDeviceId: 'watch-1',
        principalId: 'ref-1',
      ),
      isA<GenerationOneRootCommitSuccess>(),
    );
    await reopened.close();
    final afterCrash = SqliteDurableMatchStore.open(file);
    expect(
        (await afterCrash.readGenerationOneAuthorityRoot('match-1'))?.deviceId,
        'watch-1');
    expect((await afterCrash.readWatchProvisionStage('match-1'))?.stage,
        'PHONE_AUTHORITY_LOCKED');
    final cancel = await afterCrash.cancelPreparedWatchProvision(
      matchId: 'match-1',
      contentHash: 'hash-1',
    );
    expect(cancel, isA<WatchProvisionStageRefused>());
    expect((cancel as WatchProvisionStageRefused).reason, 'authority-locked');
    expect(
        (await afterCrash.readGenerationOneAuthorityRoot('match-1'))?.deviceId,
        'watch-1');
    await afterCrash.close();
  });

  test('pre-lock cancellation removes only an exact prepared stage', () async {
    final file = File('${temp.path}/cancel.sqlite');
    final store = SqliteDurableMatchStore.open(file);
    await store.saveWatchProvisionPrepared(_stage());
    final wrong = await store.cancelPreparedWatchProvision(
      matchId: 'match-1',
      contentHash: 'hash-2',
    );
    expect((wrong as WatchProvisionStageRefused).reason, 'hash');
    expect(await store.readWatchProvisionStage('match-1'), isNotNull);
    final cancelled = await store.cancelPreparedWatchProvision(
      matchId: 'match-1',
      contentHash: 'hash-1',
    );
    expect(cancelled, isA<WatchProvisionStageCancelled>());
    expect(await store.readWatchProvisionStage('match-1'), isNull);
    expect(await store.readGenerationOneAuthorityRoot('match-1'), isNull);
    await store.close();

    final raw = sqlite3.open(file.path);
    raw.execute(
      '''
      INSERT INTO watch_provision_stages (
        match_id, canonical, content_hash, stage, writer_device_id, principal_id
      ) VALUES ('match-1', '{}', 'hash-1', 'CONFIG_PREPARED', 'watch-1', 'ref-1')
      ''',
    );
    raw.execute(
      '''
      INSERT INTO committed_match_records (
        record_id, match_id, origin_device_id, origin_sequence, record_json
      ) VALUES ('row-1', 'match-1', 'phone-a', 1, '{}')
      ''',
    );
    raw.close();
    final blocked = SqliteDurableMatchStore.open(file);
    final refused = await blocked.cancelPreparedWatchProvision(
      matchId: 'match-1',
      contentHash: 'hash-1',
    );
    expect((refused as WatchProvisionStageRefused).reason,
        'existing phone-authoritative history');
    expect(await blocked.readWatchProvisionStage('match-1'), isNotNull);
    await blocked.close();
  });
}

WatchProvisionPhoneStage _stage({
  String hash = 'hash-1',
  String writer = 'watch-1',
  String principal = 'ref-1',
}) {
  return WatchProvisionPhoneStage(
    matchId: 'match-1',
    canonical: '{"schema":"forref.watch-provision.v1"}',
    contentHash: hash,
    stage: 'CONFIG_PREPARED',
    writerDeviceId: writer,
    principalId: principal,
  );
}

MatchRecord _goal() {
  return MatchRecord(
    recordId: 'goal-1',
    matchId: 'match-1',
    recordKind: RecordKind.humanDetermination,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 2, 12),
    originDeviceId: 'phone-a',
    originSequence: 1,
    payload: GoalPayload(
      scoringTeamId: MatchTeamId('team-home'),
      captureIntentId: 'intent-1',
    ),
    integrity: const IntegrityMetadata(evidenceRefs: ['evidence-1']),
    authorityContext: const AuthorityContext(
      scope: v1AuthorityScope,
      principal: AuthorityPrincipal(principalId: 'ref-1'),
      activeCaptureDevice: ActiveCaptureDevice(deviceId: 'phone-a'),
      generation: AuthorityGeneration(value: 1),
    ),
  );
}
