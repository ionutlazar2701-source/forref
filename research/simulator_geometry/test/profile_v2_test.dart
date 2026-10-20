import 'dart:io';

import 'package:simulator_geometry/simulator_geometry.dart';
import 'package:test/test.dart';

void main() {
  test('schema version 1 still parses and schema 2 does not use that parser', () {
    expect(illustrativePhonePortrait.schemaVersion, 1);
    final rejected = parseProfile(amazfitRawProbe());
    expect(rejected, isA<ProfileRejected>());
    expect((rejected as ProfileRejected).hasCode('unsupported-schema'), isTrue);
  });

  test('unknown facts reject a substituted zero', () {
    final raw = _minimal(
      '{"status":"unknown","value":0,"sourceIds":[],"derivation":null,"uncertainty":"no"}',
    );
    final result = parseProfileV2(raw);
    expect(result, isA<ProfileV2Rejected>());
    expect((result as ProfileV2Rejected).hasCode('unknown-substituted-zero'), isTrue);
  });

  test('a known zero measurement is rejected', () {
    final raw = _minimal(
      '{"status":"known","value":0,"sourceIds":["lab"],"derivation":null,"uncertainty":null}',
    );
    final result = parseProfileV2(raw);
    expect(result, isA<ProfileV2Rejected>());
    expect((result as ProfileV2Rejected).hasCode('unknown-substituted-zero'), isTrue);
  });

  test('self-asserted certification is rejected', () {
    final raw = _minimal(null).replaceFirst(
      '"schemaVersion": 2',
      '"schemaVersion": 2, "certification": "forrefCertified"',
    );
    final result = parseProfileV2(raw);
    expect(result, isA<ProfileV2Rejected>());
    expect((result as ProfileV2Rejected).hasCode('certification-claim'), isTrue);
  });

  test('an evidence stage in JSON cannot award simulation ready', () {
    final raw = _minimal(null).replaceFirst(
      '"schemaVersion": 2',
      '"schemaVersion": 2, "evidenceStage": "simulationReady"',
    );
    final result = parseProfileV2(raw);
    expect(result, isA<ProfileV2Rejected>());
  });

  test('four factual profiles load with evidenced values and unknown safe areas', () {
    expect(factualSeedProfiles, hasLength(4));
    final ids = factualSeedProfiles.map((profile) => profile.identity.profileId).toList();
    expect(ids, [
      'amazfit-gts4',
      'huawei-watch-gt4-46',
      'apple-watch-series9-45',
      'garmin-approach-s60',
    ]);
    for (final profile in factualSeedProfiles) {
      expect(profile.display.safeArea.status, FactStatus.unknown);
      expect(profile.display.safeArea.value, isNull);
      expect(profile.display.shellAperture.status, FactStatus.unknown);
      expect(profile.display.nativeLogicalWidth.status, FactStatus.unknown);
      expect(profile.display.nativeLogicalWidth.value, isNull);
      expect(profileV2EvidenceStage(profile), SimulatorEvidenceStage.profiled);
      expect(
        profileV2EvidenceStage(
          profile,
          shellManifestLinked: true,
          apertureHostImplemented: true,
        ),
        SimulatorEvidenceStage.profiled,
      );
      _everyKnownFactHasSource(profile);
    }
  });

  test('Amazfit uses the design benchmark and not a preview viewport', () {
    final profile = amazfitGts4;
    expect(profile.display.rasterWidth.value, 390);
    expect(profile.display.rasterHeight.value, 450);
    expect(profile.display.designWidth.value, 390);
    expect(profile.display.designHeight.value, 450);
    expect(profile.display.cornerRadiusPx.value, 86);
    expect(profile.controls.physicalButtons.count?.value, 1);
    expect(profile.controls.crown.availability, ControlAvailability.unknown);
    expect(profile.caseFacts.widthMm.status, FactStatus.unknown);
    final viewport = viewportContextFor(profile);
    expect(viewport.basis, ViewportBasis.designCoordinateSpace);
    expect(viewport.usesNativeLogicalViewport, isFalse);
    expect(viewport.safeAreaKnown, isFalse);
    expect(viewport.basisLabel, contains('not a native logical viewport'));
  });

  test('Huawei 46 mm facts stay on the cited specs and the viewport is a raster fallback', () {
    final profile = huaweiWatchGt446;
    expect(profile.caseFacts.widthMm.value, 46);
    expect(profile.caseFacts.heightMm.value, 46);
    expect(profile.caseFacts.depthMm.value, 10.9);
    expect(profile.display.rasterWidth.value, 466);
    expect(profile.display.ppi.value, 326);
    expect(profile.display.diagonalInches.value, 1.43);
    expect(profile.display.designWidth.status, FactStatus.unknown);
    expect(profile.controls.touchscreen.appMaySimulate, isTrue);
    expect(profile.controls.crownRotation.appMaySimulate, isFalse);
    expect(profile.controls.crownPress.availability, ControlAvailability.supported);
    final viewport = viewportContextFor(profile);
    expect(viewport.basis, ViewportBasis.rasterFallback);
    expect(viewport.safeAreaKnown, isFalse);
    expect(viewport.clipShape, ScreenShape.round);
  });

  test('Apple Series 9 keeps confirmed case facts and leaves the raster unknown', () {
    final profile = appleWatchSeries945;
    expect(profile.caseFacts.widthMm.value, 38);
    expect(profile.caseFacts.heightMm.value, 45);
    expect(profile.caseFacts.depthMm.value, 10.7);
    expect(profile.display.ppi.value, 326);
    expect(profile.display.rasterWidth.status, FactStatus.unknown);
    expect(profile.display.nativeLogicalWidth.status, FactStatus.unknown);
    expect(profile.controls.crownPress.availability, ControlAvailability.unknown);
    expect(profile.controls.crown.availability, ControlAvailability.supported);
    expect(profile.controls.haptics.availability, ControlAvailability.supported);
    final viewport = viewportContextFor(profile);
    expect(viewport.basis, ViewportBasis.unavailable);
    expect(viewport.width, isNull);
    expect(viewport.safeAreaKnown, isFalse);
  });

  test('Garmin Approach S60 loads as identity with measurements unknown', () {
    final profile = garminApproachS60;
    expect(profile.identity.manufacturer.value, 'Garmin');
    expect(profile.identity.model.value, 'S60');
    expect(profile.identity.platformFamily.status, FactStatus.unknown);
    expect(profile.caseFacts.widthMm.status, FactStatus.unknown);
    expect(profile.display.rasterWidth.status, FactStatus.unknown);
    expect(profile.controls.touchscreen.availability, ControlAvailability.unknown);
    expect(profile.controls.physicalButtons.availability, ControlAvailability.unknown);
    expect(viewportContextFor(profile).basis, ViewportBasis.unavailable);
  });

  test('catalog source does not store rejected measurement figures', () {
    final text = File('lib/src/catalog_v2.dart').readAsStringSync();
    for (final banned in [
      '266',
      '307',
      '396',
      '484',
      '42.7',
      '36.5',
      '9.9',
      '43.32',
      '14.5',
      '30.4',
      '41.3',
      '352',
    ]) {
      expect(text.contains(banned), isFalse, reason: banned);
    }
  });

  test('shared geometry has no manufacturer sporting branches', () {
    final banned = ['isGarmin', 'isHuawei', 'isApple', 'isAmazfit'];
    final hits = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      for (final token in banned) {
        if (text.contains(token)) hits.add('${entity.path}: $token');
      }
    }
    expect(hits, isEmpty);
  });
}

