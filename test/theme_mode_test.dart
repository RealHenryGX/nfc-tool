import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nfc_tool/core/storage/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final path = '/tmp/nfc_tool_theme_test_hive';
    Hive.init(path);
    await Hive.openBox('templates');
    await Hive.openBox('history');
    await Hive.openBox('settings');
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  test('theme mode persists system/light/dark names', () async {
    await StorageService.setThemeModeName('dark');
    expect(StorageService.getThemeModeName(), 'dark');
    await StorageService.setThemeModeName('light');
    expect(StorageService.getThemeModeName(), 'light');
    await StorageService.setThemeModeName('system');
    expect(StorageService.getThemeModeName(), 'system');
  });

  test('legacy darkMode bool migrates when themeMode absent', () async {
    final box = Hive.box('settings');
    await box.delete('themeMode');
    await box.put('darkMode', true);
    expect(StorageService.getThemeModeName(), 'dark');
    await box.delete('themeMode');
    await box.put('darkMode', false);
    expect(StorageService.getThemeModeName(), 'light');
  });

  test('invalid theme mode falls back to system on write', () async {
    await StorageService.setThemeModeName('nope');
    expect(StorageService.getThemeModeName(), 'system');
  });
}
