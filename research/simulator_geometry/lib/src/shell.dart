import 'evidence.dart';
import 'geometry.dart';
import 'profile.dart';
import 'profile_v2.dart';

const int shellManifestVersion = 1;

enum ShellRepresentationKind { procedural, referenceVector, approvedRaster }

enum VisualFidelityGrade {
  schematic,
  reference,
  measured,
  verifiedAgainstReference,
}

enum ShellSurface { aperture, bezel, strap, control, outside }

final class ShellBounds {
  const ShellBounds(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  bool contains(double x, double y) {
    return x >= left && y >= top && x < right && y < bottom;
  }
}

final class ShellControlAnchor {
  const ShellControlAnchor({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    required this.simulatedChannel,
    required this.evidence,
  });

  final String id;
  final String label;
  final double x;
  final double y;
  final bool simulatedChannel;
  final String evidence;
}

/// Procedural hardware drawing for one profile.
///
/// Fidelity is schematic unless a later manifest proves a measurement.
/// An aperture in this manifest is not a safe area and not certification.
final class DeviceShellManifest {
  const DeviceShellManifest({
    required this.profileId,
    required this.manifestVersion,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.canvasUnit,
    required this.body,
    required this.straps,
    required this.aperture,
    required this.clip,
    required this.cornerRadius,
    required this.cornerRadiusMeasured,
    required this.controls,
    required this.representation,
    required this.fidelity,
    required this.assetProvenance,
    required this.apertureEvidence,
    required this.apertureIsMeasured,
    required this.caption,
  });

