import 'dart:convert';
import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:uuid/uuid.dart';

/// Stable local capture identity for this phone installation.
///
/// Created once and reused across launches. This is not an account, not a
/// crew display name, and not a cloud principal.
final class PhoneCaptureIdentity {
  const PhoneCaptureIdentity({
    required this.originDeviceId,
    required this.authorityPrincipalId,
  });

  /// Initial generation until takeover semantics exist.
  static const initialAuthorityGeneration = 1;

  /// Domain clock contract pin currently available in this repository.
  static const domainClockContract = DomainContractVersion('domain-clock-v1');

  final String originDeviceId;
  final String authorityPrincipalId;

  CaptureContext contextFor(
    String matchId, {
    CompetitionRulesContext? competitionRulesContext,
  }) {
    return CaptureContext(
      matchId: matchId,
      originDeviceId: originDeviceId,
      authorityScope: v1AuthorityScope,
      authorityPrincipalId: authorityPrincipalId,
      authorityGeneration: initialAuthorityGeneration,
      projectionAuthorityGeneration: initialAuthorityGeneration,
      activeCaptureDeviceId: originDeviceId,
      domainContractVersion: domainClockContract,
      competitionRulesContext: competitionRulesContext,
    );
  }
}

/// Persists [PhoneCaptureIdentity] beside, but not inside, Match Memory.
final class PhoneCaptureIdentityStore {
  PhoneCaptureIdentityStore(Directory storageRoot)
      : _file = File('${storageRoot.path}/forref_capture_identity.json');

  final File _file;

  Future<PhoneCaptureIdentity> loadOrCreate() async {
    if (_file.existsSync()) {
      final decoded = jsonDecode(await _file.readAsString());
      if (decoded is Map) {
        final origin = decoded['originDeviceId'];
        final principal = decoded['authorityPrincipalId'];
        if (origin is String &&
            origin.isNotEmpty &&
            principal is String &&
            principal.isNotEmpty) {
          return PhoneCaptureIdentity(
            originDeviceId: origin,
            authorityPrincipalId: principal,
          );
        }
      }
      throw FormatException('Stored phone capture identity is invalid');
    }

    const uuid = Uuid();
    final identity = PhoneCaptureIdentity(
      originDeviceId: uuid.v4(),
      authorityPrincipalId: uuid.v4(),
    );
    if (!_file.parent.existsSync()) {
      _file.parent.createSync(recursive: true);
    }
    await _file.writeAsString(
      jsonEncode({
        'originDeviceId': identity.originDeviceId,
        'authorityPrincipalId': identity.authorityPrincipalId,
      }),
    );
    return identity;
  }
}
