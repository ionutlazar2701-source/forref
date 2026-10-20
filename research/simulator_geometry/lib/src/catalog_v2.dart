import 'dart:convert';

import 'profile_v2.dart';

/// Factual seed profiles.
///
/// Every numeric value below was checked against the cited page during
/// Simulator V2 preflight. Unconfirmed research-report numbers are absent.
final List<DeviceProfileV2> factualSeedProfiles = [
  amazfitGts4,
  huaweiWatchGt446,
  appleWatchSeries945,
  garminApproachS60,
];

/// Selects a seed profile by id. Manufacturer is not a code branch.
DeviceProfileV2? factualProfileById(String profileId) {
  for (final profile in factualSeedProfiles) {
    if (profile.identity.profileId == profileId) return profile;
  }
  return null;
}

final DeviceProfileV2 amazfitGts4 = _load(_amazfit);
final DeviceProfileV2 huaweiWatchGt446 = _load(_huawei);
final DeviceProfileV2 appleWatchSeries945 = _load(_apple);
final DeviceProfileV2 garminApproachS60 = _load(_garmin);

DeviceProfileV2 _load(String raw) {
  final result = parseProfileV2(raw);
  if (result is ProfileV2Rejected) {
    final detail = result.violations
        .map((item) => '${item.code}:${item.message}')
        .join('; ');
    throw StateError('Factual profile rejected: $detail');
  }
  return (result as ProfileV2Accepted).profile;
}

String _unknown(String uncertainty, [List<String> sourceIds = const []]) {
  return jsonEncode({
    'status': 'unknown',
    'value': null,
    'sourceIds': sourceIds,
    'derivation': null,
    'uncertainty': uncertainty,
  });
}

String _knownText(String value, List<String> sourceIds, String? uncertainty) {
  return jsonEncode({
    'status': 'known',
    'value': value,
    'sourceIds': sourceIds,
    'derivation': null,
    'uncertainty': uncertainty,
  });
}

String _knownNum(num value, List<String> sourceIds, String? uncertainty) {
  return jsonEncode({
    'status': 'known',
    'value': value,
    'sourceIds': sourceIds,
    'derivation': null,
    'uncertainty': uncertainty,
  });
}

String _derivedText(
  String value,
  List<String> sourceIds,
  String derivation,
  String uncertainty,
) {
  return jsonEncode({
    'status': 'derived',
    'value': value,
    'sourceIds': sourceIds,
    'derivation': derivation,
    'uncertainty': uncertainty,
  });
}

String _control({
  required String availability,
  required List<String> sourceIds,
  required bool appMaySimulate,
  String? uncertainty,
  String? countJson,
}) {
  return jsonEncode({
    'availability': availability,
    'sourceIds': sourceIds,
    'uncertainty': uncertainty,
    'appMaySimulate': appMaySimulate,
    if (countJson != null) 'count': jsonDecode(countJson),
  });
}

String _sources(List<Map<String, String>> rows) => jsonEncode(rows);

