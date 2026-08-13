import 'dart:convert';
import 'dart:typed_data';
import 'package:nfc_manager/ndef_record.dart';
import '../../models/ndef_record.dart';
import '../utils/hex.dart';

class NfcHelper {
  static const List<String> _uriPrefixes = [
    "",
    "http://www.",
    "https://www.",
    "http://",
    "https://",
    "tel:",
    "mailto:",
    "ftp://anonymous:anonymous@",
    "ftp://ftp.",
    "ftps://",
    "sftp://",
    "smb://",
    "nfs://",
    "ftp://",
    "dav://",
    "news:",
    "telnet://",
    "imap:",
    "rtsp://",
    "urn:",
    "pop:",
    "sip:",
    "sips:",
    "tftp:",
    "btspp://",
    "btl2cap://",
    "btgoep://",
    "tcpobex://",
    "irdaobex://",
    "file://",
    "urn:epc:id:",
    "urn:epc:tag:",
    "urn:epc:pat:",
    "urn:epc:raw:",
    "urn:epc:",
    "urn:nfc:",
  ];

  static const Map<String, String> socialBaseUrls = {
    'twitter': 'https://twitter.com/',
    'x': 'https://x.com/',
    'facebook': 'https://www.facebook.com/',
    'instagram': 'https://www.instagram.com/',
    'linkedin': 'https://www.linkedin.com/in/',
    'youtube': 'https://www.youtube.com/@',
    'github': 'https://github.com/',
    'tiktok': 'https://www.tiktok.com/@',
  };

  static NdefRecordModel convertToModel(NdefRecord record) {
    final typeNameFormat = record.typeNameFormat;
    final typeStr = utf8.decode(record.type, allowMalformed: true);

    if (typeNameFormat == TypeNameFormat.wellKnown) {
      if (typeStr == 'U') {
        final uri = parseUriRecord(record);
        return _modelFromUri(uri);
      } else if (typeStr == 'T') {
        return NdefRecordModel(
          type: 'text',
          payload: {'text': parseTextRecord(record)},
        );
      }
    } else if (typeNameFormat == TypeNameFormat.media) {
      if (typeStr == 'text/vcard' || typeStr == 'text/x-vCard') {
        return NdefRecordModel(
          type: 'vcard',
          payload: {'vcard': utf8.decode(record.payload, allowMalformed: true)},
        );
      } else if (typeStr == 'application/vnd.wfa.wsc') {
        final wifi = _parseWifiWsc(record.payload);
        if (wifi != null) return wifi;
        final asText = utf8.decode(record.payload, allowMalformed: true);
        if (asText.toUpperCase().startsWith('WIFI:')) {
          return _parseWifiQr(asText) ??
              NdefRecordModel(
                type: 'mime',
                payload: {'mimeType': typeStr, 'payload': asText},
              );
        }
        return NdefRecordModel(
          type: 'mime',
          payload: {
            'mimeType': typeStr,
            'payload': base64Encode(record.payload),
          },
        );
      } else if (typeStr == 'application/vnd.bluetooth.ep.oob') {
        final mac = _parseBluetoothOob(record.payload);
        return NdefRecordModel(
          type: 'bluetooth',
          payload: {'mac': mac ?? bytesToHex(record.payload, separator: ':')},
        );
      } else if (typeStr == 'application/x-nfctoolbox-task') {
        final raw = utf8.decode(record.payload, allowMalformed: true);
        try {
          final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
          return NdefRecordModel(
            type: 'task',
            payload: {
              'mimeType': typeStr,
              'task': map,
              'payload': raw,
            },
          );
        } catch (_) {
          return NdefRecordModel(
            type: 'mime',
            payload: {'mimeType': typeStr, 'payload': raw},
          );
        }
      } else {
        final payloadStr = utf8.decode(record.payload, allowMalformed: true);
        return NdefRecordModel(
          type: 'mime',
          payload: {'mimeType': typeStr, 'payload': payloadStr},
        );
      }
    } else if (typeNameFormat == TypeNameFormat.external) {
      if (typeStr == 'android.com:pkg') {
        return NdefRecordModel(
          type: 'aar',
          payload: {'packageName': utf8.decode(record.payload)},
        );
      }
    }

    return NdefRecordModel(
      type: 'custom',
      payload: {
        'tnf': typeNameFormat.index,
        'type': typeStr,
        'payload': base64Encode(record.payload),
      },
    );
  }

