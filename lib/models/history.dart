import 'ndef_record.dart';

class HistoryEntry {
  final String id;
  final String? uid;
  final DateTime timestamp;
  final String action; // 'read', 'write', 'batch_write'
  final List<NdefRecordModel> records;
  final bool success;
  final String? details; // e.g. technology, format, size

  HistoryEntry({
    required this.id,
    this.uid,
    required this.timestamp,
    required this.action,
    required this.records,
    required this.success,
    this.details,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      id: json['id'] as String,
      uid: json['uid'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      action: json['action'] as String,
      records: (json['records'] as List)
          .map((e) => NdefRecordModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      success: json['success'] as bool,
      details: json['details'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'uid': uid,
    'timestamp': timestamp.toIso8601String(),
    'action': action,
    'records': records.map((e) => e.toJson()).toList(),
    'success': success,
    'details': details,
  };
}
