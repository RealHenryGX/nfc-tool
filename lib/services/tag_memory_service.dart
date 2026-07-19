import 'dart:typed_data';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart' as kit;

import '../core/debug/app_debug.dart';

/// Low-level tag memory helpers (Ultralight / NTAG via NFC-A transceive).
class TagMemoryService {
  static Future<List<int>> _tx(List<int> cmd) async {
    AppDebug.instance.apdu('TX ${AppDebug.hex(cmd)}');
    final resp = await kit.FlutterNfcKit.transceive(cmd);
    AppDebug.instance.apdu('RX ${AppDebug.hex(resp)}');
    return resp;
  }

  /// Read Ultralight/NTAG pages starting at [startPage], [pageCount] pages (4 bytes each).
  static Future<Uint8List> readUltralightPages({
    int startPage = 0,
    int pageCount = 16,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    try {
      AppDebug.instance.nfc('UL dump pages=$startPage..${startPage + pageCount - 1}');
      await kit.FlutterNfcKit.poll(timeout: timeout, androidPlatformSound: true);
      final out = BytesBuilder();
      for (var page = startPage; page < startPage + pageCount; page++) {
        final cmd = Uint8List.fromList([0x30, page & 0xFF]); // READ
        final resp = await _tx(cmd);
        // Ultralight READ returns 16 bytes (4 pages); keep first 4 for sequential map
        if (resp.length >= 4) {
          out.add(resp.sublist(0, 4));
        } else {
          out.add(resp);
        }
      }
      return out.toBytes();
    } finally {
      try {
        await kit.FlutterNfcKit.finish();
      } catch (_) {}
    }
  }

  /// Write one 4-byte Ultralight page.
  static Future<void> writeUltralightPage(int page, Uint8List fourBytes) async {
    if (fourBytes.length != 4) {
      throw ArgumentError('Ultralight page must be exactly 4 bytes');
    }
    try {
      await kit.FlutterNfcKit.poll(
        timeout: const Duration(seconds: 20),
        androidPlatformSound: true,
      );
      final cmd = Uint8List.fromList([0xA2, page & 0xFF, ...fourBytes]); // WRITE
      await _tx(cmd);
    } finally {
      try {
        await kit.FlutterNfcKit.finish();
      } catch (_) {}
    }
  }

  /// Raw hex transceive session: poll once, send [hexCommand] (space-separated).
  static Future<String> transceiveHex(String hexCommand) async {
    try {
      final tag = await kit.FlutterNfcKit.poll(
        timeout: const Duration(seconds: 20),
        androidPlatformSound: true,
      );
      final bytes = _parseHex(hexCommand);
      AppDebug.instance.nfc('transceive uid=${tag.id}');
      final resp = await _tx(bytes);
      return 'UID=${tag.id}\nTX=${_toHex(bytes)}\nRX=${_toHex(Uint8List.fromList(resp))}';
    } finally {
      try {
        await kit.FlutterNfcKit.finish();
      } catch (_) {}
    }
  }

  /// Ultralight EV1 password auth (PWD + PACK). Best-effort; chip-specific.
  static Future<String> ultralightPasswordAuth({
    required Uint8List pwd4,
    required Uint8List pack2,
  }) async {
    if (pwd4.length != 4 || pack2.length != 2) {
      throw ArgumentError('PWD=4 bytes, PACK=2 bytes');
    }
    try {
      await kit.FlutterNfcKit.poll(
        timeout: const Duration(seconds: 20),
        androidPlatformSound: true,
      );
      final cmd = Uint8List.fromList([0x1B, ...pwd4]); // PWD_AUTH
      final resp = await _tx(cmd);
      final ok = resp.length >= 2 && resp[0] == pack2[0] && resp[1] == pack2[1];
      return ok
          ? 'AUTH OK PACK=${_toHex(Uint8List.fromList(resp))}'
          : 'AUTH response=${_toHex(Uint8List.fromList(resp))} (PACK mismatch?)';
    } finally {
      try {
        await kit.FlutterNfcKit.finish();
      } catch (_) {}
    }
  }

  /// Write contiguous Ultralight pages from a byte dump (multiple of 4).
  static Future<void> writeUltralightDump({
    required Uint8List dump,
    int startPage = 4, // skip UID/lock on many UL/NTAG
  }) async {
    if (dump.length % 4 != 0) {
      throw ArgumentError('Dump length must be multiple of 4 bytes');
    }
    try {
      await kit.FlutterNfcKit.poll(
        timeout: const Duration(seconds: 25),
        androidPlatformSound: true,
      );
      var page = startPage;
      for (var i = 0; i < dump.length; i += 4) {
        final four = dump.sublist(i, i + 4);
        final cmd = Uint8List.fromList([0xA2, page & 0xFF, ...four]);
        await _tx(cmd);
        page++;
      }
    } finally {
      try {
        await kit.FlutterNfcKit.finish();
      } catch (_) {}
    }
  }

  /// NTAG21x / UL-EV1 style password set: write PWD (4) + PACK (2) to config pages.
  /// [pwdPage] default 0xE5 for NTAG216 — caller must pass correct page for chip.
  static Future<String> setUltralightPassword({
    required Uint8List pwd4,
    required Uint8List pack2,
    required int pwdPage,
    required int packPage,
  }) async {
    if (pwd4.length != 4 || pack2.length != 2) {
      throw ArgumentError('PWD=4 bytes, PACK=2 bytes');
    }
    try {
      await kit.FlutterNfcKit.poll(
        timeout: const Duration(seconds: 25),
        androidPlatformSound: true,
      );
      // PWD is 4 bytes page; PACK is often packed with RFUI — write PACK into page start
      await _tx(Uint8List.fromList([0xA2, pwdPage & 0xFF, ...pwd4]));
      final packPageBytes = Uint8List.fromList([pack2[0], pack2[1], 0x00, 0x00]);
      await _tx(Uint8List.fromList([0xA2, packPage & 0xFF, ...packPageBytes]));
      return 'PWD written @ page $pwdPage, PACK @ page $packPage';
    } finally {
      try {
        await kit.FlutterNfcKit.finish();
      } catch (_) {}
    }
  }

  /// Clear PWD by writing zeros to PWD/PACK pages (after successful auth if needed).
  static Future<String> unsetUltralightPassword({
    required int pwdPage,
    required int packPage,
    Uint8List? pwd4ForAuth,
    Uint8List? pack2ForAuth,
  }) async {
    try {
      await kit.FlutterNfcKit.poll(
        timeout: const Duration(seconds: 25),
        androidPlatformSound: true,
      );
      if (pwd4ForAuth != null &&
          pwd4ForAuth.length == 4 &&
          pack2ForAuth != null &&
          pack2ForAuth.length == 2) {
        final resp = await _tx(Uint8List.fromList([0x1B, ...pwd4ForAuth]));
        // ignore mismatched pack — still attempt wipe
        if (resp.isEmpty) {
          // continue
        }
      }
      await _tx(Uint8List.fromList([0xA2, pwdPage & 0xFF, 0, 0, 0, 0]));
      await _tx(Uint8List.fromList([0xA2, packPage & 0xFF, 0, 0, 0, 0]));
      return 'PWD/PACK pages zeroed ($pwdPage/$packPage)';
    } finally {
      try {
        await kit.FlutterNfcKit.finish();
      } catch (_) {}
    }
  }

  static Uint8List _parseHex(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (cleaned.length.isOdd) {
      throw FormatException('Hex length must be even');
    }
    final out = Uint8List(cleaned.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(cleaned.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  static String _toHex(Uint8List bytes) =>
      bytes.map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
}
