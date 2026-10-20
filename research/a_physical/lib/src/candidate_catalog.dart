import 'geometry_checker.dart';
import 'geometry_result.dart';
import 'watch_geometry_profile.dart';

/// Uncertified rental candidates from [docs/hardware-test-matrix.md].
///
/// These are declarations only — no pixel sizes or touch maps.
List<WatchGeometryProfile> uncertifiedWatchCandidates() {
  return [
    WatchGeometryProfile(
      deviceLabel: 'Galaxy Watch 6/7/FE/8 44mm Wear OS',
      status: WatchProfileStatus.uncertifiedCandidate,
      regions: [],
    ),
    WatchGeometryProfile(
      deviceLabel: 'Pixel Watch 2/3/4 41mm Wear OS',
      status: WatchProfileStatus.uncertifiedCandidate,
      regions: [],
    ),
    WatchGeometryProfile(
      deviceLabel: 'Apple Watch SE 44mm',
      status: WatchProfileStatus.uncertifiedCandidate,
      regions: [],
    ),
    WatchGeometryProfile(
      deviceLabel: 'Garmin Forerunner 255',
      status: WatchProfileStatus.uncertifiedCandidate,
      regions: [],
    ),
  ];
}

/// Checker outcome when only the uncertified candidate catalog is supplied.
GeometryCheckResult checkCandidateCatalog() {
  const checker = WatchHitGeometryChecker();
  return checker.checkMeasuredMatrix(uncertifiedWatchCandidates());
}
