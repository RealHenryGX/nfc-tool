import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../storage/storage_service.dart';

enum DebugLevel { info, warn, error }

class DebugEntry {
  final DateTime at;
  final String tag;
  final String message;
  final DebugLevel level;

  const DebugEntry({
    required this.at,
    required this.tag,
    required this.message,
    this.level = DebugLevel.info,
  });

  String get timeLabel {
    final h = at.hour.toString().padLeft(2, '0');
    final m = at.minute.toString().padLeft(2, '0');
    final s = at.second.toString().padLeft(2, '0');
    final ms = at.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  String get levelLabel => switch (level) {
        DebugLevel.info => 'I',
        DebugLevel.warn => 'W',
        DebugLevel.error => 'E',
      };

  @override
  String toString() => '[$timeLabel] $levelLabel/$tag: $message';
}

/// In-app ring-buffer log for NFC / platform / task debugging.
class AppDebug extends ChangeNotifier {
  AppDebug._();
  static final AppDebug instance = AppDebug._();

  static const int maxEntries = 500;
  final ListQueue<DebugEntry> _entries = ListQueue();

  bool get enabled => StorageService.isDebugEnabled();

  UnmodifiableListView<DebugEntry> get entries =>
      UnmodifiableListView(_entries.toList(growable: false));

  int get length => _entries.length;

  Future<void> setEnabled(bool value) async {
    await StorageService.setDebugEnabled(value);
    log('DEBUG', value ? 'Debug logging ON' : 'Debug logging OFF');
    notifyListeners();
  }

  void log(
    String tag,
    String message, {
    DebugLevel level = DebugLevel.info,
  }) {
    // Always keep fatal / toggle lines; gate the rest behind the switch.
    final force =
        tag == 'DEBUG' || tag == 'FLUTTER' || tag == 'ZONE' || level == DebugLevel.error;
    if (!enabled && !force) return;
    final entry = DebugEntry(
      at: DateTime.now(),
      tag: tag,
      message: message,
      level: level,
    );
    _entries.addLast(entry);
    while (_entries.length > maxEntries) {
      _entries.removeFirst();
    }
    debugPrint(entry.toString());
    notifyListeners();
  }

  void info(String tag, String message) => log(tag, message);
  void warn(String tag, String message) =>
      log(tag, message, level: DebugLevel.warn);
  void error(String tag, String message) =>
      log(tag, message, level: DebugLevel.error);

  void nfc(String message, {DebugLevel level = DebugLevel.info}) =>
      log('NFC', message, level: level);

  void apdu(String message, {DebugLevel level = DebugLevel.info}) =>
      log('APDU', message, level: level);

  void platform(String message, {DebugLevel level = DebugLevel.info}) =>
      log('PLATFORM', message, level: level);

  void task(String message, {DebugLevel level = DebugLevel.info}) =>
      log('TASK', message, level: level);

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  String exportText() => _entries.map((e) => e.toString()).join('\n');

  /// Hex dump helper for APDU / raw buffers.
  static String hex(List<int> bytes, {int group = 1}) {
    final parts = <String>[];
    for (var i = 0; i < bytes.length; i++) {
      parts.add(bytes[i].toRadixString(16).padLeft(2, '0').toUpperCase());
    }
    if (group <= 1) return parts.join(' ');
    final grouped = <String>[];
    for (var i = 0; i < parts.length; i += group) {
      grouped.add(parts.sublist(i, (i + group).clamp(0, parts.length)).join());
    }
    return grouped.join(' ');
  }
}
