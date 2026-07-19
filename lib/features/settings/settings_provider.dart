import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/storage_service.dart';

class SettingsNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return _fromName(StorageService.getThemeModeName());
  }

  static ThemeMode _fromName(String name) {
    switch (name) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _toName(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await StorageService.setThemeModeName(_toName(mode));
    state = mode;
  }

  /// Cycles system → light → dark → system.
  Future<void> cycleThemeMode() async {
    final next = switch (state) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    await setThemeMode(next);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, ThemeMode>(() {
  return SettingsNotifier();
});
