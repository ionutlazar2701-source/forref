import 'dart:math' as math;

import 'profile.dart';

/// Device-logical point.
final class DevicePoint {
  const DevicePoint(this.x, this.y);

  final double x;
  final double y;
}

/// Point in the simulator stage, after letterboxing.
final class StagePoint {
  const StagePoint(this.x, this.y);

  final double x;
  final double y;
}

/// Host pointer before it is mapped into the stage.
final class HostPoint {
  const HostPoint(this.x, this.y);

  final double x;
  final double y;
}

final class DeviceRect {
  const DeviceRect(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  bool contains(double x, double y) {
    return x >= left && y >= top && x < right && y < bottom;
  }

  bool overlaps(DeviceRect other) {
    return left < other.right &&
        other.left < right &&
        top < other.bottom &&
        other.top < bottom;
  }
}

/// Axis-aligned rectangle in stage space.
final class StageRect {
  const StageRect(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;
}

final class ViewportGeometry {
  const ViewportGeometry({
    required this.shape,
    required this.width,
    required this.height,
    required this.safeLeft,
    required this.safeTop,
    required this.safeRight,
    required this.safeBottom,
    required this.cornerRadius,
    required this.circularInset,
  });

  final ScreenShape shape;
  final double width;
  final double height;
  final double safeLeft;
  final double safeTop;
  final double safeRight;
  final double safeBottom;
  final double cornerRadius;
  final double circularInset;

  bool containsVisible(double x, double y) {
    if (!_finite(x) || !_finite(y)) return false;
    return switch (shape) {
      ScreenShape.rectangle => _inRect(x, y, 0, 0, width, height),
      ScreenShape.round => _inCircle(x, y, width / 2, height / 2, width / 2),
      ScreenShape.roundedRectangle =>
        _inRounded(x, y, width, height, cornerRadius),
    };
  }

  bool containsSafe(double x, double y) {
    if (!containsVisible(x, y)) return false;
    return switch (shape) {
      ScreenShape.rectangle || ScreenShape.roundedRectangle => _inRect(
          x,
          y,
          safeLeft,
          safeTop,
          width - safeRight,
          height - safeBottom,
        ),
      ScreenShape.round => _inCircle(
          x,
          y,
          width / 2,
          height / 2,
          width / 2 - circularInset,
        ),
    };
  }

  bool rectInsideSafe(DeviceRect rect) {
    if (rect.width <= 0 || rect.height <= 0) return false;
    return containsSafe(rect.left, rect.top) &&
        containsSafe(rect.right - 0.001, rect.top) &&
        containsSafe(rect.left, rect.bottom - 0.001) &&
        containsSafe(rect.right - 0.001, rect.bottom - 0.001);
  }
}

bool _finite(double value) => value.isFinite;

bool _inRect(double x, double y, double left, double top, double right, double bottom) {
  return x >= left && y >= top && x < right && y < bottom;
}

bool _inCircle(double x, double y, double cx, double cy, double radius) {
  if (radius <= 0) return false;
  final dx = x - cx;
  final dy = y - cy;
  return dx * dx + dy * dy <= radius * radius;
}

bool _inRounded(double x, double y, double width, double height, double radius) {
  if (!_inRect(x, y, 0, 0, width, height)) return false;
  if (radius <= 0) return true;
  final left = x < radius;
  final right = x > width - radius;
  final top = y < radius;
  final bottom = y > height - radius;
  if (left && top) {
    return _inCircle(x, y, radius, radius, radius);
  }
  if (right && top) {
    return _inCircle(x, y, width - radius, radius, radius);
  }
  if (left && bottom) {
    return _inCircle(x, y, radius, height - radius, radius);
  }
  if (right && bottom) {
    return _inCircle(x, y, width - radius, height - radius, radius);
  }
  return true;
}

ViewportGeometry viewportFor(DeviceProfile profile) {
  final safe = profile.safeArea;
  return ViewportGeometry(
    shape: profile.screenShape,
    width: profile.logicalWidth,
    height: profile.logicalHeight,
    safeLeft: safe.left,
    safeTop: safe.top,
    safeRight: safe.right,
    safeBottom: safe.bottom,
    cornerRadius: profile.cornerRadius,
    circularInset: safe.circularInset ?? 0,
  );
}

enum CalibrationMode { fit, raster1to1, physical1to1 }

/// Runtime knowledge about the host display.
///
/// Null fields are unknown. A device profile cannot fill these in.
final class HostDisplayEvidence {
  const HostDisplayEvidence({
    this.devicePixelRatio,
    this.millimetresPerLogicalPixel,
  });

