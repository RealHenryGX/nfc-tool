import '../models/ndef_record.dart';

/// Parsed NFC tag snapshot from an `nfc_manager` discovery callback.
class NfcTagDetails {
  final String? uid;
  final List<String> technologies;
  final bool isNdefSupported;
  final bool? isWritable;
  final int? maxSize;
  final List<NdefRecordModel> records;
  final String? type;

  NfcTagDetails({
    this.uid,
    required this.technologies,
    required this.isNdefSupported,
    this.isWritable,
    this.maxSize,
    required this.records,
    this.type,
  });
}
