import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import 'package:uuid/uuid.dart';
import '../../models/history.dart';
import '../../models/ndef_record.dart';
import '../../core/storage/storage_service.dart';

class HistoryNotifier extends Notifier<List<HistoryEntry>> {
  @override
  List<HistoryEntry> build() {
    return StorageService.getHistory();
  }

  Future<void> addRecord({
    String? uid,
    required String action,
    required List<NdefRecordModel> records,
    required bool success,
    String? details,
  }) async {
    final entry = HistoryEntry(
      id: const Uuid().v4(),
      uid: uid,
      timestamp: DateTime.now(),
      action: action,
      records: records,
      success: success,
      details: details,
    );
    await StorageService.saveHistory(entry);
    state = [entry, ...state];
  }

  Future<void> deleteEntry(String id) async {
    await StorageService.deleteHistory(id);
    state = state.where((e) => e.id != id).toList();
  }

  Future<void> clearAll() async {
    await StorageService.clearHistory();
    state = [];
  }

  String exportToCsv() {
    final csvData = <List<dynamic>>[];
    // Header
    csvData.add(['ID', 'UID', 'Timestamp', 'Action', 'Records Count', 'Success', 'Details']);
    
    for (final entry in state) {
      csvData.add([
        entry.id,
        entry.uid ?? 'N/A',
        entry.timestamp.toIso8601String(),
        entry.action,
        entry.records.length,
        entry.success ? 'TRUE' : 'FALSE',
        entry.details ?? '',
      ]);
    }
    
    return csv.encode(csvData);
  }
}

final historyProvider = NotifierProvider<HistoryNotifier, List<HistoryEntry>>(() {
  return HistoryNotifier();
});