  static const unknown = HostDisplayEvidence();

  final double? devicePixelRatio;
  final double? millimetresPerLogicalPixel;

  bool get hasDevicePixelRatio =>
      devicePixelRatio != null &&
      devicePixelRatio!.isFinite &&
      devicePixelRatio! > 0;

  bool get hasMillimetres =>
      millimetresPerLogicalPixel != null &&
      millimetresPerLogicalPixel!.isFinite &&
      millimetresPerLogicalPixel! > 0;
}

final class ViewTransform {
  const ViewTransform({
    required this.scale,
    required this.originX,
    required this.originY,
    required this.deviceWidth,
    required this.deviceHeight,
  });

  final double scale;
  final double originX;
  final double originY;
  final double deviceWidth;
  final double deviceHeight;

  StagePoint toStage(DevicePoint device) {
    return StagePoint(
      originX + device.x * scale,
      originY + device.y * scale,
    );
  }

  DevicePoint toDevice(StagePoint stage) {
    return DevicePoint(
      (stage.x - originX) / scale,
      (stage.y - originY) / scale,
    );
  }

  StageRect toStageRect(DeviceRect rect) {
    return StageRect(
      originX + rect.left * scale,
      originY + rect.top * scale,
      rect.width * scale,
      rect.height * scale,
    );
  }
}

final class ViewAssessment {
  const ViewAssessment({
    required this.requested,
    required this.requestHonored,
    required this.calibrationLabel,
    required this.physicalFidelityLabel,
    required this.transform,
    required this.usable,
    required this.zoomAccepted,
  });

  final CalibrationMode requested;
  final bool requestHonored;
  final String calibrationLabel;
  final String physicalFidelityLabel;
  final ViewTransform transform;
  final bool usable;
  final bool zoomAccepted;

  bool get showsFit => requestHonored && requested == CalibrationMode.fit;
}

const String notCalibratedLabel = 'NOT CALIBRATED';
const String physicalTargetUnknownLabel = 'PHYSICAL TARGET SIZE UNKNOWN';

final class PhysicalTargetSize {
  const PhysicalTargetSize(this.widthMm, this.heightMm);

