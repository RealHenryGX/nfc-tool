class NdefRecordModel {
  final String type; // 'text', 'uri', 'wifi', 'vcard', 'email', 'phone', 'sms', 'location', 'mime', 'custom'
  final Map<String, dynamic> payload;

  NdefRecordModel({required this.type, required this.payload});

  factory NdefRecordModel.fromJson(Map<String, dynamic> json) {
    return NdefRecordModel(
      type: json['type'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'payload': payload,
  };
}
