import 'dart:convert';

import 'evidence.dart';
import 'profile.dart';

/// Schema for evidenced device profiles. Version 1 profiles stay on [parseProfile].
const int deviceProfileV2SchemaVersion = 2;

final class SourceRecord {
  const SourceRecord({
    required this.id,
    required this.url,
    required this.title,
    required this.retrieved,
    required this.note,
  });

  final String id;
  final String url;
  final String title;
  final String retrieved;
  final String note;
}

final class ProfileIdentity {
  const ProfileIdentity({
    required this.profileId,
    required this.manufacturer,
    required this.family,
    required this.model,
    required this.variant,
    required this.deviceClass,
    required this.platformFamily,
  });

  final String profileId;
  final EvidenceFact<String> manufacturer;
  final EvidenceFact<String> family;
  final EvidenceFact<String> model;
  final EvidenceFact<String> variant;
  final DeviceClass deviceClass;
  final EvidenceFact<String> platformFamily;
}

final class CaseFacts {
  const CaseFacts({
    required this.widthMm,
    required this.heightMm,
    required this.depthMm,
    required this.shape,
  });

  final EvidenceFact<double> widthMm;
  final EvidenceFact<double> heightMm;
  final EvidenceFact<double> depthMm;
  final EvidenceFact<ScreenShape> shape;
}

final class SafeAreaFact {
  const SafeAreaFact.unknown({
    this.sourceIds = const [],
    this.uncertainty,
  }) : status = FactStatus.unknown,
       value = null,
       derivation = null;

  const SafeAreaFact.known({
    required SafeAreaSpec this.value,
    required this.sourceIds,
    this.uncertainty,
  }) : status = FactStatus.known,
       derivation = null;

  const SafeAreaFact.derived({
    required SafeAreaSpec this.value,
    required this.sourceIds,
    required String this.derivation,
    this.uncertainty,
  }) : status = FactStatus.derived;

  final FactStatus status;
  final SafeAreaSpec? value;
  final List<String> sourceIds;
  final String? derivation;
  final String? uncertainty;
}

final class ShellApertureFact {
  const ShellApertureFact.unknown({
    this.sourceIds = const [],
    this.uncertainty,
  }) : status = FactStatus.unknown,
       value = null,
       derivation = null;

  const ShellApertureFact.known({
    required this.value,
    required this.sourceIds,
    this.uncertainty,
  }) : status = FactStatus.known,
       derivation = null;

  const ShellApertureFact.derived({
    required this.value,
    required this.sourceIds,
    required String this.derivation,
    this.uncertainty,
  }) : status = FactStatus.derived;

  final FactStatus status;
  final Map<String, Object?>? value;
  final List<String> sourceIds;
  final String? derivation;
  final String? uncertainty;
}

final class DisplayFacts {
  const DisplayFacts({
    required this.shape,
    required this.rasterWidth,
    required this.rasterHeight,
    required this.widthMm,
    required this.heightMm,
    required this.diagonalInches,
    required this.ppi,
    required this.cornerRadiusPx,
    required this.nativeLogicalWidth,
    required this.nativeLogicalHeight,
    required this.designWidth,
    required this.designHeight,
    required this.designBasis,
    required this.safeArea,
    required this.shellAperture,
  });

  final EvidenceFact<ScreenShape> shape;
  final EvidenceFact<double> rasterWidth;
  final EvidenceFact<double> rasterHeight;
  final EvidenceFact<double> widthMm;
  final EvidenceFact<double> heightMm;
  final EvidenceFact<double> diagonalInches;
  final EvidenceFact<double> ppi;
  final EvidenceFact<double> cornerRadiusPx;
  final EvidenceFact<double> nativeLogicalWidth;
  final EvidenceFact<double> nativeLogicalHeight;
  final EvidenceFact<double> designWidth;
  final EvidenceFact<double> designHeight;
  final EvidenceFact<String> designBasis;
  final SafeAreaFact safeArea;
  final ShellApertureFact shellAperture;
}

final class ControlFacts {
  const ControlFacts({
    required this.touchscreen,
    required this.crown,
    required this.crownRotation,
    required this.crownPress,
    required this.physicalButtons,
    required this.rotatingBezel,
    required this.gestureInput,
    required this.haptics,
  });

  final ControlFact touchscreen;
  final ControlFact crown;
  final ControlFact crownRotation;
  final ControlFact crownPress;
  final ControlFact physicalButtons;
  final ControlFact rotatingBezel;
  final ControlFact gestureInput;
  final ControlFact haptics;

