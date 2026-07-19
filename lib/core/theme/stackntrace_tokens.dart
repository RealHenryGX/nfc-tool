import 'package:flutter/material.dart';

/// Design tokens mirrored from `stackntrace-android-ui` / stackntrace.dev.
///
/// Keep in sync with:
/// `stackntrace-ui/.../theme/Color.kt` (`StackntraceColors`).
abstract final class StackntraceTokens {
  // Light
  static const lightBackground = Color(0xFFFBFBF9);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurface2 = Color(0xFFF3F3F0);
  static const lightBorder = Color(0xFFE4E4DF);
  static const lightBorderStrong = Color(0xFFD2D2CB);
  static const lightForeground = Color(0xFF1A1C1E);
  static const lightForegroundStrong = Color(0xFF0C0D0F);
  static const lightMuted = Color(0xFF5B636C);
  static const lightAccent = Color(0xFFB25E12);
  static const lightOnAccent = Color(0xFFFFFFFF);
  static const lightSelection = Color(0xFFF3D9BD);

  // Dark (stackntrace default)
  static const darkBackground = Color(0xFF0A0C0E);
  static const darkSurface = Color(0xFF121519);
  static const darkSurface2 = Color(0xFF181C21);
  static const darkBorder = Color(0xFF232830);
  static const darkBorderStrong = Color(0xFF313844);
  static const darkForeground = Color(0xFFE5E8EC);
  static const darkForegroundStrong = Color(0xFFF6F8FA);
  static const darkMuted = Color(0xFF97A0AB);
  static const darkAccent = Color(0xFFE0A458);
  static const darkOnAccent = Color(0xFF1A1206);
  static const darkSelection = Color(0xFF3A2E1A);
  /// Soft accent wash (~20% alpha) for chips / selection fills.
  static const darkAccentSoft = Color(0x33E0A458);
  /// Muted accent (~67% alpha) for secondary highlights.
  static const darkAccentMuted = Color(0xAAE0A458);

  static const lightAccentSoft = Color(0x33B25E12);
  static const lightAccentMuted = Color(0xAAB25E12);

  /// Primary accent for the current brightness.
  static Color accent(Brightness brightness) =>
      brightness == Brightness.dark ? darkAccent : lightAccent;

  static Color accentSoft(Brightness brightness) =>
      brightness == Brightness.dark ? darkAccentSoft : lightAccentSoft;

  static Color surface2(Brightness brightness) =>
      brightness == Brightness.dark ? darkSurface2 : lightSurface2;

  static Color border(Brightness brightness) =>
      brightness == Brightness.dark ? darkBorder : lightBorder;
}
