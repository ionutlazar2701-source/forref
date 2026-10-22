import 'package:simulator_geometry/simulator_geometry.dart';

/// Text helpers over DeviceProfileV2 facts.
///
/// Unknown stays unknown. Nothing here fills a missing number.
const unknownFactLabel = 'UNKNOWN';
const knownFactLabel = 'KNOWN';
const derivedFactLabel = 'DERIVED';

String factStatusLabel(FactStatus status) => switch (status) {
      FactStatus.known => knownFactLabel,
      FactStatus.derived => derivedFactLabel,
      FactStatus.unknown => unknownFactLabel,
    };

String deviceManufacturer(DeviceProfileV2 profile) {
  return profile.identity.manufacturer.value ?? 'Manufacturer unknown';
}

/// "Watch GT 4 · 46 mm" or "GTS 4" when the variant is unknown.
String deviceModelLine(DeviceProfileV2 profile) {
  final family = profile.identity.family.value;
  final model = profile.identity.model.value ?? profile.identity.profileId;
  final variant = profile.identity.variant.value;
  final name =
      family != null && !model.startsWith(family) ? '$family $model' : model;
  return variant == null ? name : '$name · $variant';
}

/// Full display name used under a device stage.
String deviceDisplayName(DeviceProfileV2 profile) {
  final manufacturer = profile.identity.manufacturer.value;
  final line = deviceModelLine(profile);
  return manufacturer == null ? line : '$manufacturer $line';
}

String deviceShortName(DeviceProfileV2 profile) {
  final model = profile.identity.model.value ?? profile.identity.profileId;
  final variant = profile.identity.variant.value;
  return variant == null ? model : '$model $variant';
}

/// "466 × 466" when both raster axes are known, otherwise RASTER UNKNOWN.
String deviceRasterLine(DeviceProfileV2 profile) {
  final width = profile.display.rasterWidth;
  final height = profile.display.rasterHeight;
  if (width.hasValue && height.hasValue) {
    return '${_number(width.value!)} × ${_number(height.value!)}';
  }
  return 'RASTER UNKNOWN';
}

String deviceShapeLine(DeviceProfileV2 profile) {
  final shape = profile.display.shape;
  if (!shape.hasValue) return 'shape unknown';
  final word = switch (shape.value!) {
    ScreenShape.round => 'round',
    ScreenShape.rectangle => 'rectangle',
    ScreenShape.roundedRectangle => 'rounded rectangle',
  };
  return shape.status == FactStatus.derived ? '$word (derived)' : word;
}

/// Only the stage the repository can compute. No tier is inferred from a shell.
String deviceEvidenceStageLabel(DeviceProfileV2 profile) {
  return switch (profileV2EvidenceStage(profile)) {
    SimulatorEvidenceStage.profiled => 'PROFILED',
    SimulatorEvidenceStage.simulationReady => 'SIMULATION READY',
  };
}

String shellFidelityLabel(DeviceProfileV2 profile) {
  final manifest = shellManifestFor(profile);
  final grade = switch (manifest.fidelity) {
    VisualFidelityGrade.schematic => 'SCHEMATIC SHELL',
    VisualFidelityGrade.reference => 'REFERENCE SHELL',
    VisualFidelityGrade.measured => 'MEASURED SHELL',
    VisualFidelityGrade.verifiedAgainstReference => 'VERIFIED SHELL',
  };
  return manifest.apertureIsMeasured ? grade : '$grade · APERTURE NOT MEASURED';
}

/// Compact fidelity line under a Focus stage.
String deviceStageFooterLine(DeviceProfileV2 profile) {
  final viewport = viewportContextFor(profile);
  final basis = viewport.usesNativeLogicalViewport
      ? 'NATIVE LOGICAL VIEWPORT'
      : 'DEGRADED · ${_shortBasis(viewport.basis)}';
  return '${deviceEvidenceStageLabel(profile)} · ${shellFidelityLabel(profile)} · '
      '${deviceRasterLine(profile)} · $basis · UNCALIBRATED VIEW';
}

String _shortBasis(ViewportBasis basis) => switch (basis) {
      ViewportBasis.nativeLogical => 'native logical viewport',
      ViewportBasis.designCoordinateSpace =>
        'design coordinate space, not a native logical viewport',
      ViewportBasis.rasterFallback =>
        'raster fallback, not a native logical viewport',
      ViewportBasis.unavailable => 'no evidenced coordinate space',
    };

String _number(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
