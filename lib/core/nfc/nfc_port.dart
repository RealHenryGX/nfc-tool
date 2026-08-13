import 'package:flutter_nfc_kit/flutter_nfc_kit.dart' as kit;
import 'package:nfc_manager/nfc_manager.dart';

import '../debug/app_debug.dart';

/// Thin facade documenting the dual-plugin NFC stack.
///
/// **Manager path** (`nfc_manager`): NDEF read/write/erase/lock/format + Mifare Classic.
/// **Kit path** (`flutter_nfc_kit`): poll / raw hex / Ultralight-NTAG transceive.
///
/// Never start a kit [poll] while a manager session is open — call [releaseAll]
/// (or [NfcManager.stopSession] + [kit.FlutterNfcKit.finish]) first.
abstract final class NfcPort {
  static Future<bool> isManagerAvailable() async {
    try {
      final availability = await NfcManager.instance.checkAvailability();
      return availability == NfcAvailability.enabled;
    } catch (_) {
      return false;
    }
  }

  /// Stop manager session and finish any kit poll so the next path is exclusive.
  static Future<void> releaseAll() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
    try {
      await kit.FlutterNfcKit.finish();
    } catch (_) {}
    AppDebug.instance.nfc('port releaseAll');
  }

  /// Ensure kit path can start: release manager first.
  static Future<void> prepareKitPath() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }

  /// Ensure manager path can start: finish kit first.
  static Future<void> prepareManagerPath() async {
    try {
      await kit.FlutterNfcKit.finish();
    } catch (_) {}
  }
}