  List<ControlFact> get all => [
    touchscreen,
    crown,
    crownRotation,
    crownPress,
    physicalButtons,
    rotatingBezel,
    gestureInput,
    haptics,
  ];
}

final class DeviceProfileV2 {
  const DeviceProfileV2({
    required this.schemaVersion,
    required this.identity,
    required this.caseFacts,
    required this.display,
    required this.controls,
    required this.shellReference,
    required this.sources,
  });

  final int schemaVersion;
  final ProfileIdentity identity;
  final CaseFacts caseFacts;
  final DisplayFacts display;
  final ControlFacts controls;
  final EvidenceFact<String> shellReference;
  final List<SourceRecord> sources;

  SourceRecord? sourceById(String id) {
    for (final source in sources) {
      if (source.id == id) return source;
    }
    return null;
  }
}

/// Computed by the simulator. A profile document cannot set this.
///
/// Simulation-ready requires a code-linked shell manifest and an aperture
/// host. A known aperture value in JSON is not enough.
SimulatorEvidenceStage profileV2EvidenceStage(
  DeviceProfileV2 profile, {
  bool shellManifestLinked = false,
  bool apertureHostImplemented = false,
}) {
  final apertureKnown = profile.display.shellAperture.status == FactStatus.known &&
      profile.display.shellAperture.value != null;
  if (shellManifestLinked && apertureHostImplemented && apertureKnown) {
    return SimulatorEvidenceStage.simulationReady;
  }
  return SimulatorEvidenceStage.profiled;
}

sealed class ProfileV2ParseResult {
  const ProfileV2ParseResult();
}

final class ProfileV2Accepted extends ProfileV2ParseResult {
  const ProfileV2Accepted(this.profile);

  final DeviceProfileV2 profile;
}

final class ProfileV2Rejected extends ProfileV2ParseResult {
  const ProfileV2Rejected(this.violations);

  final List<ProfileViolation> violations;

  bool hasCode(String code) => violations.any((item) => item.code == code);
}

const Set<String> _bannedKeys = {
  'certification',
  'forrefcertified',
  'platformproven',
  'evidencetier',
  'certified',
  'hardwareproven',
  'nativecrown',
  'simulatedtouchishardware',
  'evidencestage',
  'simulationready',
  'forrefcertifiedstage',
};

const Set<String> _topLevelKeys = {
  'schemaVersion',
  'identity',
  'case',
  'display',
  'controls',
  'shellReference',
  'sources',
};

const Set<String> _factKeys = {
  'status',
  'value',
  'sourceIds',
  'derivation',
  'uncertainty',
};

const Set<String> _controlKeys = {
  'availability',
  'sourceIds',
  'uncertainty',
  'appMaySimulate',
  'count',
};

ProfileV2ParseResult parseProfileV2(String raw) {
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return const ProfileV2Rejected([
      ProfileViolation('malformed-json', 'Profile JSON could not be parsed.'),
    ]);
  }
  if (decoded is! Map) {
    return const ProfileV2Rejected([
      ProfileViolation('malformed-json', 'Profile JSON must be an object.'),
    ]);
  }
  final json = _stringMap(decoded);
  final violations = <ProfileViolation>[];
  _scanBanned(json, violations);
  _rejectUnknownKeys(json, _topLevelKeys, violations, 'profile');

  final schema = json['schemaVersion'];
  if (schema is! int || schema != deviceProfileV2SchemaVersion) {
    violations.add(
      const ProfileViolation(
        'unsupported-schema',
        'Only device profile schema version 2 is accepted here.',
      ),
    );
  }

  final sources = _readSources(json['sources'], violations);
  final knownSourceIds = <String>{
    if (sources != null) ...sources.map((source) => source.id),
  };
  final identity = _readIdentity(json['identity'], knownSourceIds, violations);
  final caseFacts = _readCase(json['case'], knownSourceIds, violations);
  final display = _readDisplay(json['display'], knownSourceIds, violations);
  final controls = _readControls(json['controls'], knownSourceIds, violations);
  final shellReference = _readStringFact(
    json['shellReference'],
    'shellReference',
    knownSourceIds,
    violations,
  );

  if (violations.isNotEmpty ||
      identity == null ||
      caseFacts == null ||
      display == null ||
      controls == null ||
      shellReference == null ||
      sources == null) {
    return ProfileV2Rejected(List.unmodifiable(violations));
  }

  return ProfileV2Accepted(
    DeviceProfileV2(
      schemaVersion: deviceProfileV2SchemaVersion,
      identity: identity,
      caseFacts: caseFacts,
      display: display,
      controls: controls,
      shellReference: shellReference,
      sources: sources,
    ),
  );
}

