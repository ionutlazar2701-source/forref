import 'package:flutter/material.dart';

import 'forref_colors.dart';

/// System sans with a fixed hierarchy. No extra font package.
TextTheme forrefTextTheme({
  required TextTheme base,
  required Color ink,
  required Color muted,
}) {
  TextStyle style(
    TextStyle? source, {
    required double size,
    FontWeight weight = FontWeight.w400,
    double height = 1.35,
    bool tabular = false,
    Color? color,
  }) {
    return (source ?? const TextStyle()).copyWith(
      color: color ?? ink,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: 0,
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : const [],
    );
  }

  return base.copyWith(
    headlineLarge: style(base.headlineLarge,
        size: 48, weight: FontWeight.w500, height: 1.05, tabular: true),
    headlineMedium: style(base.headlineMedium,
        size: 28, weight: FontWeight.w500, height: 1.15),
    headlineSmall: style(base.headlineSmall,
        size: 22, weight: FontWeight.w500, height: 1.2),
    titleLarge:
        style(base.titleLarge, size: 20, weight: FontWeight.w600, height: 1.25),
    titleMedium:
        style(base.titleMedium, size: 17, weight: FontWeight.w600, height: 1.3),
    titleSmall:
        style(base.titleSmall, size: 14, weight: FontWeight.w600, height: 1.3),
    bodyLarge: style(base.bodyLarge, size: 16, height: 1.4),
    bodyMedium: style(base.bodyMedium, size: 14, height: 1.4, tabular: true),
    bodySmall: style(base.bodySmall, size: 13, height: 1.35, color: muted),
    labelLarge:
        style(base.labelLarge, size: 15, weight: FontWeight.w600, height: 1.2),
    labelMedium: style(base.labelMedium, size: 12, height: 1.3, color: muted),
    labelSmall: style(base.labelSmall, size: 12, height: 1.3, color: muted),
  );
}

/// Muted metadata color that stays legible on both themes.
Color forrefMuted(Brightness brightness) {
  return brightness == Brightness.dark
      ? ForrefColors.steel
      : const Color(0xFF4C6178);
}
