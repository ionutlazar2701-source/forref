import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:simulator_geometry/simulator_geometry.dart';

import 'lab_theme.dart';

/// Hardware shell with the child mounted inside the display aperture.
///
/// The shell paints metal, straps, and control marks. It does not own the
/// child's hit testing. Bezel, strap, and dead-corner pointers are rejected.
class DeviceShellStage extends StatefulWidget {
  const DeviceShellStage({
    super.key,
    required this.profile,
    this.child,
    this.interactive = true,
    this.stamp = '',
    this.onPointerCancel,
    this.onRejected,
  });

  final DeviceProfileV2 profile;
  final Widget? child;
  final bool interactive;
  final String stamp;
  final void Function(int pointerId)? onPointerCancel;
  final void Function(ShellSurface surface)? onRejected;

  @override
  State<DeviceShellStage> createState() => _DeviceShellStageState();
}

class _DeviceShellStageState extends State<DeviceShellStage> {
  final Set<int> _pointers = {};
  late DeviceShellManifest _manifest;

  @override
  void initState() {
    super.initState();
    _manifest = shellManifestFor(widget.profile);
  }

  @override
  void didUpdateWidget(DeviceShellStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = shellManifestFor(widget.profile);
    if (next.profileId != _manifest.profileId) {
      for (final pointerId in _pointers.toList()) {
        widget.onPointerCancel?.call(pointerId);
      }
      _pointers.clear();
    }
    _manifest = next;
  }

