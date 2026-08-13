import 'dart:convert';

import '../../core/nfc/nfc_helper.dart';

/// Result of hydrating the Add/Edit Record form from an existing
/// [NdefRecordModel.payload] — pure data, no widgets.
class RecordHydration {
  final Map<String, String> controllerValues;
  final String wifiEncryption;
  final String socialPlatform;
  final String btcScheme;
  final bool vcardAdvanced;

  const RecordHydration({
    required this.controllerValues,
    required this.wifiEncryption,
    required this.socialPlatform,
    required this.btcScheme,
    required this.vcardAdvanced,
  });
}

/// Maps a stored record payload back into text-field values + the small set
/// of dropdown/switch state the editor needs. Mirrors `_hydrate` 1:1.
RecordHydration hydrateRecordPayload(Map<String, dynamic> payload) {
  final values = <String, String>{};
  void set(String k, dynamic v) {
    if (v != null) values[k] = v.toString();
  }

  set('text', payload['text']);
  set('uri', payload['uri']);
  set('email', payload['email']);
  set('subject', payload['subject']);
  set('body', payload['body']);
  set('cc', payload['cc']);
  set('bcc', payload['bcc']);
  set('phone', payload['phone']);
  set('ssid', payload['ssid']);
  set('password', payload['password']);
  set('vcard', payload['vcard']);
  set('name', payload['name']);
  set('org', payload['org']);
  set('url', payload['url']);
  set('latitude', payload['latitude'] ?? '0');
  set('longitude', payload['longitude'] ?? '0');
  set('packageName', payload['packageName']);
  set('mimeType', payload['mimeType']);
  set('payload', payload['payload']);
  set('mac', payload['mac']);
  set('address', payload['address']);
  set('destination', payload['destination']);
  set('query', payload['query']);
  set('handle', payload['handle']);
  set('path', payload['path']);
  set('tnf', payload['tnf']?.toString() ?? '0');
  set('type', payload['type']);
  set('label', payload['label']);
  set('btcAddress', payload['address']);
  set('amount', payload['amount']);

  return RecordHydration(
    controllerValues: values,
    wifiEncryption: payload['encryption']?.toString() ?? 'WPA',
    socialPlatform: payload['platform']?.toString() ?? 'twitter',
    btcScheme: payload['scheme']?.toString() ?? 'bitcoin',
    vcardAdvanced: payload['vcard'] != null,
  );
}

/// Builds the payload map for a new/edited [NdefRecordModel]. Mirrors `_save`
/// 1:1; `texts` is a snapshot of each field controller's `.text`.
Map<String, dynamic> buildRecordPayload({
  required String type,
  required Map<String, String> texts,
  required String wifiEncryption,
  required String socialPlatform,
  required String btcScheme,
  required bool vcardAdvanced,
}) {
  String t(String key) => texts[key] ?? '';
  final payload = <String, dynamic>{};

  switch (type) {
    case 'text':
      payload['text'] = t('text');
    case 'uri':
    case 'custom_uri':
    case 'unit_link':
      payload['uri'] = t('uri');
      if (type == 'unit_link') payload['url'] = t('uri');
    case 'email':
      payload['email'] = t('email');
      payload['subject'] = t('subject');
      payload['body'] = t('body');
      payload['cc'] = t('cc');
      payload['bcc'] = t('bcc');
    case 'phone':
    case 'emergency':
      payload['phone'] = t('phone');
      payload['label'] = t('label');
    case 'sms':
      payload['phone'] = t('phone');
      payload['body'] = t('body');
    case 'wifi':
      payload['ssid'] = t('ssid');
      payload['password'] = t('password');
      payload['encryption'] = wifiEncryption;
    case 'vcard':
      if (vcardAdvanced) {
        payload['vcard'] = t('vcard');
      } else {
        payload['name'] = t('name');
        payload['phone'] = t('phone');
        payload['email'] = t('email');
        payload['org'] = t('org');
        payload['url'] = t('url');
        payload['vcard'] = NfcHelper.buildVcard(payload);
      }
    case 'location':
    case 'custom_geo':
    case 'streetview':
      payload['latitude'] = t('latitude');
      payload['longitude'] = t('longitude');
      if (t('uri').isNotEmpty) payload['url'] = t('uri');
    case 'address':
      payload['address'] = t('address');
    case 'destination':
      payload['destination'] = t('destination');
    case 'proximity':
    case 'search':
      payload['query'] = t('query');
    case 'social':
      payload['platform'] = socialPlatform;
      payload['handle'] = t('handle');
    case 'video':
      payload['url'] = t('uri');
    case 'bitcoin':
      payload['scheme'] = btcScheme;
      payload['address'] = t('btcAddress');
      payload['amount'] = t('amount');
    case 'bluetooth':
      payload['mac'] = t('mac').trim().toUpperCase();
    case 'aar':
    case 'application':
      payload['packageName'] = t('packageName');
    case 'file':
      payload['path'] = t('path');
    case 'mime':
      payload['mimeType'] = t('mimeType');
      payload['payload'] = t('payload');
    case 'custom':
      payload['tnf'] = int.tryParse(t('tnf')) ?? 0;
      payload['type'] = t('type');
      payload['payload'] = base64Encode(utf8.encode(t('payload')));
    case 'task':
      payload['payload'] = t('payload');
      try {
        payload['task'] = jsonDecode(t('payload'));
      } catch (_) {}
  }

  return payload;
}