void _everyKnownFactHasSource(DeviceProfileV2 profile) {
  void check<T>(EvidenceFact<T> fact) {
    if (fact.status == FactStatus.unknown) {
      expect(fact.value, isNull);
      return;
    }
    expect(fact.sourceIds, isNotEmpty);
    expect(fact.value, isNotNull);
    for (final id in fact.sourceIds) {
      expect(profile.sourceById(id), isNotNull, reason: id);
    }
  }

  check(profile.identity.manufacturer);
  check(profile.identity.family);
  check(profile.identity.model);
  check(profile.identity.variant);
  check(profile.identity.platformFamily);
  check(profile.caseFacts.widthMm);
  check(profile.caseFacts.heightMm);
  check(profile.caseFacts.depthMm);
  check(profile.caseFacts.shape);
  check(profile.display.shape);
  check(profile.display.rasterWidth);
  check(profile.display.rasterHeight);
  check(profile.display.widthMm);
  check(profile.display.heightMm);
  check(profile.display.diagonalInches);
  check(profile.display.ppi);
  check(profile.display.cornerRadiusPx);
  check(profile.display.nativeLogicalWidth);
  check(profile.display.nativeLogicalHeight);
  check(profile.display.designWidth);
  check(profile.display.designHeight);
  check(profile.display.designBasis);
  check(profile.shellReference);
  for (final control in profile.controls.all) {
    if (control.availability == ControlAvailability.unknown) continue;
    expect(control.sourceIds, isNotEmpty);
    if (control.availability != ControlAvailability.supported) {
      expect(control.appMaySimulate, isFalse);
    }
    final count = control.count;
    if (count != null) check(count);
  }
}

String amazfitRawProbe() => _minimal(null);

String _minimal(String? widthOverride, {String field = 'case.widthMm'}) {
  final width = widthOverride ??
      '{"status":"unknown","value":null,"sourceIds":[],"derivation":null,"uncertainty":"none"}';
  final unknown = '{"status":"unknown","value":null,"sourceIds":[],"derivation":null,"uncertainty":"none"}';
  final control = '{"availability":"unknown","sourceIds":[],"uncertainty":null,"appMaySimulate":false}';
  return '''
{
  "schemaVersion": 2,
  "identity": {
    "profileId": "lab-probe",
    "manufacturer": $unknown,
    "family": $unknown,
    "model": $unknown,
    "variant": $unknown,
    "deviceClass": "smartwatch",
    "platformFamily": $unknown
  },
  "case": {
    "widthMm": ${field == 'case.widthMm' ? width : unknown},
    "heightMm": $unknown,
    "depthMm": $unknown,
    "shape": $unknown
  },
  "display": {
    "shape": $unknown,
    "rasterWidth": $unknown,
    "rasterHeight": $unknown,
    "widthMm": $unknown,
    "heightMm": $unknown,
    "diagonalInches": $unknown,
    "ppi": $unknown,
    "cornerRadiusPx": $unknown,
    "nativeLogicalWidth": $unknown,
    "nativeLogicalHeight": $unknown,
    "designWidth": $unknown,
    "designHeight": $unknown,
    "designBasis": $unknown,
    "safeArea": $unknown,
    "shellAperture": $unknown
  },
  "controls": {
    "touchscreen": $control,
    "crown": $control,
    "crownRotation": $control,
    "crownPress": $control,
    "physicalButtons": $control,
    "rotatingBezel": $control,
    "gestureInput": $control,
    "haptics": $control
  },
  "shellReference": $unknown,
  "sources": [{
    "id": "lab",
    "url": "https://example.com/lab",
    "title": "Lab",
    "retrieved": "2026-10-20",
    "note": "Synthetic parser probe. Not a device."
  }]
}
''';
}
