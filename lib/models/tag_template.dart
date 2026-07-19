import 'ndef_record.dart';

class TagTemplate {
  final String id;
  final String name;
  final List<NdefRecordModel> records;
  final DateTime createdAt;

  TagTemplate({
    required this.id,
    required this.name,
    required this.records,
    required this.createdAt,
  });

  factory TagTemplate.fromJson(Map<String, dynamic> json) {
    return TagTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      records: (json['records'] as List)
          .map((e) => NdefRecordModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'records': records.map((e) => e.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  TagTemplate copyWith({
    String? name,
    List<NdefRecordModel>? records,
  }) {
    return TagTemplate(
      id: id,
      name: name ?? this.name,
      records: records ?? this.records,
      createdAt: createdAt,
    );
  }
}
