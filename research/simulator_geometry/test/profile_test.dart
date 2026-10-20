import 'package:simulator_geometry/simulator_geometry.dart';
import 'package:test/test.dart';

void main() {
  test('starter profiles are illustrative and carry no physical size', () {
    expect(starterProfiles, hasLength(3));
    final ids = starterProfiles.map((profile) => profile.profileId).toSet();
    expect(ids, {
      'illustrative-phone-portrait',
      'illustrative-round-watch',
      'illustrative-rectangular-watch',
    });
    for (final profile in starterProfiles) {
      expect(profile.classification, EvidenceClassification.illustrative);
      expect(profile.physicalMillimetres.known, isFalse);
      expect(profile.raster.known, isFalse);
      expect(profile.provenance.sourceType, ProvenanceSourceType.illustrative);
      expect(profile.schemaVersion, deviceProfileSchemaVersion);
    }
    expect(illustrativePhonePortrait.screenShape, ScreenShape.rectangle);
    expect(illustrativeRoundWatch.screenShape, ScreenShape.round);
    expect(illustrativeRectangularWatch.deviceClass, DeviceClass.smartwatch);
    expect(
      illustrativeRoundWatch.capability(InputChannel.crown),
      CapabilityStatus.unknown,
    );
    expect(
      illustrativeRoundWatch.capability(InputChannel.crown),
      isNot(CapabilityStatus.unsupported),
    );
  });

  test('encode and parse round-trip a starter without raising its evidence', () {
    final raw = encodeProfile(illustrativeRectangularWatch);
    final parsed = parseProfile(raw);
    expect(parsed, isA<ProfileAccepted>());
    final profile = (parsed as ProfileAccepted).profile;
    expect(profile.profileId, illustrativeRectangularWatch.profileId);
    expect(profile.logicalWidth, 192);
    expect(profile.logicalHeight, 228);
    expect(profile.physicalMillimetres.known, isFalse);
  });

  test('an arbitrary factual candidate loads without a source change', () {
    final parsed = parseProfile('''
{
  "schemaVersion": 1,
  "profileId": "candidate-rect-watch",
  "displayName": "Candidate rectangular watch",
  "manufacturer": "Example",
  "model": "Candidate",
  "deviceClass": "smartwatch",
  "screenShape": "roundedRectangle",
  "classification": "factual",
  "logicalViewport": {"width": 200, "height": 240},
  "rasterDimensions": {"known": true, "width": 400, "height": 480},
  "physicalDisplayDimensionsMm": {"known": false},
  "safeArea": {"kind": "insets", "left": 6, "top": 6, "right": 6, "bottom": 6},
  "edgeClipping": "roundedMask",
  "cornerRadius": 16,
  "inputCapabilities": {
    "touchscreen": "unknown",
    "crown": "unsupported",
    "physicalButtons": "supported",
    "rotatingBezel": "unsupported",
    "gestureInput": "unknown",
    "accessibilityInvocation": "supported"
  },
  "typography": {"minimumLogicalSp": 12},
  "provenance": {
    "sourceType": "manufacturerStated",
    "sourceReference": "Example public specification sheet",
    "observedDate": "2026-01-15",
    "measurementMethod": null
  }
}
''');
    expect(parsed, isA<ProfileAccepted>());
    final profile = (parsed as ProfileAccepted).profile;
    expect(profile.profileId, 'candidate-rect-watch');
    expect(profile.touchClaimedSupported, isFalse);
    expect(profile.capability(InputChannel.touchscreen), CapabilityStatus.unknown);
    expect(profile.raster.known, isTrue);
    expect(profile.manufacturer, 'Example');
  });

  test('malformed and unsupported schema versions fail closed', () {
    expect(
      (parseProfile('{') as ProfileRejected).hasCode('malformed-json'),
      isTrue,
    );
    final future = parseProfile(_phoneJson(schema: 2)) as ProfileRejected;
    expect(future.hasCode('unsupported-schema'), isTrue);
  });

  test('zero dimensions, inverted safe areas, and bad shapes are rejected', () {
    expect(
      (parseProfile(_phoneJson(width: 0)) as ProfileRejected)
          .hasCode('non-positive-dimension'),
      isTrue,
    );
    expect(
      (parseProfile(_phoneJson(safeLeft: 400)) as ProfileRejected)
          .hasCode('impossible-safe-area'),
      isTrue,
    );
    expect(
      (parseProfile(_phoneJson(shape: 'triangle')) as ProfileRejected)
          .hasCode('invalid-shape'),
      isTrue,
    );
  });

  test('missing identifiers and missing factual provenance are rejected', () {
    expect(
      (parseProfile(_phoneJson(id: ' ')) as ProfileRejected)
          .hasCode('missing-identifier'),
      isTrue,
    );
    final factual = parseProfile('''
{
  "schemaVersion": 1,
  "profileId": "bare-fact",
  "displayName": "Bare",
  "deviceClass": "phone",
  "screenShape": "rectangle",
  "classification": "factual",
  "logicalViewport": {"width": 200, "height": 400},
  "rasterDimensions": {"known": false},
  "physicalDisplayDimensionsMm": {"known": false},
  "safeArea": {"kind": "insets", "left": 4, "top": 4, "right": 4, "bottom": 4},
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
  "typography": {"minimumLogicalSp": 12},
  "provenance": {
    "sourceType": "illustrative",
    "sourceReference": "missing",
    "observedDate": null,
    "measurementMethod": null
  }
}
''') as ProfileRejected;
    expect(factual.hasCode('missing-provenance'), isTrue);
  });

  test('contradictory capability and size claims are rejected', () {
    final touch = parseProfile(_phoneJson(touch: 'sometimes')) as ProfileRejected;
    expect(touch.hasCode('contradictory-capability'), isTrue);
    final both = parseProfile(
      _phoneJson().replaceAll(
        '"rasterDimensions": {"known": false}',
        '"rasterDimensions": {"known": false, "width": 10, "height": 10}',
      ),
    ) as ProfileRejected;
    expect(both.hasCode('contradictory-capability'), isTrue);
  });

  test('a profile cannot self-assign certification or host calibration', () {
    final certified = parseProfile(
      _phoneJson().replaceAll(
        '"classification": "illustrative"',
        '"classification": "illustrative", "forrefCertified": true',
      ),
    ) as ProfileRejected;
    expect(certified.hasCode('certification-claim'), isTrue);

    final platform = parseProfile(
      _phoneJson().replaceAll(
        '"displayName": "Illustrative phone portrait"',
        '"displayName": "PLATFORM PROVEN"',
      ),
    ) as ProfileRejected;
    expect(platform.hasCode('certification-claim'), isTrue);

    final host = parseProfile(
      _phoneJson().replaceAll(
        '"cornerRadius": 0',
        '"cornerRadius": 0, "calibration": {"hostMillimetersPerLogicalPixel": 0.1}',
      ),
    ) as ProfileRejected;
    expect(host.hasCode('invalid-calibration'), isTrue);
  });

  test('illustrative physical millimetres are rejected', () {
    final spoof = parseProfile(
      _phoneJson().replaceAll(
        '"physicalDisplayDimensionsMm": {"known": false}',
        '"physicalDisplayDimensionsMm": {"known": true, "width": 70, "height": 150}',
      ),
    ) as ProfileRejected;
    expect(spoof.hasCode('fabricated-physical-dimension'), isTrue);
  });

  test('a no-touch profile can say touch is unsupported or unknown', () {
    final unsupported = parseProfile(_phoneJson(touch: 'unsupported'));
    expect(unsupported, isA<ProfileAccepted>());
    expect((unsupported as ProfileAccepted).profile.touchClaimedSupported, isFalse);
    final unknown = parseProfile(_phoneJson(touch: 'unknown'));
    expect(unknown, isA<ProfileAccepted>());
    expect(
      (unknown as ProfileAccepted).profile.capability(InputChannel.touchscreen),
      CapabilityStatus.unknown,
    );
  });
}

String _phoneJson({
  int schema = 1,
  String id = 'illustrative-phone-portrait',
  double width = 390,
  double safeLeft = 8,
  String shape = 'rectangle',
  String touch = 'supported',
}) {
  return '''
{
  "schemaVersion": $schema,
  "profileId": "$id",
  "displayName": "Illustrative phone portrait",
  "manufacturer": null,
  "model": null,
  "deviceClass": "phone",
  "screenShape": "$shape",
  "classification": "illustrative",
  "logicalViewport": {"width": $width, "height": 844},
  "rasterDimensions": {"known": false},
  "physicalDisplayDimensionsMm": {"known": false},
  "safeArea": {"kind": "insets", "left": $safeLeft, "top": 8, "right": 8, "bottom": 8},
  "edgeClipping": "none",
  "cornerRadius": 0,
  "inputCapabilities": {
    "touchscreen": "$touch",
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
''';
}
