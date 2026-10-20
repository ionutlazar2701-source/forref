import 'geometry.dart';

/// Bump when preferred placement or the fallback column changes meaning.
const int layoutPolicyVersion = 1;

/// Smallest logical action control this research layout will present.
const double minimumActionExtent = 48;

const String layoutNotFitLabel = 'LAYOUT NOT FIT FOR THIS PROFILE';

final class ActionSlot {
  const ActionSlot({
    required this.id,
    required this.preferred,
    required this.minimumWidth,
    required this.minimumHeight,
  });

  final String id;
  final DeviceRect preferred;
  final double minimumWidth;
  final double minimumHeight;
}

final class LayoutResolution {
  const LayoutResolution({
    required this.policyVersion,
    required this.fits,
    required this.usedPreferred,
    required this.label,
    required this.rects,
  });

  final int policyVersion;
  final bool fits;
  final bool usedPreferred;
  final String label;
  final Map<String, DeviceRect> rects;

  static const notFit = LayoutResolution(
    policyVersion: layoutPolicyVersion,
    fits: false,
    usedPreferred: false,
    label: layoutNotFitLabel,
    rects: {},
  );
}

/// Places action rectangles in device-logical coordinates.
///
/// Preferred rectangles are kept when every one of them sits inside the safe
/// region at or above its minimum. Otherwise a column at the minimum extent
/// is tried. The column is not a shrunk copy of an unsafe control.
LayoutResolution resolveActionLayout({
  required ViewportGeometry viewport,
  required List<ActionSlot> actions,
  ActionSlot? roster,
}) {
  if (actions.isEmpty) return LayoutResolution.notFit;
  if (_preferredFits(viewport, actions, roster)) {
    return LayoutResolution(
      policyVersion: layoutPolicyVersion,
      fits: true,
      usedPreferred: true,
      label: 'PREFERRED',
      rects: {
        for (final slot in actions) slot.id: slot.preferred,
        if (roster != null) roster.id: roster.preferred,
      },
    );
  }

  final readable = _column(viewport, actions, 112, minimumActionExtent);
  final minimum = readable ??
      _column(viewport, actions, minimumActionExtent, minimumActionExtent);
  if (minimum == null) return LayoutResolution.notFit;
  return LayoutResolution(
    policyVersion: layoutPolicyVersion,
    fits: true,
    usedPreferred: false,
    label: 'BOUNDED',
    rects: {
      ...minimum,
      if (roster != null) roster.id: const DeviceRect(-1000, -1000, 48, 48),
    },
  );
}

bool _preferredFits(
  ViewportGeometry viewport,
  List<ActionSlot> actions,
  ActionSlot? roster,
) {
  final rects = <DeviceRect>[];
  for (final slot in actions) {
    final rect = slot.preferred;
    if (rect.width < slot.minimumWidth || rect.height < slot.minimumHeight) {
      return false;
    }
    if (!viewport.rectInsideSafe(rect)) return false;
    rects.add(rect);
  }
  if (roster != null) {
    if (!viewport.rectInsideSafe(roster.preferred)) return false;
    rects.add(roster.preferred);
  }
  for (var i = 0; i < rects.length; i++) {
    for (var j = i + 1; j < rects.length; j++) {
      if (rects[i].overlaps(rects[j])) return false;
    }
  }
  return true;
}

Map<String, DeviceRect>? _column(
  ViewportGeometry viewport,
  List<ActionSlot> actions,
  double width,
  double height,
) {
  if (width < minimumActionExtent || height < minimumActionExtent) return null;
  const gap = 8.0;
  final totalHeight = actions.length * height + (actions.length - 1) * gap;
  final left = (viewport.width - width) / 2;
  final top = (viewport.height - totalHeight) / 2;
  final placed = <String, DeviceRect>{};
  for (var i = 0; i < actions.length; i++) {
    final rect = DeviceRect(left, top + i * (height + gap), width, height);
    if (!viewport.rectInsideSafe(rect)) return null;
    placed[actions[i].id] = rect;
  }
  final values = placed.values.toList();
  for (var i = 0; i < values.length; i++) {
    for (var j = i + 1; j < values.length; j++) {
      if (values[i].overlaps(values[j])) return null;
    }
  }
  return placed;
}
