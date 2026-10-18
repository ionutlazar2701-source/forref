import 'hit_region.dart';

/// Central Instrument region identifiers (fixed set).
abstract final class CentralInstrumentRegionIds {
  static const timePhase = 'timePhase';
  static const score = 'score';
  static const capture = 'capture';
  static const cautions = 'cautions';

  static const requiredIds = <String>{
    timePhase,
    score,
    capture,
    cautions,
  };
}

/// Rental / lab catalog entry — not a measured device matrix row.
enum WatchProfileStatus {
  uncertifiedCandidate,
}

/// Declared or measured watch hit-region layout.
class WatchGeometryProfile {
  WatchGeometryProfile({
    required this.deviceLabel,
    required this.status,
    required this.regions,
    this.viewportWidth,
    this.viewportHeight,
    this.interRegionGap,
    this.edgeClearance,
    this.operatorSuppliedMeasurement = false,
  });

  final String deviceLabel;
  final WatchProfileStatus status;
  final List<HitRegion> regions;

  /// Viewport bounds. Both must be finite and positive before a profile
  /// can be ready for a physical gate. A missing side is not a pass.
  final double? viewportWidth;
  final double? viewportHeight;

  /// Declared minimum separation between region edges.
  final double? interRegionGap;

  /// Declared inset from viewport edges; null if unknown.
  final double? edgeClearance;

  /// True only when an operator measured this profile for physical gating.
  final bool operatorSuppliedMeasurement;
}
