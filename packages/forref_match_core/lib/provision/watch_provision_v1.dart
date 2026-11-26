import 'dart:convert';

import '../authority_root.dart';
import 'sha256_hex.dart';

/// Wire schema for a new watch-operated match. Generation is exactly 1.
const String watchProvisionSchemaV1 = 'forref.watch-provision.v1';

const String watchProvisionDisplayPrepared =
    'CONFIG PREPARED — AUTHORITY NOT LOCKED';
const String watchProvisionDisplayVerified = 'CONFIG VERIFIED — NOT ACTIVATED';
const String watchProvisionDisplayLocked =
    'PHONE AUTHORITY LOCKED — D1 UNCERTIFIED';
const String watchProvisionDisplayActivated =
    'WATCH ACTIVATED — D1 UNCERTIFIED';

/// Staged preparation and activation. None of these states is Saved or D1.
enum WatchProvisionState {
  unprovisioned('UNPROVISIONED'),
  configPrepared('CONFIG_PREPARED'),
  watchConfigVerified('WATCH_CONFIG_VERIFIED'),
  phoneAuthorityLocked('PHONE_AUTHORITY_LOCKED'),
  watchActivated('WATCH_ACTIVATED'),
  configInvalid('CONFIG_INVALID'),
  authorityConflict('AUTHORITY_CONFLICT'),
  storageUnverified('STORAGE_UNVERIFIED'),
  recoveryRequired('RECOVERY_REQUIRED');

  const WatchProvisionState(this.wire);

  final String wire;

  static WatchProvisionState? parse(String? wire) {
    for (final state in WatchProvisionState.values) {
      if (state.wire == wire) return state;
    }
    return null;
  }
}

final class WatchProvisionDocument {
  const WatchProvisionDocument({
    required this.matchId,
    required this.principalId,
    required this.writerDeviceId,
    required this.homeTeamId,
    required this.homeName,
    required this.awayTeamId,
    required this.awayName,
    required this.halfDurationMs,
    required this.provisionVersion,
  });

  final String matchId;
  final String principalId;
  final String writerDeviceId;
  final String homeTeamId;
  final String homeName;
  final String awayTeamId;
  final String awayName;
  final int halfDurationMs;
  final int provisionVersion;

  String get canonical => canonicalWatchProvisionV1(this);

  String get contentHash => sha256Hex(canonical);
}

final class WatchProvisionDecision {
  const WatchProvisionDecision({
    required this.state,
    required this.trace,
    this.reason = '',
    this.canonical = '',
    this.contentHash = '',
    this.rootToCommit,
  });

  final WatchProvisionState state;
  final List<WatchProvisionState> trace;
  final String reason;
  final String canonical;
  final String contentHash;

  /// Phone preparation lock. Null when the phone must not write a root.
  final GenerationOneAuthorityRoot? rootToCommit;

  /// A1 never claims Saved.
  bool get saved => false;

  /// A hash readback is not a power-loss certificate.
  bool get d1Certified => false;

  /// Sporting appends wait until activation is stored and can be reloaded.
  bool get mayAppendSportingRecords =>
      state == WatchProvisionState.watchActivated;

  String get display {
    return switch (state) {
      WatchProvisionState.configPrepared => watchProvisionDisplayPrepared,
      WatchProvisionState.watchConfigVerified => watchProvisionDisplayVerified,
      WatchProvisionState.phoneAuthorityLocked => watchProvisionDisplayLocked,
      WatchProvisionState.watchActivated => watchProvisionDisplayActivated,
      _ => state.wire,
    };
  }
}

/// Evidence the watch produced after a local readback. A message alone is not this.
final class WatchConfigVerifiedReceipt {
  const WatchConfigVerifiedReceipt({
    required this.contentHash,
    required this.writerDeviceId,
    required this.generation,
    required this.readBack,
  });

  final String contentHash;
  final String writerDeviceId;
  final int generation;
  final bool readBack;

