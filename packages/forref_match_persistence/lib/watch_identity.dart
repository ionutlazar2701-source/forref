import 'dart:typed_data';

/// Domain-separated candidate digest, version 1.
///
/// The exact input is the UTF-8 bytes of `forref-candidate-v1:` followed by
/// 64 lowercase hex characters. SHA-256 of that string is a correlation
/// handle. It is not encryption, anonymity, possession proof, or device
/// authentication.
const String watchCandidateDigestDomain = 'forref-candidate-v1:';

/// Domain for a documented 32-byte platform string.
///
/// The exact input is the UTF-8 bytes of `forref-candidate-v2:` followed by
/// 32 raw identifier bytes. ASCII hex is lowercased first. Any other byte is
/// unchanged. This is not a reinterpretation of a version-1 digest.
const String watchCandidateDigestDomainV2 = 'forref-candidate-v2:';

const String watchWitnessSchema = 'forref.identity-witness.v1';

const String watchEvidenceTypedInstallation = 'typed-installation';

const String watchEvidenceUnverifiedDevice =
    'watch-message-observed/unverified-device-identity';

const int watchCandidateDigestVersion = 1;

const int watchCandidateDigestVersionV2 = 2;

/// SHA-256 of [text] as lowercase hex. Matches `utils/sha256_hex.js`.
String sha256Hex(String text) {
  return _hex(sha256Bytes(_utf8(text)));
}

/// Digest of a verified 64-character hex platform id.
///
/// [normalizedHex] must already be lowercase hex of length 64. This function
/// does not lowercase or accept any other alphabet.
Uint8List candidateDigestBytes(String normalizedHex) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalizedHex)) {
    throw ArgumentError('platform id is not lowercase hex64');
  }
  return sha256Bytes(_utf8('$watchCandidateDigestDomain$normalizedHex'));
}

/// Digest of a 32-byte platform id.
///
/// [platformBytes] is the normalized identifier: lowercase ASCII when every
/// byte is hex, otherwise the original bytes. The domain is
/// [watchCandidateDigestDomainV2].
Uint8List candidateDigestV2Bytes(List<int> platformBytes) {
  if (platformBytes.length != 32) {
    throw ArgumentError('platform id is not 32 bytes');
  }
  for (final byte in platformBytes) {
    if (byte < 0 || byte > 255) {
      throw ArgumentError('platform id byte is outside 0..255');
    }
  }
  final prefix = _utf8(watchCandidateDigestDomainV2);
  final body = Uint8List(prefix.length + 32);
  body.setRange(0, prefix.length, prefix);
  body.setRange(prefix.length, body.length, platformBytes);
  return sha256Bytes(body);
}

/// Normalized 32-byte form of a platform string, or null when it is not one.
///
/// A string of 32 code units, each in 0..255, is the documented shape. When
/// every byte is ASCII hex, the result is lowercase. Version-1 hex64 strings
/// are not accepted here.
List<int>? platformBytesV2(String value) {
  if (value.length != 32) return null;
  final bytes = List<int>.filled(32, 0);
  var hex = true;
  for (var i = 0; i < 32; i++) {
    final code = value.codeUnitAt(i);
    if (code > 255) return null;
    bytes[i] = code;
    final isHex = (code >= 0x30 && code <= 0x39) ||
        (code >= 0x61 && code <= 0x66) ||
        (code >= 0x41 && code <= 0x46);
    if (!isHex) hex = false;
  }
  if (!hex) return bytes;
  for (var i = 0; i < 32; i++) {
    final code = bytes[i];
    if (code >= 0x41 && code <= 0x46) bytes[i] = code + 0x20;
  }
  return bytes;
}

Uint8List? decodeDigestHex(String hex) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hex)) return null;
  final out = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

String encodeDigestHex(Uint8List digest) {
  if (digest.length != 32) {
    throw ArgumentError('digest must be 32 bytes');
  }
  return _hex(digest);
}

/// Log label. Identity comparison uses the full 32 bytes.
String digestPreview(Uint8List digest) {
  final hex = encodeDigestHex(digest);
  return '${hex.substring(0, 4)}...${hex.substring(60)}';
}