ProfileIdentity? _readIdentity(
  Object? raw,
  Set<String> sourceIds,
  List<ProfileViolation> violations,
) {
  final map = _expectMap(raw, 'identity', violations);
  if (map == null) return null;
  _rejectUnknownKeys(map, {
    'profileId',
    'manufacturer',
    'family',
    'model',
    'variant',
    'deviceClass',
    'platformFamily',
  }, violations, 'identity');
  final profileId = map['profileId'];
  if (profileId is! String || !_profileId.hasMatch(profileId)) {
    violations.add(
      const ProfileViolation(
        'missing-identifier',
        'profileId must be a lowercase hyphenated identifier.',
      ),
    );
  }
  final deviceClass = switch (map['deviceClass']) {
    'phone' => DeviceClass.phone,
    'smartwatch' => DeviceClass.smartwatch,
    _ => null,
  };
  if (deviceClass == null) {
    violations.add(
      const ProfileViolation(
        'invalid-shape',
        'deviceClass must be phone or smartwatch.',
      ),
    );
  }
  final manufacturer = _readStringFact(
    map['manufacturer'],
    'manufacturer',
    sourceIds,
    violations,
  );
  final family = _readStringFact(map['family'], 'family', sourceIds, violations);
  final model = _readStringFact(map['model'], 'model', sourceIds, violations);
  final variant = _readStringFact(map['variant'], 'variant', sourceIds, violations);
  final platform = _readStringFact(
    map['platformFamily'],
    'platformFamily',
    sourceIds,
    violations,
  );
  if (profileId is! String ||
      deviceClass == null ||
      manufacturer == null ||
      family == null ||
      model == null ||
      variant == null ||
      platform == null) {
    return null;
  }
  return ProfileIdentity(
    profileId: profileId,
    manufacturer: manufacturer,
    family: family,
    model: model,
    variant: variant,
    deviceClass: deviceClass,
    platformFamily: platform,
  );
}

CaseFacts? _readCase(
  Object? raw,
  Set<String> sourceIds,
  List<ProfileViolation> violations,
) {
  final map = _expectMap(raw, 'case', violations);
  if (map == null) return null;
  _rejectUnknownKeys(map, {
    'widthMm',
    'heightMm',
    'depthMm',
    'shape',
  }, violations, 'case');
  final width = _readPositiveFact(map['widthMm'], 'case.widthMm', sourceIds, violations);
  final height = _readPositiveFact(
    map['heightMm'],
    'case.heightMm',
    sourceIds,
    violations,
  );
  final depth = _readPositiveFact(map['depthMm'], 'case.depthMm', sourceIds, violations);
  final shape = _readShapeFact(map['shape'], 'case.shape', sourceIds, violations);
  if (width == null || height == null || depth == null || shape == null) {
    return null;
  }
  return CaseFacts(widthMm: width, heightMm: height, depthMm: depth, shape: shape);
}