  bool get usable =>
      readBack &&
      generation == 1 &&
      contentHash.isNotEmpty &&
      writerDeviceId.isNotEmpty;
}

/// Evidence the phone root commit finished. A lost ACK has [durable] false.
final class PhoneAuthorityLockReceipt {
  const PhoneAuthorityLockReceipt({
    required this.contentHash,
    required this.writerDeviceId,
    required this.generation,
    required this.durable,
  });

  final String contentHash;
  final String writerDeviceId;
  final int generation;
  final bool durable;

  bool get usable =>
      durable &&
      generation == 1 &&
      contentHash.isNotEmpty &&
      writerDeviceId.isNotEmpty;
}

sealed class ProvisionSlotRead {
  const ProvisionSlotRead();
}

final class ProvisionSlotAbsent extends ProvisionSlotRead {
  const ProvisionSlotAbsent();
}

final class ProvisionSlotOk extends ProvisionSlotRead {
  const ProvisionSlotOk(this.text);

  final String text;
}

final class ProvisionSlotUnverified extends ProvisionSlotRead {
  const ProvisionSlotUnverified();
}

abstract interface class WatchProvisionStore {
  ProvisionSlotRead readRoot();
  ProvisionSlotRead readAdmission();
  ProvisionSlotRead writeRoot(String canonical);
  ProvisionSlotRead writeAdmission(String text);
}

final class MemoryWatchProvisionStore implements WatchProvisionStore {
  String? root;
  String? admission;
  bool failRootWrite = false;
  bool failAdmissionWrite = false;
  bool unverifiedRootRead = false;

  @override
  ProvisionSlotRead readRoot() {
    if (unverifiedRootRead) return const ProvisionSlotUnverified();
    final text = root;
    if (text == null) return const ProvisionSlotAbsent();
    return ProvisionSlotOk(text);
  }

  @override
  ProvisionSlotRead readAdmission() {
    final text = admission;
    if (text == null) return const ProvisionSlotAbsent();
    return ProvisionSlotOk(text);
  }

  @override
  ProvisionSlotRead writeRoot(String canonical) {
    if (failRootWrite) return const ProvisionSlotUnverified();
    root = canonical;
    return ProvisionSlotOk(canonical);
  }

  @override
  ProvisionSlotRead writeAdmission(String text) {
    if (failAdmissionWrite) return const ProvisionSlotUnverified();
    admission = text;
    return ProvisionSlotOk(text);
  }
}

final class WatchProvisionParse {
  const WatchProvisionParse.ok(this.document) : reason = '';
  const WatchProvisionParse.invalid(this.reason) : document = null;

  final WatchProvisionDocument? document;
  final String reason;
}

String canonicalWatchProvisionV1(WatchProvisionDocument document) {
  return '{"schema":"$watchProvisionSchemaV1",'
      '"matchId":${jsonEncode(document.matchId)},'
      '"authority":{"scope":"MAIN_REFEREE",'
      '"principalId":${jsonEncode(document.principalId)},'
      '"generation":1,'
      '"writerDeviceId":${jsonEncode(document.writerDeviceId)}},'
      '"teams":{"home":{"teamId":${jsonEncode(document.homeTeamId)},'
      '"name":${jsonEncode(document.homeName)}},'
      '"away":{"teamId":${jsonEncode(document.awayTeamId)},'
      '"name":${jsonEncode(document.awayName)}}},'
      '"clock":{"halfDurationMs":${document.halfDurationMs}},'
      '"provisionVersion":${document.provisionVersion}}';
}

String stageMarker(String contentHash, String state) =>
    'v=1\nhash=$contentHash\nstate=$state\n';

