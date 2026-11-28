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
    expect(events.single.digestVersion, watchCandidateDigestVersion);
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
      digestVersion: watchCandidateDigestVersion,
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
      digestVersion: watchCandidateDigestVersion,
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
      digestVersion: watchCandidateDigestVersion,
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
      digestVersion: watchCandidateDigestVersion,
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
      digestVersion: watchCandidateDigestVersion,
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
      digestVersion: watchCandidateDigestVersion,
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
      digestVersion: watchCandidateDigestVersion,
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
      digestVersion: watchCandidateDigestVersion,
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

  test('version 2 digests stay distinct from version 1 and from each other',
      () async {
    const hex32 = '00112233445566778899aabbccddeeff';
    final bytes = platformBytesV2(hex32.toUpperCase());
    expect(bytes, isNotNull);
    final digest = candidateDigestV2Bytes(bytes!);
    expect(
      encodeDigestHex(digest),
      '3be95c18a1a81de5a4165d603696e4fe42725cf7c1bc54b5807e1a6ad46358a0',
    );
    final opaque = List<int>.filled(32, 0x11);
    opaque[31] = 0x80;
    expect(platformBytesV2(String.fromCharCodes(opaque)), opaque);
    expect(
      encodeDigestHex(candidateDigestV2Bytes(opaque)),
      'cc618c08acccf2e1aeebcaa197faf07a188a72bf7de0088dfeb535372581f17a',
    );
    expect(platformBytesV2(hex32.substring(1)), isNull);
    expect(platformBytesV2('${hex32}aa'), isNull);
    expect(
        platformBytesV2(
            '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff'),
        isNull);

    final store = SqliteDurableMatchStore.open(File('${temp.path}/v2.sqlite'));
    await store.saveWatchProvisionPrepared(_stage());
    final before = await store.readWatchProvisionStage('match-1');
    final missing = await store.classifyWatchInstallation(
      matchId: 'match-1',
      principalId: 'ref-1',
      installationId: 'watch-2',
      requestId: 'req-late',
      candidateKind: 'platform_uuid',
      digest: digest,
      digestVersion: watchCandidateDigestVersionV2,
      witnessMalformed: false,
      sourceBuilds: '1.0.32',
    );
    expect((missing as WatchIdentityRefused).reason, 'installation');
    expect(
      (await store.readWatchIdentityEvents('match-1'))
          .map((event) => event.eventKind),
      ['prepare_intent'],
    );

    final observed = await store.observeWatchWitness(
      matchId: 'match-1',
      principalId: 'ref-1',
      installationId: 'watch-1',
      requestId: 'req-v2',
      digest: digest,
      digestVersion: watchCandidateDigestVersionV2,
      sourceBuilds: '1.0.32',
    );
    expect((observed as WatchIdentityAppended).reason, 'observed');
    expect(observed.event.digestVersion, watchCandidateDigestVersionV2);
    final projection = await store.readWatchIdentityProjection('match-1');
    expect(projection.state, 'witnessed');
    expect(projection.eligibleDigestVersion, watchCandidateDigestVersionV2);

    final replay = await store.observeWatchWitness(
      matchId: 'match-1',
      principalId: 'ref-1',
      installationId: 'watch-1',
      requestId: 'req-v2',
      digest: digest,
      digestVersion: watchCandidateDigestVersionV2,
      sourceBuilds: '1.0.32',
    );
    expect((replay as WatchIdentityAppended).event.eventId,
        observed.event.eventId);
    final crossed = await store.observeWatchWitness(
      matchId: 'match-1',
      principalId: 'ref-1',
      installationId: 'watch-1',
      requestId: 'req-v2',
      digest: digest,
      digestVersion: watchCandidateDigestVersion,
      sourceBuilds: '1.0.32',
    );
    expect((crossed as WatchIdentityRefused).reason, 'replay-conflict');

    final otherVersion = await store.classifyWatchInstallation(
      matchId: 'match-1',
      principalId: 'ref-1',
      installationId: 'watch-2',
      requestId: 'req-v1',
      candidateKind: 'platform_uuid',
      digest: digest,
      digestVersion: watchCandidateDigestVersion,
      witnessMalformed: false,
      sourceBuilds: '1.0.32',
    );
    expect(
        (otherVersion as WatchIdentityRefused).reason, 'installation-conflict');

    final recovered = await store.classifyWatchInstallation(
      matchId: 'match-1',
      principalId: 'ref-1',
      installationId: 'watch-2',
      requestId: 'req-v2-seen',
      candidateKind: 'platform_uuid',
      digest: digest,
      digestVersion: watchCandidateDigestVersionV2,
      witnessMalformed: false,
      sourceBuilds: '1.0.32',
    );
    expect((recovered as WatchIdentityAppended).reason, 'recovery-required');

    final second = candidateDigestV2Bytes(opaque);
    final conflict = await store.observeWatchWitness(
      matchId: 'match-1',
      principalId: 'ref-1',
      installationId: 'watch-1',
      requestId: 'req-other-fingerprint',
      digest: second,
      digestVersion: watchCandidateDigestVersionV2,
      sourceBuilds: '1.0.32',
    );
    expect((conflict as WatchIdentityAppended).reason, 'observed');
    expect(
      (await store.readWatchIdentityProjection('match-1')).state,
      'candidate-conflict',
    );
    final blocked = await store.classifyWatchInstallation(
      matchId: 'match-1',
      principalId: 'ref-1',
      installationId: 'watch-3',
      requestId: 'req-blocked',
      candidateKind: 'platform_uuid',
      digest: digest,
      digestVersion: watchCandidateDigestVersionV2,
      witnessMalformed: false,
      sourceBuilds: '1.0.32',
    );
    expect((blocked as WatchIdentityRefused).reason, 'candidate-conflict');

    final after = await store.readWatchProvisionStage('match-1');
    expect(after?.writerDeviceId, before?.writerDeviceId);
    expect(after?.canonical, before?.canonical);
    expect(after?.contentHash, before?.contentHash);
    expect(await store.readGenerationOneAuthorityRoot('match-1'), isNull);
    final auth = await store.authorizeInstallationEnrollment(
      matchId: 'match-1',
      principalId: 'ref-1',
      previousInstallationId: 'watch-1',
      installationId: 'watch-2',
    );
    expect((auth as WatchIdentityRefused).reason, 'authorization-unavailable');
    await store.close();
  });

  test('a version-1 registry is copied and still refuses updates', () async {
    final file = File('${temp.path}/legacy-events.sqlite');
    final raw = sqlite3.open(file.path);
    raw.execute('''
      CREATE TABLE watch_identity_events (
        event_sequence INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id TEXT NOT NULL UNIQUE,
        event_schema_version INTEGER NOT NULL CHECK (event_schema_version = 1),
        event_kind TEXT NOT NULL CHECK (event_kind IN (
          'prepare_intent', 'watch_witness_observed', 'candidate_seen'
        )),
        match_id TEXT NOT NULL,
        principal_id TEXT NOT NULL,
        prior_installation_id TEXT NULL,
        observed_installation_id TEXT NOT NULL,
        candidate_kind TEXT NOT NULL CHECK (candidate_kind IN (
          'platform_uuid', 'model_only', 'absent'
        )),
        candidate_digest BLOB NULL CHECK (
          candidate_digest IS NULL OR length(candidate_digest) = 32
        ),
        digest_version INTEGER NOT NULL CHECK (digest_version = 1),
        evidence_grade TEXT NOT NULL CHECK (evidence_grade IN (
          'typed-installation',
          'watch-message-observed/unverified-device-identity'
        )),
        channel_trace_id TEXT NULL,
        protocol_request_id TEXT NOT NULL,
        prior_event_id TEXT NULL,
        authorization_event_id TEXT NULL CHECK (authorization_event_id IS NULL),
        created_at_ms INTEGER NOT NULL,
        source_builds TEXT NOT NULL CHECK (length(source_builds) <= 160),
        CHECK (
          (event_kind = 'prepare_intent'
            AND candidate_kind = 'absent'
            AND candidate_digest IS NULL
            AND evidence_grade = 'typed-installation'
            AND prior_installation_id IS NULL)
          OR
          (event_kind = 'watch_witness_observed'
            AND candidate_kind = 'platform_uuid'
            AND length(candidate_digest) = 32
            AND evidence_grade = 'watch-message-observed/unverified-device-identity'
            AND prior_installation_id IS NULL)
          OR
          (event_kind = 'candidate_seen'
            AND candidate_kind = 'platform_uuid'
            AND length(candidate_digest) = 32
            AND evidence_grade = 'watch-message-observed/unverified-device-identity'
            AND prior_installation_id IS NOT NULL)
        )
      )
    ''');
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
    final legacyDigest = candidateDigestBytes(_platformHex);
    raw.execute(
      '''
      INSERT INTO watch_provision_stages (
        match_id, canonical, content_hash, stage, writer_device_id, principal_id
      ) VALUES ('match-1', '{"schema":"forref.watch-provision.v1"}', 'hash-1', 'CONFIG_PREPARED', 'watch-1', 'ref-1')
      ''',
    );
    raw.execute(
      '''
      INSERT INTO watch_identity_events (
        event_id, event_schema_version, event_kind, match_id, principal_id,
        prior_installation_id, observed_installation_id, candidate_kind,
        candidate_digest, digest_version, evidence_grade, channel_trace_id,
        protocol_request_id, prior_event_id, authorization_event_id,
        created_at_ms, source_builds
      ) VALUES (
        'event-legacy', 1, 'watch_witness_observed', 'match-1', 'ref-1',
        NULL, 'watch-1', 'platform_uuid', ?, 1,
        'watch-message-observed/unverified-device-identity', 'req-legacy',
        'req-legacy', NULL, NULL, 10, '1.0.31'
      )
      ''',
      [legacyDigest],
    );
    raw.close();

    final store = SqliteDurableMatchStore.open(file);
    final copied = await store.readWatchIdentityEvents('match-1');
    expect(copied, hasLength(1));
    expect(copied.single.eventId, 'event-legacy');
    expect(copied.single.digestVersion, watchCandidateDigestVersion);
    expect(encodeDigestHex(copied.single.candidateDigest!),
        encodeDigestHex(legacyDigest));
    expect(
      (await store.readWatchIdentityProjection('match-1'))
          .eligibleDigestVersion,
      watchCandidateDigestVersion,
    );
    final v2 = candidateDigestV2Bytes(
        platformBytesV2('00112233445566778899aabbccddeeff')!);
    final added = await store.observeWatchWitness(
      matchId: 'match-1',
      principalId: 'ref-1',
      installationId: 'watch-1',
      requestId: 'req-v2-new',
      digest: v2,
      digestVersion: watchCandidateDigestVersionV2,
      sourceBuilds: '1.0.32',
    );
    expect((added as WatchIdentityAppended).reason, 'observed');
    expect(added.event.eventSequence, greaterThan(copied.single.eventSequence));
    final still = await store.readWatchIdentityEvents('match-1');
    final legacy = still.firstWhere((event) => event.eventId == 'event-legacy');
    expect(encodeDigestHex(legacy.candidateDigest!),
        encodeDigestHex(legacyDigest));
    expect(legacy.digestVersion, watchCandidateDigestVersion);
    expect(
      (await store.readWatchProvisionStage('match-1'))?.writerDeviceId,
      'watch-1',
    );
    await store.close();

    final again = sqlite3.open(file.path);
    expect(
      () => again.execute('DELETE FROM watch_identity_events'),
      throwsA(isA<SqliteException>()),
    );
    expect(
      () => again.execute(
        "UPDATE watch_identity_events SET digest_version = 2 WHERE event_id = 'event-legacy'",
      ),
      throwsA(isA<SqliteException>()),
    );
    final sql = again
        .select(
          "SELECT sql FROM sqlite_master WHERE name = 'watch_identity_events'",
        )
        .single
        .columnAt(0) as String;
    expect(sql.contains('digest_version IN (1, 2)'), isTrue);
    again.close();
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