DisplayFacts? _readDisplay(
  Object? raw,
  Set<String> sourceIds,
  List<ProfileViolation> violations,
) {
  final map = _expectMap(raw, 'display', violations);
  if (map == null) return null;
  _rejectUnknownKeys(map, {
    'shape',
    'rasterWidth',
    'rasterHeight',
    'widthMm',
    'heightMm',
    'diagonalInches',
    'ppi',
    'cornerRadiusPx',
    'nativeLogicalWidth',
    'nativeLogicalHeight',
    'designWidth',
    'designHeight',
    'designBasis',
    'safeArea',
    'shellAperture',
  }, violations, 'display');
  final shape = _readShapeFact(map['shape'], 'display.shape', sourceIds, violations);
  final rasterWidth = _readPositiveFact(
    map['rasterWidth'],
    'display.rasterWidth',
    sourceIds,
    violations,
  );
  final rasterHeight = _readPositiveFact(
    map['rasterHeight'],
    'display.rasterHeight',
    sourceIds,
    violations,
  );
  final widthMm = _readPositiveFact(
    map['widthMm'],
    'display.widthMm',
    sourceIds,
    violations,
  );
  final heightMm = _readPositiveFact(
    map['heightMm'],
    'display.heightMm',
    sourceIds,
    violations,
  );
  final diagonal = _readPositiveFact(
    map['diagonalInches'],
    'display.diagonalInches',
    sourceIds,
    violations,
  );
  final ppi = _readPositiveFact(map['ppi'], 'display.ppi', sourceIds, violations);
  final radius = _readPositiveFact(
    map['cornerRadiusPx'],
    'display.cornerRadiusPx',
    sourceIds,
    violations,
  );
  final nativeWidth = _readPositiveFact(
    map['nativeLogicalWidth'],
    'display.nativeLogicalWidth',
    sourceIds,
    violations,
  );
  final nativeHeight = _readPositiveFact(
    map['nativeLogicalHeight'],
    'display.nativeLogicalHeight',
    sourceIds,
    violations,
  );
  final designWidth = _readPositiveFact(
    map['designWidth'],
    'display.designWidth',
    sourceIds,
    violations,
  );
  final designHeight = _readPositiveFact(
    map['designHeight'],
    'display.designHeight',
    sourceIds,
    violations,
  );
  final designBasis = _readStringFact(
    map['designBasis'],
    'display.designBasis',
    sourceIds,
    violations,
  );
  final safe = _readSafeArea(map['safeArea'], sourceIds, violations);
  final aperture = _readAperture(map['shellAperture'], sourceIds, violations);
  if (shape == null ||
      rasterWidth == null ||
      rasterHeight == null ||
      widthMm == null ||
      heightMm == null ||
      diagonal == null ||
      ppi == null ||
      radius == null ||
      nativeWidth == null ||
      nativeHeight == null ||
      designWidth == null ||
      designHeight == null ||
      designBasis == null ||
      safe == null ||
      aperture == null) {
    return null;
  }
  return DisplayFacts(
    shape: shape,
    rasterWidth: rasterWidth,
    rasterHeight: rasterHeight,
    widthMm: widthMm,
    heightMm: heightMm,
    diagonalInches: diagonal,
    ppi: ppi,
    cornerRadiusPx: radius,
    nativeLogicalWidth: nativeWidth,
    nativeLogicalHeight: nativeHeight,
    designWidth: designWidth,
    designHeight: designHeight,
    designBasis: designBasis,
    safeArea: safe,
    shellAperture: aperture,
  );
}

ControlFacts? _readControls(
  Object? raw,
  Set<String> sourceIds,
  List<ProfileViolation> violations,
) {
  final map = _expectMap(raw, 'controls', violations);
  if (map == null) return null;
  const names = [
    'touchscreen',
    'crown',
    'crownRotation',
    'crownPress',
    'physicalButtons',
    'rotatingBezel',
    'gestureInput',
    'haptics',
  ];
  _rejectUnknownKeys(map, names.toSet(), violations, 'controls');
  final parsed = <String, ControlFact>{};
  for (final name in names) {
    final fact = _readControl(
      map[name],
      name,
      sourceIds,
      violations,
      allowCount: name == 'physicalButtons',
    );
    if (fact != null) parsed[name] = fact;
  }
  if (parsed.length != names.length) return null;
  return ControlFacts(
    touchscreen: parsed['touchscreen']!,
    crown: parsed['crown']!,
    crownRotation: parsed['crownRotation']!,
    crownPress: parsed['crownPress']!,
    physicalButtons: parsed['physicalButtons']!,
    rotatingBezel: parsed['rotatingBezel']!,
    gestureInput: parsed['gestureInput']!,
    haptics: parsed['haptics']!,
  );
}

List<SourceRecord>? _readSources(Object? raw, List<ProfileViolation> violations) {
  if (raw is! List || raw.isEmpty) {
    violations.add(
      const ProfileViolation('missing-provenance', 'sources must be a non-empty list.'),
    );
    return null;
  }
  final records = <SourceRecord>[];
  final seen = <String>{};
  for (final item in raw) {
    if (item is! Map) {
      violations.add(
        const ProfileViolation('missing-provenance', 'Each source must be an object.'),
      );
      return null;
    }
    final map = _stringMap(item);
    _rejectUnknownKeys(map, {
      'id',
      'url',
      'title',
      'retrieved',
      'note',
    }, violations, 'sources');
    final id = map['id'];
    final url = map['url'];
    final title = map['title'];
    final retrieved = map['retrieved'];
    final note = map['note'];
    if (id is! String || id.isEmpty || !seen.add(id)) {
      violations.add(
        const ProfileViolation('missing-provenance', 'Each source needs a unique id.'),
      );
      return null;
    }
    if (url is! String || !url.startsWith('https://')) {
      violations.add(
        ProfileViolation('missing-provenance', 'Source $id needs an https URL.'),
      );
      return null;
    }
    if (title is! String || title.trim().isEmpty) {
      violations.add(
        ProfileViolation('missing-provenance', 'Source $id needs a title.'),
      );
      return null;
    }
    if (retrieved is! String || retrieved.trim().isEmpty) {
      violations.add(
        ProfileViolation('missing-provenance', 'Source $id needs a retrieved date.'),
      );
      return null;
    }
    if (note is! String) {
      violations.add(
        ProfileViolation('missing-provenance', 'Source $id needs a note.'),
      );
      return null;
    }
    records.add(
      SourceRecord(
        id: id,
        url: url,
        title: title,
        retrieved: retrieved,
        note: note,
      ),
    );
  }
  return records;
}