WatchProvisionParse parseWatchProvisionV1(String raw) {
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return const WatchProvisionParse.invalid('schema');
  }
  if (decoded is! Map) return const WatchProvisionParse.invalid('schema');
  final map = decoded.cast<Object?, Object?>();
  const allowed = {
    'schema',
    'matchId',
    'authority',
    'teams',
    'clock',
    'provisionVersion',
  };
  if (map.keys.length != allowed.length || !map.keys.every(allowed.contains)) {
    return const WatchProvisionParse.invalid('schema');
  }
  if (map['schema'] != watchProvisionSchemaV1) {
    return const WatchProvisionParse.invalid('schema');
  }
  final matchId = _id(map['matchId']);
  if (matchId == null) return const WatchProvisionParse.invalid('matchId');
  final authority = map['authority'];
  if (authority is! Map) return const WatchProvisionParse.invalid('authority');
  final authorityMap = authority.cast<Object?, Object?>();
  const authorityKeys = {
    'scope',
    'principalId',
    'generation',
    'writerDeviceId'
  };
  if (authorityMap.keys.length != authorityKeys.length ||
      !authorityMap.keys.every(authorityKeys.contains)) {
    return const WatchProvisionParse.invalid('authority');
  }
  if (authorityMap['scope'] != 'MAIN_REFEREE') {
    return const WatchProvisionParse.invalid('scope');
  }
  if (authorityMap['generation'] != 1) {
    return const WatchProvisionParse.invalid('generation');
  }
  final principalId = _id(authorityMap['principalId']);
  if (principalId == null) {
    return const WatchProvisionParse.invalid('principalId');
  }
  final writer = authorityMap['writerDeviceId'];
  if (writer is! String || !_installationUuid.hasMatch(writer)) {
    return const WatchProvisionParse.invalid('writerDeviceId');
  }
  final teams = map['teams'];
  if (teams is! Map) return const WatchProvisionParse.invalid('teams');
  final teamMap = teams.cast<Object?, Object?>();
  if (teamMap.keys.length != 2 ||
      !teamMap.keys.contains('home') ||
      !teamMap.keys.contains('away')) {
    return const WatchProvisionParse.invalid('teams');
  }
  final home = _team(teamMap['home']);
  final away = _team(teamMap['away']);
  if (home == null || away == null) {
    return const WatchProvisionParse.invalid('teamId');
  }
  if (home.$1 == away.$1) return const WatchProvisionParse.invalid('teamId');
  final clock = map['clock'];
  if (clock is! Map) return const WatchProvisionParse.invalid('clock');
  final clockMap = clock.cast<Object?, Object?>();
  if (clockMap.length != 1 || !clockMap.containsKey('halfDurationMs')) {
    return const WatchProvisionParse.invalid('clock');
  }
  final half = clockMap['halfDurationMs'];
  if (half is! int || half <= 0 || half > 0x1fffffffffffff) {
    return const WatchProvisionParse.invalid('halfDurationMs');
  }
  if (map['provisionVersion'] != 1) {
    return const WatchProvisionParse.invalid('provisionVersion');
  }
  final document = WatchProvisionDocument(
    matchId: matchId,
    principalId: principalId,
    writerDeviceId: writer,
    homeTeamId: home.$1,
    homeName: home.$2,
    awayTeamId: away.$1,
    awayName: away.$2,
    halfDurationMs: half,
    provisionVersion: 1,
  );
  if (canonicalWatchProvisionV1(document) != raw.trim()) {
    return const WatchProvisionParse.invalid('canonical');
  }
  return WatchProvisionParse.ok(document);
}

final _installationUuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

String? _id(Object? value) {
  if (value is! String || value.isEmpty || value.length > 128) return null;
  if (value.contains(RegExp(r'[\u0000-\u001f]')) || value != value.trim()) {
    return null;
  }
  return value;
}

(String, String)? _team(Object? value) {
  if (value is! Map) return null;
  final map = value.cast<Object?, Object?>();
  if (map.length != 2 ||
      !map.containsKey('teamId') ||
      !map.containsKey('name')) {
    return null;
  }
  final teamId = _id(map['teamId']);
  final name = map['name'];
  if (teamId == null) return null;
  final upper = teamId.toUpperCase();
  if (upper == 'HOME' || upper == 'AWAY') return null;
  if (name is! String ||
      name.isEmpty ||
      name.length > 80 ||
      name != name.trim()) {
    return null;
  }
  return (teamId, name);
}

