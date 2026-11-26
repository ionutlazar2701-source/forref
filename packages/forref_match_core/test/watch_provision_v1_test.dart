import 'dart:convert';
import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

void main() {
  late Map<String, Object?> fixture;
  late String canonical;

  setUp(() {
    fixture = jsonDecode(
      File('test/fixtures/watch_provision_v1.json').readAsStringSync(),
    ) as Map<String, Object?>;
    canonical = fixture['canonical']! as String;
  });

  test('sha256 matches the published abc vector', () {
    expect(
      sha256Hex('abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test('the canonical fixture parses and hashes the same bytes', () {
    final parsed = parseWatchProvisionV1(canonical);
    expect(parsed.document, isNotNull);
    expect(parsed.document!.canonical, canonical);
    expect(parsed.document!.contentHash, fixture['contentHash']);
    expect(sha256Hex(canonical), fixture['contentHash']);
    expect(parsed.document!.homeTeamId, isNot('HOME'));
    expect(parsed.document!.awayTeamId, isNot('AWAY'));
    expect(parsed.document!.homeTeamId, isNot(parsed.document!.awayTeamId));
  });

  test('missing, duplicated, and display-token ids are rejected', () {
    expect(parseWatchProvisionV1(canonical.replaceFirst('team-beta-001', 'team-alpha-001')).reason, 'teamId');
    expect(parseWatchProvisionV1(canonical.replaceFirst('team-alpha-001', 'HOME')).reason, 'teamId');
    expect(parseWatchProvisionV1(canonical.replaceFirst('team-beta-001', 'AWAY')).reason, 'teamId');
    expect(parseWatchProvisionV1('${canonical.substring(0, canonical.length - 1)},"extra":1}').reason, 'schema');
    expect(parseWatchProvisionV1(canonical.replaceFirst('"generation":1', '"generation":2')).reason, 'generation');
  });

  test('a valid message becomes local match-ready only after readback', () {
    final store = MemoryWatchProvisionStore();
    final admission = WatchProvisionAdmission(store);
    final result = admission.receive(
      message: canonical,
      localInstallationId: fixture['localInstallationId']! as String,
      sportingRecordsExist: false,
    );
    expect(result.trace.map((state) => state.wire).toList(), [
      'CONFIG_RECEIVED',
      'ROOT_VERIFIED',
      'MATCH_READY',
    ]);
    expect(result.saved, isFalse);
    expect(result.d1Certified, isFalse);
    expect(result.display, watchProvisionDisplayLocalReadback);
    expect(result.matchReady, isTrue);
    expect(store.root, canonical);
  });

  test('an identical provision replays and a conflicting one is refused', () {
    final store = MemoryWatchProvisionStore();
    final admission = WatchProvisionAdmission(store);
    final installation = fixture['localInstallationId']! as String;
    admission.receive(
      message: canonical,
      localInstallationId: installation,
      sportingRecordsExist: false,
    );
    final again = admission.receive(
      message: canonical,
      localInstallationId: installation,
      sportingRecordsExist: false,
    );
    expect(again.state, WatchProvisionState.matchReady);
    expect(store.root, canonical);
    final other = canonical.replaceFirst('North', 'East');
    final conflict = admission.receive(
      message: other,
      localInstallationId: installation,
      sportingRecordsExist: false,
    );
    expect(conflict.state, WatchProvisionState.authorityConflict);
    expect(conflict.reason, 'reprovision');
    expect(store.root, canonical);
  });

  test('the wrong installation identity writes nothing', () {
    final store = MemoryWatchProvisionStore();
    final result = WatchProvisionAdmission(store).receive(
      message: canonical,
      localInstallationId: '00000000-0000-4000-8000-000000000001',
      sportingRecordsExist: false,
    );
    expect(result.state, WatchProvisionState.authorityConflict);
    expect(result.reason, 'writerDeviceId');
    expect(store.root, isNull);
  });

  test('sporting history with a missing root is not recreated', () {
    final store = MemoryWatchProvisionStore();
    final result = WatchProvisionAdmission(store).receive(
      message: canonical,
      localInstallationId: fixture['localInstallationId']! as String,
      sportingRecordsExist: true,
    );
    expect(result.state, WatchProvisionState.recoveryRequired);
    expect(result.reason, 'missing-root');
    expect(store.root, isNull);
  });

  test('a corrupt root is not replaced', () {
    final store = MemoryWatchProvisionStore()..root = '{';
    final result = WatchProvisionAdmission(store).receive(
      message: canonical,
      localInstallationId: fixture['localInstallationId']! as String,
      sportingRecordsExist: false,
    );
    expect(result.state, WatchProvisionState.recoveryRequired);
    expect(result.reason, 'corrupt-root');
    expect(store.root, '{');
  });

  test('an interrupted root write is storage-unverified', () {
    final store = MemoryWatchProvisionStore()..failRootWrite = true;
    final result = WatchProvisionAdmission(store).receive(
      message: canonical,
      localInstallationId: fixture['localInstallationId']! as String,
      sportingRecordsExist: false,
    );
    expect(result.state, WatchProvisionState.storageUnverified);
    expect(result.matchReady, isFalse);
    expect(store.root, isNull);
  });

  test('reopen reads the durable root after the first object is discarded', () {
    final store = MemoryWatchProvisionStore();
    final installation = fixture['localInstallationId']! as String;
    WatchProvisionAdmission(store).receive(
      message: canonical,
      localInstallationId: installation,
      sportingRecordsExist: false,
    );
    final reopened = WatchProvisionAdmission(store).loadDurable(sportingRecordsExist: false);
    expect(reopened.state, WatchProvisionState.matchReady);
    expect(reopened.canonical, canonical);
    expect(reopened.saved, isFalse);
  });

  test('bluetooth loss after receipt keeps the stored configuration', () {
    final store = MemoryWatchProvisionStore();
    final installation = fixture['localInstallationId']! as String;
    WatchProvisionAdmission(store).receive(
      message: canonical,
      localInstallationId: installation,
      sportingRecordsExist: false,
    );
    final offline = WatchProvisionAdmission(store).loadDurable(sportingRecordsExist: false);
    expect(offline.state, WatchProvisionState.matchReady);
    expect(offline.canonical, canonical);
  });

  test('the phone refuses its own writer and existing sporting history', () {
    final phone = fixture['phoneOriginDeviceId']! as String;
    final asPhone = canonical.replaceFirst(
      fixture['localInstallationId']! as String,
      phone,
    );
    final self = decidePhoneWatchProvision(
      message: asPhone,
      facts: PhoneProvisionFacts(committedSportingRecords: 0, phoneOriginDeviceId: phone),
    );
    expect(self.state, WatchProvisionState.authorityConflict);
    expect(self.reason, 'phone-writer');
    expect(self.rootToCommit, isNull);

    final history = decidePhoneWatchProvision(
      message: canonical,
      facts: PhoneProvisionFacts(committedSportingRecords: 2, phoneOriginDeviceId: phone),
    );
    expect(history.reason, 'existing phone-authoritative history');
    expect(history.rootToCommit, isNull);
    expect(history.matchReady, isFalse);
    expect(history.saved, isFalse);
  });

  test('a clean phone preparation names the watch and writes no sporting payload', () {
    final decision = decidePhoneWatchProvision(
      message: canonical,
      facts: PhoneProvisionFacts(
        committedSportingRecords: 0,
        phoneOriginDeviceId: fixture['phoneOriginDeviceId']! as String,
      ),
    );
    expect(decision.state, WatchProvisionState.configReceived);
    expect(decision.reason, 'phone-prepared');
    expect(decision.matchReady, isFalse);
    expect(decision.rootToCommit!.deviceId, fixture['localInstallationId']);
    expect(decision.rootToCommit!.generation, 1);
    expect(decision.canonical.contains('GOAL'), isFalse);
  });
}
