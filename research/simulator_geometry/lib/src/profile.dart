import 'dart:convert';

/// Schema understood by this package. Other versions are rejected.
const int deviceProfileSchemaVersion = 1;

enum DeviceClass { phone, smartwatch }

enum ScreenShape { rectangle, round, roundedRectangle }

enum CapabilityStatus { supported, unsupported, unknown }

enum InputChannel {
  touchscreen,
  crown,
  physicalButtons,
  rotatingBezel,
  gestureInput,
  accessibilityInvocation,
}

enum EvidenceClassification { illustrative, factual }

enum ProvenanceSourceType {
  manufacturerStated,
  independentlyMeasured,
  userEntered,
  illustrative,
}

/// Stages this simulator is allowed to assign.
///
/// Platform proof and FORREF certification are intentionally absent.
enum SimulatorEvidenceStage { profiled, simulationReady }

enum EdgeClipping { none, circularMask, roundedMask }

final class KnownSize {
  const KnownSize.unknown()
      : known = false,
        width = null,
        height = null;

  const KnownSize.known({required double this.width, required double this.height})
      : known = true;

  final bool known;
  final double? width;
  final double? height;
}

final class Provenance {
  const Provenance({
    required this.sourceType,
    required this.sourceReference,
    this.observedDate,
    this.measurementMethod,
  });

  final ProvenanceSourceType sourceType;
  final String sourceReference;
  final String? observedDate;
  final String? measurementMethod;
}

final class SafeAreaSpec {
  const SafeAreaSpec.insets({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  }) : circularInset = null;

  const SafeAreaSpec.circular({required double this.circularInset})
      : left = 0,
        top = 0,
        right = 0,
        bottom = 0;

  final double left;
  final double top;
  final double right;
  final double bottom;
  final double? circularInset;

  bool get isCircular => circularInset != null;
}

final class DeviceProfile {
  const DeviceProfile({
    required this.schemaVersion,
    required this.profileId,
    required this.displayName,
    required this.manufacturer,
    required this.model,
    required this.deviceClass,
    required this.screenShape,
    required this.logicalWidth,
    required this.logicalHeight,
    required this.raster,
    required this.physicalMillimetres,
    required this.safeArea,
    required this.edgeClipping,
    required this.cornerRadius,
    required this.capabilities,
    required this.minimumLogicalSp,
    required this.provenance,
    required this.classification,
  });

  final int schemaVersion;
  final String profileId;
  final String displayName;
  final String? manufacturer;
  final String? model;
  final DeviceClass deviceClass;
  final ScreenShape screenShape;
  final double logicalWidth;
  final double logicalHeight;
  final KnownSize raster;
  final KnownSize physicalMillimetres;
  final SafeAreaSpec safeArea;
  final EdgeClipping edgeClipping;
  final double cornerRadius;
  final Map<InputChannel, CapabilityStatus> capabilities;
  final double minimumLogicalSp;
  final Provenance provenance;
  final EvidenceClassification classification;

  CapabilityStatus capability(InputChannel channel) {
    return capabilities[channel] ?? CapabilityStatus.unknown;
  }

  /// Touch may be forwarded only when the profile itself says supported.
  ///
  /// Unsupported and unknown both refuse silent touch. A research override
  /// lives in the shell and is not part of this claim.
  bool get touchClaimedSupported =>
      capability(InputChannel.touchscreen) == CapabilityStatus.supported;
}

final class ProfileViolation {
  const ProfileViolation(this.code, this.message);

  final String code;
  final String message;
}

sealed class ProfileParseResult {
  const ProfileParseResult();
}

final class ProfileAccepted extends ProfileParseResult {
  const ProfileAccepted(this.profile);

  final DeviceProfile profile;
}

final class ProfileRejected extends ProfileParseResult {
  const ProfileRejected(this.violations);

  final List<ProfileViolation> violations;

  bool hasCode(String code) => violations.any((item) => item.code == code);
}