/// Watch admission. Success is read back from [store], never from the message alone.
final class WatchProvisionAdmission {
  WatchProvisionAdmission(this.store);

  final WatchProvisionStore store;

  WatchProvisionDecision loadDurable({
    required String localInstallationId,
    required bool sportingRecordsExist,
  }) {
    return _fromStore(
      localInstallationId: localInstallationId,
      sportingRecordsExist: sportingRecordsExist,
    );
  }

  /// Stores the configuration and stops at [WatchProvisionState.watchConfigVerified].
  ///
  /// [mayAppendSportingRecords] stays false. Activation is a later call.
  WatchProvisionDecision receive({
    required String message,
    required String localInstallationId,
    required bool sportingRecordsExist,
  }) {
    final stored = _fromStore(
      localInstallationId: localInstallationId,
      sportingRecordsExist: sportingRecordsExist,
    );
    final interrupted = stored.state == WatchProvisionState.storageUnverified &&
        stored.reason == 'incomplete-verification';
    if (!interrupted &&
        (stored.state == WatchProvisionState.storageUnverified ||
            stored.state == WatchProvisionState.recoveryRequired ||
            stored.state == WatchProvisionState.authorityConflict)) {
      return stored;
    }
    final parsed = parseWatchProvisionV1(message);
    final document = parsed.document;
    if (document == null) {
      return WatchProvisionDecision(
        state: WatchProvisionState.configInvalid,
        trace: [WatchProvisionState.configInvalid],
        reason: parsed.reason,
      );
    }
    if (document.writerDeviceId != localInstallationId) {
      return const WatchProvisionDecision(
        state: WatchProvisionState.authorityConflict,
        trace: [WatchProvisionState.authorityConflict],
        reason: 'writerDeviceId',
      );
    }
    final canonical = document.canonical;
    final hash = document.contentHash;
    if (stored.canonical.isNotEmpty && stored.canonical != canonical) {
      return WatchProvisionDecision(
        state: interrupted
            ? WatchProvisionState.storageUnverified
            : WatchProvisionState.authorityConflict,
        trace: [
          interrupted
              ? WatchProvisionState.storageUnverified
              : WatchProvisionState.authorityConflict,
        ],
        reason: interrupted ? 'incomplete-verification' : 'reprovision',
        canonical: stored.canonical,
        contentHash: stored.contentHash,
      );
    }
    if (stored.state == WatchProvisionState.watchActivated &&
        stored.canonical == canonical) {
      return stored;
    }
    if (stored.state == WatchProvisionState.watchConfigVerified &&
        stored.canonical == canonical) {
      return stored;
    }
    if (stored.canonical.isEmpty && !interrupted) {
      final wrote = store.writeRoot(canonical);
      if (wrote is! ProvisionSlotOk || wrote.text != canonical) {
        return WatchProvisionDecision(
          state: WatchProvisionState.storageUnverified,
          trace: const [WatchProvisionState.storageUnverified],
          reason: 'root-write',
          canonical: canonical,
          contentHash: hash,
        );
      }
      final readBack = store.readRoot();
      if (readBack is! ProvisionSlotOk || readBack.text != canonical) {
        return WatchProvisionDecision(
          state: WatchProvisionState.storageUnverified,
          trace: const [WatchProvisionState.storageUnverified],
          reason: 'root-readback',
          canonical: canonical,
          contentHash: hash,
        );
      }
    }
    final marker =
        stageMarker(hash, WatchProvisionState.watchConfigVerified.wire);
    final admissionWrite = store.writeAdmission(marker);
    if (admissionWrite is! ProvisionSlotOk || admissionWrite.text != marker) {
      return WatchProvisionDecision(
        state: WatchProvisionState.storageUnverified,
        trace: const [WatchProvisionState.storageUnverified],
        reason: 'verification-write',
        canonical: canonical,
        contentHash: hash,
      );
    }
    final admissionRead = store.readAdmission();
    if (admissionRead is! ProvisionSlotOk || admissionRead.text != marker) {
      return WatchProvisionDecision(
        state: WatchProvisionState.storageUnverified,
        trace: const [WatchProvisionState.storageUnverified],
        reason: 'verification-readback',
        canonical: canonical,
        contentHash: hash,
      );
    }
    return WatchProvisionDecision(
      state: WatchProvisionState.watchConfigVerified,
      trace: const [WatchProvisionState.watchConfigVerified],
      canonical: canonical,
      contentHash: hash,
    );
  }