  static NdefRecordModel _modelFromUri(String uri) {
        if (uri.startsWith('mailto:')) {
      final parts = uri.substring(7).split('?');
      final email = parts[0];
      String subject = '';
      String body = '';
      String cc = '';
      String bcc = '';
      if (parts.length > 1) {
        final queryParams = Uri.splitQueryString(parts[1]);
        subject = queryParams['subject'] ?? '';
        body = queryParams['body'] ?? '';
        cc = queryParams['cc'] ?? '';
        bcc = queryParams['bcc'] ?? '';
      }
      return NdefRecordModel(
        type: 'email',
        payload: {
          'email': email,
          'subject': subject,
          'body': body,
          'cc': cc,
          'bcc': bcc,
        },
      );
    }
    if (uri.startsWith('tel:')) {
      return NdefRecordModel(type: 'phone', payload: {'phone': uri.substring(4)});
    }
    if (uri.startsWith('sms:') || uri.startsWith('smsto:')) {
      final raw = uri.startsWith('smsto:') ? uri.substring(6) : uri.substring(4);
      final parts = raw.split('?');
      final phone = parts[0];
      String body = '';
      if (parts.length > 1) {
        body = Uri.splitQueryString(parts[1])['body'] ?? '';
      }
      return NdefRecordModel(type: 'sms', payload: {'phone': phone, 'body': body});
    }
    if (uri.startsWith('geo:')) {
      final coords = uri.substring(4).split(',');
      return NdefRecordModel(
        type: 'location',
        payload: {
          'latitude': coords.isNotEmpty ? coords[0] : '0',
          'longitude': coords.length > 1 ? coords[1].split(';').first : '0',
        },
      );
    }
    if (uri.toUpperCase().startsWith('WIFI:')) {
      return _parseWifiQr(uri) ?? NdefRecordModel(type: 'uri', payload: {'uri': uri});
    }
    if (uri.toLowerCase().startsWith('bitcoin:') ||
        uri.toLowerCase().startsWith('ethereum:') ||
        uri.toLowerCase().startsWith('lightning:')) {
      final schemeEnd = uri.indexOf(':');
      final rest = uri.substring(schemeEnd + 1);
      final parts = rest.split('?');
      return NdefRecordModel(
        type: 'bitcoin',
        payload: {
          'scheme': uri.substring(0, schemeEnd).toLowerCase(),
          'address': parts[0],
          'amount': parts.length > 1
              ? (Uri.splitQueryString(parts[1])['amount'] ?? '')
              : '',
        },
      );
    }
    for (final entry in socialBaseUrls.entries) {
      if (uri.startsWith(entry.value)) {
        return NdefRecordModel(
          type: 'social',
          payload: {
            'platform': entry.key,
            'handle': uri.substring(entry.value.length),
          },
        );
      }
    }
    if (uri.startsWith('https://www.google.com/search?q=') ||
        uri.startsWith('https://google.com/search?q=')) {
      final q = Uri.tryParse(uri)?.queryParameters['q'] ?? '';
      return NdefRecordModel(type: 'search', payload: {'query': q});
    }
    if (uri.contains('youtube.com') ||
        uri.contains('youtu.be') ||
        uri.contains('vimeo.com')) {
      return NdefRecordModel(type: 'video', payload: {'url': uri});
    }
    if (uri.startsWith('https://www.google.com/maps/dir/') ||
        uri.contains('maps/dir/?api=1')) {
      final dest = Uri.tryParse(uri)?.queryParameters['destination'] ?? uri;
      return NdefRecordModel(type: 'destination', payload: {'destination': dest});
    }
    if (uri.contains('map_action=pano') || uri.contains('streetview')) {
      return NdefRecordModel(type: 'streetview', payload: {'url': uri});
    }
    if (uri.startsWith('https://www.google.com/maps/search/') ||
        uri.contains('maps/search/?api=1')) {
      final q = Uri.tryParse(uri)?.queryParameters['query'] ?? '';
      return NdefRecordModel(type: 'proximity', payload: {'query': q});
    }
    if (uri.startsWith('https://maps.google.com/?q=') ||
        uri.startsWith('https://www.google.com/maps?q=')) {
      final q = Uri.tryParse(uri)?.queryParameters['q'] ?? '';
      if (RegExp(r'^-?\d+(\.\d+)?,-?\d+(\.\d+)?$').hasMatch(q)) {
        final parts = q.split(',');
        return NdefRecordModel(
          type: 'custom_geo',
          payload: {'latitude': parts[0], 'longitude': parts[1]},
        );
      }
      return NdefRecordModel(type: 'address', payload: {'address': q});
    }
    if (uri.startsWith('tel:') &&
        (uri.contains('112') || uri.contains('911') || uri.contains('999'))) {
      return NdefRecordModel(
        type: 'emergency',
        payload: {'phone': uri.substring(4), 'label': 'ICE'},
      );
    }
    if (uri.startsWith('file://') || uri.startsWith('content://')) {
      return NdefRecordModel(type: 'file', payload: {'path': uri});
    }
    // Non-standard schemes → custom_uri
    final scheme = Uri.tryParse(uri)?.scheme ?? '';
    if (scheme.isNotEmpty &&
        !['http', 'https', 'tel', 'mailto', 'sms', 'smsto', 'geo', 'bitcoin', 'ethereum', 'lightning']
            .contains(scheme)) {
      return NdefRecordModel(type: 'custom_uri', payload: {'uri': uri});
    }
    return NdefRecordModel(type: 'uri', payload: {'uri': uri});
  }

