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
    expect(
        parseWatchProvisionV1(
                canonical.replaceFirst('team-beta-001', 'team-alpha-001'))
            .reason,
        'teamId');
    expect(
        parseWatchProvisionV1(canonical.replaceFirst('team-alpha-001', 'HOME'))
            .reason,
        'teamId');
    expect(
        parseWatchProvisionV1(canonical.replaceFirst('team-beta-001', 'AWAY'))
            .reason,
        'teamId');
    expect(
        parseWatchProvisionV1(
                '${canonical.substring(0, canonical.length - 1)},"extra":1}')
            .reason,
        'schema');
    expect(
        parseWatchProvisionV1(
                canonical.replaceFirst('"generation":1', '"generation":2'))
            .reason,
        'generation');
  });

  test('a valid message stops at verified configuration', () {
    final store = MemoryWatchProvisionStore();
    final admission = WatchProvisionAdmission(store);
    final result = admission.receive(
      message: canonical,
      localInstallationId: fixture['localInstallationId']! as String,
      sportingRecordsExist: false,
    );
    expect(result.state, WatchProvisionState.watchConfigVerified);
    expect(result.saved, isFalse);
    expect(result.d1Certified, isFalse);
    expect(result.mayAppendSportingRecords, isFalse);
    expect(result.display, watchProvisionDisplayVerified);
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
    expect(again.state, WatchProvisionState.watchConfigVerified);
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
    expect(result.mayAppendSportingRecords, isFalse);
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
    final reopened = WatchProvisionAdmission(store).loadDurable(
      localInstallationId: installation,
      sportingRecordsExist: false,
    );
    expect(reopened.state, WatchProvisionState.watchConfigVerified);
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
    final offline = WatchProvisionAdmission(store).loadDurable(
      localInstallationId: installation,
      sportingRecordsExist: false,
    );
    expect(offline.state, WatchProvisionState.watchConfigVerified);
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
      facts: PhoneProvisionFacts(
          committedSportingRecords: 0, phoneOriginDeviceId: phone),
    );
    expect(self.state, WatchProvisionState.authorityConflict);
    expect(self.reason, 'phone-writer');
    expect(self.rootToCommit, isNull);

    final history = decidePhoneWatchProvision(
      message: canonical,
      facts: PhoneProvisionFacts(
          committedSportingRecords: 2, phoneOriginDeviceId: phone),
    );
    expect(history.reason, 'existing phone-authoritative history');
    expect(history.rootToCommit, isNull);
    expect(history.mayAppendSportingRecords, isFalse);
    expect(history.saved, isFalse);
  });

  test(
      'a clean phone preparation names the watch and writes no sporting payload',
      () {
    final decision = decidePhoneWatchProvision(
      message: canonical,
      facts: PhoneProvisionFacts(
        committedSportingRecords: 0,
        phoneOriginDeviceId: fixture['phoneOriginDeviceId']! as String,
      ),
    );
    expect(decision.state, WatchProvisionState.configPrepared);
    expect(decision.reason, 'phone-prepared');
    expect(decision.mayAppendSportingRecords, isFalse);
    expect(decision.rootToCommit, isNull);
    expect(decision.canonical.contains('GOAL'), isFalse);
  });

  test('transport unavailable leaves the phone prepared and unlocked', () {
    final facts = PhoneProvisionFacts(
      committedSportingRecords: 0,
      phoneOriginDeviceId: fixture['phoneOriginDeviceId']! as String,
    );
    final locked = decidePhoneAuthorityLock(
      message: canonical,
      facts: facts,
      receipt: null,
      transportAvailable: false,
    );
    expect(locked.state, WatchProvisionState.configPrepared);
    expect(locked.reason, 'transport-unavailable');
    expect(locked.rootToCommit, isNull);
  });

  test('an existing root does not make an invalid receipt durable', () {
    final facts = PhoneProvisionFacts(
      committedSportingRecords: 0,
      phoneOriginDeviceId: fixture['phoneOriginDeviceId']! as String,
      rootDeviceId: fixture['localInstallationId']! as String,
      rootPrincipalId: 'referee-001',
    );
    final invalid = decidePhoneAuthorityLock(
      message: canonical,
      facts: facts,
      receipt: WatchConfigVerifiedReceipt(
        contentHash: fixture['contentHash']! as String,
        writerDeviceId: fixture['localInstallationId']! as String,
        generation: 1,
        readBack: false,
      ),
      transportAvailable: true,
    );
    expect(invalid.state, WatchProvisionState.configPrepared);
    expect(invalid.reason, 'receipt-invalid');
    expect(invalid.rootToCommit, isNull);
    final repeated = decidePhoneAuthorityLock(
      message: canonical,
      facts: facts,
      receipt: WatchConfigVerifiedReceipt(
        contentHash: fixture['contentHash']! as String,
        writerDeviceId: fixture['localInstallationId']! as String,
        generation: 1,
        readBack: true,
      ),
      transportAvailable: true,
    );
    expect(repeated.state, WatchProvisionState.phoneAuthorityLocked);
    expect(repeated.reason, 'idempotent-lock');
    expect(repeated.rootToCommit, isNull);
  });

  test('activation never arrives so the watch cannot append', () {
    final store = MemoryWatchProvisionStore();
    final installation = fixture['localInstallationId']! as String;
    final verified = WatchProvisionAdmission(store).receive(
      message: canonical,
      localInstallationId: installation,
      sportingRecordsExist: false,
    );
    expect(verified.state, WatchProvisionState.watchConfigVerified);
    final waiting = WatchProvisionAdmission(store).activate(
      localInstallationId: installation,
      lockReceipt: null,
    );
    expect(waiting.state, WatchProvisionState.watchConfigVerified);
    expect(waiting.reason, 'activation-ack');
    expect(waiting.mayAppendSportingRecords, isFalse);
  });

  test('a lost activation acknowledgement retries once', () {
    final store = MemoryWatchProvisionStore();
    final installation = fixture['localInstallationId']! as String;
    final admission = WatchProvisionAdmission(store);
    admission.receive(
      message: canonical,
      localInstallationId: installation,
      sportingRecordsExist: false,
    );
    final lost = PhoneAuthorityLockReceipt(
      contentHash: fixture['contentHash']! as String,
      writerDeviceId: installation,
      generation: 1,
      durable: false,
    );
    expect(
      admission
          .activate(localInstallationId: installation, lockReceipt: lost)
          .state,
      WatchProvisionState.watchConfigVerified,
    );
    final durable = PhoneAuthorityLockReceipt(
      contentHash: fixture['contentHash']! as String,
      writerDeviceId: installation,
      generation: 1,
      durable: true,
    );
    final activated = admission.activate(
      localInstallationId: installation,
      lockReceipt: durable,
    );
    expect(activated.state, WatchProvisionState.watchActivated);
    expect(activated.authorityActivated, isTrue);
    expect(activated.captureStorageCertified, isFalse);
    expect(activated.authoritativeCaptureAdmitted, isFalse);
    expect(activated.mayAppendSportingRecords, isFalse);
    expect(activated.saved, isFalse);
    expect(activated.d1Certified, isFalse);
    final again = admission.activate(
      localInstallationId: installation,
      lockReceipt: durable,
    );
    expect(again.state, WatchProvisionState.watchActivated);
    expect(store.admission,
        stageMarker(fixture['contentHash']! as String, 'WATCH_ACTIVATED'));
  });

  test('restart before activation stays verified and after stays activated',
      () {
    final store = MemoryWatchProvisionStore();
    final installation = fixture['localInstallationId']! as String;
    WatchProvisionAdmission(store).receive(
      message: canonical,
      localInstallationId: installation,
      sportingRecordsExist: false,
    );
    final before = WatchProvisionAdmission(store).loadDurable(
      localInstallationId: installation,
      sportingRecordsExist: false,
    );
    expect(before.state, WatchProvisionState.watchConfigVerified);
    expect(before.mayAppendSportingRecords, isFalse);
    WatchProvisionAdmission(store).activate(
      localInstallationId: installation,
      lockReceipt: PhoneAuthorityLockReceipt(
        contentHash: fixture['contentHash']! as String,
        writerDeviceId: installation,
        generation: 1,
        durable: true,
      ),
    );
    final after = WatchProvisionAdmission(store).loadDurable(
      localInstallationId: installation,
      sportingRecordsExist: false,
    );
    expect(after.state, WatchProvisionState.watchActivated);
    expect(after.authorityActivated, isTrue);
    expect(after.authoritativeCaptureAdmitted, isFalse);
  });

  test('a changed installation identity fails closed and keeps the root', () {
    final store = MemoryWatchProvisionStore();
    final installation = fixture['localInstallationId']! as String;
    WatchProvisionAdmission(store).receive(
      message: canonical,
      localInstallationId: installation,
      sportingRecordsExist: false,
    );
    final changed = WatchProvisionAdmission(store).loadDurable(
      localInstallationId: '00000000-0000-4000-8000-000000000099',
      sportingRecordsExist: false,
    );
    expect(changed.state, WatchProvisionState.authorityConflict);
    expect(changed.reason, 'installation-identity');
    expect(changed.mayAppendSportingRecords, isFalse);
    expect(store.root, canonical);
  });

  test('a conflicting activation is refused', () {
    final store = MemoryWatchProvisionStore();
    final installation = fixture['localInstallationId']! as String;
    final admission = WatchProvisionAdmission(store);
    admission.receive(
      message: canonical,
      localInstallationId: installation,
      sportingRecordsExist: false,
    );
    final conflict = admission.activate(
      localInstallationId: installation,
      lockReceipt: const PhoneAuthorityLockReceipt(
        contentHash:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        writerDeviceId: '6f1e2d3c-4b5a-4678-9abc-def012345678',
        generation: 1,
        durable: true,
      ),
    );
    expect(conflict.state, WatchProvisionState.authorityConflict);
    expect(conflict.reason, 'conflicting-activation');
    expect(store.admission, contains('WATCH_CONFIG_VERIFIED'));
  });

  test('an incomplete verification can be finished without replacing the root',
      () {
    final store = MemoryWatchProvisionStore()..root = canonical;
    final installation = fixture['localInstallationId']! as String;
    final admission = WatchProvisionAdmission(store);
    final interrupted = admission.loadDurable(
      localInstallationId: installation,
      sportingRecordsExist: false,
    );
    expect(interrupted.reason, 'incomplete-verification');
    final finished = admission.receive(
      message: canonical,
      localInstallationId: installation,
      sportingRecordsExist: false,
    );
    expect(finished.state, WatchProvisionState.watchConfigVerified);
    expect(store.root, canonical);
  });

  test('a durable lock names the watch root only after a verified receipt', () {
    final facts = PhoneProvisionFacts(
      committedSportingRecords: 0,
      phoneOriginDeviceId: fixture['phoneOriginDeviceId']! as String,
    );
    final locked = decidePhoneAuthorityLock(
      message: canonical,
      facts: facts,
      receipt: WatchConfigVerifiedReceipt(
        contentHash: fixture['contentHash']! as String,
        writerDeviceId: fixture['localInstallationId']! as String,
        generation: 1,
        readBack: true,
      ),
      transportAvailable: true,
    );
    expect(locked.state, WatchProvisionState.phoneAuthorityLocked);
    expect(locked.rootToCommit!.deviceId, fixture['localInstallationId']);
    expect(locked.rootToCommit!.generation, 1);
    expect(locked.display, watchProvisionDisplayLocked);
    expect(locked.saved, isFalse);
    expect(locked.d1Certified, isFalse);
  });

  test('a verified message without readback does not lock authority', () {
    final facts = PhoneProvisionFacts(
      committedSportingRecords: 0,
      phoneOriginDeviceId: fixture['phoneOriginDeviceId']! as String,
    );
    expect(
      verifiedReceiptFromMessage(const {
        'type': watchProvisionVerifiedV1,
        'contentHash': 'abc',
        'writerDeviceId': '6f1e2d3c-4b5a-4678-9abc-def012345678',
        'generation': 1,
        'readBack': false,
      }),
      isNull,
    );
    final receipt = verifiedReceiptFromMessage({
      'type': watchProvisionVerifiedV1,
      'contentHash': fixture['contentHash']! as String,
      'writerDeviceId': fixture['localInstallationId']! as String,
      'generation': 1,
      'readBack': true,
    });
    final locked = decidePhoneAuthorityLock(
      message: canonical,
      facts: facts,
      receipt: receipt,
      transportAvailable: true,
    );
    expect(locked.rootToCommit, isNotNull);
    expect(
      activationDurable(const {
        'type': watchActivatedV1,
        'generation': 1,
        'durable': false,
      }),
      isFalse,
    );
  });
}