const Set<String> _topLevelKeys = {
  'schemaVersion',
  'profileId',
  'displayName',
  'manufacturer',
  'model',
  'deviceClass',
  'screenShape',
  'logicalViewport',
  'rasterDimensions',
  'physicalDisplayDimensionsMm',
  'safeArea',
  'edgeClipping',
  'cornerRadius',
  'inputCapabilities',
  'typography',
  'provenance',
  'classification',
  'calibration',
};

const Set<String> _bannedKeys = {
  'certification',
  'forrefcertified',
  'platformproven',
  'evidencetier',
  'certified',
  'hardwareproven',
  'nativecrown',
  'simulatedtouchishardware',
};

ProfileParseResult parseProfile(String raw) {
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return const ProfileRejected([
      ProfileViolation('malformed-json', 'Profile JSON could not be parsed.'),
    ]);
  }
  if (decoded is! Map) {
    return const ProfileRejected([
      ProfileViolation('malformed-json', 'Profile JSON must be an object.'),
    ]);
  }
  final json = _asStringMap(decoded);
  final violations = <ProfileViolation>[];
  _scanBanned(json, violations);

  for (final key in json.keys) {
    if (!_topLevelKeys.contains(key)) {
      violations.add(
        ProfileViolation('unknown-field', 'Unknown profile field $key.'),
      );
    }
  }

  final schema = json['schemaVersion'];
  if (schema is! int || schema != deviceProfileSchemaVersion) {
    violations.add(
      const ProfileViolation(
        'unsupported-schema',
        'Only device profile schema version 1 is accepted.',
      ),
    );
  }

  final profileId = json['profileId'];
  final displayName = json['displayName'];
  if (profileId is! String || profileId.trim().isEmpty) {
    violations.add(
      const ProfileViolation('missing-identifier', 'profileId is required.'),
    );
  }
  if (displayName is! String || displayName.trim().isEmpty) {
    violations.add(
      const ProfileViolation('missing-identifier', 'displayName is required.'),
    );
  }

  final deviceClass = _enumDeviceClass(json['deviceClass'], violations);
  final shape = _enumShape(json['screenShape'], violations);
  final classification = _enumClassification(json['classification'], violations);
  final viewport = _readViewport(json['logicalViewport'], violations);
  final raster = _readKnownSize(
    json['rasterDimensions'],
    'rasterDimensions',
    violations,
  );
  final physical = _readKnownSize(
    json['physicalDisplayDimensionsMm'],
    'physicalDisplayDimensionsMm',
    violations,
  );
  final clipping = _enumClipping(json['edgeClipping'], violations);
  final radius = _readRadius(json['cornerRadius'], violations);
  final safe = _readSafe(json['safeArea'], violations);
  final capabilities = _readCapabilities(json['inputCapabilities'], violations);
  final typography = _readTypography(json['typography'], violations);
  final provenance = _readProvenance(json['provenance'], violations);
  _rejectHostCalibration(json, violations);

  if (shape == ScreenShape.round &&
      viewport != null &&
      viewport.$1 != viewport.$2) {
    violations.add(
      const ProfileViolation(
        'invalid-shape',
        'A round viewport bounding box must be square.',
      ),
    );
  }
  if (shape == ScreenShape.round && clipping != null && clipping != EdgeClipping.circularMask) {
    violations.add(
      const ProfileViolation(
        'invalid-shape',
        'A round screen uses a circular mask.',
      ),
    );
  }
  if (shape == ScreenShape.rectangle &&
      clipping != null &&
      clipping != EdgeClipping.none) {
    violations.add(
      const ProfileViolation(
        'invalid-shape',
        'A rectangular screen in this schema has no corner mask.',
      ),
    );
  }
  if (shape == ScreenShape.roundedRectangle &&
      clipping != null &&
      clipping != EdgeClipping.roundedMask) {
    violations.add(
      const ProfileViolation(
        'invalid-shape',
        'A rounded rectangle uses a rounded mask.',
      ),
    );
  }
  if (shape == ScreenShape.roundedRectangle && radius != null && viewport != null) {
    final limit = viewport.$1 < viewport.$2 ? viewport.$1 : viewport.$2;
    if (radius <= 0 || radius * 2 >= limit) {
      violations.add(
        const ProfileViolation(
          'invalid-shape',
          'Corner radius must be positive and leave a flat span.',
        ),
      );
    }
  }
  if (shape != ScreenShape.roundedRectangle && radius != null && radius != 0) {
    violations.add(
      const ProfileViolation(
        'invalid-shape',
        'Corner radius belongs on a rounded rectangle.',
      ),
    );
  }

  if (safe != null && viewport != null) {
    if (safe.isCircular) {
      if (shape != ScreenShape.round) {
        violations.add(
          const ProfileViolation(
            'impossible-safe-area',
            'A circular safe inset belongs on a round screen.',
          ),
        );
      }
      final inset = safe.circularInset ?? 0;
      if (inset < 0 || inset * 2 >= viewport.$1) {
        violations.add(
          const ProfileViolation(
            'impossible-safe-area',
            'Circular safe inset leaves no interactive area.',
          ),
        );
      }
    } else if (shape == ScreenShape.round) {
      violations.add(
        const ProfileViolation(
          'impossible-safe-area',
          'A round screen names a circular safe inset.',
        ),
      );
    } else {
      if (safe.left < 0 || safe.top < 0 || safe.right < 0 || safe.bottom < 0) {
        violations.add(
          const ProfileViolation(
            'impossible-safe-area',
            'Safe insets cannot be negative.',
          ),
        );
      }
      if (safe.left + safe.right >= viewport.$1 ||
          safe.top + safe.bottom >= viewport.$2) {
        violations.add(
          const ProfileViolation(
            'impossible-safe-area',
            'Safe insets cover the whole viewport.',
          ),
        );
      }
    }
  }

  if (classification == EvidenceClassification.illustrative &&
      physical != null &&
      physical.known) {
    violations.add(
      const ProfileViolation(
        'fabricated-physical-dimension',
        'An illustrative profile cannot carry physical millimetres.',
      ),
    );
  }
  if (classification == EvidenceClassification.factual &&
      provenance != null &&
      provenance.sourceType == ProvenanceSourceType.illustrative) {
    violations.add(
      const ProfileViolation(
        'missing-provenance',
        'A factual profile needs a non-illustrative provenance source.',
      ),
    );
  }
  if (classification == EvidenceClassification.illustrative &&
      provenance != null &&
      provenance.sourceType != ProvenanceSourceType.illustrative) {
    violations.add(
      const ProfileViolation(
        'missing-provenance',
        'An illustrative profile must say its source is illustrative.',
      ),
    );
  }
  if (physical != null &&
      physical.known &&
      provenance != null &&
      provenance.sourceType == ProvenanceSourceType.illustrative) {
    violations.add(
      const ProfileViolation(
        'fabricated-physical-dimension',
        'Illustrative provenance cannot support physical millimetres.',
      ),
    );
  }
  if (physical != null &&
      physical.known &&
      provenance != null &&
      provenance.sourceType == ProvenanceSourceType.independentlyMeasured &&
      (provenance.measurementMethod == null ||
          provenance.measurementMethod!.trim().isEmpty)) {
    violations.add(
      const ProfileViolation(
        'missing-provenance',
        'An independent measurement needs a measurement method.',
      ),
    );
  }

  if (violations.isNotEmpty ||
      deviceClass == null ||
      shape == null ||
      classification == null ||
      viewport == null ||
      raster == null ||
      physical == null ||
      clipping == null ||
      radius == null ||
      safe == null ||
      capabilities == null ||
      typography == null ||
      provenance == null ||
      profileId is! String ||
      displayName is! String) {
    return ProfileRejected(List.unmodifiable(violations));
  }

  return ProfileAccepted(
    DeviceProfile(
      schemaVersion: deviceProfileSchemaVersion,
      profileId: profileId,
      displayName: displayName,
      manufacturer: _optionalString(json['manufacturer']),
      model: _optionalString(json['model']),
      deviceClass: deviceClass,
      screenShape: shape,
      logicalWidth: viewport.$1,
      logicalHeight: viewport.$2,
      raster: raster,
      physicalMillimetres: physical,
      safeArea: safe,
      edgeClipping: clipping,
      cornerRadius: radius,
      capabilities: capabilities,
      minimumLogicalSp: typography,
      provenance: provenance,
      classification: classification,
    ),
  );
}