  static NdefRecord convertToNdefRecord(NdefRecordModel model) {
    switch (model.type) {
      case 'text':
        final text = model.payload['text']?.toString() ?? '';
        final langBytes = utf8.encode('en');
        final textBytes = utf8.encode(text);
        final payload = Uint8List(1 + langBytes.length + textBytes.length);
        payload[0] = langBytes.length;
        payload.setRange(1, 1 + langBytes.length, langBytes);
        payload.setRange(1 + langBytes.length, payload.length, textBytes);
        return NdefRecord(
          typeNameFormat: TypeNameFormat.wellKnown,
          type: Uint8List.fromList(utf8.encode('T')),
          identifier: Uint8List(0),
          payload: payload,
        );
      case 'uri':
        return _createUriNdefRecord(model.payload['uri']?.toString() ?? '');
      case 'email':
        final email = model.payload['email']?.toString() ?? '';
        final subject = model.payload['subject']?.toString() ?? '';
        final body = model.payload['body']?.toString() ?? '';
        final cc = model.payload['cc']?.toString() ?? '';
        final bcc = model.payload['bcc']?.toString() ?? '';
        final q = <String>[
          if (subject.isNotEmpty) 'subject=${Uri.encodeComponent(subject)}',
          if (body.isNotEmpty) 'body=${Uri.encodeComponent(body)}',
          if (cc.isNotEmpty) 'cc=${Uri.encodeComponent(cc)}',
          if (bcc.isNotEmpty) 'bcc=${Uri.encodeComponent(bcc)}',
        ].join('&');
        return _createUriNdefRecord(q.isEmpty ? 'mailto:$email' : 'mailto:$email?$q');
      case 'phone':
        return _createUriNdefRecord('tel:${model.payload['phone'] ?? ''}');
      case 'sms':
        final phone = model.payload['phone']?.toString() ?? '';
        final body = model.payload['body']?.toString() ?? '';
        return _createUriNdefRecord(
          'sms:$phone?body=${Uri.encodeComponent(body)}',
        );
      case 'location':
        final lat = model.payload['latitude']?.toString() ?? '0';
        final lng = model.payload['longitude']?.toString() ?? '0';
        return _createUriNdefRecord('geo:$lat,$lng');
      case 'wifi':
        return NdefRecord(
          typeNameFormat: TypeNameFormat.media,
          type: Uint8List.fromList(utf8.encode('application/vnd.wfa.wsc')),
          identifier: Uint8List(0),
          payload: buildWifiWscPayload(
            ssid: model.payload['ssid']?.toString() ?? '',
            password: model.payload['password']?.toString() ?? '',
            encryption: model.payload['encryption']?.toString() ?? 'WPA',
          ),
        );
      case 'vcard':
        final vcard = model.payload['vcard']?.toString() ?? buildVcard(model.payload);
        return NdefRecord(
          typeNameFormat: TypeNameFormat.media,
          type: Uint8List.fromList(utf8.encode('text/vcard')),
          identifier: Uint8List(0),
          payload: Uint8List.fromList(utf8.encode(vcard)),
        );
      case 'aar':
        final pkg = model.payload['packageName']?.toString() ?? '';
        return NdefRecord(
          typeNameFormat: TypeNameFormat.external,
          type: Uint8List.fromList(utf8.encode('android.com:pkg')),
          identifier: Uint8List(0),
          payload: Uint8List.fromList(utf8.encode(pkg)),
        );
      case 'mime':
        final mimeType = model.payload['mimeType']?.toString() ?? 'text/plain';
        final payload = model.payload['payload']?.toString() ?? '';
        return NdefRecord(
          typeNameFormat: TypeNameFormat.media,
          type: Uint8List.fromList(utf8.encode(mimeType)),
          identifier: Uint8List(0),
          payload: Uint8List.fromList(utf8.encode(payload)),
        );
      case 'bluetooth':
        return NdefRecord(
          typeNameFormat: TypeNameFormat.media,
          type: Uint8List.fromList(
            utf8.encode('application/vnd.bluetooth.ep.oob'),
          ),
          identifier: Uint8List(0),
          payload: buildBluetoothOobPayload(
            model.payload['mac']?.toString() ?? '',
          ),
        );
      case 'bitcoin':
        final scheme = model.payload['scheme']?.toString() ?? 'bitcoin';
        final address = model.payload['address']?.toString() ?? '';
        final amount = model.payload['amount']?.toString() ?? '';
        final uri = amount.isEmpty
            ? '$scheme:$address'
            : '$scheme:$address?amount=${Uri.encodeComponent(amount)}';
        return _createUriNdefRecord(uri);
      case 'social':
        final platform =
            (model.payload['platform']?.toString() ?? 'twitter').toLowerCase();
        final handle = model.payload['handle']?.toString() ?? '';
        final base = socialBaseUrls[platform] ?? 'https://';
        final cleaned = handle.startsWith('@') ? handle.substring(1) : handle;
        return _createUriNdefRecord('$base$cleaned');
      case 'search':
        final query = model.payload['query']?.toString() ?? '';
        return _createUriNdefRecord(
          'https://www.google.com/search?q=${Uri.encodeComponent(query)}',
        );
      case 'address':
        final address = model.payload['address']?.toString() ?? '';
        return _createUriNdefRecord(
          'https://maps.google.com/?q=${Uri.encodeComponent(address)}',
        );
      case 'destination':
        final dest = model.payload['destination']?.toString() ?? '';
        return _createUriNdefRecord(
          'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(dest)}',
        );
      case 'custom_geo':
        final lat = model.payload['latitude']?.toString() ?? '0';
        final lng = model.payload['longitude']?.toString() ?? '0';
        return _createUriNdefRecord('https://maps.google.com/?q=$lat,$lng');
      case 'streetview':
        final url = model.payload['url']?.toString();
        if (url != null && url.isNotEmpty) {
          return _createUriNdefRecord(url);
        }
        final lat = model.payload['latitude']?.toString() ?? '0';
        final lng = model.payload['longitude']?.toString() ?? '0';
        return _createUriNdefRecord(
          'https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=$lat,$lng',
        );
      case 'proximity':
        final query = model.payload['query']?.toString() ?? '';
        return _createUriNdefRecord(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
        );
      case 'video':
        return _createUriNdefRecord(model.payload['url']?.toString() ?? '');
      case 'unit_link':
        return _createUriNdefRecord(model.payload['url']?.toString() ?? '');
      case 'emergency':
        final phone = model.payload['phone']?.toString() ?? '112';
        return _createUriNdefRecord('tel:$phone');
      case 'file':
        return _createUriNdefRecord(model.payload['path']?.toString() ?? '');
      case 'custom_uri':
        return _createUriNdefRecord(model.payload['uri']?.toString() ?? '');
      case 'application':
        final pkg = model.payload['packageName']?.toString() ?? '';
        return NdefRecord(
          typeNameFormat: TypeNameFormat.external,
          type: Uint8List.fromList(utf8.encode('android.com:pkg')),
          identifier: Uint8List(0),
          payload: Uint8List.fromList(utf8.encode(pkg)),
        );
      case 'task':
        final raw = model.payload['payload']?.toString() ??
            jsonEncode(model.payload['task'] ?? model.payload);
        return NdefRecord(
          typeNameFormat: TypeNameFormat.media,
          type: Uint8List.fromList(
            utf8.encode('application/x-nfctoolbox-task'),
          ),
          identifier: Uint8List(0),
          payload: Uint8List.fromList(utf8.encode(raw)),
        );
      case 'custom':
        final tnfIndex = model.payload['tnf'] as int? ?? 0;
        final tnf = TypeNameFormat.values[
            tnfIndex.clamp(0, TypeNameFormat.values.length - 1)];
        final type = model.payload['type']?.toString() ?? '';
        final payloadBase64 = model.payload['payload']?.toString() ?? '';
        return NdefRecord(
          typeNameFormat: tnf,
          type: Uint8List.fromList(utf8.encode(type)),
          identifier: Uint8List(0),
          payload: base64Decode(payloadBase64),
        );
      default:
        final textBytes = utf8.encode(model.payload.toString());
        final payload = Uint8List(3 + textBytes.length);
        payload[0] = 2;
        payload[1] = 0x65; // e
        payload[2] = 0x6E; // n
        payload.setRange(3, payload.length, textBytes);
        return NdefRecord(
          typeNameFormat: TypeNameFormat.wellKnown,
          type: Uint8List.fromList([0x54]),
          identifier: Uint8List(0),
          payload: payload,
        );
    }
  }

