import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/debug/app_debug.dart';
import '../../core/storage/storage_service.dart';

class DebugSettings {
  final bool enabled;
  final bool showBanner;

  const DebugSettings({required this.enabled, required this.showBanner});

  DebugSettings copyWith({bool? enabled, bool? showBanner}) {
    return DebugSettings(
      enabled: enabled ?? this.enabled,
      showBanner: showBanner ?? this.showBanner,
    );
  }
}

class DebugSettingsNotifier extends Notifier<DebugSettings> {
  @override
  DebugSettings build() {
    return DebugSettings(
      enabled: StorageService.isDebugEnabled(),
      showBanner: StorageService.showDebugBanner(),
    );
  }

  Future<void> setEnabled(bool value) async {
    await AppDebug.instance.setEnabled(value);
    state = state.copyWith(enabled: value);
  }

  Future<void> setShowBanner(bool value) async {
    await StorageService.setShowDebugBanner(value);
    state = state.copyWith(showBanner: value);
  }
}

final debugSettingsProvider =
    NotifierProvider<DebugSettingsNotifier, DebugSettings>(() {
  return DebugSettingsNotifier();
});