String encodeProfile(DeviceProfile profile) {
  return jsonEncode(_profileMap(profile));
}

Map<String, Object?> _profileMap(DeviceProfile profile) {
  return {
    'schemaVersion': profile.schemaVersion,
    'profileId': profile.profileId,
    'displayName': profile.displayName,
    'manufacturer': profile.manufacturer,
    'model': profile.model,
    'deviceClass': profile.deviceClass.name,
    'screenShape': profile.screenShape.name,
    'classification': profile.classification.name,
    'logicalViewport': {
      'width': profile.logicalWidth,
      'height': profile.logicalHeight,
    },
    'rasterDimensions': _sizeMap(profile.raster),
    'physicalDisplayDimensionsMm': _sizeMap(profile.physicalMillimetres),
    'safeArea': profile.safeArea.isCircular
        ? {
            'kind': 'circularInset',
            'inset': profile.safeArea.circularInset,
          }
        : {
            'kind': 'insets',
            'left': profile.safeArea.left,
            'top': profile.safeArea.top,
            'right': profile.safeArea.right,
            'bottom': profile.safeArea.bottom,
          },
    'edgeClipping': profile.edgeClipping.name,
    'cornerRadius': profile.cornerRadius,
    'inputCapabilities': {
      for (final channel in InputChannel.values)
        channel.name: profile.capability(channel).name,
    },
    'typography': {'minimumLogicalSp': profile.minimumLogicalSp},
    'provenance': {
      'sourceType': profile.provenance.sourceType.name,
      'sourceReference': profile.provenance.sourceReference,
      'observedDate': profile.provenance.observedDate,
      'measurementMethod': profile.provenance.measurementMethod,
    },
  };
}