  @override
  Widget build(BuildContext context) {
    final manifest = _manifest;
    final viewport = viewportContextFor(widget.profile);
    final child = widget.child ??
        DiagnosticViewport(
          manifest: manifest,
          viewport: viewport,
          stamp: widget.stamp,
        );
    final name = _shortName(widget.profile);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          name,
          key: Key('shell-caption-${manifest.profileId}'),
          style: const TextStyle(
            color: LabColors.navy,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            fontFamily: 'Roboto',
          ),
        ),
        Text(
          'Fidelity: schematic · not measured · not certified',
          style: const TextStyle(
            color: LabColors.navy,
            fontSize: 14,
            fontFamily: 'Roboto',
          ),
        ),
        Text(
          manifest.apertureEvidence,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: LabColors.steel,
            fontSize: 12,
            height: 1.25,
            fontFamily: 'Roboto',
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fitted = _fit(manifest, constraints.maxWidth, constraints.maxHeight);
              return Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (event) => _track(event.localPosition, event.pointer, fitted, down: true),
                onPointerUp: (event) => _track(event.localPosition, event.pointer, fitted, down: false),
                onPointerCancel: (event) {
                  _pointers.remove(event.pointer);
                  widget.onPointerCancel?.call(event.pointer);
                },
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        key: const Key('shell-paint'),
                        painter: _ShellPainter(manifest: manifest, fit: fitted),
                      ),
                    ),
                    Positioned(
                      left: fitted.originX + manifest.aperture.left * fitted.scale,
                      top: fitted.originY + manifest.aperture.top * fitted.scale,
                      width: manifest.aperture.width * fitted.scale,
                      height: manifest.aperture.height * fitted.scale,
                      child: ClipPath(
                        clipBehavior: Clip.antiAlias,
                        clipper: _ApertureClipper(manifest),
                        child: IgnorePointer(
                          ignoring: !widget.interactive,
                          child: child,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _track(Offset local, int pointerId, _ShellFit fitted, {required bool down}) {
    if (!down) {
      _pointers.remove(pointerId);
      return;
    }
    _pointers.add(pointerId);
    final canvas = fitted.toCanvas(local);
    final surface = shellSurfaceAt(_manifest, canvas.dx, canvas.dy);
    if (surface != ShellSurface.aperture) {
      widget.onRejected?.call(surface);
    }
  }
}

class DiagnosticViewport extends StatelessWidget {
  const DiagnosticViewport({
    super.key,
    required this.manifest,
    required this.viewport,
    required this.stamp,
  });

  final DeviceShellManifest manifest;
  final ProfileViewportContext viewport;
  final String stamp;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: LabColors.navy,
      fontSize: 13,
      height: 1.2,
      fontFamily: 'Roboto',
    );
    return ColoredBox(
      color: LabColors.softWhite,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              manifest.profileId,
              textAlign: TextAlign.center,
              style: style.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const Text('DIAGNOSTIC VIEWPORT', textAlign: TextAlign.center, style: style),
            const Text('Runtime: Research', textAlign: TextAlign.center, style: style),
            Text(
              'Fidelity: ${manifest.fidelity.name}',
              textAlign: TextAlign.center,
              style: style,
            ),
            Text(viewport.safeAreaLabel, textAlign: TextAlign.center, style: style),
            Text(
              viewport.basisLabel,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: style.copyWith(color: LabColors.steel, fontSize: 11),
            ),
            if (stamp.isNotEmpty)
              Text(
                stamp,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: style.copyWith(color: LabColors.steel, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShellFit {
  const _ShellFit({
    required this.scale,
    required this.originX,
    required this.originY,
  });

  final double scale;
  final double originX;
  final double originY;

  Offset toCanvas(Offset local) {
    return Offset(
      (local.dx - originX) / scale,
      (local.dy - originY) / scale,
    );
  }
}

_ShellFit _fit(DeviceShellManifest manifest, double width, double height) {
  if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
    return const _ShellFit(scale: 1, originX: 0, originY: 0);
  }
  final scale = math.min(width / manifest.canvasWidth, height / manifest.canvasHeight);
  final drawnW = manifest.canvasWidth * scale;
  final drawnH = manifest.canvasHeight * scale;
  return _ShellFit(
    scale: scale,
    originX: (width - drawnW) / 2,
    originY: (height - drawnH) / 2,
  );
}

class _ApertureClipper extends CustomClipper<Path> {
  _ApertureClipper(this.manifest);

  final DeviceShellManifest manifest;

  @override
  Path getClip(Size size) {
    final rect = Offset.zero & size;
    return switch (manifest.clip) {
      ScreenShape.round => Path()..addOval(rect),
      ScreenShape.rectangle => Path()..addRect(rect),
      ScreenShape.roundedRectangle => Path()..addRRect(
          RRect.fromRectAndRadius(
            rect,
            Radius.circular(_scaledRadius(size)),
          ),
        ),
    };
  }

  double _scaledRadius(Size size) {
    final radius = manifest.cornerRadius;
    if (radius == null || manifest.aperture.width <= 0) return 0;
    return radius / manifest.aperture.width * size.width;
  }

  @override
  bool shouldReclip(covariant _ApertureClipper oldClipper) {
    return oldClipper.manifest.profileId != manifest.profileId;
  }
}

class _ShellPainter extends CustomPainter {
  _ShellPainter({required this.manifest, required this.fit});

  final DeviceShellManifest manifest;
  final _ShellFit fit;

  @override
  void paint(Canvas canvas, Size size) {
    final body = _rect(manifest.body);
    final paint = Paint()..color = _bodyColor(manifest);
    if (manifest.clip == ScreenShape.round && manifest.canvasUnit.startsWith('millimetre')) {
      canvas.drawOval(body, paint);
    } else if (manifest.canvasUnit.contains('plate')) {
      final stroke = Paint()
        ..color = LabColors.steel
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(8)), stroke);
    } else {
      final radius = manifest.cornerRadius == null
          ? 10.0
          : manifest.cornerRadius! * fit.scale + 6;
      canvas.drawRRect(RRect.fromRectAndRadius(body, Radius.circular(radius)), paint);
    }
    final strapPaint = Paint()..color = const Color(0xFF6E6258);
    for (final strap in manifest.straps) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(_rect(strap), const Radius.circular(6)),
        strapPaint,
      );
    }
    final control = Paint()..color = const Color(0xFF8D97A3);
    for (final anchor in manifest.controls) {
      final center = Offset(
        fit.originX + anchor.x * fit.scale,
        fit.originY + anchor.y * fit.scale,
      );
      canvas.drawCircle(center, anchor.id == 'crown' ? 7 : 5, control);
    }
  }

  Rect _rect(ShellBounds bounds) {
    return Rect.fromLTWH(
      fit.originX + bounds.left * fit.scale,
      fit.originY + bounds.top * fit.scale,
      bounds.width * fit.scale,
      bounds.height * fit.scale,
    );
  }

  @override
  bool shouldRepaint(covariant _ShellPainter oldDelegate) {
    return oldDelegate.manifest.profileId != manifest.profileId ||
        oldDelegate.fit.scale != fit.scale;
  }
}

String _shortName(DeviceProfileV2 profile) {
  final manufacturer = profile.identity.manufacturer.value ?? 'Unknown manufacturer';
  final model = profile.identity.model.value ?? profile.identity.profileId;
  final variant = profile.identity.variant.value;
  if (variant == null) return '$manufacturer $model';
  return '$manufacturer $model $variant';
}

Color _bodyColor(DeviceShellManifest manifest) {
  if (manifest.canvasUnit.contains('plate')) return const Color(0xFFE8EEF4);
  if (manifest.clip == ScreenShape.round) return const Color(0xFF1C1F24);
  if (manifest.canvasUnit.contains('not millimetres')) return const Color(0xFF2C333A);
  return const Color(0xFFE4DDD4);
}
