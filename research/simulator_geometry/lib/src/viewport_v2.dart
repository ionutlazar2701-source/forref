import 'evidence.dart';
import 'profile.dart';
import 'profile_v2.dart';

/// Which published numbers, if any, size the simulator coordinate space.
enum ViewportBasis {
  nativeLogical,
  designCoordinateSpace,
  rasterFallback,
  unavailable,
}

/// How a profile may be placed in a stage.
///
/// An unknown safe area has no inset numbers. Zero is not substituted.
final class ProfileViewportContext {
  const ProfileViewportContext({
    required this.profileId,
    required this.basis,
    required this.basisLabel,
    required this.width,
    required this.height,
    required this.safeAreaKnown,
    required this.safeAreaLabel,
    required this.clipShape,
    required this.cornerRadiusPx,
    required this.cornerRadiusKnown,
  });

  final String profileId;
  final ViewportBasis basis;
  final String basisLabel;
  final double? width;
  final double? height;
  final bool safeAreaKnown;
  final String safeAreaLabel;
  final ScreenShape? clipShape;
  final double? cornerRadiusPx;
  final bool cornerRadiusKnown;

  bool get hasCoordinateSpace =>
      basis != ViewportBasis.unavailable && width != null && height != null;

  bool get usesNativeLogicalViewport => basis == ViewportBasis.nativeLogical;
}

const String safeAreaUnknownLabel = 'SAFE AREA UNKNOWN';

const String nativeLogicalLabel = 'NATIVE LOGICAL VIEWPORT';

const String designCoordinateLabel =
    'DESIGN COORDINATE SPACE — not a native logical viewport';

const String rasterFallbackLabel =
    'RASTER FALLBACK — not a native logical viewport';

const String viewportUnavailableLabel =
    'VIEWPORT UNAVAILABLE — no evidenced coordinate space';

ProfileViewportContext viewportContextFor(DeviceProfileV2 profile) {
  final display = profile.display;
  final nativeWidth = _positive(display.nativeLogicalWidth);
  final nativeHeight = _positive(display.nativeLogicalHeight);
  final designWidth = _positive(display.designWidth);
  final designHeight = _positive(display.designHeight);
  final rasterWidth = _positive(display.rasterWidth);
  final rasterHeight = _positive(display.rasterHeight);

  late final ViewportBasis basis;
  late final String label;
  late final double? width;
  late final double? height;
  if (nativeWidth != null && nativeHeight != null) {
    basis = ViewportBasis.nativeLogical;
    label = nativeLogicalLabel;
    width = nativeWidth;
    height = nativeHeight;
  } else if (designWidth != null && designHeight != null) {
    basis = ViewportBasis.designCoordinateSpace;
    label = designCoordinateLabel;
    width = designWidth;
    height = designHeight;
  } else if (rasterWidth != null && rasterHeight != null) {
    basis = ViewportBasis.rasterFallback;
    label = rasterFallbackLabel;
    width = rasterWidth;
    height = rasterHeight;
  } else {
    basis = ViewportBasis.unavailable;
    label = viewportUnavailableLabel;
    width = null;
    height = null;
  }

  final shapeFact = display.shape;
  final clip = shapeFact.hasValue ? shapeFact.value : null;
  final radiusFact = display.cornerRadiusPx;
  final radius = radiusFact.hasValue ? radiusFact.value : null;
  final safeKnown = display.safeArea.status != FactStatus.unknown &&
      display.safeArea.value != null;

  return ProfileViewportContext(
    profileId: profile.identity.profileId,
    basis: basis,
    basisLabel: label,
    width: width,
    height: height,
    safeAreaKnown: safeKnown,
    safeAreaLabel: safeKnown ? 'SAFE AREA EVIDENCED' : safeAreaUnknownLabel,
    clipShape: clip,
    cornerRadiusPx: radius,
    cornerRadiusKnown: radius != null,
  );
}

double? _positive(EvidenceFact<double> fact) {
  final value = fact.value;
  if (!fact.hasValue || value == null || !value.isFinite || value <= 0) {
    return null;
  }
  return value;
}