Map<String, Object?> _sizeMap(KnownSize size) {
  if (!size.known) return {'known': false};
  return {'known': true, 'width': size.width, 'height': size.height};
}

void _rejectHostCalibration(Map<String, Object?> json, List<ProfileViolation> violations) {
  if (!json.containsKey('calibration')) return;
  violations.add(
    const ProfileViolation(
      'invalid-calibration',
      'A profile cannot carry host calibration proof.',
    ),
  );
}

void _scanBanned(Object? node, List<ProfileViolation> violations) {
  if (node is Map) {
    node.forEach((key, value) {
      final normalized = '$key'.toLowerCase().replaceAll('_', '').replaceAll('-', '');
      if (_bannedKeys.contains(normalized)) {
        violations.add(
          ProfileViolation(
            'certification-claim',
            'Self-asserted field $key is rejected.',
          ),
        );
      }
      _scanBanned(value, violations);
    });
    return;
  }
  if (node is List) {
    for (final item in node) {
      _scanBanned(item, violations);
    }
    return;
  }
  if (node is String) {
    final normalized = node.toLowerCase().replaceAll('_', '').replaceAll(' ', '').replaceAll('-', '');
    if (normalized == 'forrefcertified' || normalized == 'platformproven') {
      violations.add(
        const ProfileViolation(
          'certification-claim',
          'Self-asserted certification or platform-proven tier is rejected.',
        ),
      );
    }
  }
}

Map<String, Object?> _asStringMap(Map<dynamic, dynamic> value) {
  final out = <String, Object?>{};
  value.forEach((key, val) {
    out['$key'] = val as Object?;
  });
  return out;
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  if (value is String && value.trim().isNotEmpty) return value;
  return null;
}

double? _positive(Object? value) {
  if (value is! num) return null;
  final number = value.toDouble();
  if (!number.isFinite || number <= 0) return null;
  return number;
}

DeviceClass? _enumDeviceClass(Object? raw, List<ProfileViolation> violations) {
  if (raw == 'phone') return DeviceClass.phone;
  if (raw == 'smartwatch') return DeviceClass.smartwatch;
  violations.add(
    const ProfileViolation('invalid-shape', 'deviceClass must be phone or smartwatch.'),
  );
  return null;
}