  final String profileId;
  final int manifestVersion;
  final double canvasWidth;
  final double canvasHeight;
  final String canvasUnit;
  final ShellBounds body;
  final List<ShellBounds> straps;
  final ShellBounds aperture;
  final ScreenShape clip;
  final double? cornerRadius;
  final bool cornerRadiusMeasured;
  final List<ShellControlAnchor> controls;
  final ShellRepresentationKind representation;
  final VisualFidelityGrade fidelity;
  final String assetProvenance;
  final String apertureEvidence;
  final bool apertureIsMeasured;
  final String caption;
}

const String schematicProvenance =
    'Procedural drawing from DeviceProfileV2 facts. No manufacturer image is embedded.';

const String notMeasuredAperture =
    'NOT A MEASURED APERTURE. Schematic placement only. Not a safe area.';

/// Builds a schematic shell from profile facts. Selection is by facts, not manufacturer.
DeviceShellManifest shellManifestFor(DeviceProfileV2 profile) {
  final caseWidth = _positive(profile.caseFacts.widthMm);
  final caseHeight = _positive(profile.caseFacts.heightMm);
  final shape = profile.caseFacts.shape.hasValue
      ? profile.caseFacts.shape.value
      : (profile.display.shape.hasValue ? profile.display.shape.value : null);
  if (caseWidth != null && caseHeight != null && shape == ScreenShape.round) {
    return _roundCase(profile, caseWidth, caseHeight);
  }
  if (caseWidth != null &&
      caseHeight != null &&
      shape == ScreenShape.roundedRectangle) {
    return _roundedCase(profile, caseWidth, caseHeight);
  }
  final designWidth = _positive(profile.display.designWidth);
  final designHeight = _positive(profile.display.designHeight);
  if (designWidth != null &&
      designHeight != null &&
      shape == ScreenShape.roundedRectangle) {
    return _aspectCase(profile, designWidth, designHeight);
  }
  return _unknownPlate(profile);
}

ShellSurface shellSurfaceAt(DeviceShellManifest manifest, double x, double y) {
  if (!_finite(x) || !_finite(y)) return ShellSurface.outside;
  if (_apertureContains(manifest, x, y)) return ShellSurface.aperture;
  for (final anchor in manifest.controls) {
    final dx = x - anchor.x;
    final dy = y - anchor.y;
    if (dx * dx + dy * dy <= 4.5 * 4.5) return ShellSurface.control;
  }
  if (_bodyContains(manifest, x, y)) return ShellSurface.bezel;
  for (final strap in manifest.straps) {
    if (strap.contains(x, y)) return ShellSurface.strap;
  }
  return ShellSurface.outside;
}

bool shellApertureContains(DeviceShellManifest manifest, double x, double y) {
  return shellSurfaceAt(manifest, x, y) == ShellSurface.aperture;
}

DeviceShellManifest _roundCase(
  DeviceProfileV2 profile,
  double caseWidth,
  double caseHeight,
) {
  const strap = 14.0;
  const leftGutter = 6.0;
  const rightGutter = 14.0;
  final canvasWidth = leftGutter + caseWidth + rightGutter;
  final canvasHeight = strap + caseHeight + strap;
  final body = ShellBounds(leftGutter, strap, caseWidth, caseHeight);
  final diagonalMm = _millimetresFromInches(profile.display.diagonalInches);
  final diameter = diagonalMm != null && diagonalMm < caseWidth && diagonalMm < caseHeight
      ? diagonalMm
      : caseWidth * 0.78;
  final aperture = ShellBounds(
    body.left + (caseWidth - diameter) / 2,
    body.top + (caseHeight - diameter) / 2,
    diameter,
    diameter,
  );
  final fromDiagonal = diagonalMm != null && diameter == diagonalMm;
  return DeviceShellManifest(
    profileId: profile.identity.profileId,
    manifestVersion: shellManifestVersion,
    canvasWidth: canvasWidth,
    canvasHeight: canvasHeight,
    canvasUnit: 'millimetre schematic',
    body: body,
    straps: _straps(body),
    aperture: aperture,
    clip: ScreenShape.round,
    cornerRadius: null,
    cornerRadiusMeasured: false,
    controls: _anchors(profile, body),
    representation: ShellRepresentationKind.procedural,
    fidelity: VisualFidelityGrade.schematic,
    assetProvenance: schematicProvenance,
    apertureIsMeasured: false,
    apertureEvidence: fromDiagonal
        ? 'Display circle uses the published diagonal converted at 25.4 mm per inch and centered in the published case. Specs that call dimensions theoretical stay theoretical. $notMeasuredAperture'
        : 'Display circle is 78 percent of the published case. The diagonal was missing or did not fit. $notMeasuredAperture',
    caption: _caption(profile, 'Round case from published equal axes.'),
  );
}

DeviceShellManifest _roundedCase(
  DeviceProfileV2 profile,
  double caseWidth,
  double caseHeight,
) {
  const strap = 14.0;
  const leftGutter = 4.0;
  const rightGutter = 14.0;
  const bezel = 2.4;
  final canvasWidth = leftGutter + caseWidth + rightGutter;
  final canvasHeight = strap + caseHeight + strap;
  final body = ShellBounds(leftGutter, strap, caseWidth, caseHeight);
  final aperture = ShellBounds(
    body.left + bezel,
    body.top + bezel,
    caseWidth - bezel * 2,
    caseHeight - bezel * 2,
  );
  final radius = aperture.width < aperture.height
      ? aperture.width * 0.16
      : aperture.height * 0.16;
  return DeviceShellManifest(
    profileId: profile.identity.profileId,
    manifestVersion: shellManifestVersion,
    canvasWidth: canvasWidth,
    canvasHeight: canvasHeight,
    canvasUnit: 'millimetre schematic',
    body: body,
    straps: _straps(body),
    aperture: aperture,
    clip: ScreenShape.roundedRectangle,
    cornerRadius: radius,
    cornerRadiusMeasured: false,
    controls: _anchors(profile, body),
    representation: ShellRepresentationKind.procedural,
    fidelity: VisualFidelityGrade.schematic,
    assetProvenance: schematicProvenance,
    apertureIsMeasured: false,
    apertureEvidence:
        'Aperture is the published case inset by a 2.4 mm schematic bezel. Corner radius is 16 percent of the shorter aperture side. Neither number is a manufacturer safe area or a measured opening. $notMeasuredAperture',
    caption: _caption(profile, 'Rounded case from the published width and height.'),
  );
}

DeviceShellManifest _aspectCase(
  DeviceProfileV2 profile,
  double designWidth,
  double designHeight,
) {
  const targetHeight = 45.0;
  const bezel = 3.2;
  const strap = 12.0;
  const rightGutter = 12.0;
  final apertureHeight = targetHeight;
  final apertureWidth = targetHeight * designWidth / designHeight;
  final body = ShellBounds(4, strap, apertureWidth + bezel * 2, apertureHeight + bezel * 2);
  final aperture = ShellBounds(body.left + bezel, body.top + bezel, apertureWidth, apertureHeight);
  final radiusFact = profile.display.cornerRadiusPx;
  final radius = radiusFact.hasValue && radiusFact.value != null
      ? radiusFact.value! / designWidth * apertureWidth
      : null;
  final canvasWidth = body.right + rightGutter;
  final canvasHeight = body.bottom + strap;
  return DeviceShellManifest(
    profileId: profile.identity.profileId,
    manifestVersion: shellManifestVersion,
    canvasWidth: canvasWidth,
    canvasHeight: canvasHeight,
    canvasUnit: 'schematic aspect units, not millimetres',
    body: body,
    straps: _straps(body),
    aperture: aperture,
    clip: ScreenShape.roundedRectangle,
    cornerRadius: radius,
    cornerRadiusMeasured: false,
    controls: _anchors(profile, body),
    representation: ShellRepresentationKind.procedural,
    fidelity: VisualFidelityGrade.schematic,
    assetProvenance: schematicProvenance,
    apertureIsMeasured: false,
    apertureEvidence:
        'Aperture aspect follows the design-coordinate space. The margin around it is a schematic bezel, not a measured case. $notMeasuredAperture',
    caption: _caption(
      profile,
      'Body aspect follows the design benchmark because case millimetres are unknown.',
    ),
  );
}

DeviceShellManifest _unknownPlate(DeviceProfileV2 profile) {
  final body = const ShellBounds(8, 8, 54, 76);
  final aperture = const ShellBounds(16, 22, 38, 48);
  return DeviceShellManifest(
    profileId: profile.identity.profileId,
    manifestVersion: shellManifestVersion,
    canvasWidth: 70,
    canvasHeight: 92,
    canvasUnit: 'schematic plate units, not the product',
    body: body,
    straps: const [],
    aperture: aperture,
    clip: ScreenShape.rectangle,
    cornerRadius: null,
    cornerRadiusMeasured: false,
    controls: const [],
    representation: ShellRepresentationKind.procedural,
    fidelity: VisualFidelityGrade.schematic,
    assetProvenance: schematicProvenance,
    apertureIsMeasured: false,
    apertureEvidence:
        'CASE GEOMETRY UNKNOWN. $notMeasuredAperture This plate is not a generic watch claim.',
    caption: _caption(
      profile,
      'Case geometry was not in the retrieved sources. No watch silhouette is invented.',
    ),
  );
}

List<ShellBounds> _straps(ShellBounds body) {
  final width = body.width * 0.55;
  final left = body.left + (body.width - width) / 2;
  final strap = body.top;
  return [
    ShellBounds(left, body.top - strap, width, strap),
    ShellBounds(left, body.bottom, width, strap),
  ];
}

List<ShellControlAnchor> _anchors(DeviceProfileV2 profile, ShellBounds body) {
  final anchors = <ShellControlAnchor>[];
  final x = body.right + 4;
  var y = body.top + body.height * 0.36;
  const evidence =
      'The control is supported by a cited source. This anchor is a schematic right-side convention. The source does not publish coordinates, and the channel is not simulated from the drawing.';
  if (profile.controls.crown.isSupported) {
    anchors.add(
      ShellControlAnchor(
        id: 'crown',
        label: 'Crown',
        x: x,
        y: y,
        simulatedChannel: profile.controls.crown.appMaySimulate,
        evidence: evidence,
      ),
    );
    y += body.height * 0.22;
  }
  final countFact = profile.controls.physicalButtons.count;
  final count = countFact != null && countFact.hasValue ? countFact.value ?? 0 : 0;
  if (profile.controls.physicalButtons.isSupported && count > 0) {
    for (var index = 0; index < count; index++) {
      anchors.add(
        ShellControlAnchor(
          id: 'physical-key-${index + 1}',
          label: 'Physical key ${index + 1}',
          x: x,
          y: y,
          simulatedChannel: false,
          evidence: evidence,
        ),
      );
      y += body.height * 0.18;
    }
  }
  return anchors;
}

String _caption(DeviceProfileV2 profile, String detail) {
  final manufacturer = profile.identity.manufacturer.value ?? 'Unknown manufacturer';
  final model = profile.identity.model.value ?? profile.identity.profileId;
  final variant = profile.identity.variant.value;
  final name = variant == null ? '$manufacturer $model' : '$manufacturer $model $variant';
  return '$name. SCHEMATIC. $detail Not official. Not certified. Not platform proven.';
}

double? _positive(EvidenceFact<double> fact) {
  final value = fact.value;
  if (!fact.hasValue || value == null || !value.isFinite || value <= 0) return null;
  return value;
}

double? _millimetresFromInches(EvidenceFact<double> inches) {
  final value = _positive(inches);
  if (value == null) return null;
  return value * 25.4;
}

bool _bodyContains(DeviceShellManifest manifest, double x, double y) {
  final body = manifest.body;
  if (manifest.clip == ScreenShape.round &&
      manifest.canvasUnit.startsWith('millimetre')) {
    final cx = body.left + body.width / 2;
    final cy = body.top + body.height / 2;
    final radius = body.width < body.height ? body.width / 2 : body.height / 2;
    final dx = x - cx;
    final dy = y - cy;
    return dx * dx + dy * dy <= radius * radius;
  }
  return body.contains(x, y);
}

bool _apertureContains(DeviceShellManifest manifest, double x, double y) {
  final aperture = manifest.aperture;
  final viewport = ViewportGeometry(
    shape: manifest.clip,
    width: aperture.width,
    height: aperture.height,
    safeLeft: 0,
    safeTop: 0,
    safeRight: 0,
    safeBottom: 0,
    cornerRadius: manifest.cornerRadius ?? 0,
    circularInset: 0,
  );
  return viewport.containsVisible(x - aperture.left, y - aperture.top);
}

bool _finite(double value) => value.isFinite;