final String _amazfit = '''
{
  "schemaVersion": 2,
  "identity": {
    "profileId": "amazfit-gts4",
    "manufacturer": ${_knownText('Amazfit', ['zepp-device-list'], 'Named on the Zepp OS device list row for Amazfit GTS 4.')},
    "family": ${_knownText('GTS', ['zepp-device-list'], null)},
    "model": ${_knownText('GTS 4', ['zepp-device-list'], null)},
    "variant": ${_unknown('The Zepp device list row used here does not publish a separate size variant.')},
    "deviceClass": "smartwatch",
    "platformFamily": ${_knownText('Zepp OS', ['zepp-device-list', 'zepp-screen-adaption'], 'The device list places GTS 4 on Zepp OS 3.5. The screen-adaptation guide describes Zepp OS Mini Program design benchmarks.')}
  },
  "case": {
    "widthMm": ${_unknown('No GTS 4 case width was isolated from an unambiguous official specification in this session. A shared Amazfit product page contained other products and was not used.')},
    "heightMm": ${_unknown('No GTS 4 case height was isolated from an unambiguous official specification in this session.')},
    "depthMm": ${_unknown('No GTS 4 case depth was isolated from an unambiguous official specification in this session.')},
    "shape": ${_unknown('The Zepp device list describes the screen as Square. It does not state the case shape.')}
  },
  "display": {
    "shape": ${_derivedText('roundedRectangle', ['zepp-device-list'], 'Zepp device list shape column is Square and the radius column is 86. The profile maps that pair to roundedRectangle.', 'This is a simulator mapping of the published Square plus radius columns. It is not a separate manufacturer shape enum.')},
    "rasterWidth": ${_knownNum(390, ['zepp-device-list'], 'Resolution column 390 × 450.')},
    "rasterHeight": ${_knownNum(450, ['zepp-device-list'], 'Resolution column 390 × 450.')},
    "widthMm": ${_unknown('Physical display width in millimetres was not published in the cited Zepp pages.')},
    "heightMm": ${_unknown('Physical display height in millimetres was not published in the cited Zepp pages.')},
    "diagonalInches": ${_unknown('A 1.75 inch figure appears on an Amazfit marketing page that also lists other products. It is not marked known for GTS 4 from that page.')},
    "ppi": ${_unknown('A 341 PPI figure appears on an Amazfit marketing page that also lists other products. It is not marked known for GTS 4 from that page.')},
    "cornerRadiusPx": ${_knownNum(86, ['zepp-device-list'], 'Radius column on the Amazfit GTS 4 row. Unit is the device-list radius, not a measured bezel.')},
    "nativeLogicalWidth": ${_unknown('The Zepp device list watch-face preview column is a preview image size. It is not an application logical viewport and is not stored here.', ['zepp-device-list'])},
    "nativeLogicalHeight": ${_unknown('No native logical viewport height is published for GTS 4 application layout. The watch-face preview size is not used.', ['zepp-device-list'])},
    "designWidth": ${_knownNum(390, ['zepp-screen-adaption'], 'Zepp screen adaptation publishes 390 × 450 as the square-screen design benchmark for Mini Programs. This is not a native logical viewport.')},
    "designHeight": ${_knownNum(450, ['zepp-screen-adaption'], 'Square-screen design benchmark height. Not a native logical viewport.')},
    "designBasis": ${_knownText('Zepp OS square-screen design benchmark 390 × 450', ['zepp-screen-adaption'], 'If designWidth is omitted, the square baseline defaults to 390. That default is a framework benchmark, not a measurement of this device logical viewport.')},
    "safeArea": ${_unknown('No official safe-area inset for GTS 4 was published in the cited sources. Unknown is not inset zero.', ['zepp-device-list', 'zepp-screen-adaption'])},
    "shellAperture": ${_unknown('No measured display aperture inside a case drawing was available. Simulator shell aperture is not invented from the raster.')}
  },
  "controls": {
    "touchscreen": ${_control(availability: 'unknown', sourceIds: ['zepp-device-list'], appMaySimulate: false, uncertainty: 'The device-list row used here does not state touchscreen support.')},
    "crown": ${_control(availability: 'unknown', sourceIds: ['zepp-device-list'], appMaySimulate: false, uncertainty: 'One physical key is listed. The list does not identify that key as a crown.')},
    "crownRotation": ${_control(availability: 'unknown', sourceIds: ['zepp-device-list'], appMaySimulate: false, uncertainty: 'Crown rotation is not stated on the cited device-list row.')},
    "crownPress": ${_control(availability: 'unknown', sourceIds: ['zepp-device-list'], appMaySimulate: false, uncertainty: 'Crown press is not stated on the cited device-list row.')},
    "physicalButtons": ${_control(availability: 'supported', sourceIds: ['zepp-device-list'], appMaySimulate: false, uncertainty: 'The physical-keys column is 1. The key is not identified as a crown, so crown stays unknown.', countJson: _knownNum(1, ['zepp-device-list'], 'physical-keys column.'))},
    "rotatingBezel": ${_control(availability: 'unknown', sourceIds: ['zepp-device-list'], appMaySimulate: false, uncertainty: 'A rotating bezel is not stated. Absence of a statement is not an unsupported claim.')},
    "gestureInput": ${_control(availability: 'unknown', sourceIds: ['zepp-device-list'], appMaySimulate: false, uncertainty: 'Gesture input is not stated on the cited row.')},
    "haptics": ${_control(availability: 'unknown', sourceIds: ['zepp-device-list'], appMaySimulate: false, uncertainty: 'Haptics are not stated on the cited row.')}
  },
  "shellReference": ${_unknown('No shell manifest is linked. A profile is not a rendered device shell.')},
  "sources": ${_sources([
    {
      'id': 'zepp-device-list',
      'url': 'https://docs.zepp.com/docs/reference/related-resources/device-list/',
      'title': 'Zepp OS device list',
      'retrieved': '2026-10-20',
      'note': 'Amazfit GTS 4 row: Square, radius 86, resolution 390×450, physical-keys 1. The watch-face preview column is a separate preview size and is not an application viewport.',
    },
    {
      'id': 'zepp-screen-adaption',
      'url': 'https://docs.zepp.com/docs/guides/framework/device/screen-adaption/',
      'title': 'Zepp OS screen adaptation',
      'retrieved': '2026-10-20',
      'note': 'Square design benchmark is 390×450. Round benchmark 480×480 and band benchmark 194×368 are different baselines and are not GTS 4 viewports.',
    }
  ])}
}
''';