SafeAreaFact? _readSafeArea(
  Object? raw,
  Set<String> sourceIds,
  List<ProfileViolation> violations,
) {
  final fact = _readRawFact(raw, 'display.safeArea', sourceIds, violations);
  if (fact == null) return null;
  if (fact.status == FactStatus.unknown) {
    if (fact.value != null) {
      violations.add(
        const ProfileViolation(
          'unknown-carries-value',
          'display.safeArea is unknown and must not carry insets.',
        ),
      );
      return null;
    }
    return SafeAreaFact.unknown(
      sourceIds: fact.sourceIds,
      uncertainty: fact.uncertainty,
    );
  }
  final value = fact.value;
  if (value is! Map) {
    violations.add(
      const ProfileViolation(
        'missing-evidence',
        'A known safe area needs an inset object.',
      ),
    );
    return null;
  }
  final map = _stringMap(value);
  final spec = _readSafeSpec(map, violations);
  if (spec == null) return null;
  if (fact.status == FactStatus.derived) {
    return SafeAreaFact.derived(
      value: spec,
      sourceIds: fact.sourceIds,
      derivation: fact.derivation!,
      uncertainty: fact.uncertainty,
    );
  }
  return SafeAreaFact.known(
    value: spec,
    sourceIds: fact.sourceIds,
    uncertainty: fact.uncertainty,
  );
}

SafeAreaSpec? _readSafeSpec(Map<String, Object?> map, List<ProfileViolation> violations) {
  _rejectUnknownKeys(map, {
    'kind',
    'left',
    'top',
    'right',
    'bottom',
    'inset',
  }, violations, 'safeArea.value');
  if (map['kind'] == 'circularInset') {
    final inset = map['inset'];
    if (inset is! num || inset <= 0) {
      violations.add(
        const ProfileViolation(
          'unknown-substituted-zero',
          'A circular safe inset must be a positive evidenced number.',
        ),
      );
      return null;
    }
    return SafeAreaSpec.circular(circularInset: inset.toDouble());
  }
  if (map['kind'] == 'insets') {
    final values = <String, double>{};
    for (final edge in ['left', 'top', 'right', 'bottom']) {
      final number = map[edge];
      if (number is! num || number <= 0 || number == 0) {
        violations.add(
          ProfileViolation(
            'unknown-substituted-zero',
            'Safe inset $edge must be positive. Zero is not known-none.',
          ),
        );
        return null;
      }
      values[edge] = number.toDouble();
    }
    return SafeAreaSpec.insets(
      left: values['left']!,
      top: values['top']!,
      right: values['right']!,
      bottom: values['bottom']!,
    );
  }
  violations.add(
    const ProfileViolation('impossible-safe-area', 'safeArea.value.kind is invalid.'),
  );
  return null;
}

ShellApertureFact? _readAperture(
  Object? raw,
  Set<String> sourceIds,
  List<ProfileViolation> violations,
) {
  final fact = _readRawFact(raw, 'display.shellAperture', sourceIds, violations);
  if (fact == null) return null;
  if (fact.status == FactStatus.unknown) {
    if (fact.value != null) {
      violations.add(
        const ProfileViolation(
          'unknown-carries-value',
          'shellAperture is unknown and must not carry geometry.',
        ),
      );
      return null;
    }
    return ShellApertureFact.unknown(
      sourceIds: fact.sourceIds,
      uncertainty: fact.uncertainty,
    );
  }
  if (fact.value is! Map) {
    violations.add(
      const ProfileViolation(
        'missing-evidence',
        'A known shell aperture needs a geometry object.',
      ),
    );
    return null;
  }
  final value = _stringMap(fact.value! as Map<dynamic, dynamic>);
  if (fact.status == FactStatus.derived) {
    return ShellApertureFact.derived(
      value: value,
      sourceIds: fact.sourceIds,
      derivation: fact.derivation!,
      uncertainty: fact.uncertainty,
    );
  }
  return ShellApertureFact.known(
    value: value,
    sourceIds: fact.sourceIds,
    uncertainty: fact.uncertainty,
  );
}