  /// Activation requires a durable phone lock receipt. A lost ACK does not activate.
  WatchProvisionDecision activate({
    required String localInstallationId,
    required PhoneAuthorityLockReceipt? lockReceipt,
  }) {
    final stored = _fromStore(
      localInstallationId: localInstallationId,
      sportingRecordsExist: false,
    );
    if (stored.state == WatchProvisionState.watchActivated &&
        lockReceipt != null &&
        lockReceipt.usable &&
        lockReceipt.contentHash == stored.contentHash &&
        lockReceipt.writerDeviceId == localInstallationId) {
      return stored;
    }
    if (stored.state != WatchProvisionState.watchConfigVerified) {
      if (stored.state == WatchProvisionState.watchActivated) {
        return const WatchProvisionDecision(
          state: WatchProvisionState.authorityConflict,
          trace: [WatchProvisionState.authorityConflict],
          reason: 'conflicting-activation',
        );
      }
      return stored;
    }
    if (lockReceipt == null || !lockReceipt.usable) {
      return WatchProvisionDecision(
        state: WatchProvisionState.watchConfigVerified,
        trace: const [WatchProvisionState.watchConfigVerified],
        reason: 'activation-ack',
        canonical: stored.canonical,
        contentHash: stored.contentHash,
      );
    }
    if (lockReceipt.contentHash != stored.contentHash ||
        lockReceipt.writerDeviceId != localInstallationId) {
      return WatchProvisionDecision(
        state: WatchProvisionState.authorityConflict,
        trace: const [WatchProvisionState.authorityConflict],
        reason: 'conflicting-activation',
        canonical: stored.canonical,
        contentHash: stored.contentHash,
      );
    }
    final marker = stageMarker(
        stored.contentHash, WatchProvisionState.watchActivated.wire);
    final wrote = store.writeAdmission(marker);
    if (wrote is! ProvisionSlotOk || wrote.text != marker) {
      return WatchProvisionDecision(
        state: WatchProvisionState.watchConfigVerified,
        trace: const [WatchProvisionState.watchConfigVerified],
        reason: 'activation-write',
        canonical: stored.canonical,
        contentHash: stored.contentHash,
      );
    }
    final readBack = store.readAdmission();
    if (readBack is! ProvisionSlotOk || readBack.text != marker) {
      return WatchProvisionDecision(
        state: WatchProvisionState.watchConfigVerified,
        trace: const [WatchProvisionState.watchConfigVerified],
        reason: 'activation-readback',
        canonical: stored.canonical,
        contentHash: stored.contentHash,
      );
    }
    return WatchProvisionDecision(
      state: WatchProvisionState.watchActivated,
      trace: const [
        WatchProvisionState.watchConfigVerified,
        WatchProvisionState.watchActivated
      ],
      canonical: stored.canonical,
      contentHash: stored.contentHash,
    );
  }