  /// Build WPS Credential NDEF payload (application/vnd.wfa.wsc).
  static Uint8List buildWifiWscPayload({
    required String ssid,
    required String password,
    required String encryption,
  }) {
    final enc = encryption.toUpperCase();
    int authType;
    int encrType;
    if (enc == 'NOPASS' || enc == 'OPEN' || enc == 'NONE') {
      authType = 0x0001;
      encrType = 0x0001;
    } else if (enc == 'WEP') {
      authType = 0x0002;
      encrType = 0x0002;
    } else {
      // WPA / WPA2-PSK
      authType = 0x0020;
      encrType = 0x0008;
    }

    final credentialInner = BytesBuilder();
    credentialInner.add(_wpsTlv(0x1026, Uint8List.fromList([0x01]))); // NETWORK_INDEX
    credentialInner.add(_wpsTlv(0x1045, utf8.encode(ssid))); // SSID
    credentialInner.add(_wpsTlv(0x1003, _u16be(authType))); // AUTH_TYPE
    credentialInner.add(_wpsTlv(0x100F, _u16be(encrType))); // ENCR_TYPE
    if (password.isNotEmpty) {
      credentialInner.add(_wpsTlv(0x1027, utf8.encode(password))); // NETWORK_KEY
    }
    credentialInner.add(
      _wpsTlv(0x1020, Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])),
    ); // MAC_ADDRESS

    return _wpsTlv(0x100E, credentialInner.toBytes()); // CREDENTIAL
  }

  static Uint8List _wpsTlv(int type, List<int> data) {
    final out = BytesBuilder();
    out.add(_u16be(type));
    out.add(_u16be(data.length));
    out.add(data);
    return out.toBytes();
  }

  static Uint8List _u16be(int value) =>
      Uint8List.fromList([(value >> 8) & 0xFF, value & 0xFF]);

  static NdefRecordModel? _parseWifiWsc(Uint8List payload) {
    try {
      String? ssid;
      String? password;
      String encryption = 'WPA';
      var i = 0;
      while (i + 4 <= payload.length) {
        final type = (payload[i] << 8) | payload[i + 1];
        final len = (payload[i + 2] << 8) | payload[i + 3];
        i += 4;
        if (i + len > payload.length) break;
        final value = payload.sublist(i, i + len);
        i += len;
        if (type == 0x100E) {
          // nested credential
          final nested = _parseWifiWsc(value);
          if (nested != null) return nested;
        } else if (type == 0x1045) {
          ssid = utf8.decode(value, allowMalformed: true);
        } else if (type == 0x1027) {
          password = utf8.decode(value, allowMalformed: true);
        } else if (type == 0x1003 && value.length >= 2) {
          final auth = (value[0] << 8) | value[1];
          if (auth == 0x0001) {
            encryption = 'nopass';
          } else if (auth == 0x0002) {
            encryption = 'WEP';
          } else {
            encryption = 'WPA';
          }
        }
      }
      if (ssid != null) {
        return NdefRecordModel(
          type: 'wifi',
          payload: {
            'ssid': ssid,
            'password': password ?? '',
            'encryption': encryption,
          },
        );
      }
    } catch (_) {}
    return null;
  }

  static NdefRecordModel? _parseWifiQr(String wifiString) {
    final wifiPattern = RegExp(
      r'WIFI:S:(.*?);T:(.*?);P:(.*?);;',
      caseSensitive: false,
    );
    final match = wifiPattern.firstMatch(wifiString);
    if (match == null) return null;
    return NdefRecordModel(
      type: 'wifi',
      payload: {
        'ssid': match.group(1),
        'encryption': match.group(2) ?? 'WPA',
        'password': match.group(3) ?? '',
      },
    );
  }

  static Uint8List buildBluetoothOobPayload(String mac) {
    final parts = mac.split(RegExp(r'[:\-\s]'));
    if (parts.length != 6) {
      return Uint8List.fromList(utf8.encode(mac));
    }
    final addr = Uint8List(6);
    for (var i = 0; i < 6; i++) {
      // BD_ADDR is little-endian on the wire for OOB
      addr[i] = int.parse(parts[5 - i], radix: 16);
    }
    final out = BytesBuilder();
    // length includes itself (2) + BD_ADDR (6)
    out.add([0x08, 0x00]);
    out.add(addr);
    return out.toBytes();
  }

  static String? _parseBluetoothOob(Uint8List payload) {
    if (payload.length < 8) return null;
    final addr = payload.sublist(2, 8);
    return List.generate(
      6,
      (i) => addr[5 - i].toRadixString(16).padLeft(2, '0').toUpperCase(),
    ).join(':');
  }

  static String buildVcard(Map<String, dynamic> p) {
    if (p['vcard'] != null && p['vcard'].toString().trim().isNotEmpty) {
      return p['vcard'].toString();
    }
    final fn = p['name']?.toString() ?? '';
    final tel = p['phone']?.toString() ?? '';
    final email = p['email']?.toString() ?? '';
    final org = p['org']?.toString() ?? '';
    final url = p['url']?.toString() ?? '';
    final buf = StringBuffer()
      ..writeln('BEGIN:VCARD')
      ..writeln('VERSION:3.0')
      ..writeln('FN:$fn')
      ..writeln('N:$fn');
    if (tel.isNotEmpty) buf.writeln('TEL:$tel');
    if (email.isNotEmpty) buf.writeln('EMAIL:$email');
    if (org.isNotEmpty) buf.writeln('ORG:$org');
    if (url.isNotEmpty) buf.writeln('URL:$url');
    buf.writeln('END:VCARD');
    return buf.toString();
  }

  static NdefRecord _createUriNdefRecord(String uriStr) {
    int prefixIndex = 0;
    String suffix = uriStr;
    for (int i = 1; i < _uriPrefixes.length; i++) {
      if (uriStr.startsWith(_uriPrefixes[i])) {
        if (_uriPrefixes[i].length > _uriPrefixes[prefixIndex].length) {
          prefixIndex = i;
          suffix = uriStr.substring(_uriPrefixes[i].length);
        }
      }
    }
    final suffixBytes = utf8.encode(suffix);
    final payload = Uint8List(1 + suffixBytes.length);
    payload[0] = prefixIndex;
    payload.setRange(1, payload.length, suffixBytes);
    return NdefRecord(
      typeNameFormat: TypeNameFormat.wellKnown,
      type: Uint8List.fromList([0x55]),
      identifier: Uint8List(0),
      payload: payload,
    );
  }

  static String parseUriRecord(NdefRecord record) {
    if (record.payload.isEmpty) return '';
    final prefixIndex = record.payload[0];
    if (prefixIndex < 0 || prefixIndex >= _uriPrefixes.length) {
      return utf8.decode(record.payload.sublist(1), allowMalformed: true);
    }
    final prefix = _uriPrefixes[prefixIndex];
    final suffix = utf8.decode(record.payload.sublist(1), allowMalformed: true);
    return '$prefix$suffix';
  }

  static String parseTextRecord(NdefRecord record) {
    if (record.payload.isEmpty) return '';
    final statusByte = record.payload[0];
    final isUtf16 = (statusByte & 0x80) != 0;
    final langLen = statusByte & 0x3F;
    if (record.payload.length < 1 + langLen) return '';
    final textBytes = record.payload.sublist(1 + langLen);
    if (isUtf16) {
      if (textBytes.length.isOdd) {
        return utf8.decode(textBytes, allowMalformed: true);
      }
      final codeUnits = <int>[];
      for (var i = 0; i + 1 < textBytes.length; i += 2) {
        codeUnits.add((textBytes[i] << 8) | textBytes[i + 1]);
      }
      return String.fromCharCodes(codeUnits);
    }
    return utf8.decode(textBytes, allowMalformed: true);
  }
}