ControlFact? _readControl(
  Object? raw,
  String label,
  Set<String> sourceIds,
  List<ProfileViolation> violations, {
  required bool allowCount,
}) {
  if (raw is! Map) {
    violations.add(
      ProfileViolation('missing-evidence', '$label control is required.'),
    );
    return null;
  }
  final map = _stringMap(raw);
  _rejectUnknownKeys(map, _controlKeys, violations, label);
  if (!allowCount && map.containsKey('count')) {
    violations.add(
      ProfileViolation(
        'unknown-field',
        '$label cannot carry a button count.',
      ),
    );
    return null;
  }
  final availability = switch (map['availability']) {
    'supported' => ControlAvailability.supported,
    'unsupported' => ControlAvailability.unsupported,
    'unknown' => ControlAvailability.unknown,
    'systemReserved' => ControlAvailability.systemReserved,
    _ => null,
  };
  if (availability == null) {
    violations.add(
      ProfileViolation(
        'contradictory-capability',
        '$label.availability is invalid.',
      ),
    );
    return null;
  }
  final ids = _readSourceIdList(map['sourceIds'], '$label.sourceIds', violations);
  final simulate = map['appMaySimulate'];
  if (simulate is! bool) {
    violations.add(
      ProfileViolation(
        'contradictory-capability',
        '$label.appMaySimulate must be boolean.',
      ),
    );
    return null;
  }
  if (simulate && availability != ControlAvailability.supported) {
    violations.add(
      ProfileViolation(
        'contradictory-capability',
        '$label may be simulated only when supported.',
      ),
    );
    return null;
  }
  if (availability != ControlAvailability.unknown && (ids == null || ids.isEmpty)) {
    violations.add(
      ProfileViolation(
        'missing-provenance',
        '$label needs a source for a non-unknown claim.',
      ),
    );
    return null;
  }
  if (ids != null) {
    _requireKnownSources(ids, sourceIds, label, violations);
  }
  final uncertainty = map['uncertainty'];
  if (uncertainty != null && uncertainty is! String) {
    violations.add(
      ProfileViolation('missing-evidence', '$label.uncertainty must be text or null.'),
    );
    return null;
  }
  EvidenceFact<int>? count;
  if (allowCount && map.containsKey('count')) {
    count = _readCountFact(map['count'], '$label.count', sourceIds, violations);
    if (count == null) return null;
  }
  if (ids == null) return null;
  return ControlFact(
    availability: availability,
    sourceIds: ids,
    appMaySimulate: simulate,
    uncertainty: uncertainty is String ? uncertainty : null,
    count: count,
  );
}

EvidenceFact<int>? _readCountFact(
  Object? raw,
  String label,
  Set<String> sourceIds,
  List<ProfileViolation> violations,
) {
  final fact = _readRawFact(raw, label, sourceIds, violations);
  if (fact == null) return null;
  if (fact.status == FactStatus.unknown) {
    return EvidenceFact<int>.unknown(
      sourceIds: fact.sourceIds,
      uncertainty: fact.uncertainty,
    );
  }
  final value = fact.value;
  if (value is! num || value != value.roundToDouble() || value < 1) {
    violations.add(
      ProfileViolation(
        'unknown-substituted-zero',
        '$label must be a positive integer when evidenced.',
      ),
    );
    return null;
  }
  final count = value.toInt();
  if (fact.status == FactStatus.derived) {
    return EvidenceFact<int>.derived(
      value: count,
      sourceIds: fact.sourceIds,
      derivation: fact.derivation!,
      uncertainty: fact.uncertainty,
    );
  }
  return EvidenceFact<int>.known(
    value: count,
    sourceIds: fact.sourceIds,
    uncertainty: fact.uncertainty,
  );
}