  WatchProvisionDecision _fromStore({
    required String localInstallationId,
    required bool sportingRecordsExist,
  }) {
    final root = store.readRoot();
    if (root is ProvisionSlotUnverified) {
      return const WatchProvisionDecision(
        state: WatchProvisionState.storageUnverified,
        trace: [WatchProvisionState.storageUnverified],
        reason: 'root-unverified',
      );
    }
    if (root is ProvisionSlotAbsent) {
      final admission = store.readAdmission();
      if (admission is ProvisionSlotOk || sportingRecordsExist) {
        return const WatchProvisionDecision(
          state: WatchProvisionState.recoveryRequired,
          trace: [WatchProvisionState.recoveryRequired],
          reason: 'missing-root',
        );
      }
      return const WatchProvisionDecision(
        state: WatchProvisionState.unprovisioned,
        trace: [WatchProvisionState.unprovisioned],
      );
    }
    final text = (root as ProvisionSlotOk).text;
    final parsed = parseWatchProvisionV1(text);
    final document = parsed.document;
    if (document == null) {
      return const WatchProvisionDecision(
        state: WatchProvisionState.recoveryRequired,
        trace: [WatchProvisionState.recoveryRequired],
        reason: 'corrupt-root',
      );
    }
    if (document.writerDeviceId != localInstallationId) {
      return WatchProvisionDecision(
        state: WatchProvisionState.authorityConflict,
        trace: const [WatchProvisionState.authorityConflict],
        reason: 'installation-identity',
        canonical: document.canonical,
        contentHash: document.contentHash,
      );
    }
    final admission = store.readAdmission();
    if (admission is ProvisionSlotUnverified) {
      return const WatchProvisionDecision(
        state: WatchProvisionState.storageUnverified,
        trace: [WatchProvisionState.storageUnverified],
        reason: 'admission-unverified',
      );
    }
    if (admission is ProvisionSlotAbsent) {
      return WatchProvisionDecision(
        state: WatchProvisionState.storageUnverified,
        trace: const [WatchProvisionState.storageUnverified],
        reason: 'incomplete-verification',
        canonical: document.canonical,
        contentHash: document.contentHash,
      );
    }
    final marker = (admission as ProvisionSlotOk).text;
    final verified = stageMarker(
        document.contentHash, WatchProvisionState.watchConfigVerified.wire);
    final activated = stageMarker(
        document.contentHash, WatchProvisionState.watchActivated.wire);
    if (marker == activated) {
      return WatchProvisionDecision(
        state: WatchProvisionState.watchActivated,
        trace: const [WatchProvisionState.watchActivated],
        canonical: document.canonical,
        contentHash: document.contentHash,
      );
    }
    if (marker == verified) {
      return WatchProvisionDecision(
        state: WatchProvisionState.watchConfigVerified,
        trace: const [WatchProvisionState.watchConfigVerified],
        canonical: document.canonical,
        contentHash: document.contentHash,
      );
    }
    return const WatchProvisionDecision(
      state: WatchProvisionState.recoveryRequired,
      trace: [WatchProvisionState.recoveryRequired],
      reason: 'admission-mismatch',
    );
  }
}

/// Phone-side preparation. This does not append a sporting record and is not MATCH_READY.
final class PhoneProvisionFacts {
  const PhoneProvisionFacts({
    required this.committedSportingRecords,
    required this.phoneOriginDeviceId,
    this.rootDeviceId,
    this.rootPrincipalId,
    this.rootUnreadable = false,
  });

  final int committedSportingRecords;
  final String phoneOriginDeviceId;
  final String? rootDeviceId;
  final String? rootPrincipalId;
  final bool rootUnreadable;
}

