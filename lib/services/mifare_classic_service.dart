import 'dart:async';
import 'dart:typed_data';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

import '../core/debug/app_debug.dart';

/// Mifare Classic sector dump / block write via `nfc_manager`.
class MifareClassicService {
  static final Uint8List keyFFFFFFFFFFFF =
      Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);

  /// Poll tag, auth every sector with [key6], return hex dump text.
  static Future<String> dumpAllSectors({
    required Uint8List key6,
    bool useKeyA = true,
  }) async {
    if (key6.length != 6) {
      throw ArgumentError('Classic key must be 6 bytes');
    }

    final availability = await NfcManager.instance.checkAvailability();
    if (availability != NfcAvailability.enabled) {
      throw StateError('NFC not available or disabled');
    }

    await NfcManager.instance.stopSession();
    final done = Completer<String>();
    AppDebug.instance.nfc(
      'Classic dump keyA=$useKeyA key=${AppDebug.hex(key6)}',
    );

    await NfcManager.instance.startSession(
      pollingOptions: {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
        NfcPollingOption.iso18092,
      },
      onDiscovered: (tag) async {
        try {
          final classic = MifareClassicAndroid.from(tag);
          if (classic == null) {
            throw StateError('Tag is not Mifare Classic');
          }
          final buf = StringBuffer();
          buf.writeln(
            'Type=${classic.type} sectors=${classic.sectorCount} '
            'blocks=${classic.blockCount} size=${classic.size}B',
          );
          AppDebug.instance.nfc(
            'Classic sectors=${classic.sectorCount} blocks=${classic.blockCount}',
          );
          for (var sector = 0; sector < classic.sectorCount; sector++) {
            final ok = useKeyA
                ? await classic.authenticateSectorWithKeyA(
                    sectorIndex: sector,
                    key: key6,
                  )
                : await classic.authenticateSectorWithKeyB(
                    sectorIndex: sector,
                    key: key6,
                  );
            if (!ok) {
              buf.writeln('Sector $sector: AUTH FAIL');
              continue;
            }
            final first = sector < 32 ? sector * 4 : 128 + (sector - 32) * 16;
            final count = sector < 32 ? 4 : 16;
            for (var i = 0; i < count; i++) {
              final block = first + i;
              final data = await classic.readBlock(blockIndex: block);
              final hex = data
                  .map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase())
                  .join(' ');
              buf.writeln('S$sector B$block: $hex');
            }
          }
          if (!done.isCompleted) done.complete(buf.toString());
        } catch (e) {
          if (!done.isCompleted) done.completeError(e);
        } finally {
          await NfcManager.instance.stopSession();
        }
      },
    );

    return done.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        NfcManager.instance.stopSession();
        throw TimeoutException('Tap a Mifare Classic tag (timeout)');
      },
    );
  }

  static Future<void> writeBlock({
    required int sectorIndex,
    required int blockInSector,
    required Uint8List data16,
    required Uint8List key6,
    bool useKeyA = true,
  }) async {
    if (data16.length != 16) {
      throw ArgumentError('Classic block must be 16 bytes');
    }
    AppDebug.instance.nfc(
      'Classic writeBlock sector=$sectorIndex blockInSector=$blockInSector '
      'data=${AppDebug.hex(data16)}',
    );
    await NfcManager.instance.stopSession();
    final done = Completer<void>();
    await NfcManager.instance.startSession(
      pollingOptions: {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
        NfcPollingOption.iso18092,
      },
      onDiscovered: (tag) async {
        try {
          final classic = MifareClassicAndroid.from(tag);
          if (classic == null) throw StateError('Not Mifare Classic');
          final ok = useKeyA
              ? await classic.authenticateSectorWithKeyA(
                  sectorIndex: sectorIndex,
                  key: key6,
                )
              : await classic.authenticateSectorWithKeyB(
                  sectorIndex: sectorIndex,
                  key: key6,
                );
          if (!ok) throw StateError('Auth failed for sector $sectorIndex');
          final first =
              sectorIndex < 32 ? sectorIndex * 4 : 128 + (sectorIndex - 32) * 16;
          final block = first + blockInSector;
          await classic.writeBlock(blockIndex: block, data: data16);
          AppDebug.instance.nfc('Classic writeBlock OK block=$block');
          if (!done.isCompleted) done.complete();
        } catch (e) {
          AppDebug.instance.nfc(
            'Classic writeBlock failed: $e',
            level: DebugLevel.error,
          );
          if (!done.isCompleted) done.completeError(e);
        } finally {
          await NfcManager.instance.stopSession();
        }
      },
    );
    await done.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        NfcManager.instance.stopSession();
        throw TimeoutException('Tap Classic tag to write (timeout)');
      },
    );
  }

  /// Legacy probe used by Tools UI.
  static Future<Map<String, dynamic>> dumpWithKey({
    required Uint8List key6,
    bool useKeyA = true,
  }) async {
    final text = await dumpAllSectors(key6: key6, useKeyA: useKeyA);
    return {'dump': text};
  }

  static Uint8List parseKey(String hex) {
    final cleaned = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (cleaned.length != 12) {
      throw FormatException('Classic key must be 6 bytes (12 hex chars)');
    }
    final out = Uint8List(6);
    for (var i = 0; i < 6; i++) {
      out[i] = int.parse(cleaned.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }
}