ScreenShape? _enumShape(Object? raw, List<ProfileViolation> violations) {
  return switch (raw) {
    'rectangle' => ScreenShape.rectangle,
    'round' => ScreenShape.round,
    'roundedRectangle' => ScreenShape.roundedRectangle,
    _ => _failShape(violations),
  };
}

ScreenShape? _failShape(List<ProfileViolation> violations) {
  violations.add(
    const ProfileViolation(
      'invalid-shape',
      'screenShape must be rectangle, round, or roundedRectangle.',
    ),
  );
  return null;
}

EvidenceClassification? _enumClassification(
  Object? raw,
  List<ProfileViolation> violations,
) {
  if (raw == 'illustrative') return EvidenceClassification.illustrative;
  if (raw == 'factual') return EvidenceClassification.factual;
  violations.add(
    const ProfileViolation(
      'missing-provenance',
      'classification must be illustrative or factual.',
    ),
  );
  return null;
}

EdgeClipping? _enumClipping(Object? raw, List<ProfileViolation> violations) {
  return switch (raw) {
    'none' => EdgeClipping.none,
    'circularMask' => EdgeClipping.circularMask,
    'roundedMask' => EdgeClipping.roundedMask,
    _ => () {
        violations.add(
          const ProfileViolation('invalid-shape', 'edgeClipping is invalid.'),
        );
        return null;
      }(),
  };
}

(double, double)? _readViewport(Object? raw, List<ProfileViolation> violations) {
  if (raw is! Map) {
    violations.add(
      const ProfileViolation('non-positive-dimension', 'logicalViewport is required.'),
    );
    return null;
  }
  final map = _asStringMap(raw);
  final width = _positive(map['width']);
  final height = _positive(map['height']);
  if (width == null || height == null || width > 10000 || height > 10000) {
    violations.add(
      const ProfileViolation(
        'non-positive-dimension',
        'Logical viewport dimensions must be positive and bounded.',
      ),
    );
    return null;
  }
  return (width, height);
}

KnownSize? _readKnownSize(
  Object? raw,
  String label,
  List<ProfileViolation> violations,
) {
  if (raw is! Map) {
    violations.add(
      ProfileViolation('non-positive-dimension', '$label must say whether it is known.'),
    );
    return null;
  }
  final map = _asStringMap(raw);
  final known = map['known'];
  if (known is! bool) {
    violations.add(
      ProfileViolation('non-positive-dimension', '$label.known must be boolean.'),
    );
    return null;
  }
  if (!known) {
    if (map.containsKey('width') || map.containsKey('height')) {
      violations.add(
        ProfileViolation(
          'contradictory-capability',
          '$label says unknown and also carries numbers.',
        ),
      );
      return null;
    }
    return const KnownSize.unknown();
  }
  final width = _positive(map['width']);
  final height = _positive(map['height']);
  if (width == null || height == null) {
    violations.add(
      ProfileViolation(
        'non-positive-dimension',
        '$label numbers must be positive when known.',
      ),
    );
    return null;
  }
  return KnownSize.known(width: width, height: height);
}

double? _readRadius(Object? raw, List<ProfileViolation> violations) {
  if (raw == null) return 0;
  if (raw is! num) {
    violations.add(
      const ProfileViolation('invalid-shape', 'cornerRadius must be a number.'),
    );
    return null;
  }
  final value = raw.toDouble();
  if (!value.isFinite || value < 0) {
    violations.add(
      const ProfileViolation('invalid-shape', 'cornerRadius cannot be negative.'),
    );
    return null;
  }
  return value;
}

SafeAreaSpec? _readSafe(Object? raw, List<ProfileViolation> violations) {
  if (raw is! Map) {
    violations.add(
      const ProfileViolation('impossible-safe-area', 'safeArea is required.'),
    );
    return null;
  }
  final map = _asStringMap(raw);
  final kind = map['kind'];
  if (kind == 'circularInset') {
    final inset = map['inset'];
    if (inset is! num || !inset.toDouble().isFinite || inset < 0) {
      violations.add(
        const ProfileViolation(
          'impossible-safe-area',
          'Circular inset must be a non-negative number.',
        ),
      );
      return null;
    }
    return SafeAreaSpec.circular(circularInset: inset.toDouble());
  }
  if (kind == 'insets') {
    final left = map['left'];
    final top = map['top'];
    final right = map['right'];
    final bottom = map['bottom'];
    if (left is! num || top is! num || right is! num || bottom is! num) {
      violations.add(
        const ProfileViolation('impossible-safe-area', 'Insets must be numbers.'),
      );
      return null;
    }
    return SafeAreaSpec.insets(
      left: left.toDouble(),
      top: top.toDouble(),
      right: right.toDouble(),
      bottom: bottom.toDouble(),
    );
  }
  violations.add(
    const ProfileViolation('impossible-safe-area', 'safeArea.kind is invalid.'),
  );
  return null;
}