WatchProvisionDecision decidePhoneWatchProvision({
  required String message,
  required PhoneProvisionFacts facts,
}) {
  if (facts.rootUnreadable) {
    return const WatchProvisionDecision(
      state: WatchProvisionState.recoveryRequired,
      trace: [WatchProvisionState.recoveryRequired],
      reason: 'phone-root-unreadable',
    );
  }
  final parsed = parseWatchProvisionV1(message);
  final document = parsed.document;
  if (document == null) {
    return WatchProvisionDecision(
      state: WatchProvisionState.configInvalid,
      trace: [WatchProvisionState.configInvalid],
      reason: parsed.reason,
    );
  }
  if (document.writerDeviceId == facts.phoneOriginDeviceId) {
    return const WatchProvisionDecision(
      state: WatchProvisionState.authorityConflict,
      trace: [WatchProvisionState.authorityConflict],
      reason: 'phone-writer',
    );
  }
  if (facts.committedSportingRecords > 0) {
    return const WatchProvisionDecision(
      state: WatchProvisionState.authorityConflict,
      trace: [WatchProvisionState.authorityConflict],
      reason: 'existing phone-authoritative history',
    );
  }
  final existingDevice = facts.rootDeviceId;
  if (existingDevice != null) {
    if (existingDevice != document.writerDeviceId ||
        facts.rootPrincipalId != document.principalId) {
      return const WatchProvisionDecision(
        state: WatchProvisionState.authorityConflict,
        trace: [WatchProvisionState.authorityConflict],
        reason: 'phone-root',
      );
    }
    return WatchProvisionDecision(
      state: WatchProvisionState.phoneAuthorityLocked,
      trace: const [WatchProvisionState.phoneAuthorityLocked],
      reason: 'idempotent-phone-root',
      canonical: document.canonical,
      contentHash: document.contentHash,
    );
  }
  return WatchProvisionDecision(
    state: WatchProvisionState.configPrepared,
    trace: const [WatchProvisionState.configPrepared],
    reason: 'phone-prepared',
    canonical: document.canonical,
    contentHash: document.contentHash,
  );
}

/// Locks the phone root only after a watch readback receipt and a live transport.
WatchProvisionDecision decidePhoneAuthorityLock({
  required String message,
  required PhoneProvisionFacts facts,
  required WatchConfigVerifiedReceipt? receipt,
  required bool transportAvailable,
}) {
  final prepared = decidePhoneWatchProvision(message: message, facts: facts);
  if (prepared.state == WatchProvisionState.authorityConflict ||
      prepared.state == WatchProvisionState.recoveryRequired ||
      prepared.state == WatchProvisionState.configInvalid ||
      prepared.state == WatchProvisionState.phoneAuthorityLocked) {
    return prepared;
  }
  if (!transportAvailable || receipt == null || !receipt.usable) {
    return WatchProvisionDecision(
      state: WatchProvisionState.configPrepared,
      trace: const [WatchProvisionState.configPrepared],
      reason: 'transport-unavailable',
      canonical: prepared.canonical,
      contentHash: prepared.contentHash,
    );
  }
  final document = parseWatchProvisionV1(message).document;
  if (document == null ||
      receipt.contentHash != document.contentHash ||
      receipt.writerDeviceId != document.writerDeviceId) {
    return const WatchProvisionDecision(
      state: WatchProvisionState.authorityConflict,
      trace: [WatchProvisionState.authorityConflict],
      reason: 'receipt-mismatch',
    );
  }
  if (facts.rootDeviceId == document.writerDeviceId &&
      facts.rootPrincipalId == document.principalId) {
    return WatchProvisionDecision(
      state: WatchProvisionState.phoneAuthorityLocked,
      trace: const [WatchProvisionState.phoneAuthorityLocked],
      reason: 'idempotent-lock',
      canonical: document.canonical,
      contentHash: document.contentHash,
    );
  }
  return WatchProvisionDecision(
    state: WatchProvisionState.phoneAuthorityLocked,
    trace: const [
      WatchProvisionState.configPrepared,
      WatchProvisionState.phoneAuthorityLocked,
    ],
    reason: 'lock',
    canonical: document.canonical,
    contentHash: document.contentHash,
    rootToCommit: GenerationOneAuthorityRoot(
      matchId: document.matchId,
      principalId: document.principalId,
      deviceId: document.writerDeviceId,
    ),
  );
}
