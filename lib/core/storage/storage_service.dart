import 'package:hive_flutter/hive_flutter.dart';
import '../../models/tag_template.dart';
import '../../models/history.dart';

class StorageService {
  static const String _templatesBoxName = 'templates';
  static const String _historyBoxName = 'history';
  static const String _settingsBoxName = 'settings';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_templatesBoxName);
    await Hive.openBox(_historyBoxName);
    await Hive.openBox(_settingsBoxName);
  }

  static Box get _templatesBox => Hive.box(_templatesBoxName);
  static Box get _historyBox => Hive.box(_historyBoxName);
  static Box get _settingsBox => Hive.box(_settingsBoxName);

  // Templates
  static List<TagTemplate> getTemplates() {
    try {
      return _templatesBox.values
          .map((e) => TagTemplate.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveTemplate(TagTemplate template) async {
    await _templatesBox.put(template.id, template.toJson());
  }

  static Future<void> deleteTemplate(String id) async {
    await _templatesBox.delete(id);
  }

  static Future<void> clearTemplates() async {
    await _templatesBox.clear();
  }

  // History
  static List<HistoryEntry> getHistory() {
    try {
      final list = _historyBox.values
          .map((e) => HistoryEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveHistory(HistoryEntry entry) async {
    await _historyBox.put(entry.id, entry.toJson());
  }

  static Future<void> deleteHistory(String id) async {
    await _historyBox.delete(id);
  }

  static Future<void> clearHistory() async {
    await _historyBox.clear();
  }

  // Settings: ThemeMode — 'system' | 'light' | 'dark'
  static String getThemeModeName() {
    final stored = _settingsBox.get('themeMode') as String?;
    if (stored == 'light' || stored == 'dark' || stored == 'system') {
      return stored!;
    }
    // Migrate legacy bool darkMode
    final legacy = _settingsBox.get('darkMode');
    if (legacy is bool) {
      return legacy ? 'dark' : 'light';
    }
    return 'system';
  }

  static Future<void> setThemeModeName(String mode) async {
    if (mode != 'light' && mode != 'dark' && mode != 'system') {
      mode = 'system';
    }
    await _settingsBox.put('themeMode', mode);
  }

  static bool isDarkMode() => getThemeModeName() == 'dark';

  static Future<void> setDarkMode(bool value) async {
    await setThemeModeName(value ? 'dark' : 'light');
  }

  static bool isOnboardingDone() {
    return _settingsBox.get('onboardingDone', defaultValue: false) as bool;
  }

  static Future<void> setOnboardingDone(bool value) async {
    await _settingsBox.put('onboardingDone', value);
  }

  // Developer / debug
  static bool isDebugEnabled() {
    return _settingsBox.get('debugEnabled', defaultValue: false) as bool;
  }

  static Future<void> setDebugEnabled(bool value) async {
    await _settingsBox.put('debugEnabled', value);
  }

  static bool showDebugBanner() {
    return _settingsBox.get('showDebugBanner', defaultValue: false) as bool;
  }

  static Future<void> setShowDebugBanner(bool value) async {
    await _settingsBox.put('showDebugBanner', value);
  }

  // Task variables (NFC Tasks-style key/value store)
  static Future<void> setTaskVar(String key, String value) async {
    if (key.isEmpty) return;
    await _settingsBox.put('tvar_$key', value);
  }

  static String? getTaskVar(String key) {
    return _settingsBox.get('tvar_$key') as String?;
  }

  static Future<void> delTaskVar(String key) async {
    await _settingsBox.delete('tvar_$key');
  }

  static Map<String, String> getAllTaskVars() {
    final out = <String, String>{};
    for (final key in _settingsBox.keys) {
      final k = key.toString();
      if (k.startsWith('tvar_')) {
        out[k.substring(5)] = _settingsBox.get(key)?.toString() ?? '';
      }
    }
    return out;
  }
}
