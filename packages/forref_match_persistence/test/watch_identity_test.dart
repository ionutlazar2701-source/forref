import 'dart:io';
import 'dart:typed_data';

import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

const String _platformHex =
    '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('forref_watch_identity_');
  });

  tearDown(() async {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('sha256 of abc matches the published vector', () {
    expect(
      sha256Hex('abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test('the domain-separated digest is 32 bytes and rejects other alphabets',
      () {
    final digest = candidateDigestBytes(_platformHex);
    expect(digest.length, 32);
    expect(encodeDigestHex(digest), hasLength(64));
    expect(digestPreview(digest), hasLength(11));
    expect(
      () => candidateDigestBytes(_platformHex.toUpperCase()),
      throwsArgumentError,
    );
    expect(decodeDigestHex('abcd'), isNull);
    expect(decodeDigestHex('${encodeDigestHex(digest)}gg'), isNull);
  });

  test('prepare writes an intent and leaves a legacy stage unverified',
      () async {
    final file = File('${temp.path}/intent.sqlite');
    final store = SqliteDurableMatchStore.open(file);
    final saved = await store.saveWatchProvisionPrepared(_stage());
    expect(saved, isA<WatchProvisionStageSaved>());
    final events = await store.readWatchIdentityEvents('match-1');
    expect(events, hasLength(1));
    expect(events.single.eventKind, 'prepare_intent');
    expect(events.single.candidateDigest, isNull);
    expect(events.single.evidenceGrade, watchEvidenceTypedInstallation);
    final projection = await store.readWatchIdentityProjection('match-1');
    expect(projection.state, 'unverified-pre-registry');
    expect(projection.eligibleDigest, isNull);

    final again = await store.saveWatchProvisionPrepared(_stage());
    expect(again, isA<WatchProvisionStageSaved>());
    expect(await store.readWatchIdentityEvents('match-1'), hasLength(1));
    await store.close();

    final legacyFile = File('${temp.path}/legacy.sqlite');
    final raw = sqlite3.open(legacyFile.path);
    raw.execute('''
      CREATE TABLE watch_provision_stages (
        match_id TEXT PRIMARY KEY,
        canonical TEXT NOT NULL,
        content_hash TEXT NOT NULL,
        stage TEXT NOT NULL,
        writer_device_id TEXT NOT NULL,
        principal_id TEXT NOT NULL
      )
    ''');
    raw.execute(
      '''
      INSERT INTO watch_provision_stages (
        match_id, canonical, content_hash, stage, writer_device_id, principal_id
      ) VALUES ('match-1', '{"schema":"forref.watch-provision.v1"}', 'hash-1', 'CONFIG_PREPARED', 'watch-1', 'ref-1')
      ''',
    );
    raw.close();
    final legacy = SqliteDurableMatchStore.open(legacyFile);
    expect(
      (await legacy.readWatchIdentityProjection('match-1')).state,
      'unverified-pre-registry',
    );
    expect(await legacy.readWatchIdentityEvents('match-1'), isEmpty);
    final stage = await legacy.readWatchProvisionStage('match-1');
    expect(stage?.writerDeviceId, 'watch-1');
    expect(stage?.canonical, '{"schema":"forref.watch-provision.v1"}');
    await legacy.close();
  });

  test('an aborted prepare leaves no stage and no intent', () async {
    final store =
        SqliteDurableMatchStore.open(File('${temp.path}/abort.sqlite'));
    store.abortIdentityCommitForTest = () => throw StateError('abort');
    final refused = await store.saveWatchProvisionPrepared(_stage());
    expect(refused, isA<WatchProvisionStageRefused>());
    expect(await store.readWatchProvisionStage('match-1'), isNull);
    expect(await store.readWatchIdentityEvents('match-1'), isEmpty);
    await store.close();
  });

  test('a witness is eligible and a later installation is recovery-required',
      () async {
    final store =
        SqliteDurableMatchStore.open(File('${temp.path}/witness.sqlite'));
    await store.saveWatchProvisionPrepared(_stage());
    final before = await store.readWatchProvisionStage('match-1');
    final digest = candidateDigestBytes(_platformHex);
    final observed = await store.observeWatchWitness(
      matchId: 'match-1',
      principalId: 'ref-1',
      installationId: 'watch-1',
      requestId: 'req-witness',
      digest: digest,
      sourceBuilds: '1.0.31',
    );
    expect(observed, isA<WatchIdentityAppended>());
    expect((observed as WatchIdentityAppended).reason, 'observed');
    expect(
      (observed).event.evidenceGrade,
      watchEvidenceUnverifiedDevice,
    );
    final replay = await store.observeWatchWitness(
      matchId: 'match-1',
      principalId: 'ref-1',
      installationId: 'watch-1',
      requestId: 'req-witness',
      digest: digest,
      sourceBuilds: '1.0.31',
    );
    expect((replay as WatchIdentityAppended).reason, 'replay');
    expect(replay.event.eventId, observed.event.eventId);
    final changed = Uint8List.fromList(digest);
    changed[0] = changed[0] ^ 0xff;
    final conflict = await store.observeWatchWitness(
      matchId: 'match-1',
      principalId: 'ref-1',
      installationId: 'watch-1',
      requestId: 'req-witness',
      digest: changed,
      sourceBuilds: '1.0.31',
    );
    expect((conflict as WatchIdentityRefused).reason, 'replay-conflict');

    final other = await store.classifyWatchInstallation(
      matchId: 'match-1',
      principalId: 'ref-1',
      installationId: 'watch-2',
      requestId: 'req-candidate',
      candidateKind: 'platform_uuid',
      digest: digest,
      witnessMalformed: false,
      sourceBuilds: '1.0.31',
    );
    expect(other, isA<WatchIdentityAppended>());
    expect((other as WatchIdentityAppended).reason, 'recovery-required');
    expect(other.event.priorInstallationId, 'watch-1');
    final again = await store.classifyWatchInstallation(
      matchId: 'match-1',
      principalId: 'ref-1',
      installationId: 'watch-2',
      requestId: 'req-candidate',
      candidateKind: 'platform_uuid',
      digest: digest,
      witnessMalformed: false,
      sourceBuilds: '1.0.31',
    );
    expect((again as WatchIdentityAppended).event.eventId, other.event.eventId);

    final after = await store.readWatchProvisionStage('match-1');
    expect(after?.canonical, before?.canonical);
    expect(after?.contentHash, before?.contentHash);
    expect(after?.writerDeviceId, 'watch-1');
    expect(after?.principalId, 'ref-1');
    expect(await store.readGenerationOneAuthorityRoot('match-1'), isNull);

    final model = await store.classifyWatchInstallation(
      matchId: 'match-1',
      principalId: 'ref-1',
      installationId: 'watch-3',
      requestId: 'req-model',
      candidateKind: 'model_only',
      digest: null,
      witnessMalformed: false,
      sourceBuilds: '1.0.31',
    );
    expect((model as WatchIdentityRefused).reason,
        'identity-evidence-unavailable');
    final wrong = await store.classifyWatchInstallation(
      matchId: 'match-1',
      principalId: 'ref-1',
      installationId: 'watch-3',
      requestId: 'req-wrong',
      candidateKind: 'platform_uuid',
      digest: changed,
      witnessMalformed: false,
      sourceBuilds: '1.0.31',
    );
    expect((wrong as WatchIdentityRefused).reason, 'installation-conflict');
    final otherPrincipal = await store.classifyWatchInstallation(
      matchId: 'match-1',
      principalId: 'ref-2',
      installationId: 'watch-2',
      requestId: 'req-principal',
      candidateKind: 'platform_uuid',
      digest: digest,
      witnessMalformed: false,
      sourceBuilds: '1.0.31',
    );
    expect((otherPrincipal as WatchIdentityRefused).reason, 'principal');

    final auth = await store.authorizeInstallationEnrollment(
      matchId: 'match-1',
      principalId: 'ref-1',
      previousInstallationId: 'watch-1',
      installationId: 'watch-2',
    );
    expect((auth as WatchIdentityRefused).reason, 'authorization-unavailable');
    final kinds = [
      for (final event in await store.readWatchIdentityEvents('match-1'))
        event.eventKind,
    ];
    expect(
        kinds, ['prepare_intent', 'watch_witness_observed', 'candidate_seen']);
    await store.close();
  });

  test('identity events cannot be updated or deleted', () async {
    final file = File('${temp.path}/append.sqlite');
    final store = SqliteDurableMatchStore.open(file);
    await store.saveWatchProvisionPrepared(_stage());
    await store.close();
    final raw = sqlite3.open(file.path);
    expect(
      () => raw.execute(
        "UPDATE watch_identity_events SET evidence_grade = 'typed-installation'",
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(
      () => raw.execute('DELETE FROM watch_identity_events'),
      throwsA(isA<SqliteException>()),
    );
    raw.close();
  });

  test('cancel removes the stage and keeps the intent', () async {
    final store =
        SqliteDurableMatchStore.open(File('${temp.path}/cancel.sqlite'));
    await store.saveWatchProvisionPrepared(_stage());
    final cancelled = await store.cancelPreparedWatchProvision(
      matchId: 'match-1',
      contentHash: 'hash-1',
    );
    expect(cancelled, isA<WatchProvisionStageCancelled>());
    expect(await store.readWatchProvisionStage('match-1'), isNull);
    expect(await store.readWatchIdentityEvents('match-1'), hasLength(1));
    expect(
      (await store.readWatchIdentityProjection('match-1')).state,
      'absent',
    );
    await store.close();
  });
}

WatchProvisionPhoneStage _stage() {
  return const WatchProvisionPhoneStage(
    matchId: 'match-1',
    canonical: '{"schema":"forref.watch-provision.v1"}',
    contentHash: 'hash-1',
    stage: 'CONFIG_PREPARED',
    writerDeviceId: 'watch-1',
    principalId: 'ref-1',
  );
}
