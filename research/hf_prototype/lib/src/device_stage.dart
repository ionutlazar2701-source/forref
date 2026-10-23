import 'package:flutter/material.dart';
import 'package:simulator_geometry/simulator_geometry.dart';

import 'lab_theme.dart';

class DeviceStage extends StatelessWidget {
  const DeviceStage({
    super.key,
    required this.profile,
    required this.placement,
    required this.interactive,
    required this.calibration,
    required this.zoom,
    required this.host,
    required this.showYellow,
    required this.showSendOff,
    required this.showSubstitution,
    required this.onDeviceDown,
    required this.onDeviceUp,
    required this.onDeviceCancel,
  });

  final DeviceProfile profile;
  final LayoutResolution placement;
  final bool interactive;
  final CalibrationMode calibration;
  final double zoom;
  final HostDisplayEvidence host;
  final bool showYellow;
  final bool showSendOff;
  final bool showSubstitution;
  final void Function(double x, double y, int pointerId, bool inside) onDeviceDown;
  final void Function(double x, double y, int pointerId) onDeviceUp;
  final void Function(int pointerId) onDeviceCancel;

  @override
  Widget build(BuildContext context) {
    final geometry = viewportFor(profile);
    final probe = assessView(
      profile: profile,
      stageWidth: 400,
      stageHeight: 400,
      requested: calibration,
      host: host,
      zoom: zoom,
    );
    final stage = evidenceStageFor(
      geometryAcceptsProfile: true,
      layoutFits: placement.fits,
    );
    final touch = profile.capability(InputChannel.touchscreen);
    final target = physicalTargetSize(
      profile: profile,
      rect: const DeviceRect(0, 0, minimumActionExtent, minimumActionExtent),
    );
    final lines = [
      interactive ? 'ACTIVE' : 'READ ONLY',
      shortShape(profile),
      profile.classification == EvidenceClassification.illustrative
          ? 'ILLUSTRATIVE — dimensions are not a measured product'
          : 'FACTUAL — provenance attached — not certified',
      'Calibration: ${probe.calibrationLabel}',
      'Physical fidelity: ${probe.physicalFidelityLabel}',
      target == null
          ? physicalTargetUnknownLabel
          : 'Target ${target.widthMm.toStringAsFixed(1)} x ${target.heightMm.toStringAsFixed(1)} mm',
      stage == SimulatorEvidenceStage.simulationReady
          ? 'Evidence: PROFILED · SIMULATION READY'
          : 'Evidence: PROFILED',
      'Platform: not claimed',
      'Certification: not claimed',
      'Touch: ${touch.name}',
      'Safe area shown',
    ];
    return LayoutBuilder(
      builder: (context, outer) {
        final available = outer.maxHeight.isFinite ? outer.maxHeight : 400.0;
        final headerHeight = available > 220 ? 132.0 : (available * 0.38).clamp(36.0, 132.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: headerHeight,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in lines)
                      Text(
                        line,
                        style: const TextStyle(
                          color: LabColors.navy,
                          fontSize: 11,
                          height: 1.25,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final view = assessView(
                    profile: profile,
                    stageWidth: constraints.maxWidth,
                    stageHeight: constraints.maxHeight,
                    requested: calibration,
                    host: host,
                    zoom: zoom,
                  );
                  return _Viewport(
                    key: interactive
                        ? const Key('research-capture')
                        : Key('mirror-${profile.profileId}'),
                    profile: profile,
                    geometry: geometry,
                    placement: placement,
                    view: view,
                    interactive: interactive,
                    showYellow: showYellow,
                    showSendOff: showSendOff,
                    showSubstitution: showSubstitution,
                    onDeviceDown: onDeviceDown,
                    onDeviceUp: onDeviceUp,
                    onDeviceCancel: onDeviceCancel,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  static String shortShape(DeviceProfile profile) {
    return switch (profile.screenShape) {
      ScreenShape.round => 'Screen shape: round',
      ScreenShape.rectangle => 'Screen shape: rectangle',
      ScreenShape.roundedRectangle => 'Screen shape: rounded rectangle',
    };
  }
}

class _Viewport extends StatelessWidget {
  const _Viewport({
    super.key,
    required this.profile,
    required this.geometry,
    required this.placement,
    required this.view,
    required this.interactive,
    required this.showYellow,
    required this.showSendOff,
    required this.showSubstitution,
    required this.onDeviceDown,
    required this.onDeviceUp,
    required this.onDeviceCancel,
  });

  final DeviceProfile profile;
  final ViewportGeometry geometry;
  final LayoutResolution placement;
  final ViewAssessment view;
  final bool interactive;
  final bool showYellow;
  final bool showSendOff;
  final bool showSubstitution;
  final void Function(double x, double y, int pointerId, bool inside) onDeviceDown;
  final void Function(double x, double y, int pointerId) onDeviceUp;
  final void Function(int pointerId) onDeviceCancel;

  @override
  Widget build(BuildContext context) {
    final transform = view.transform;
    final drawnWidth = profile.logicalWidth * transform.scale;
    final drawnHeight = profile.logicalHeight * transform.scale;
    final viewport = IgnorePointer(
      ignoring: !interactive,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: interactive
            ? (event) => _forward(context, event.position, event.pointer, down: true)
            : null,
        onPointerUp: interactive
            ? (event) => _forward(context, event.position, event.pointer, down: false)
            : null,
        onPointerCancel: interactive ? (event) => onDeviceCancel(event.pointer) : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: LabColors.softWhite),
            if (view.usable)
              Positioned(
                left: transform.originX,
                top: transform.originY,
                width: drawnWidth,
                height: drawnHeight,
                child: ClipPath(
                  clipper: _ShapeClipper(profile),
                  child: ColoredBox(
                    color: LabColors.navy,
                    child: Stack(
                      children: [
                        CustomPaint(
                          painter: _SafeAreaPainter(profile, transform.scale),
                          child: const SizedBox.expand(),
                        ),
                        if (!placement.fits)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                layoutNotFitLabel,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: LabColors.softWhite,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        if (placement.fits && showYellow)
                          _target('yellow', 'Record yellow', transform.scale),
                        if (placement.fits && showSendOff)
                          _target('sendOff', 'Record sending-off', transform.scale),
                        if (placement.fits && showSubstitution)
                          _target('substitution', 'Record substitution', transform.scale),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return viewport;
  }

  void _forward(BuildContext context, Offset global, int pointerId, {required bool down}) {
    if (!view.usable) return;
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final local = box.globalToLocal(global);
    final device = view.transform.toDevice(StagePoint(local.dx, local.dy));
    if (down) {
      final inside = geometry.containsVisible(device.x, device.y) &&
          geometry.containsSafe(device.x, device.y);
      onDeviceDown(device.x, device.y, pointerId, inside);
      return;
    }
    onDeviceUp(device.x, device.y, pointerId);
  }

  Widget _target(String id, String label, double scale) {
    final rect = placement.rects[id];
    if (rect == null) return const SizedBox.shrink();
    return Positioned(
      left: rect.left * scale,
      top: rect.top * scale,
      width: rect.width * scale,
      height: rect.height * scale,
      child: DecoratedBox(
        key: interactive ? Key('target-$id') : null,
        decoration: BoxDecoration(
          color: LabColors.softWhite,
          border: Border.all(color: LabColors.steel, width: 1),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: LabColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShapeClipper extends CustomClipper<Path> {
  _ShapeClipper(this.profile);

  final DeviceProfile profile;

  @override
  Path getClip(Size size) {
    final path = Path();
    switch (profile.screenShape) {
      case ScreenShape.round:
        path.addOval(Offset.zero & size);
      case ScreenShape.rectangle:
        path.addRect(Offset.zero & size);
      case ScreenShape.roundedRectangle:
        final radius = profile.cornerRadius <= 0
            ? Radius.zero
            : Radius.circular(
                profile.cornerRadius / profile.logicalWidth * size.width,
              );
        path.addRRect(RRect.fromRectAndRadius(Offset.zero & size, radius));
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _ShapeClipper oldClipper) {
    return oldClipper.profile.profileId != profile.profileId ||
        oldClipper.profile.cornerRadius != profile.cornerRadius;
  }
}

class _SafeAreaPainter extends CustomPainter {
  _SafeAreaPainter(this.profile, this.scale);

  final DeviceProfile profile;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = LabColors.steel;
    final safe = profile.safeArea;
    if (profile.screenShape == ScreenShape.round) {
      final inset = (safe.circularInset ?? 0) * scale;
      canvas.drawOval(Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2), paint);
      return;
    }
    final rect = Rect.fromLTWH(
      safe.left * scale,
      safe.top * scale,
      size.width - (safe.left + safe.right) * scale,
      size.height - (safe.top + safe.bottom) * scale,
    );
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _SafeAreaPainter oldDelegate) => true;
}
