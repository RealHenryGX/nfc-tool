import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/mifare_classic_service.dart';
import '../../services/tag_memory_service.dart';
import '../../services/task_runner.dart';

/// Reports a message from a [ToolsNotifier] action back to the UI (snackbar).
typedef ToolsReporter = void Function(String message, {bool isError});

@immutable
class ToolsState {
  final bool busy;
  final bool gridView;
  final Uint8List? memoryBytes;
  final String? memoryHex;
  final String? txLog;
  final String? classicInfo;

  const ToolsState({
    this.busy = false,
    this.gridView = true,
    this.memoryBytes,
    this.memoryHex,
    this.txLog,
    this.classicInfo,
  });

  ToolsState copyWith({
    bool? busy,
    bool? gridView,
    Uint8List? memoryBytes,
    String? memoryHex,
    String? txLog,
    String? classicInfo,
  }) {
    return ToolsState(
      busy: busy ?? this.busy,
      gridView: gridView ?? this.gridView,
      memoryBytes: memoryBytes ?? this.memoryBytes,
      memoryHex: memoryHex ?? this.memoryHex,
      txLog: txLog ?? this.txLog,
      classicInfo: classicInfo ?? this.classicInfo,
    );
  }
}

/// Business logic for the Tools screen (Ultralight memory, transceive,
/// password, Mifare Classic). Widgets own [TextEditingController]s and pass
/// their `.text` in; this notifier owns busy/result state plus the NFC/IO
/// calls, and reports success/error strings via [ToolsReporter] so the
/// screen can show a snack with the exact same wording as before.
class ToolsNotifier extends Notifier<ToolsState> {
  @override
  ToolsState build() => const ToolsState();

  void toggleGridView() => state = state.copyWith(gridView: !state.gridView);

  Future<void> readMemory({ToolsReporter? report}) async {
    state = state.copyWith(busy: true);
    try {
      final bytes = await TagMemoryService.readUltralightPages(
        startPage: 0,
        pageCount: 16,
      );
      state = state.copyWith(
        busy: false,
        memoryBytes: bytes,
        memoryHex: _formatDump(bytes),
      );
    } catch (e) {
      state = state.copyWith(busy: false);
      report?.call('Memory read failed: $e', isError: true);
    }
  }

  Future<void> exportBin({required ToolsReporter report}) async {
    final bytes = state.memoryBytes;
    if (bytes == null) return;
    final uri = await PlatformBridge.saveBytes(bytes, 'nfc_ul_dump.bin');
    report(uri == null ? 'Export cancelled' : 'Saved: $uri');
  }

