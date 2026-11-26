import 'dart:convert';

import '../authority_root.dart';
import 'sha256_hex.dart';

/// Wire schema for a new watch-operated match. Generation is exactly 1.
const String watchProvisionSchemaV1 = 'forref.watch-provision.v1';

const String watchProvisionDisplayLocalReadback = 'LOCAL READBACK — D1 UNCERTIFIED';

/// Admission and failure states. [matchReady] still means local readback only.
enum WatchProvisionState {
  unprovisioned('UNPROVISIONED'),
  configReceived('CONFIG_RECEIVED'),
  rootVerified('ROOT_VERIFIED'),
  matchReady('MATCH_READY'),
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

  /// True only for the local admission state the contract names MATCH_READY.
  bool get matchReady => state == WatchProvisionState.matchReady;

  String get display {
    if (state == WatchProvisionState.matchReady) {
      return watchProvisionDisplayLocalReadback;
    }
    return state.wire;
  }
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

String admissionTextFor(String contentHash) => 'v=1\nhash=$contentHash\nstate=MATCH_READY\n';

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
  const authorityKeys = {'scope', 'principalId', 'generation', 'writerDeviceId'};
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
  if (principalId == null) return const WatchProvisionParse.invalid('principalId');
  final writer = authorityMap['writerDeviceId'];
  if (writer is! String || !_installationUuid.hasMatch(writer)) {
    return const WatchProvisionParse.invalid('writerDeviceId');
  }
  final teams = map['teams'];
  if (teams is! Map) return const WatchProvisionParse.invalid('teams');
  final teamMap = teams.cast<Object?, Object?>();
  if (teamMap.keys.length != 2 || !teamMap.keys.contains('home') || !teamMap.keys.contains('away')) {
    return const WatchProvisionParse.invalid('teams');
  }
  final home = _team(teamMap['home']);
  final away = _team(teamMap['away']);
  if (home == null || away == null) return const WatchProvisionParse.invalid('teamId');
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
  if (map.length != 2 || !map.containsKey('teamId') || !map.containsKey('name')) {
    return null;
  }
  final teamId = _id(map['teamId']);
  final name = map['name'];
  if (teamId == null) return null;
  final upper = teamId.toUpperCase();
  if (upper == 'HOME' || upper == 'AWAY') return null;
  if (name is! String || name.isEmpty || name.length > 80 || name != name.trim()) {
    return null;
  }
  return (teamId, name);
}

/// Watch admission. Success is read back from [store], never from the message alone.
final class WatchProvisionAdmission {
  WatchProvisionAdmission(this.store);

  final WatchProvisionStore store;

  WatchProvisionDecision loadDurable({required bool sportingRecordsExist}) {
    return _fromStore(sportingRecordsExist: sportingRecordsExist);
  }

  WatchProvisionDecision receive({
    required String message,
    required String localInstallationId,
    required bool sportingRecordsExist,
  }) {
    final stored = _fromStore(sportingRecordsExist: sportingRecordsExist);
    if (stored.state == WatchProvisionState.storageUnverified ||
        stored.state == WatchProvisionState.recoveryRequired) {
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
        state: WatchProvisionState.authorityConflict,
        trace: [WatchProvisionState.authorityConflict],
        reason: 'reprovision',
        canonical: stored.canonical,
        contentHash: stored.contentHash,
      );
    }
    if (stored.state == WatchProvisionState.matchReady && stored.canonical == canonical) {
      return stored;
    }
    final trace = <WatchProvisionState>[WatchProvisionState.configReceived];
    if (stored.canonical.isEmpty) {
      final wrote = store.writeRoot(canonical);
      if (wrote is! ProvisionSlotOk || wrote.text != canonical) {
        return WatchProvisionDecision(
          state: WatchProvisionState.storageUnverified,
          trace: [...trace, WatchProvisionState.storageUnverified],
          reason: 'root-write',
          canonical: canonical,
          contentHash: hash,
        );
      }
      final readBack = store.readRoot();
      if (readBack is! ProvisionSlotOk || readBack.text != canonical) {
        return WatchProvisionDecision(
          state: WatchProvisionState.storageUnverified,
          trace: [...trace, WatchProvisionState.storageUnverified],
          reason: 'root-readback',
          canonical: canonical,
          contentHash: hash,
        );
      }
    }
    trace.add(WatchProvisionState.rootVerified);
    final marker = admissionTextFor(hash);
    final admissionWrite = store.writeAdmission(marker);
    if (admissionWrite is! ProvisionSlotOk || admissionWrite.text != marker) {
      return WatchProvisionDecision(
        state: WatchProvisionState.rootVerified,
        trace: trace,
        reason: 'admission-write',
        canonical: canonical,
        contentHash: hash,
      );
    }
    final admissionRead = store.readAdmission();
    if (admissionRead is! ProvisionSlotOk || admissionRead.text != marker) {
      return WatchProvisionDecision(
        state: WatchProvisionState.rootVerified,
        trace: trace,
        reason: 'admission-readback',
        canonical: canonical,
        contentHash: hash,
      );
    }
    trace.add(WatchProvisionState.matchReady);
    return WatchProvisionDecision(
      state: WatchProvisionState.matchReady,
      trace: trace,
      canonical: canonical,
      contentHash: hash,
    );
  }

  WatchProvisionDecision _fromStore({required bool sportingRecordsExist}) {
    final root = store.readRoot();
    if (root is ProvisionSlotUnverified) {
      return const WatchProvisionDecision(
        state: WatchProvisionState.storageUnverified,
        trace: [WatchProvisionState.storageUnverified],
        reason: 'root-unverified',
      );
    }
    if (root is ProvisionSlotAbsent) {
      if (sportingRecordsExist) {
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
        state: WatchProvisionState.rootVerified,
        trace: const [WatchProvisionState.rootVerified],
        canonical: document.canonical,
        contentHash: document.contentHash,
      );
    }
    final marker = (admission as ProvisionSlotOk).text;
    if (marker != admissionTextFor(document.contentHash)) {
      return const WatchProvisionDecision(
        state: WatchProvisionState.recoveryRequired,
        trace: [WatchProvisionState.recoveryRequired],
        reason: 'admission-mismatch',
      );
    }
    return WatchProvisionDecision(
      state: WatchProvisionState.matchReady,
      trace: const [WatchProvisionState.matchReady],
      canonical: document.canonical,
      contentHash: document.contentHash,
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
      state: WatchProvisionState.configReceived,
      trace: const [WatchProvisionState.configReceived],
      reason: 'idempotent-phone-root',
      canonical: document.canonical,
      contentHash: document.contentHash,
    );
  }
  return WatchProvisionDecision(
    state: WatchProvisionState.configReceived,
    trace: const [WatchProvisionState.configReceived],
    reason: 'phone-prepared',
    canonical: document.canonical,
    contentHash: document.contentHash,
    rootToCommit: GenerationOneAuthorityRoot(
      matchId: document.matchId,
      principalId: document.principalId,
      deviceId: document.writerDeviceId,
    ),
  );
}
