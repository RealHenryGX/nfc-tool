import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nfc_tool/core/debug/app_debug.dart';
import 'package:nfc_tool/core/storage/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Hive.init('/tmp/nfc_tool_debug_test_hive');
    await Hive.openBox('templates');
    await Hive.openBox('history');
    await Hive.openBox('settings');
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  setUp(() async {
    AppDebug.instance.clear();
    await StorageService.setDebugEnabled(false);
  });

  test('gated logs skipped when debug off', () {
    AppDebug.instance.nfc('should not appear');
    expect(AppDebug.instance.length, 0);
  });

  test('enabled captures NFC and APDU lines', () async {
    await AppDebug.instance.setEnabled(true);
    AppDebug.instance.clear();
    AppDebug.instance.nfc('uid=AA:BB');
    AppDebug.instance.apdu('TX 30 00');
    expect(AppDebug.instance.length, 2);
    expect(AppDebug.instance.exportText(), contains('NFC'));
    expect(AppDebug.instance.exportText(), contains('APDU'));
  });

  test('errors always captured', () {
    AppDebug.instance.error('FLUTTER', 'boom');
    expect(AppDebug.instance.length, 1);
    expect(AppDebug.instance.entries.first.level, DebugLevel.error);
  });

  test('hex helper formats bytes', () {
    expect(AppDebug.hex([0x0A, 0xFF]), '0A FF');
  });

  test('ring buffer caps at maxEntries', () async {
    await AppDebug.instance.setEnabled(true);
    AppDebug.instance.clear();
    for (var i = 0; i < AppDebug.maxEntries + 20; i++) {
      AppDebug.instance.info('T', 'line $i');
    }
    expect(AppDebug.instance.length, AppDebug.maxEntries);
  });
}