  Future<void> importBin({required ToolsReporter report}) async {
    state = state.copyWith(busy: true);
    try {
      final bytes = await PlatformBridge.pickBytes(mime: '*/*');
      if (bytes == null) return;
      state = state.copyWith(memoryBytes: bytes, memoryHex: _formatDump(bytes));
      report('Loaded ${bytes.length} bytes');
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> writeDumpBack({required ToolsReporter report}) async {
    final bytes = state.memoryBytes;
    if (bytes == null) return;
    state = state.copyWith(busy: true);
    try {
      // If dump includes pages 0.., skip first 16 bytes (pages 0-3)
      final payload = bytes.length > 16 ? bytes.sublist(16) : bytes;
      await TagMemoryService.writeUltralightDump(dump: payload, startPage: 4);
      report('Dump written');
    } catch (e) {
      report('Write dump failed: $e', isError: true);
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> transceive(String hexCommand) async {
    state = state.copyWith(busy: true);
    try {
      final log = await TagMemoryService.transceiveHex(hexCommand);
      state = state.copyWith(txLog: log);
    } catch (e) {
      state = state.copyWith(txLog: 'Error: $e');
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> passwordAuth({
    required String pwdHex,
    required String packHex,
    required ToolsReporter report,
  }) async {
    state = state.copyWith(busy: true);
    try {
      final msg = await TagMemoryService.ultralightPasswordAuth(
        pwd4: _hexToBytes(pwdHex),
        pack2: _hexToBytes(packHex),
      );
      report(msg);
    } catch (e) {
      report('$e', isError: true);
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> passwordSet({
    required String pwdHex,
    required String packHex,
    required String pwdPageText,
    required String packPageText,
    required ToolsReporter report,
  }) async {
    state = state.copyWith(busy: true);
    try {
      final msg = await TagMemoryService.setUltralightPassword(
        pwd4: _hexToBytes(pwdHex),
        pack2: _hexToBytes(packHex),
        pwdPage: int.parse(pwdPageText.trim()),
        packPage: int.parse(packPageText.trim()),
      );
      report(msg);
    } catch (e) {
      report('$e', isError: true);
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> passwordUnset({
    required String pwdHex,
    required String packHex,
    required String pwdPageText,
    required String packPageText,
    required ToolsReporter report,
  }) async {
    state = state.copyWith(busy: true);
    try {
      final msg = await TagMemoryService.unsetUltralightPassword(
        pwdPage: int.parse(pwdPageText.trim()),
        packPage: int.parse(packPageText.trim()),
        pwd4ForAuth: _hexToBytes(pwdHex),
        pack2ForAuth: _hexToBytes(packHex),
      );
      report(msg);
    } catch (e) {
      report('$e', isError: true);
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> classicDump(String keyHex) async {
    state = state.copyWith(busy: true);
    try {
      final key = MifareClassicService.parseKey(keyHex);
      final info = await MifareClassicService.dumpWithKey(key6: key);
      state = state.copyWith(classicInfo: info['dump']?.toString() ?? info.toString());
    } catch (e) {
      state = state.copyWith(classicInfo: 'Error: $e');
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> classicWriteBlock({
    required String keyHex,
    required String dataHex,
    required String sectorText,
    required String blockText,
    required ToolsReporter report,
  }) async {
    state = state.copyWith(busy: true);
    try {
      final key = MifareClassicService.parseKey(keyHex);
      final data = _hexToBytes(dataHex);
      if (data.length != 16) throw const FormatException('Need exactly 16 bytes');
      await MifareClassicService.writeBlock(
        sectorIndex: int.parse(sectorText.trim()),
        blockInSector: int.parse(blockText.trim()),
        data16: data,
        key6: key,
      );
      report('Classic block written');
    } catch (e) {
      report('$e', isError: true);
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> classicExportBin({required ToolsReporter report}) async {
    final text = state.classicInfo;
    if (text == null || text.startsWith('Error')) return;
    final bytes = _classicDumpTextToBytes(text);
    final uri = await PlatformBridge.saveBytes(bytes, 'mifare_classic_dump.bin');
    report(uri == null ? 'Export cancelled' : 'Saved: $uri');
  }

  /// Writes a previously-picked Classic dump (16-byte blocks, trailer blocks
  /// skipped). Caller is responsible for the file pick + confirmation flow.
  Future<void> classicImportAndWrite({
    required Uint8List bytes,
    required String keyHex,
    required ToolsReporter report,
  }) async {
    state = state.copyWith(busy: true);
    try {
      final key = MifareClassicService.parseKey(keyHex);
      var sector = 0;
      var blockInSector = 0;
      for (var i = 0; i < bytes.length; i += 16) {
        final blocksInSector = sector < 32 ? 4 : 16;
        // skip trailer block (last in sector)
        if (blockInSector == blocksInSector - 1) {
          sector++;
          blockInSector = 0;
          continue;
        }
        await MifareClassicService.writeBlock(
          sectorIndex: sector,
          blockInSector: blockInSector,
          data16: bytes.sublist(i, i + 16),
          key6: key,
        );
        blockInSector++;
        if (blockInSector >= blocksInSector) {
          sector++;
          blockInSector = 0;
        }
      }
      report('Classic dump write finished');
    } catch (e) {
      report('$e', isError: true);
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  static Uint8List _classicDumpTextToBytes(String text) {
    final out = BytesBuilder();
    for (final line in text.split('\n')) {
      if (!line.contains(' B')) continue;
      final idx = line.indexOf(':');
      if (idx < 0) continue;
      out.add(_hexToBytes(line.substring(idx + 1)));
    }
    return out.toBytes();
  }

  static Uint8List _hexToBytes(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    final out = Uint8List(cleaned.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(cleaned.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  static String _formatDump(Uint8List bytes) {
    final buf = StringBuffer();
    for (var i = 0; i < bytes.length; i += 4) {
      final page = i ~/ 4;
      final slice = bytes.sublist(i, (i + 4).clamp(0, bytes.length));
      final hex = slice
          .map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(' ');
      buf.writeln('Page ${page.toString().padLeft(2, '0')}: $hex');
    }
    return buf.toString();
  }
}

final toolsProvider = NotifierProvider<ToolsNotifier, ToolsState>(() {
  return ToolsNotifier();
});
