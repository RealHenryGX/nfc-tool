import '../../models/ndef_record.dart';
import '../../models/tag_template.dart';

/// Built-in Pro-style presets (FOSS originals, not wakdev assets).
class PresetLibrary {
  static List<TagTemplate> all() {
    final now = DateTime.now();
    return [
      TagTemplate(
        id: 'preset_office_wifi',
        name: 'Office Wi-Fi',
        createdAt: now,
        records: [
          NdefRecordModel(
            type: 'wifi',
            payload: {'ssid': 'Office', 'password': 'changeme', 'encryption': 'WPA'},
          ),
        ],
      ),
      TagTemplate(
        id: 'preset_portfolio',
        name: 'Portfolio Link',
        createdAt: now,
        records: [
          NdefRecordModel(type: 'uri', payload: {'uri': 'https://example.com'}),
        ],
      ),
      TagTemplate(
        id: 'preset_business_card',
        name: 'Business Card',
        createdAt: now,
        records: [
          NdefRecordModel(
            type: 'vcard',
            payload: {
              'name': 'Jane Doe',
              'phone': '+10000000000',
              'email': 'jane@example.com',
              'org': 'Acme',
              'url': 'https://example.com',
              'vcard':
                  'BEGIN:VCARD\nVERSION:3.0\nFN:Jane Doe\nTEL:+10000000000\nEMAIL:jane@example.com\nORG:Acme\nURL:https://example.com\nEND:VCARD\n',
            },
          ),
        ],
      ),
      TagTemplate(
        id: 'preset_emergency',
        name: 'Emergency Call',
        createdAt: now,
        records: [
          NdefRecordModel(type: 'emergency', payload: {'phone': '112', 'label': 'ICE'}),
        ],
      ),
      TagTemplate(
        id: 'preset_maps_home',
        name: 'Navigate Home',
        createdAt: now,
        records: [
          NdefRecordModel(type: 'destination', payload: {'destination': 'Home'}),
        ],
      ),
      TagTemplate(
        id: 'preset_bt_speaker',
        name: 'Bluetooth Pair Hint',
        createdAt: now,
        records: [
          NdefRecordModel(type: 'bluetooth', payload: {'mac': 'AA:BB:CC:DD:EE:FF'}),
        ],
      ),
      TagTemplate(
        id: 'preset_task_wifi',
        name: 'Task: Open Wi-Fi Settings',
        createdAt: now,
        records: [
          NdefRecordModel(
            type: 'task',
            payload: {
              'mimeType': 'application/x-nfctoolbox-task',
              'task': {
                'id': 'preset_task_wifi',
                'kind': 'wifi_network',
                'params': {},
                'label': 'Wi-Fi Settings',
              },
              'payload':
                  '{"id":"preset_task_wifi","kind":"wifi_network","params":{},"label":"Wi-Fi Settings"}',
            },
          ),
        ],
      ),
    ];
  }
}
