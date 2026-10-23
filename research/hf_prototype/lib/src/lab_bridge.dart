import 'package:hf_v2/hf_v2.dart';
import 'package:simulator_geometry/simulator_geometry.dart';

/// Phone rectangles accepted by the Session III instrument.
///
/// They are used only when they fit the active profile's safe geometry.
const researchActionSlots = <ActionSlot>[
  ActionSlot(
    id: 'yellow',
    preferred: DeviceRect(16, 180, 150, 48),
    minimumWidth: minimumActionExtent,
    minimumHeight: minimumActionExtent,
  ),
  ActionSlot(
    id: 'sendOff',
    preferred: DeviceRect(220, 180, 160, 48),
    minimumWidth: minimumActionExtent,
    minimumHeight: minimumActionExtent,
  ),
  ActionSlot(
    id: 'substitution',
    preferred: DeviceRect(16, 250, 200, 48),
    minimumWidth: minimumActionExtent,
    minimumHeight: minimumActionExtent,
  ),
];

const researchRosterSlot = ActionSlot(
  id: 'roster',
  preferred: DeviceRect(16, 8, 320, 150),
  minimumWidth: minimumActionExtent,
  minimumHeight: minimumActionExtent,
);

const unreachableResearchLayout = ResearchLayout(
  yellow: ResearchRect(-10000, -10000, 48, 48),
  sendOff: ResearchRect(-10000, -9000, 48, 48),
  substitution: ResearchRect(-10000, -8000, 48, 48),
  roster: ResearchRect(-10000, -7000, 48, 48),
);

LayoutResolution placementFor(DeviceProfile profile) {
  return resolveActionLayout(
    viewport: viewportFor(profile),
    actions: researchActionSlots,
    roster: researchRosterSlot,
  );
}

ResearchLayout researchLayoutFrom(LayoutResolution placement) {
  ResearchRect to(DeviceRect rect) {
    return ResearchRect(rect.left, rect.top, rect.width, rect.height);
  }

  final roster = placement.rects['roster'] ?? const DeviceRect(-1000, -1000, 48, 48);
  return ResearchLayout(
    yellow: to(placement.rects['yellow']!),
    sendOff: to(placement.rects['sendOff']!),
    substitution: to(placement.rects['substitution']!),
    roster: to(roster),
  );
}

String shortProfileLabel(DeviceProfile profile) {
  return switch (profile.profileId) {
    'illustrative-phone-portrait' => 'Phone profile',
    'illustrative-round-watch' => 'Round watch',
    'illustrative-rectangular-watch' => 'Rectangular watch',
    _ => profile.displayName,
  };
}