final String _huawei = '''
{
  "schemaVersion": 2,
  "identity": {
    "profileId": "huawei-watch-gt4-46",
    "manufacturer": ${_knownText('Huawei', ['huawei-gt4-specs'], null)},
    "family": ${_knownText('Watch GT', ['huawei-gt4-specs'], null)},
    "model": ${_knownText('GT 4', ['huawei-gt4-specs'], null)},
    "variant": ${_knownText('46 mm', ['huawei-gt4-specs'], 'The 41 mm GT 4 is a different variant and is not mixed into this profile.')},
    "deviceClass": "smartwatch",
    "platformFamily": ${_knownText('Huawei Watch GT 4', ['huawei-gt4-specs'], 'The UK specs page names Watch GT 4. It does not publish a separate OS product name in the excerpt used here.')}
  },
  "case": {
    "widthMm": ${_knownNum(46, ['huawei-gt4-specs'], 'UK specs: 46 × 46 × 10.9 mm for the 46 mm model.')},
    "heightMm": ${_knownNum(46, ['huawei-gt4-specs'], 'UK specs: 46 × 46 × 10.9 mm for the 46 mm model.')},
    "depthMm": ${_knownNum(10.9, ['huawei-gt4-specs'], 'UK specs list depth 10.9 mm. The page calls specifications theoretical.')},
    "shape": ${_derivedText('round', ['huawei-gt4-specs'], 'Published case width and height are both 46 mm.', 'The UK specs excerpt used here does not contain the word round.')}
  },
  "display": {
    "shape": ${_derivedText('round', ['huawei-gt4-specs'], 'Published resolution is 466 × 466.', 'A square raster is not itself a statement that the visible mask is circular. The mask is a simulator derivation.')},
    "rasterWidth": ${_knownNum(466, ['huawei-gt4-specs'], null)},
    "rasterHeight": ${_knownNum(466, ['huawei-gt4-specs'], null)},
    "widthMm": ${_unknown('Display width in millimetres is not published. PPI and raster are not converted into a known millimetre width.')},
    "heightMm": ${_unknown('Display height in millimetres is not published.')},
    "diagonalInches": ${_knownNum(1.43, ['huawei-gt4-specs'], 'UK specs: 1.43 inch AMOLED for the 46 mm model.')},
    "ppi": ${_knownNum(326, ['huawei-gt4-specs'], null)},
    "cornerRadiusPx": ${_unknown('No corner radius is published for this circular raster.')},
    "nativeLogicalWidth": ${_unknown('No application logical viewport is published on the cited Huawei pages.')},
    "nativeLogicalHeight": ${_unknown('No application logical viewport is published on the cited Huawei pages.')},
    "designWidth": ${_unknown('No Huawei design-coordinate width is published. The raster is not relabeled as a design space.')},
    "designHeight": ${_unknown('No Huawei design-coordinate height is published.')},
    "designBasis": ${_unknown('No manufacturer design-coordinate basis is published.')},
    "safeArea": ${_unknown('No official safe-area inset is published. Unknown is not inset zero.', ['huawei-gt4-specs', 'huawei-gt4-controls'])},
    "shellAperture": ${_unknown('No measured aperture inside the case is published. The 466 raster is not an aperture drawing.')}
  },
  "controls": {
    "touchscreen": ${_control(availability: 'supported', sourceIds: ['huawei-gt4-controls'], appMaySimulate: true, uncertainty: 'The support article documents touch for GT 4.')},
    "crown": ${_control(availability: 'supported', sourceIds: ['huawei-gt4-specs', 'huawei-gt4-controls'], appMaySimulate: false, uncertainty: 'Specs name Home Button (Rotating Crown). Simulation of crown behavior is not claimed by the support article alone.')},
    "crownRotation": ${_control(availability: 'supported', sourceIds: ['huawei-gt4-controls'], appMaySimulate: false, uncertainty: 'Up button rotate scrolls and zooms. appMaySimulate stays false until a simulator channel exists.')},
    "crownPress": ${_control(availability: 'supported', sourceIds: ['huawei-gt4-controls'], appMaySimulate: false, uncertainty: 'Up button press wakes, returns home, or goes back. Double-press opens recent tasks on GT 4.')},
    "physicalButtons": ${_control(availability: 'supported', sourceIds: ['huawei-gt4-specs', 'huawei-gt4-controls'], appMaySimulate: false, uncertainty: 'Specs name a Side Button in addition to the rotating crown. Count 1 is that side button, not the crown.', countJson: _knownNum(1, ['huawei-gt4-specs'], 'Side Button named separately from the rotating crown.'))},
    "rotatingBezel": ${_control(availability: 'unknown', sourceIds: ['huawei-gt4-specs'], appMaySimulate: false, uncertainty: 'A rotating bezel is not stated. That is not an unsupported claim.')},
    "gestureInput": ${_control(availability: 'supported', sourceIds: ['huawei-gt4-controls'], appMaySimulate: false, uncertainty: 'The article documents touch-and-hold and swipes. It does not publish an application gesture API.')},
    "haptics": ${_control(availability: 'unknown', sourceIds: ['huawei-gt4-controls'], appMaySimulate: false, uncertainty: 'Haptics are not stated in the control excerpt used here.')}
  },
  "shellReference": ${_unknown('No shell manifest is linked.')},
  "sources": ${_sources([
    {
      'id': 'huawei-gt4-specs',
      'url': 'https://consumer.huawei.com/uk/wearables/watch-gt4/specs/',
      'title': 'Huawei Watch GT 4 specifications (UK)',
      'retrieved': '2026-10-20',
      'note': '46 mm model: 46 × 46 × 10.9 mm, 1.43 inch AMOLED, 466 × 466, PPI 326, Home Button (Rotating Crown) and Side Button. Specifications are described as theoretical. The 41 mm model is a different product row.',
    },
    {
      'id': 'huawei-gt4-controls',
      'url': 'https://consumer.huawei.com/en/support/content/en-us15818704/',
      'title': 'Huawei wearable gestures and buttons',
      'retrieved': '2026-10-20',
      'note': 'GT 4 is in the applicable set. Up button rotate scrolls or zooms. Up button press wakes, goes home, or goes back. Down button press opens Workout by default and is customizable. Touch, touch-and-hold, and swipes are documented.',
    }
  ])}
}
''';