EvidenceFact<double>? _readPositiveFact(
  Object? raw,
  String label,
  Set<String> sourceIds,
  List<ProfileViolation> violations,
) {
  final fact = _readRawFact(raw, label, sourceIds, violations);
  if (fact == null) return null;
  if (fact.status == FactStatus.unknown) {
    return EvidenceFact<double>.unknown(
      sourceIds: fact.sourceIds,
      uncertainty: fact.uncertainty,
    );
  }
  final value = fact.value;
  if (value is! num || !value.toDouble().isFinite || value <= 0) {
    violations.add(
      ProfileViolation(
        'unknown-substituted-zero',
        '$label must be a positive number when evidenced. Zero is not unknown.',
      ),
    );
    return null;
  }
  final number = value.toDouble();
  if (fact.status == FactStatus.derived) {
    return EvidenceFact<double>.derived(
      value: number,
      sourceIds: fact.sourceIds,
      derivation: fact.derivation!,
      uncertainty: fact.uncertainty,
    );
  }
  return EvidenceFact<double>.known(
    value: number,
    sourceIds: fact.sourceIds,
    uncertainty: fact.uncertainty,
  );
}

EvidenceFact<String>? _readStringFact(
  Object? raw,
  String label,
  Set<String> sourceIds,
  List<ProfileViolation> violations,
) {
  final fact = _readRawFact(raw, label, sourceIds, violations);
  if (fact == null) return null;
  if (fact.status == FactStatus.unknown) {
    return EvidenceFact<String>.unknown(
      sourceIds: fact.sourceIds,
      uncertainty: fact.uncertainty,
    );
  }
  final value = fact.value;
  if (value is! String || value.trim().isEmpty) {
    violations.add(
      ProfileViolation('missing-evidence', '$label needs non-empty text.'),
    );
    return null;
  }
  if (fact.status == FactStatus.derived) {
    return EvidenceFact<String>.derived(
      value: value,
      sourceIds: fact.sourceIds,
      derivation: fact.derivation!,
      uncertainty: fact.uncertainty,
    );
  }
  return EvidenceFact<String>.known(
    value: value,
    sourceIds: fact.sourceIds,
    uncertainty: fact.uncertainty,
  );
}

EvidenceFact<ScreenShape>? _readShapeFact(
  Object? raw,
  String label,
  Set<String> sourceIds,
  List<ProfileViolation> violations,
) {
  final fact = _readRawFact(raw, label, sourceIds, violations);
  if (fact == null) return null;
  if (fact.status == FactStatus.unknown) {
    return const EvidenceFact<ScreenShape>.unknown().copyUncertainty(fact);
  }
  final shape = switch (fact.value) {
    'rectangle' => ScreenShape.rectangle,
    'round' => ScreenShape.round,
    'roundedRectangle' => ScreenShape.roundedRectangle,
    _ => null,
  };
  if (shape == null) {
    violations.add(
      ProfileViolation('invalid-shape', '$label value is not a screen shape.'),
    );
    return null;
  }
  if (fact.status == FactStatus.derived) {
    return EvidenceFact<ScreenShape>.derived(
      value: shape,
      sourceIds: fact.sourceIds,
      derivation: fact.derivation!,
      uncertainty: fact.uncertainty,
    );
  }
  return EvidenceFact<ScreenShape>.known(
    value: shape,
    sourceIds: fact.sourceIds,
    uncertainty: fact.uncertainty,
  );
}

final class _RawFact {
  const _RawFact({
    required this.status,
    required this.value,
    required this.sourceIds,
    required this.derivation,
    required this.uncertainty,
  });

  final FactStatus status;
  final Object? value;
  final List<String> sourceIds;
  final String? derivation;
  final String? uncertainty;
}

