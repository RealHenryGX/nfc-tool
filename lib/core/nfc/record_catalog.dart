import 'package:flutter/material.dart';

/// Catalog of all NDEF record kinds (parity with NFC Tools Pro Record* screens).
class RecordKind {
  final String id;
  final String label;
  final IconData icon;
  final String group;

  const RecordKind({
    required this.id,
    required this.label,
    required this.icon,
    required this.group,
  });
}

class RecordCatalog {
  static const Map<String, String> groupLabels = {
    'basic': 'Basic',
    'comms': 'Communication',
    'network': 'Network',
    'people': 'People',
    'maps': 'Maps & Places',
    'web': 'Web & Media',
    'app': 'Apps',
    'data': 'Raw / Data',
    'tasks': 'Tasks',
  };

  static const List<RecordKind> all = [
    RecordKind(id: 'text', label: 'Text', icon: Icons.text_fields, group: 'basic'),
    RecordKind(id: 'uri', label: 'URL / URI', icon: Icons.link, group: 'basic'),
    RecordKind(id: 'custom_uri', label: 'Custom URI', icon: Icons.link_outlined, group: 'basic'),
    RecordKind(id: 'email', label: 'Email', icon: Icons.email_outlined, group: 'comms'),
    RecordKind(id: 'phone', label: 'Phone', icon: Icons.phone_outlined, group: 'comms'),
    RecordKind(id: 'sms', label: 'SMS', icon: Icons.sms_outlined, group: 'comms'),
    RecordKind(id: 'emergency', label: 'Emergency', icon: Icons.emergency_outlined, group: 'comms'),
    RecordKind(id: 'wifi', label: 'Wi-Fi', icon: Icons.wifi, group: 'network'),
    RecordKind(id: 'bluetooth', label: 'Bluetooth', icon: Icons.bluetooth, group: 'network'),
    RecordKind(id: 'vcard', label: 'Contact', icon: Icons.contact_page_outlined, group: 'people'),
    RecordKind(id: 'location', label: 'Geo', icon: Icons.my_location, group: 'maps'),
    RecordKind(id: 'address', label: 'Address', icon: Icons.home_outlined, group: 'maps'),
    RecordKind(id: 'destination', label: 'Destination', icon: Icons.navigation_outlined, group: 'maps'),
    RecordKind(id: 'custom_geo', label: 'Maps LatLng', icon: Icons.map_outlined, group: 'maps'),
    RecordKind(id: 'streetview', label: 'Street View', icon: Icons.streetview, group: 'maps'),
    RecordKind(id: 'proximity', label: 'Local Search', icon: Icons.place_outlined, group: 'maps'),
    RecordKind(id: 'search', label: 'Web Search', icon: Icons.search, group: 'web'),
    RecordKind(id: 'social', label: 'Social', icon: Icons.share_outlined, group: 'web'),
    RecordKind(id: 'video', label: 'Video', icon: Icons.play_circle_outline, group: 'web'),
    RecordKind(id: 'bitcoin', label: 'Crypto', icon: Icons.currency_bitcoin, group: 'web'),
    RecordKind(id: 'aar', label: 'Android App', icon: Icons.android, group: 'app'),
    RecordKind(id: 'application', label: 'Application', icon: Icons.apps, group: 'app'),
    RecordKind(id: 'unit_link', label: 'Unit / App Link', icon: Icons.open_in_new, group: 'app'),
    RecordKind(id: 'file', label: 'File', icon: Icons.insert_drive_file_outlined, group: 'data'),
    RecordKind(id: 'mime', label: 'MIME', icon: Icons.category_outlined, group: 'data'),
    RecordKind(id: 'custom', label: 'Custom TNF', icon: Icons.settings_ethernet, group: 'data'),
    RecordKind(id: 'task', label: 'Task Payload', icon: Icons.bolt, group: 'tasks'),
  ];

  static RecordKind? byId(String id) {
    for (final k in all) {
      if (k.id == id) return k;
    }
    return null;
  }

  static List<String> get groups =>
      groupLabels.keys.where((g) => all.any((k) => k.group == g)).toList();
}