final String _apple = '''
{
  "schemaVersion": 2,
  "identity": {
    "profileId": "apple-watch-series9-45",
    "manufacturer": ${_knownText('Apple', ['apple-series9-support'], null)},
    "family": ${_knownText('Watch', ['apple-series9-support'], null)},
    "model": ${_knownText('Series 9', ['apple-series9-support'], null)},
    "variant": ${_knownText('45 mm', ['apple-series9-support'], null)},
    "deviceClass": "smartwatch",
    "platformFamily": ${_knownText('Apple Watch', ['apple-series9-support'], 'Support page 111833 identifies Apple Watch Series 9. The fetched excerpt did not quote a separate OS version string.')}
  },
  "case": {
    "widthMm": ${_knownNum(38, ['apple-series9-support'], 'Support page: 45 mm model width 38 mm.')},
    "heightMm": ${_knownNum(45, ['apple-series9-support'], 'Support page: 45 mm model height 45 mm.')},
    "depthMm": ${_knownNum(10.7, ['apple-series9-support'], 'Support page: depth 10.7 mm.')},
    "shape": ${_derivedText('roundedRectangle', ['apple-series9-support'], 'Published case width is 38 mm and height is 45 mm.', 'The support page does not publish a case-shape enum. Equal-axis round is not used because the published width and height differ.')}
  },
  "display": {
    "shape": ${_derivedText('roundedRectangle', ['apple-series9-support'], 'The 45 mm case is wider than it is tall in the published millimetre table, and the display is the Retina face of that case.', 'Display corner geometry and the pixel raster were not in the fetched support excerpt. Shape is derived from the case, not from a pixel mask.')},
    "rasterWidth": ${_unknown('The fetched Apple Support excerpt does not list a pixel raster. An unconfirmed third-party raster is not stored.')},
    "rasterHeight": ${_unknown('The fetched Apple Support 111833 excerpt does not list a pixel raster.')},
    "widthMm": ${_unknown('Display glass width is not separately published. Case width is not copied into the display.')},
    "heightMm": ${_unknown('Display glass height is not separately published.')},
    "diagonalInches": ${_unknown('No display diagonal was in the fetched support excerpt.')},
    "ppi": ${_knownNum(326, ['apple-series9-support'], 'Support page: Always-On Retina display, 326 ppi.')},
    "cornerRadiusPx": ${_unknown('No corner radius was in the fetched support excerpt.')},
    "nativeLogicalWidth": ${_unknown('No logical point viewport was in the fetched support excerpt.')},
    "nativeLogicalHeight": ${_unknown('No logical point viewport was in the fetched support excerpt.')},
    "designWidth": ${_unknown('No Apple design-coordinate width was confirmed. An unconfirmed raster is not used as a design space.')},
    "designHeight": ${_unknown('No Apple design-coordinate height was confirmed.')},
    "designBasis": ${_unknown('Apple Human Interface Guidelines pages fetched in this session did not return a usable layout table.')},
    "safeArea": ${_unknown('No official safe-area inset was in the fetched support excerpt. Unknown is not inset zero. Marketing photography is not a safe area.', ['apple-series9-support'])},
    "shellAperture": ${_unknown('No measured display aperture is published in the fetched excerpt.')}
  },
  "controls": {
    "touchscreen": ${_control(availability: 'supported', sourceIds: ['apple-series9-support'], appMaySimulate: true, uncertainty: 'The page documents double tap and a Retina display. The excerpt used here does not contain the word touchscreen.')},
    "crown": ${_control(availability: 'supported', sourceIds: ['apple-series9-support'], appMaySimulate: false, uncertainty: 'Hardware list names the Digital Crown. Simulation of crown behavior is not claimed.')},
    "crownRotation": ${_control(availability: 'unknown', sourceIds: ['apple-series9-support'], appMaySimulate: false, uncertainty: 'The fetched excerpt names the Digital Crown. It does not state that rotation is an application input.')},
    "crownPress": ${_control(availability: 'unknown', sourceIds: ['apple-series9-support'], appMaySimulate: false, uncertainty: 'A system-reserved crown-press claim was not confirmed from the fetched Human Interface Guidelines text. Unknown is not system-reserved and not unsupported.')},
    "physicalButtons": ${_control(availability: 'supported', sourceIds: ['apple-series9-support'], appMaySimulate: false, uncertainty: 'The page names the side button separately from the Digital Crown.', countJson: _knownNum(1, ['apple-series9-support'], 'One side button is named.'))},
    "rotatingBezel": ${_control(availability: 'unknown', sourceIds: ['apple-series9-support'], appMaySimulate: false, uncertainty: 'A rotating bezel is not stated. That is not an unsupported claim.')},
    "gestureInput": ${_control(availability: 'supported', sourceIds: ['apple-series9-support'], appMaySimulate: false, uncertainty: 'Double tap is documented. The simulator does not claim the watchOS gesture recognizer.')},
    "haptics": ${_control(availability: 'supported', sourceIds: ['apple-series9-support'], appMaySimulate: false, uncertainty: 'The page says the Digital Crown has haptic feedback.')}
  },
  "shellReference": ${_unknown('No shell manifest is linked.')},
  "sources": ${_sources([
    {
      'id': 'apple-series9-support',
      'url': 'https://support.apple.com/111833',
      'title': 'Apple Watch Series 9 specifications',
      'retrieved': '2026-10-20',
      'note': '45 mm model: height 45 mm, width 38 mm, depth 10.7 mm. Digital Crown and side button. Double tap gesture. Digital Crown haptic feedback. Always-On Retina display, 326 ppi. The fetched page does not list a pixel raster or a logical point viewport.',
    }
  ])}
}
''';

