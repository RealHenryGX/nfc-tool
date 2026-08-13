import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'stackntrace_tokens.dart';

/// Shared Material 3 theme for NFC Toolbox.
///
/// Colors follow the helllguest [StackntraceTokens] / stackntrace.dev palette.
class AppTheme {
  /// Amber accent (dark default); used as Material seed / primary.
  static const Color seed = StackntraceTokens.darkAccent;

  /// Bottom [NavigationBar] height — keep snackbars / insets in sync with this.
  static const double navBarHeight = 64;

  static ThemeData light() {
    final scheme = ColorScheme.light(
      primary: StackntraceTokens.lightAccent,
      onPrimary: StackntraceTokens.lightOnAccent,
      primaryContainer: StackntraceTokens.lightSelection,
      onPrimaryContainer: StackntraceTokens.lightForegroundStrong,
      secondary: StackntraceTokens.lightAccent,
      onSecondary: StackntraceTokens.lightOnAccent,
      surface: StackntraceTokens.lightSurface,
      onSurface: StackntraceTokens.lightForeground,
      surfaceContainerLowest: StackntraceTokens.lightBackground,
      surfaceContainerLow: StackntraceTokens.lightSurface,
      surfaceContainer: StackntraceTokens.lightSurface2,
      surfaceContainerHigh: StackntraceTokens.lightSurface2,
      surfaceContainerHighest: StackntraceTokens.lightBorder,
      onSurfaceVariant: StackntraceTokens.lightMuted,
      outline: StackntraceTokens.lightBorder,
      outlineVariant: StackntraceTokens.lightBorderStrong,
    );
    return _base(
      scheme,
      brightness: Brightness.light,
      scaffoldBg: StackntraceTokens.lightBackground,
      cardColor: StackntraceTokens.lightSurface,
      navBg: StackntraceTokens.lightBackground,
    );
  }

  /// Dark theme matching stackntrace.dev (`#0A0C0E` + amber `#E0A458`).
  static ThemeData dark() {
    final scheme = ColorScheme.dark(
      primary: StackntraceTokens.darkAccent,
      onPrimary: StackntraceTokens.darkOnAccent,
      primaryContainer: StackntraceTokens.darkSelection,
      onPrimaryContainer: StackntraceTokens.darkForegroundStrong,
      secondary: StackntraceTokens.darkAccent,
      onSecondary: StackntraceTokens.darkOnAccent,
      surface: StackntraceTokens.darkSurface,
      onSurface: StackntraceTokens.darkForeground,
      surfaceContainerLowest: StackntraceTokens.darkBackground,
      surfaceContainerLow: StackntraceTokens.darkSurface,
      surfaceContainer: StackntraceTokens.darkSurface2,
      surfaceContainerHigh: StackntraceTokens.darkSurface2,
      surfaceContainerHighest: StackntraceTokens.darkBorder,
      onSurfaceVariant: StackntraceTokens.darkMuted,
      outline: StackntraceTokens.darkBorder,
      outlineVariant: StackntraceTokens.darkBorderStrong,
    );
    return _base(
      scheme,
      brightness: Brightness.dark,
      scaffoldBg: StackntraceTokens.darkBackground,
      cardColor: StackntraceTokens.darkSurface,
      navBg: StackntraceTokens.darkBackground,
    );
  }

  static ThemeData _base(
    ColorScheme scheme, {
    required Brightness brightness,
    Color? scaffoldBg,
    Color? cardColor,
    Color? navBg,
  }) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: scaffoldBg ?? scheme.surface,
        surfaceTintColor: Colors.transparent,
        // Dark icons on light surfaces / light icons on dark — avoids
        // invisible white-on-white status bar on Read/Write/Tools.
        systemOverlayStyle: isDark
            ? const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
              )
            : const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
              ),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor ?? scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.55 : 0.8),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: navBarHeight,
        backgroundColor: navBg ?? scaffoldBg ?? scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        overlayColor: WidgetStatePropertyAll(scheme.primary.withValues(alpha: 0.08)),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: selected ? 24 : 22,
            color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.45 : 0.55),
        // Extra vertical padding so floating labels don't sit on the value text.
        contentPadding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, navBarHeight + 16),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.comfortable,
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        space: 1,
        thickness: 1,
      ),
    );
  }
}