  final double widthMm;
  final double heightMm;
}

ViewAssessment assessView({
  required DeviceProfile profile,
  required double stageWidth,
  required double stageHeight,
  required CalibrationMode requested,
  HostDisplayEvidence host = HostDisplayEvidence.unknown,
  double zoom = 1,
}) {
  final zoomAccepted = zoom.isFinite && zoom >= 0.25 && zoom <= 3;
  final usableStage = stageWidth.isFinite &&
      stageHeight.isFinite &&
      stageWidth > 0 &&
      stageHeight > 0 &&
      profile.logicalWidth > 0 &&
      profile.logicalHeight > 0;
  if (!usableStage) {
    return ViewAssessment(
      requested: requested,
      requestHonored: false,
      calibrationLabel: notCalibratedLabel,
      physicalFidelityLabel: notCalibratedLabel,
      transform: const ViewTransform(
        scale: 1,
        originX: 0,
        originY: 0,
        deviceWidth: 1,
        deviceHeight: 1,
      ),
      usable: false,
      zoomAccepted: zoomAccepted,
    );
  }

  final appliedZoom = zoomAccepted ? zoom : 1.0;
  final zoomIsNeutral = appliedZoom == 1;
  final modeAvailable = _honor(profile, host, requested);
  final honored = modeAvailable &&
      (requested == CalibrationMode.fit || zoomIsNeutral);
  final baseScale = honored && requested != CalibrationMode.fit
      ? _honoredScale(profile, host, requested)
      : _fitScale(
          profile.logicalWidth,
          profile.logicalHeight,
          stageWidth,
          stageHeight,
        );
  final scale = baseScale * appliedZoom;
  final drawnWidth = profile.logicalWidth * scale;
  final drawnHeight = profile.logicalHeight * scale;
  final transform = ViewTransform(
    scale: scale,
    originX: (stageWidth - drawnWidth) / 2,
    originY: (stageHeight - drawnHeight) / 2,
    deviceWidth: profile.logicalWidth,
    deviceHeight: profile.logicalHeight,
  );
  final physicalHonored = honored && requested == CalibrationMode.physical1to1;
  return ViewAssessment(
    requested: requested,
    requestHonored: honored,
    calibrationLabel: honored ? _modeLabel(requested) : notCalibratedLabel,
    physicalFidelityLabel: physicalHonored ? _modeLabel(requested) : notCalibratedLabel,
    transform: transform,
    usable: scale.isFinite && scale > 0,
    zoomAccepted: zoomAccepted,
  );
}

bool _honor(DeviceProfile profile, HostDisplayEvidence host, CalibrationMode mode) {
  return switch (mode) {
    CalibrationMode.fit => true,
    CalibrationMode.raster1to1 =>
      profile.raster.known && host.hasDevicePixelRatio,
    CalibrationMode.physical1to1 =>
      profile.physicalMillimetres.known &&
          host.hasMillimetres &&
          _uniformPixels(profile),
  };
}

bool _uniformPixels(DeviceProfile profile) {
  final physical = profile.physicalMillimetres;
  if (!physical.known || physical.width == null || physical.height == null) {
    return false;
  }
  final x = physical.width! / profile.logicalWidth;
  final y = physical.height! / profile.logicalHeight;
  return (x - y).abs() <= 0.01;
}

double _fitScale(double deviceWidth, double deviceHeight, double stageWidth, double stageHeight) {
  return math.min(stageWidth / deviceWidth, stageHeight / deviceHeight);
}

double _honoredScale(
  DeviceProfile profile,
  HostDisplayEvidence host,
  CalibrationMode mode,
) {
  return switch (mode) {
    CalibrationMode.fit => throw StateError('FIT uses the stage fit scale.'),
    CalibrationMode.raster1to1 =>
      (profile.raster.width! / profile.logicalWidth) / host.devicePixelRatio!,
    CalibrationMode.physical1to1 =>
      (profile.physicalMillimetres.width! / profile.logicalWidth) /
          host.millimetresPerLogicalPixel!,
  };
}

String _modeLabel(CalibrationMode mode) {
  return switch (mode) {
    CalibrationMode.fit => 'FIT',
    CalibrationMode.raster1to1 => 'RASTER_1_TO_1',
    CalibrationMode.physical1to1 => 'PHYSICAL_1_TO_1',
  };
}

/// Millimetres on the represented device, not on the host screen.
PhysicalTargetSize? physicalTargetSize({
  required DeviceProfile profile,
  required DeviceRect rect,
}) {
  final physical = profile.physicalMillimetres;
  if (!physical.known || physical.width == null || physical.height == null) {
    return null;
  }
  if (profile.classification != EvidenceClassification.factual) return null;
  return PhysicalTargetSize(
    rect.width * (physical.width! / profile.logicalWidth),
    rect.height * (physical.height! / profile.logicalHeight),
  );
}

StagePoint hostToStage(HostPoint host, {required double stageOriginX, required double stageOriginY}) {
  return StagePoint(host.x - stageOriginX, host.y - stageOriginY);
}

/// Evidence stage assigned by the simulator, never by profile JSON.
SimulatorEvidenceStage evidenceStageFor({
  required bool geometryAcceptsProfile,
  required bool layoutFits,
}) {
  if (geometryAcceptsProfile && layoutFits) {
    return SimulatorEvidenceStage.simulationReady;
  }
  return SimulatorEvidenceStage.profiled;
}