Map<InputChannel, CapabilityStatus>? _readCapabilities(
  Object? raw,
  List<ProfileViolation> violations,
) {
  if (raw is! Map) {
    violations.add(
      const ProfileViolation(
        'contradictory-capability',
        'inputCapabilities is required.',
      ),
    );
    return null;
  }
  final map = _asStringMap(raw);
  final parsed = <InputChannel, CapabilityStatus>{};
  for (final channel in InputChannel.values) {
    final value = map[channel.name];
    final status = switch (value) {
      'supported' => CapabilityStatus.supported,
      'unsupported' => CapabilityStatus.unsupported,
      'unknown' => CapabilityStatus.unknown,
      _ => null,
    };
    if (status == null) {
      violations.add(
        ProfileViolation(
          'contradictory-capability',
          '${channel.name} must be supported, unsupported, or unknown.',
        ),
      );
      return null;
    }
    parsed[channel] = status;
  }
  for (final key in map.keys) {
    final known = InputChannel.values.any((channel) => channel.name == key);
    if (!known) {
      violations.add(
        ProfileViolation(
          'contradictory-capability',
          'Unknown input capability $key.',
        ),
      );
    }
  }
  if (violations.any((item) => item.code == 'contradictory-capability')) {
    return null;
  }
  return parsed;
}

double? _readTypography(Object? raw, List<ProfileViolation> violations) {
  if (raw is! Map) {
    violations.add(
      const ProfileViolation('non-positive-dimension', 'typography is required.'),
    );
    return null;
  }
  final minimum = _positive(_asStringMap(raw)['minimumLogicalSp']);
  if (minimum == null) {
    violations.add(
      const ProfileViolation(
        'non-positive-dimension',
        'typography.minimumLogicalSp must be positive.',
      ),
    );
    return null;
  }
  return minimum;
}

Provenance? _readProvenance(Object? raw, List<ProfileViolation> violations) {
  if (raw is! Map) {
    violations.add(
      const ProfileViolation('missing-provenance', 'provenance is required.'),
    );
    return null;
  }
  final map = _asStringMap(raw);
  final source = switch (map['sourceType']) {
    'manufacturerStated' => ProvenanceSourceType.manufacturerStated,
    'independentlyMeasured' => ProvenanceSourceType.independentlyMeasured,
    'userEntered' => ProvenanceSourceType.userEntered,
    'illustrative' => ProvenanceSourceType.illustrative,
    _ => null,
  };
  if (source == null) {
    violations.add(
      const ProfileViolation('missing-provenance', 'provenance.sourceType is invalid.'),
    );
    return null;
  }
  final reference = map['sourceReference'];
  if (reference is! String || reference.trim().isEmpty) {
    violations.add(
      const ProfileViolation(
        'missing-provenance',
        'provenance.sourceReference is required.',
      ),
    );
    return null;
  }
  final observed = map['observedDate'];
  final method = map['measurementMethod'];
  if (observed != null && observed is! String) {
    violations.add(
      const ProfileViolation('missing-provenance', 'observedDate must be text or null.'),
    );
    return null;
  }
  if (method != null && method is! String) {
    violations.add(
      const ProfileViolation(
        'missing-provenance',
        'measurementMethod must be text or null.',
      ),
    );
    return null;
  }
  return Provenance(
    sourceType: source,
    sourceReference: reference,
    observedDate: observed is String ? observed : null,
    measurementMethod: method is String ? method : null,
  );
}

