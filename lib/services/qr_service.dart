import '../models/ndef_record.dart';

class QrService {
  static NdefRecordModel parseQrString(String data) {
    final trimmed = data.trim();

    // 1. vCard
    if (trimmed.toUpperCase().startsWith('BEGIN:VCARD')) {
      return NdefRecordModel(
        type: 'vcard',
        payload: {'vcard': trimmed},
      );
    }

    // 2. WiFi
    if (trimmed.toUpperCase().startsWith('WIFI:')) {
      final wifiPattern = RegExp(r'WIFI:S:(.*?);T:(.*?);P:(.*?);;', caseSensitive: false);
      final match = wifiPattern.firstMatch(trimmed);
      if (match != null) {
        return NdefRecordModel(
          type: 'wifi',
          payload: {
            'ssid': match.group(1),
            'encryption': match.group(2) ?? 'WPA',
            'password': match.group(3),
          },
        );
      }
    }

    // 3. Email
    if (trimmed.toLowerCase().startsWith('mailto:')) {
      final parts = trimmed.substring(7).split('?');
      final email = parts[0];
      String subject = '';
      String body = '';
      if (parts.length > 1) {
        final queryParams = Uri.splitQueryString(parts[1]);
        subject = queryParams['subject'] ?? '';
        body = queryParams['body'] ?? '';
      }
      return NdefRecordModel(
        type: 'email',
        payload: {'email': email, 'subject': subject, 'body': body},
      );
    }

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (emailRegex.hasMatch(trimmed)) {
      return NdefRecordModel(
        type: 'email',
        payload: {'email': trimmed, 'subject': '', 'body': ''},
      );
    }

    // 4. SMS
    if (trimmed.toLowerCase().startsWith('sms:')) {
      final parts = trimmed.substring(4).split('?');
      final phone = parts[0];
      String body = '';
      if (parts.length > 1) {
        final queryParams = Uri.splitQueryString(parts[1]);
        body = queryParams['body'] ?? '';
      }
      return NdefRecordModel(
        type: 'sms',
        payload: {'phone': phone, 'body': body},
      );
    }

    // 5. Phone number
    if (trimmed.toLowerCase().startsWith('tel:')) {
      return NdefRecordModel(
        type: 'phone',
        payload: {'phone': trimmed.substring(4)},
      );
    }
    final phoneRegex = RegExp(r'^\+?[0-9\-\s]{5,15}$');
    if (phoneRegex.hasMatch(trimmed)) {
      return NdefRecordModel(
        type: 'phone',
        payload: {'phone': trimmed},
      );
    }

    // 6. Location / Geo
    if (trimmed.toLowerCase().startsWith('geo:')) {
      final coords = trimmed.substring(4).split(',');
      final lat = coords.isNotEmpty ? coords[0] : '0';
      final lng = coords.length > 1 ? coords[1] : '0';
      return NdefRecordModel(
        type: 'location',
        payload: {'latitude': lat, 'longitude': lng},
      );
    }

    // 7. Crypto payment URI
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('bitcoin:') ||
        lower.startsWith('ethereum:') ||
        lower.startsWith('lightning:')) {
      final schemeEnd = trimmed.indexOf(':');
      final rest = trimmed.substring(schemeEnd + 1);
      final parts = rest.split('?');
      return NdefRecordModel(
        type: 'bitcoin',
        payload: {
          'scheme': trimmed.substring(0, schemeEnd).toLowerCase(),
          'address': parts[0],
          'amount': parts.length > 1
              ? (Uri.splitQueryString(parts[1])['amount'] ?? '')
              : '',
        },
      );
    }

    // 8. URL
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return NdefRecordModel(
        type: 'uri',
        payload: {'uri': trimmed},
      );
    }

    final domainRegex = RegExp(r'^[a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,5}(/\S*)?$');
    if (domainRegex.hasMatch(trimmed)) {
      return NdefRecordModel(
        type: 'uri',
        payload: {'uri': 'https://$trimmed'},
      );
    }

    // 8. Fallback to Text
    return NdefRecordModel(
      type: 'text',
      payload: {'text': trimmed},
    );
  }
}
