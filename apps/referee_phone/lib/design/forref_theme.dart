import 'package:flutter/material.dart';

import 'forref_colors.dart';
import 'forref_spacing.dart';
import 'forref_typography.dart';

/// Material 3 shaped to the FORREF instrument, not the default seed demo.
abstract final class ForrefTheme {
  static ThemeData light() => _theme(Brightness.light);

  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: ForrefColors.navy,
      brightness: brightness,
      primary: dark ? ForrefColors.darkInk : ForrefColors.navy,
      onPrimary: dark ? ForrefColors.deepNavy : ForrefColors.lightCard,
      secondary: ForrefColors.steel,
      onSecondary: dark ? ForrefColors.deepNavy : ForrefColors.lightCard,
      tertiary: dark ? const Color(0xFF8ED4D1) : const Color(0xFF1C6E6B),
      onTertiary: dark ? ForrefColors.deepNavy : ForrefColors.lightCard,
      error: dark ? const Color(0xFFFFB4AB) : const Color(0xFF8C2F2F),
      onError: dark ? const Color(0xFF690005) : ForrefColors.lightCard,
      surface: dark ? ForrefColors.darkSurface : ForrefColors.lightSurface,
    ).copyWith(
      surfaceTint: Colors.transparent,
      onSurface: dark ? ForrefColors.darkInk : ForrefColors.ink,
      onSurfaceVariant: forrefMuted(brightness),
      outline: ForrefColors.steel,
      outlineVariant: dark ? const Color(0xFF2A4664) : const Color(0xFFD5DEE8),
      surfaceContainerLowest:
          dark ? ForrefColors.deepNavy : ForrefColors.lightSurface,
      surfaceContainerLow:
          dark ? const Color(0xFF102C4A) : const Color(0xFFEEF2F6),
      surfaceContainer: dark ? ForrefColors.darkRaised : ForrefColors.lightCard,
      surfaceContainerHigh:
          dark ? const Color(0xFF1B3C60) : const Color(0xFFE7EEF5),
      surfaceContainerHighest:
          dark ? const Color(0xFF23486F) : const Color(0xFFDCE6F0),
    );
    final muted = forrefMuted(brightness);
    final text = forrefTextTheme(
      base: Typography.material2021(
        platform: TargetPlatform.android,
      ).black.apply(
            bodyColor: scheme.onSurface,
            displayColor: scheme.onSurface,
          ),
      ink: scheme.onSurface,
      muted: muted,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ForrefSpace.radiusControl),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      primaryTextTheme: text,
      dividerColor: scheme.outlineVariant,
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, ForrefSpace.minTouch),
          shape: shape,
          backgroundColor: dark ? const Color(0xFFD7E3F0) : ForrefColors.navy,
          foregroundColor:
              dark ? ForrefColors.deepNavy : ForrefColors.lightCard,
          disabledBackgroundColor:
              dark ? const Color(0xFF1A334C) : const Color(0xFFD7DEE7),
          disabledForegroundColor:
              dark ? const Color(0xFFC5D2E0) : const Color(0xFF3E5166),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, ForrefSpace.minTouch),
          shape: shape,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(48, ForrefSpace.minTouch),
          textStyle: text.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ForrefSpace.s16,
          vertical: ForrefSpace.s12,
        ),
        labelStyle: text.bodyMedium,
        helperStyle: text.bodySmall?.copyWith(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ForrefSpace.radiusControl),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ForrefSpace.radiusControl),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ForrefSpace.radiusControl),
          borderSide: BorderSide(color: scheme.outline, width: 1.5),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurface,
        textColor: scheme.onSurface,
        visualDensity: VisualDensity.compact,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodyMedium?.copyWith(color: muted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? ForrefColors.darkRaised : ForrefColors.navy,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: dark ? ForrefColors.darkInk : ForrefColors.lightCard,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: dark ? ForrefColors.steel : ForrefColors.navy,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _ForrefPageTransitionsBuilder(),
          TargetPlatform.iOS: _ForrefPageTransitionsBuilder(),
          TargetPlatform.linux: _ForrefPageTransitionsBuilder(),
          TargetPlatform.macOS: _ForrefPageTransitionsBuilder(),
          TargetPlatform.windows: _ForrefPageTransitionsBuilder(),
          TargetPlatform.fuchsia: _ForrefPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Short fade and a few pixels of rise. The incoming page stays inside the
/// window so a bottom action remains reachable during the transition.
class _ForrefPageTransitionsBuilder extends PageTransitionsBuilder {
  const _ForrefPageTransitionsBuilder();

  static final Animatable<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.03),
    end: Offset.zero,
  ).chain(CurveTween(curve: Curves.easeOutCubic));

  static final Animatable<double> _fade = CurveTween(curve: Curves.easeOut);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation.drive(_fade),
      child: SlideTransition(
        position: animation.drive(_slide),
        child: child,
      ),
    );
  }
}