DeviceProfile _mustParse(String raw) {
  final result = parseProfile(raw);
  if (result is ProfileRejected) {
    final codes = result.violations.map((item) => '${item.code}:${item.message}').join('; ');
    throw StateError('Starter profile rejected: $codes');
  }
  return (result as ProfileAccepted).profile;
}

/// Generic research fixtures. Dimensions are illustrative, not measured products.
final DeviceProfile illustrativePhonePortrait = _mustParse(r'''
{
  "schemaVersion": 1,
  "profileId": "illustrative-phone-portrait",
  "displayName": "Illustrative phone portrait",
  "manufacturer": null,
  "model": null,
  "deviceClass": "phone",
  "screenShape": "rectangle",
  "classification": "illustrative",
  "logicalViewport": {"width": 390, "height": 844},
  "rasterDimensions": {"known": false},
  "physicalDisplayDimensionsMm": {"known": false},
  "safeArea": {"kind": "insets", "left": 8, "top": 8, "right": 8, "bottom": 8},
  "edgeClipping": "none",
  "cornerRadius": 0,
  "inputCapabilities": {
    "touchscreen": "supported",
    "crown": "unsupported",
    "physicalButtons": "unknown",
    "rotatingBezel": "unsupported",
    "gestureInput": "unknown",
    "accessibilityInvocation": "supported"
  },
  "typography": {"minimumLogicalSp": 14},
  "provenance": {
    "sourceType": "illustrative",
    "sourceReference": "FORREF research fixture. Dimensions are illustrative, not a measured product.",
    "observedDate": null,
    "measurementMethod": null
  }
}
''');

final DeviceProfile illustrativeRoundWatch = _mustParse(r'''
{
  "schemaVersion": 1,
  "profileId": "illustrative-round-watch",
  "displayName": "Illustrative round watch",
  "manufacturer": null,
  "model": null,
  "deviceClass": "smartwatch",
  "screenShape": "round",
  "classification": "illustrative",
  "logicalViewport": {"width": 240, "height": 240},
  "rasterDimensions": {"known": false},
  "physicalDisplayDimensionsMm": {"known": false},
  "safeArea": {"kind": "circularInset", "inset": 12},
  "edgeClipping": "circularMask",
  "cornerRadius": 0,
  "inputCapabilities": {
    "touchscreen": "supported",
    "crown": "unknown",
    "physicalButtons": "unknown",
    "rotatingBezel": "unknown",
    "gestureInput": "unknown",
    "accessibilityInvocation": "unknown"
  },
  "typography": {"minimumLogicalSp": 12},
  "provenance": {
    "sourceType": "illustrative",
    "sourceReference": "FORREF research fixture. Dimensions are illustrative, not a measured product.",
    "observedDate": null,
    "measurementMethod": null
  }
}
''');

final DeviceProfile illustrativeRectangularWatch = _mustParse(r'''
{
  "schemaVersion": 1,
  "profileId": "illustrative-rectangular-watch",
  "displayName": "Illustrative rectangular watch",
  "manufacturer": null,
  "model": null,
  "deviceClass": "smartwatch",
  "screenShape": "rectangle",
  "classification": "illustrative",
  "logicalViewport": {"width": 192, "height": 228},
  "rasterDimensions": {"known": false},
  "physicalDisplayDimensionsMm": {"known": false},
  "safeArea": {"kind": "insets", "left": 8, "top": 8, "right": 8, "bottom": 8},
  "edgeClipping": "none",
  "cornerRadius": 0,
  "inputCapabilities": {
    "touchscreen": "supported",
    "crown": "unknown",
    "physicalButtons": "unknown",
    "rotatingBezel": "unsupported",
    "gestureInput": "unknown",
    "accessibilityInvocation": "unknown"
  },
  "typography": {"minimumLogicalSp": 12},
  "provenance": {
    "sourceType": "illustrative",
    "sourceReference": "FORREF research fixture. Dimensions are illustrative, not a measured product.",
    "observedDate": null,
    "measurementMethod": null
  }
}
''');

final List<DeviceProfile> starterProfiles = [
  illustrativePhonePortrait,
  illustrativeRoundWatch,
  illustrativeRectangularWatch,
];
