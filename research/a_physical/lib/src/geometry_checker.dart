import 'geometry_result.dart';
import 'watch_geometry_profile.dart';

/// Fail-closed checker for declared watch hit-region geometry.
class WatchHitGeometryChecker {
  const WatchHitGeometryChecker();

  /// Evaluates a list of profiles intended as the measured device matrix.
  ///
  /// Returns [GeometryCheckResult.deviceMatrixRequired] when no profile is
  /// marked [WatchGeometryProfile.operatorSuppliedMeasurement].
  GeometryCheckResult checkMeasuredMatrix(List<WatchGeometryProfile> profiles) {
    final measured =
        profiles.where((p) => p.operatorSuppliedMeasurement).toList();
    if (measured.isEmpty) {
      return GeometryCheckResult.deviceMatrixRequired;
    }
    for (final profile in measured) {
      final result = checkProfile(profile);
      if (result != GeometryCheckResult.readyForPhysicalGate) {
        return result;
      }
    }
    return GeometryCheckResult.readyForPhysicalGate;
  }

  /// Validates a single profile's internal geometry.
  GeometryCheckResult checkProfile(WatchGeometryProfile profile) {
    if (!profile.operatorSuppliedMeasurement) {
      return GeometryCheckResult.deviceMatrixRequired;
    }

    if (profile.edgeClearance != null && profile.edgeClearance! < 0) {
      return GeometryCheckResult.geometryInconsistent;
    }

    final ids = <String>{};
    for (final region in profile.regions) {
      if (!ids.add(region.id)) {
        return GeometryCheckResult.geometryInconsistent;
      }
    }

    for (final requiredId in CentralInstrumentRegionIds.requiredIds) {
      if (!ids.contains(requiredId)) {
        return GeometryCheckResult.geometryInconsistent;
      }
    }

    final regions = profile.regions;
    for (var i = 0; i < regions.length; i++) {
      for (var j = i + 1; j < regions.length; j++) {
        if (regions[i].overlaps(regions[j])) {
          return GeometryCheckResult.geometryInconsistent;
        }
      }
    }

    final gap = profile.interRegionGap;
    if (gap == null || gap <= 0) {
      return GeometryCheckResult.geometryInconsistent;
    }

    for (var i = 0; i < regions.length; i++) {
      for (var j = i + 1; j < regions.length; j++) {
        if (regions[i].separationDistanceTo(regions[j]) < gap) {
          return GeometryCheckResult.geometryInconsistent;
        }
      }
    }

    final clearance = profile.edgeClearance;
    if (clearance == null) {
      return GeometryCheckResult.geometryInconsistent;
    }

    final vw = profile.viewportWidth;
    final vh = profile.viewportHeight;
    if (vw != null && vh != null) {
      for (final region in regions) {
        if (region.x < clearance ||
            region.y < clearance ||
            region.right > vw - clearance ||
            region.bottom > vh - clearance) {
          return GeometryCheckResult.geometryInconsistent;
        }
      }
    }

    return GeometryCheckResult.readyForPhysicalGate;
  }
}
