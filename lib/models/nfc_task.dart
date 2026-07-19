import 'dart:convert';
import '../core/tasks/task_catalog.dart';
import 'ndef_record.dart';

class NfcTask {
  final String id;
  final String kind;
  final Map<String, dynamic> params;
  final String? label;

  const NfcTask({
    required this.id,
    required this.kind,
    this.params = const {},
    this.label,
  });

  TaskKind? get meta => TaskCatalog.byId(kind);

  String get displayName => label ?? meta?.label ?? kind;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'params': params,
        if (label != null) 'label': label,
      };

  factory NfcTask.fromJson(Map<String, dynamic> json) => NfcTask(
        id: json['id']?.toString() ?? '',
        kind: json['kind']?.toString() ?? '',
        params: Map<String, dynamic>.from(json['params'] as Map? ?? {}),
        label: json['label']?.toString(),
      );

  NdefRecordModel toNdefRecord() => NdefRecordModel(
        type: 'task',
        payload: {
          'mimeType': 'application/x-nfctoolbox-task',
          'task': toJson(),
          'payload': jsonEncode(toJson()),
        },
      );

  static NfcTask? fromNdefRecord(NdefRecordModel record) {
    if (record.type == 'task') {
      final nested = record.payload['task'];
      if (nested is Map) {
        return NfcTask.fromJson(Map<String, dynamic>.from(nested));
      }
      final raw = record.payload['payload']?.toString();
      if (raw != null && raw.isNotEmpty) {
        try {
          return NfcTask.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map),
          );
        } catch (_) {}
      }
    }
    if (record.type == 'mime' &&
        record.payload['mimeType'] == 'application/x-nfctoolbox-task') {
      try {
        return NfcTask.fromJson(
          Map<String, dynamic>.from(
            jsonDecode(record.payload['payload'].toString()) as Map,
          ),
        );
      } catch (_) {}
    }
    return null;
  }
}
