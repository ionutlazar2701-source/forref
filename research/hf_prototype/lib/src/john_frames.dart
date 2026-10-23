import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:simulator_geometry/simulator_geometry.dart';

import 'lab_theme.dart';

/// Visual hardware shell derived from a Founder-supplied John frame.
///
/// Normalized aperture is the transparent glass cut in the derived PNG.
/// It is presentation geometry, not a measured safe area.
class JohnWatchFrame {
  const JohnWatchFrame({
    required this.asset,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.circular,
    required this.cornerRadiusFactor,
  });

  final String asset;
  final double left;
  final double top;
  final double width;
  final double height;
  final bool circular;
  final double cornerRadiusFactor;

  static const aspect = 1024 / 1536;

  /// Taller rounded rectangle (crown on the right). Source ee2ec25a.
  static const rectangularA = JohnWatchFrame(
    asset:
        'assets/john_design/derived/ee2ec25a-0ada-4fb0-8fd4-6a8c4ad0b756.png',
    left: 161 / 1024,
    top: 341 / 1536,
    width: (855 - 161) / 1024,
    height: (1122 - 341) / 1536,
    circular: false,
    cornerRadiusFactor: 0.12,
  );

  /// Squarer rounded rectangle (buttons on the right). Source 53c9c4d8.
  static const rectangularB = JohnWatchFrame(
    asset:
        'assets/john_design/derived/53c9c4d8-23fe-4321-9239-c7441b29ca55.png',
    left: 153 / 1024,
    top: 330 / 1536,
    width: (863 - 153) / 1024,
    height: (1105 - 330) / 1536,
    circular: false,
    cornerRadiusFactor: 0.16,
  );

  /// Round metal case. Source c89addd2.
  static const round = JohnWatchFrame(
    asset:
        'assets/john_design/derived/c89addd2-9479-444c-837c-dabc2deeb9ea.png',
    left: 138 / 1024,
    top: 355 / 1536,
    width: (872 - 138) / 1024,
    height: (1072 - 355) / 1536,
    circular: true,
    cornerRadiusFactor: 0.5,
  );
}

/// Maps a profile to a supplied frame from case/display shape facts.
///
/// Unknown shape returns null. The schematic shell stays. No brand is inferred
/// from a file name.
JohnWatchFrame? johnFrameForProfile(DeviceProfileV2 profile) {
  final display = profile.display.shape;
  final caseShape = profile.caseFacts.shape;
  final shape = display.hasValue
      ? display.value
      : caseShape.hasValue
          ? caseShape.value
          : null;
  if (shape == ScreenShape.round) return JohnWatchFrame.round;
  if (shape == ScreenShape.roundedRectangle) {
    final width = profile.caseFacts.widthMm.value;
    final height = profile.caseFacts.heightMm.value;
    if (width != null && height != null && height > width * 1.05) {
      return JohnWatchFrame.rectangularA;
    }
    return JohnWatchFrame.rectangularB;
  }
  return null;
}

/// Live child under a cached hardware overlay. The overlay ignores pointers.
class PhotographicWatchFrame extends StatelessWidget {
  const PhotographicWatchFrame({
    super.key,
    required this.frame,
    required this.child,
  });

  final JohnWatchFrame frame;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0;
        final maxH = constraints.maxHeight.isFinite ? constraints.maxHeight : 520.0;
        // Fill the card width with the case. The strap may clip. The live
        // aperture stays large enough to read.
        var width = maxW;
        var height = width / JohnWatchFrame.aspect;
        if (frame.height * height > maxH * 0.92) {
          height = (maxH * 0.92) / frame.height;
          width = height * JohnWatchFrame.aspect;
        }
        if (width > maxW) {
          width = maxW;
          height = width / JohnWatchFrame.aspect;
        }
        final apertureCenterX = (frame.left + frame.width / 2) * width;
        final apertureCenterY = (frame.top + frame.height / 2) * height;
        final dx = maxW / 2 - apertureCenterX;
        final dy = maxH / 2 - apertureCenterY;
        return ClipRect(
          child: Stack(
            children: [
              Positioned(
                left: dx + frame.left * width,
                top: dy + frame.top * height,
                width: frame.width * width,
                height: frame.height * height,
                child: ClipPath(
                  clipper: _ApertureClipper(frame),
                  child: child,
                ),
              ),
              Positioned(
                left: dx,
                top: dy,
                width: width,
                height: height,
                child: IgnorePointer(
                  child: Image.asset(
                    frame.asset,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ApertureClipper extends CustomClipper<Path> {
  _ApertureClipper(this.frame);

  final JohnWatchFrame frame;

  @override
  Path getClip(Size size) {
    if (frame.circular) {
      return Path()..addOval(Offset.zero & size);
    }
    final radius = math.min(size.width, size.height) * frame.cornerRadiusFactor;
    return Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
  }

  @override
  bool shouldReclip(covariant _ApertureClipper oldClipper) =>
      oldClipper.frame.asset != frame.asset;
}

/// Dark phone bezel. The child is the live Flutter surface, not a screenshot.
class PhoneBezel extends StatelessWidget {
  const PhoneBezel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: const Color(0xFF3C3C3C), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33081E36),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(9, 10, 9, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: ColoredBox(
            color: LabColors.softWhite,
            child: Column(
              children: [
                const _PhoneStatusBar(),
                Expanded(child: child),
                const SizedBox(
                  height: 14,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.all(Radius.circular(3)),
                      ),
                      child: SizedBox(width: 72, height: 4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhoneStatusBar extends StatelessWidget {
  const _PhoneStatusBar();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF10283F),
      child: SizedBox(
        height: 28,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Text(
                    'FORREF',
                    style: TextStyle(
                      color: Color(0xFFF4F9FC),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.signal_cellular_alt, size: 12, color: Color(0xFFF4F9FC)),
                ],
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF141414),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: SizedBox(width: 72, height: 16),
            ),
          ],
        ),
      ),
    );
  }
}
