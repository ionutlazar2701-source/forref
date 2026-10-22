import 'package:flutter/material.dart';

/// FORREF research palette. Turquoise is decorative, not a status code.
abstract final class LabColors {
  static const navy = Color(0xFF0B2A4A);
  static const softWhite = Color(0xFFF8FAFC);
  static const steel = Color(0xFF5B7EA6);
  static const turquoise = Color(0xFF00D4C8);

  /// Neutral chrome surfaces. Stage separation comes from whitespace, not cards.
  static const canvas = Color(0xFFEEF2F6);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFD5DEE8);
  static const inkMuted = Color(0xFF4A5B70);
  static const navyDeep = Color(0xFF07203A);

  /// Semantic colors are separate from brand colors. Words carry the state.
  static const attention = Color(0xFFB45309);
  static const failure = Color(0xFF9F1239);
  static const unknownFact = Color(0xFF6B7280);
}

/// Spacing rhythm, widths, and radii for the Simulator Lab chrome.
///
/// Research-specific tokens stay inside hf_prototype. This is not a design
/// system package.
abstract final class LabMetrics {
  static const double topBarHeight = 56;
  static const double workspaceBarHeight = 44;
  static const double footerHeight = 28;
  static const double pageMargin = 24;
  static const double gutter = 16;
  static const double tight = 8;
  static const double railWidth = 264;
  static const double railMinWidth = 224;
  static const double inspectorWidth = 360;
  static const double inspectorMinWidth = 320;
  static const double controlHeight = 40;
  static const double controlRadius = 10;
  static const double surfaceRadius = 16;
  static const double chipRadius = 8;

  /// Window regimes from the John V1 responsive table.
  static const double wideBreakpoint = 1440;
  static const double desktopBreakpoint = 1100;
  static const double compactBreakpoint = 800;
}

abstract final class LabText {
  static const title = TextStyle(
    color: LabColors.navy,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );
  static const subtitle = TextStyle(
    color: LabColors.inkMuted,
    fontSize: 13,
    height: 1.35,
  );
  static const body = TextStyle(
    color: LabColors.navy,
    fontSize: 14,
    height: 1.4,
  );
  static const bodyStrong = TextStyle(
    color: LabColors.navy,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.4,
  );
  static const caption = TextStyle(
    color: LabColors.inkMuted,
    fontSize: 12,
    height: 1.35,
  );
  static const label = TextStyle(
    color: LabColors.steel,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    height: 1.2,
  );
  static const onNavy = TextStyle(
    color: LabColors.softWhite,
    fontSize: 13,
    height: 1.2,
  );
  static const onNavyStrong = TextStyle(
    color: LabColors.softWhite,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    height: 1.2,
  );
  static const numeric = TextStyle(
    color: LabColors.navy,
    fontSize: 13,
    fontFeatures: [FontFeature.tabularFigures()],
    height: 1.35,
  );
}

const labTitle = 'FORREF SIMULATOR LAB';
const labIdentity = 'RESEARCH / NON-PRODUCTION';
const labBrand = 'FORREF';
const labBrandSub = 'SIM LAB';
const labFooterNote = 'REFERENCE UI ≠ NATIVE WATCH APP';