_RawFact? _readRawFact(
  Object? raw,
  String label,
  Set<String> sourceIds,
  List<ProfileViolation> violations,
) {
  if (raw is! Map) {
    violations.add(ProfileViolation('missing-evidence', '$label fact is required.'));
    return null;
  }
  final map = _stringMap(raw);
  _rejectUnknownKeys(map, _factKeys, violations, label);
  final status = switch (map['status']) {
    'known' => FactStatus.known,
    'unknown' => FactStatus.unknown,
    'derived' => FactStatus.derived,
    _ => null,
  };
  if (status == null) {
    violations.add(ProfileViolation('missing-evidence', '$label.status is invalid.'));
    return null;
  }
  final ids = _readSourceIdList(map['sourceIds'], '$label.sourceIds', violations);
  if (ids == null) return null;
  _requireKnownSources(ids, sourceIds, label, violations);
  final derivation = map['derivation'];
  final uncertainty = map['uncertainty'];
  if (derivation != null && derivation is! String) {
    violations.add(
      ProfileViolation('missing-evidence', '$label.derivation must be text or null.'),
    );
    return null;
  }
  if (uncertainty != null && uncertainty is! String) {
    violations.add(
      ProfileViolation('missing-evidence', '$label.uncertainty must be text or null.'),
    );
    return null;
  }
  final hasValue = map.containsKey('value') && map['value'] != null;
  if (status == FactStatus.unknown) {
    if (hasValue) {
      final code = _isZero(map['value'])
          ? 'unknown-substituted-zero'
          : 'unknown-carries-value';
      violations.add(
        ProfileViolation(code, '$label is unknown and must not carry a value.'),
      );
      return null;
    }
    if (derivation is String && derivation.trim().isNotEmpty) {
      violations.add(
        ProfileViolation(
          'missing-evidence',
          '$label is unknown and must not carry a derivation.',
        ),
      );
      return null;
    }
    return _RawFact(
      status: status,
      value: null,
      sourceIds: ids,
      derivation: null,
      uncertainty: uncertainty is String ? uncertainty : null,
    );
  }
  if (!hasValue) {
    violations.add(
      ProfileViolation('missing-evidence', '$label needs a value when $status.'),
    );
    return null;
  }
  if (ids.isEmpty) {
    violations.add(
      ProfileViolation('missing-provenance', '$label needs at least one source id.'),
    );
    return null;
  }
  if (status == FactStatus.derived) {
    if (derivation is! String || derivation.trim().isEmpty) {
      violations.add(
        ProfileViolation('missing-evidence', '$label derivation is required.'),
      );
      return null;
    }
  } else if (derivation is String && derivation.trim().isNotEmpty) {
    violations.add(
      ProfileViolation(
        'missing-evidence',
        '$label is known and must not carry a derivation.',
      ),
    );
    return null;
  }
  if (_isZero(map['value'])) {
    violations.add(
      ProfileViolation(
        'unknown-substituted-zero',
        '$label uses zero. Zero is not an evidenced measurement.',
      ),
    );
    return null;
  }
  return _RawFact(
    status: status,
    value: map['value'],
    sourceIds: ids,
    derivation: derivation is String ? derivation : null,
    uncertainty: uncertainty is String ? uncertainty : null,
  );
}

bool _isZero(Object? value) {
  if (value is num && value == 0) return true;
  if (value is String && value.trim() == '0') return true;
  return false;
}

List<String>? _readSourceIdList(
  Object? raw,
  String label,
  List<ProfileViolation> violations,
) {
  if (raw is! List) {
    violations.add(ProfileViolation('missing-provenance', '$label must be a list.'));
    return null;
  }
  final ids = <String>[];
  for (final item in raw) {
    if (item is! String || item.trim().isEmpty) {
      violations.add(
        ProfileViolation('missing-provenance', '$label entries must be text.'),
      );
      return null;
    }
    ids.add(item);
  }
  return ids;
}

void _requireKnownSources(
  List<String> ids,
  Set<String> known,
  String label,
  List<ProfileViolation> violations,
) {
  for (final id in ids) {
    if (!known.contains(id)) {
      violations.add(
        ProfileViolation(
          'missing-provenance',
          '$label cites unknown source $id.',
        ),
      );
    }
  }
}

Map<String, Object?>? _expectMap(
  Object? raw,
  String label,
  List<ProfileViolation> violations,
) {
  if (raw is! Map) {
    violations.add(ProfileViolation('malformed-json', '$label must be an object.'));
    return null;
  }
  return _stringMap(raw);
}

void _rejectUnknownKeys(
  Map<String, Object?> json,
  Set<String> allowed,
  List<ProfileViolation> violations,
  String label,
) {
  for (final key in json.keys) {
    if (!allowed.contains(key)) {
      violations.add(
        ProfileViolation('unknown-field', 'Unknown $label field $key.'),
      );
    }
  }
}

void _scanBanned(Object? node, List<ProfileViolation> violations) {
  if (node is Map) {
    node.forEach((key, value) {
      final normalized = '$key'.toLowerCase().replaceAll('_', '').replaceAll('-', '');
      if (_bannedKeys.contains(normalized)) {
        violations.add(
          ProfileViolation('certification-claim', 'Self-asserted field $key is rejected.'),
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

Map<String, Object?> _stringMap(Map<dynamic, dynamic> value) {
  final out = <String, Object?>{};
  value.forEach((key, val) {
    out['$key'] = val as Object?;
  });
  return out;
}

final RegExp _profileId = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

extension on EvidenceFact<ScreenShape> {
  EvidenceFact<ScreenShape> copyUncertainty(_RawFact fact) {
    return EvidenceFact<ScreenShape>.unknown(
      sourceIds: fact.sourceIds,
      uncertainty: fact.uncertainty,
    );
  }
}
