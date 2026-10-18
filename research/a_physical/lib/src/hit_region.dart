import 'dart:math' as math;

/// Declared rectangular hit target in a single linear unit (e.g. logical px).
class HitRegion {
  HitRegion({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  }) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError.value(
        width <= 0 ? width : height,
        width <= 0 ? 'width' : 'height',
        'must be positive',
      );
    }
  }

  final String id;
  final double x;
  final double y;
  final double width;
  final double height;

  double get right => x + width;
  double get bottom => y + height;

  bool overlaps(HitRegion other) {
    if (identical(this, other)) return false;
    return x < other.right &&
        right > other.x &&
        y < other.bottom &&
        bottom > other.y;
  }

  /// Shortest edge-to-edge distance between axis-aligned boxes (0 if overlapping).
  double separationDistanceTo(HitRegion other) {
    final dx = x > other.right
        ? x - other.right
        : other.x > right
            ? other.x - right
            : 0.0;
    final dy = y > other.bottom
        ? y - other.bottom
        : other.y > bottom
            ? other.y - bottom
            : 0.0;
    if (dx == 0 && dy == 0) return 0.0;
    if (dx == 0) return dy;
    if (dy == 0) return dx;
    return math.sqrt(dx * dx + dy * dy);
  }
}