bool sameDigest(Uint8List? left, Uint8List? right) {
  if (left == null || right == null || left.length != right.length) {
    return false;
  }
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

/// One append-only identity event. The digest is absent on a prepare intent.
final class WatchIdentityEvent {
  const WatchIdentityEvent({
    required this.eventSequence,
    required this.eventId,
    required this.eventKind,
    required this.matchId,
    required this.principalId,
    required this.observedInstallationId,
    required this.priorInstallationId,
    required this.candidateKind,
    required this.candidateDigest,
    required this.digestVersion,
    required this.evidenceGrade,
    required this.protocolRequestId,
    required this.priorEventId,
  });

  final int eventSequence;
  final String eventId;
  final String eventKind;
  final String matchId;
  final String principalId;
  final String observedInstallationId;
  final String? priorInstallationId;
  final String candidateKind;
  final Uint8List? candidateDigest;
  final int digestVersion;
  final String evidenceGrade;
  final String protocolRequestId;
  final String? priorEventId;
}

/// Read-only fold. It does not invent a witness for an older stage.
final class WatchIdentityProjection {
  const WatchIdentityProjection({
    required this.state,
    required this.eligibleDigest,
    this.eligibleDigestVersion,
  });

  /// `absent`, `unverified-pre-registry`, `witnessed`, or `candidate-conflict`.
  final String state;
  final Uint8List? eligibleDigest;

  /// `1` or `2` when [eligibleDigest] is set. A version-1 digest is not a
  /// version-2 digest, including when the 32 hash bytes happen to match.
  final int? eligibleDigestVersion;
}

WatchIdentityProjection projectIdentity({
  required bool stagePresent,
  required String? stageWriterId,
  required List<WatchIdentityEvent> events,
}) {
  if (!stagePresent || stageWriterId == null || stageWriterId.isEmpty) {
    return const WatchIdentityProjection(state: 'absent', eligibleDigest: null);
  }
  final digests = <({int version, Uint8List digest})>[];
  for (final event in events) {
    if (event.eventKind != 'watch_witness_observed') continue;
    if (event.observedInstallationId != stageWriterId) continue;
    if (event.evidenceGrade != watchEvidenceUnverifiedDevice) continue;
    if (event.digestVersion != watchCandidateDigestVersion &&
        event.digestVersion != watchCandidateDigestVersionV2) {
      continue;
    }
    final digest = event.candidateDigest;
    if (digest == null || digest.length != 32) continue;
    final known = digests.any(
      (item) =>
          item.version == event.digestVersion &&
          sameDigest(item.digest, digest),
    );
    if (!known) {
      digests.add((version: event.digestVersion, digest: digest));
    }
  }
  if (digests.isEmpty) {
    return const WatchIdentityProjection(
      state: 'unverified-pre-registry',
      eligibleDigest: null,
    );
  }
  if (digests.length != 1) {
    return const WatchIdentityProjection(
      state: 'candidate-conflict',
      eligibleDigest: null,
    );
  }
  return WatchIdentityProjection(
    state: 'witnessed',
    eligibleDigest: digests.single.digest,
    eligibleDigestVersion: digests.single.version,
  );
}

sealed class WatchIdentityResult {
  const WatchIdentityResult();
}

final class WatchIdentityAppended extends WatchIdentityResult {
  const WatchIdentityAppended(this.event, {required this.reason});

  final WatchIdentityEvent event;
  final String reason;
}

final class WatchIdentityRefused extends WatchIdentityResult {
  const WatchIdentityRefused(this.reason);

  final String reason;
}

Uint8List sha256Bytes(List<int> bytes) {
  final padded = List<int>.from(bytes);
  final bitLength = bytes.length * 8;
  padded.add(0x80);
  while (padded.length % 64 != 56) {
    padded.add(0);
  }
  final high = bitLength ~/ 0x100000000;
  final low = bitLength & 0xffffffff;
  for (var shift = 24; shift >= 0; shift -= 8) {
    padded.add((high >> shift) & 0xff);
  }
  for (var shift = 24; shift >= 0; shift -= 8) {
    padded.add((low >> shift) & 0xff);
  }

  var h0 = 0x6a09e667;
  var h1 = 0xbb67ae85;
  var h2 = 0x3c6ef372;
  var h3 = 0xa54ff53a;
  var h4 = 0x510e527f;
  var h5 = 0x9b05688c;
  var h6 = 0x1f83d9ab;
  var h7 = 0x5be0cd19;
  final w = List<int>.filled(64, 0);
  for (var offset = 0; offset < padded.length; offset += 64) {
    for (var i = 0; i < 16; i++) {
      final j = offset + i * 4;
      w[i] = ((padded[j] << 24) |
              (padded[j + 1] << 16) |
              (padded[j + 2] << 8) |
              padded[j + 3]) &
          0xffffffff;
    }
    for (var i = 16; i < 64; i++) {
      final s0 = _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      final s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
    }
    var a = h0;
    var b = h1;
    var c = h2;
    var d = h3;
    var e = h4;
    var f = h5;
    var g = h6;
    var h = h7;
    for (var i = 0; i < 64; i++) {
      final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final ch = (e & f) ^ ((~e) & g);
      final temp1 = (h + s1 + ch + _k[i] + w[i]) & 0xffffffff;
      final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (s0 + maj) & 0xffffffff;
      h = g;
      g = f;
      f = e;
      e = (d + temp1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & 0xffffffff;
    }
    h0 = (h0 + a) & 0xffffffff;
    h1 = (h1 + b) & 0xffffffff;
    h2 = (h2 + c) & 0xffffffff;
    h3 = (h3 + d) & 0xffffffff;
    h4 = (h4 + e) & 0xffffffff;
    h5 = (h5 + f) & 0xffffffff;
    h6 = (h6 + g) & 0xffffffff;
    h7 = (h7 + h) & 0xffffffff;
  }
  final out = Uint8List(32);
  final words = [h0, h1, h2, h3, h4, h5, h6, h7];
  for (var i = 0; i < 8; i++) {
    out[i * 4] = (words[i] >> 24) & 0xff;
    out[i * 4 + 1] = (words[i] >> 16) & 0xff;
    out[i * 4 + 2] = (words[i] >> 8) & 0xff;
    out[i * 4 + 3] = words[i] & 0xff;
  }
  return out;
}

int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xffffffff;

List<int> _utf8(String text) {
  final out = <int>[];
  for (final rune in text.runes) {
    if (rune < 0x80) {
      out.add(rune);
    } else if (rune < 0x800) {
      out
        ..add(0xc0 | (rune >> 6))
        ..add(0x80 | (rune & 0x3f));
    } else if (rune < 0x10000) {
      out
        ..add(0xe0 | (rune >> 12))
        ..add(0x80 | ((rune >> 6) & 0x3f))
        ..add(0x80 | (rune & 0x3f));
    } else {
      out
        ..add(0xf0 | (rune >> 18))
        ..add(0x80 | ((rune >> 12) & 0x3f))
        ..add(0x80 | ((rune >> 6) & 0x3f))
        ..add(0x80 | (rune & 0x3f));
    }
  }
  return out;
}

String _hex(Uint8List bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

const List<int> _k = [
  0x428a2f98,
  0x71374491,
  0xb5c0fbcf,
  0xe9b5dba5,
  0x3956c25b,
  0x59f111f1,
  0x923f82a4,
  0xab1c5ed5,
  0xd807aa98,
  0x12835b01,
  0x243185be,
  0x550c7dc3,
  0x72be5d74,
  0x80deb1fe,
  0x9bdc06a7,
  0xc19bf174,
  0xe49b69c1,
  0xefbe4786,
  0x0fc19dc6,
  0x240ca1cc,
  0x2de92c6f,
  0x4a7484aa,
  0x5cb0a9dc,
  0x76f988da,
  0x983e5152,
  0xa831c66d,
  0xb00327c8,
  0xbf597fc7,
  0xc6e00bf3,
  0xd5a79147,
  0x06ca6351,
  0x14292967,
  0x27b70a85,
  0x2e1b2138,
  0x4d2c6dfc,
  0x53380d13,
  0x650a7354,
  0x766a0abb,
  0x81c2c92e,
  0x92722c85,
  0xa2bfe8a1,
  0xa81a664b,
  0xc24b8b70,
  0xc76c51a3,
  0xd192e819,
  0xd6990624,
  0xf40e3585,
  0x106aa070,
  0x19a4c116,
  0x1e376c08,
  0x2748774c,
  0x34b0bcb5,
  0x391c0cb3,
  0x4ed8aa4a,
  0x5b9cca4f,
  0x682e6ff3,
  0x748f82ee,
  0x78a5636f,
  0x84c87814,
  0x8cc70208,
  0x90befffa,
  0xa4506ceb,
  0xbef9a3f7,
  0xc67178f2,
];
