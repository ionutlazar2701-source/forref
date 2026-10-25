/// Logical-pixel floors inside a simulated aperture.
///
/// These numbers are not millimetres, not a published device safe area,
/// and not a measurement of the ornamental bezel in a source PNG.
abstract final class WatchApertureLimits {
  static const capture = 48.0;
  static const footer = 40.0;
  static const back = 36.0;
  static const family = 44.0;
  static const chip = 36.0;
  static const clock = 28.0;
}

/// Breathing room inside the aperture the shell already clipped.
///
/// Round and rectangular values are layout margins. They are not safe-area
/// evidence. Unknown device insets stay unknown.
double watchContentMargin({required bool round}) {
  return round ? 8 : 6;
}

/// Whether consequential controls fit without shrinking below [WatchApertureLimits].
final class WatchApertureAssessment {
  const WatchApertureAssessment.fit()
      : holds = false,
        reason = null;

  const WatchApertureAssessment.hold(this.reason) : holds = true;

  final bool holds;
  final String? reason;

  static const holdReason =
      'Capture, cautions, and back cannot keep their minimum logical size in this simulated aperture.';

  static WatchApertureAssessment live({
    required double width,
    required double height,
    required bool round,
    required bool showPhase,
    required bool showBeyond,
    required bool showResolve,
  }) {
    final margin = watchContentMargin(round: round) * 2;
    var used = margin;
    if (showPhase) used += 16;
    if (showBeyond) used += 14;
    used += WatchApertureLimits.clock;
    used += 24;
    used += 4;
    used += WatchApertureLimits.capture;
    used += 4;
    used += WatchApertureLimits.footer;
    used += 28;
    if (showResolve) used += 32;
    final wideEnough = width >= WatchApertureLimits.capture + margin;
    if (height < used || !wideEnough) {
      return const WatchApertureAssessment.hold(holdReason);
    }
    return const WatchApertureAssessment.fit();
  }

  static WatchApertureAssessment capture({
    required double width,
    required double height,
    required bool round,
  }) {
    final margin = watchContentMargin(round: round) * 2;
    final rows = round ? 3 : 2;
    final footer = round ? 0.0 : WatchApertureLimits.back;
    final used = margin +
        WatchApertureLimits.back +
        8 +
        (WatchApertureLimits.family * rows) +
        (rows - 1) * 6 +
        footer;
    final wideEnough = width >= WatchApertureLimits.family * 2 + margin + 12;
    if (height < used || !wideEnough) {
      return const WatchApertureAssessment.hold(holdReason);
    }
    return const WatchApertureAssessment.fit();
  }

  static WatchApertureAssessment team({
    required double width,
    required double height,
    required bool round,
  }) {
    final margin = watchContentMargin(round: round) * 2;
    final used =
        margin + WatchApertureLimits.back + 8 + WatchApertureLimits.capture;
    if (height < used ||
        width < WatchApertureLimits.capture * 2 + margin + 10) {
      return const WatchApertureAssessment.hold(holdReason);
    }
    return const WatchApertureAssessment.fit();
  }

  static WatchApertureAssessment participant({
    required double width,
    required double height,
    required bool round,
  }) {
    final margin = watchContentMargin(round: round) * 2;
    final used = margin +
        WatchApertureLimits.back +
        16 +
        (WatchApertureLimits.chip * 3) +
        16;
    if (height < used || width < WatchApertureLimits.chip * 2 + margin) {
      return const WatchApertureAssessment.hold(holdReason);
    }
    return const WatchApertureAssessment.fit();
  }
}