final String _garmin = '''
{
  "schemaVersion": 2,
  "identity": {
    "profileId": "garmin-approach-s60",
    "manufacturer": ${_knownText('Garmin', ['garmin-s60-manual'], 'The cited page is the Approach S60 owner manual.')},
    "family": ${_knownText('Approach', ['garmin-s60-manual'], null)},
    "model": ${_knownText('S60', ['garmin-s60-manual'], null)},
    "variant": ${_unknown('No size variant was published in the retrieved specifications excerpt.')},
    "deviceClass": "smartwatch",
    "platformFamily": ${_unknown('The Connect IQ device-reference page for this model returned a title only in this session. Platform family is not marked known from a title.', ['garmin-s60-device-reference'])}
  },
  "case": {
    "widthMm": ${_unknown('Case width was not in the retrieved owner-manual specifications excerpt.', ['garmin-s60-manual'])},
    "heightMm": ${_unknown('Case height was not in the retrieved owner-manual specifications excerpt.', ['garmin-s60-manual'])},
    "depthMm": ${_unknown('Case depth was not in the retrieved owner-manual specifications excerpt.', ['garmin-s60-manual'])},
    "shape": ${_unknown('Case shape was not in the retrieved specifications excerpt.', ['garmin-s60-manual'])}
  },
  "display": {
    "shape": ${_unknown('Display shape was not in the retrieved specifications excerpt.', ['garmin-s60-manual', 'garmin-s60-device-reference'])},
    "rasterWidth": ${_unknown('No raster width was retrieved from the owner manual specifications page or from the device-reference title page.', ['garmin-s60-manual', 'garmin-s60-device-reference'])},
    "rasterHeight": ${_unknown('No raster height was retrieved from the owner manual specifications page or from the device-reference title page.', ['garmin-s60-manual', 'garmin-s60-device-reference'])},
    "widthMm": ${_unknown('Display width in millimetres was not retrieved.')},
    "heightMm": ${_unknown('Display height in millimetres was not retrieved.')},
    "diagonalInches": ${_unknown('Display diagonal was not retrieved.')},
    "ppi": ${_unknown('PPI was not retrieved.')},
    "cornerRadiusPx": ${_unknown('Corner radius was not retrieved.')},
    "nativeLogicalWidth": ${_unknown('No native logical viewport was retrieved.')},
    "nativeLogicalHeight": ${_unknown('No native logical viewport was retrieved.')},
    "designWidth": ${_unknown('No design-coordinate width was retrieved. An unverified raster is not stored as a design space.')},
    "designHeight": ${_unknown('No design-coordinate height was retrieved.')},
    "designBasis": ${_unknown('No design-coordinate basis was retrieved.')},
    "safeArea": ${_unknown('No safe area was retrieved. Unknown is not inset zero.', ['garmin-s60-manual'])},
    "shellAperture": ${_unknown('No shell aperture was retrieved.')}
  },
  "controls": {
    "touchscreen": ${_control(availability: 'unknown', sourceIds: ['garmin-s60-manual', 'garmin-s60-device-reference'], appMaySimulate: false, uncertainty: 'Touch support was not in the retrieved specifications excerpt. A compare-page claim was not used.')},
    "crown": ${_control(availability: 'unknown', sourceIds: ['garmin-s60-manual'], appMaySimulate: false, uncertainty: 'A crown is not stated in the retrieved excerpt. That is not an unsupported claim.')},
    "crownRotation": ${_control(availability: 'unknown', sourceIds: ['garmin-s60-manual'], appMaySimulate: false, uncertainty: 'Crown rotation is not stated in the retrieved excerpt.')},
    "crownPress": ${_control(availability: 'unknown', sourceIds: ['garmin-s60-manual'], appMaySimulate: false, uncertainty: 'Crown press is not stated in the retrieved excerpt.')},
    "physicalButtons": ${_control(availability: 'unknown', sourceIds: ['garmin-s60-manual', 'garmin-s60-device-reference'], appMaySimulate: false, uncertainty: 'Enter, back, and menu keys were not in the retrieved specifications excerpt. They are not marked supported from an unverified device-reference table.', countJson: _unknown('Button count was not in the retrieved excerpt.', ['garmin-s60-manual']))},
    "rotatingBezel": ${_control(availability: 'unknown', sourceIds: ['garmin-s60-manual'], appMaySimulate: false, uncertainty: 'A rotating bezel is not stated in the retrieved excerpt.')},
    "gestureInput": ${_control(availability: 'unknown', sourceIds: ['garmin-s60-manual'], appMaySimulate: false, uncertainty: 'Gesture input is not stated in the retrieved excerpt.')},
    "haptics": ${_control(availability: 'unknown', sourceIds: ['garmin-s60-manual'], appMaySimulate: false, uncertainty: 'Haptics are not stated in the retrieved excerpt.')}
  },
  "shellReference": ${_unknown('No shell manifest is linked. Identity alone does not create a measured shell.')},
  "sources": ${_sources([
    {
      'id': 'garmin-s60-manual',
      'url': 'https://www8.garmin.com/manuals/webhelp/approachs60/EN-US/GUID-E0C7F5F4-D845-44EC-A4E2-3F5E6A15C5D2.html',
      'title': 'Approach S60 owner manual specifications',
      'retrieved': '2026-10-20',
      'note': 'Retrieved specifications text covers battery, water rating, temperature, and wireless. It does not include case millimetres, a pixel raster, a display diameter, or button names. Those fields stay unknown.',
    },
    {
      'id': 'garmin-s60-device-reference',
      'url': 'https://developer.garmin.com/connect-iq/device-reference/approachs60/',
      'title': 'Connect IQ device reference Approach S60',
      'retrieved': '2026-10-20',
      'note': 'This session retrieved a title page only. No resolution, touch, or button table from that URL is marked known.',
    }
  ])}
}
''';
