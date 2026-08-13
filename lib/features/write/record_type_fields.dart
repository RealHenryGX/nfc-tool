import 'package:flutter/material.dart';

import '../../core/nfc/nfc_helper.dart';
import '../../core/widgets/app_ui.dart';
import 'app_picker_dialog.dart';

/// Payload field matrix for the Add/Edit Record form — one branch per
/// record type, mirroring the previous inline `_fields()` switch.
class RecordTypeFields extends StatelessWidget {
  final String selectedType;
  final TextEditingController Function(String key) controllerFor;
  final String wifiEncryption;
  final ValueChanged<String?> onWifiEncryptionChanged;
  final String socialPlatform;
  final ValueChanged<String?> onSocialPlatformChanged;
  final String btcScheme;
  final ValueChanged<String?> onBtcSchemeChanged;
  final bool vcardAdvanced;
  final ValueChanged<bool> onVcardAdvancedChanged;
  final ValueChanged<String> onPackageNamePicked;

  const RecordTypeFields({
    super.key,
    required this.selectedType,
    required this.controllerFor,
    required this.wifiEncryption,
    required this.onWifiEncryptionChanged,
    required this.socialPlatform,
    required this.onSocialPlatformChanged,
    required this.btcScheme,
    required this.onBtcSchemeChanged,
    required this.vcardAdvanced,
    required this.onVcardAdvancedChanged,
    required this.onPackageNamePicked,
  });

  Widget _tf(
    String key,
    String label, {
    String? hint,
    IconData? icon,
    int lines = 1,
    bool optional = false,
    TextInputType? keyboard,
    bool obscure = false,
  }) {
    return AppLabeledField(
      label: optional ? '$label (optional)' : label,
      child: TextFormField(
        controller: controllerFor(key),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon) : null,
        ),
        maxLines: lines,
        obscureText: obscure,
        keyboardType: keyboard,
        validator: optional
            ? null
            : (v) => (v == null || v.isEmpty) ? 'Required' : null,
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return AppLabeledField(
      label: label,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        decoration: const InputDecoration(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (selectedType) {
      case 'text':
        return _tf('text', 'Text', icon: Icons.text_fields, lines: 3);
      case 'uri':
      case 'custom_uri':
      case 'unit_link':
      case 'video':
        return _tf('uri', 'URL / URI', icon: Icons.link, hint: 'https://…');
      case 'email':
        return Column(children: [
          _tf('email', 'Email', icon: Icons.email, keyboard: TextInputType.emailAddress),
          _tf('subject', 'Subject', icon: Icons.subject, optional: true),
          _tf('cc', 'Cc', icon: Icons.group_add, optional: true),
          _tf('bcc', 'Bcc', icon: Icons.group_off, optional: true),
          _tf('body', 'Body', icon: Icons.edit_note, lines: 3, optional: true),
        ]);
      case 'phone':
        return _tf('phone', 'Phone', icon: Icons.phone, keyboard: TextInputType.phone);
      case 'emergency':
        return Column(children: [
          _tf('phone', 'Emergency number', hint: '112 / 911', icon: Icons.emergency, keyboard: TextInputType.phone),
          _tf('label', 'Label', optional: true, icon: Icons.label),
        ]);
      case 'sms':
        return Column(children: [
          _tf('phone', 'Phone', icon: Icons.phone, keyboard: TextInputType.phone),
          _tf('body', 'Message', icon: Icons.message, lines: 3),
        ]);
      case 'wifi':
        return Column(children: [
          _tf('ssid', 'SSID', icon: Icons.wifi),
          _tf('password', 'Password', icon: Icons.lock, obscure: true, optional: true),
          _dropdown<String>(
            label: 'Encryption',
            value: wifiEncryption,
            items: const [
              DropdownMenuItem(value: 'WPA', child: Text('WPA/WPA2')),
              DropdownMenuItem(value: 'WEP', child: Text('WEP')),
              DropdownMenuItem(value: 'nopass', child: Text('Open')),
            ],
            onChanged: onWifiEncryptionChanged,
          ),
        ]);
      case 'vcard':
        return Column(children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Raw vCard'),
            value: vcardAdvanced,
            onChanged: onVcardAdvancedChanged,
          ),
          if (vcardAdvanced)
            _tf('vcard', 'vCard', lines: 8, icon: Icons.person)
          else ...[
            _tf('name', 'Name', icon: Icons.badge),
            _tf('phone', 'Phone', optional: true, icon: Icons.phone),
            _tf('email', 'Email', optional: true, icon: Icons.email),
            _tf('org', 'Org', optional: true, icon: Icons.business),
            _tf('url', 'Website', optional: true, icon: Icons.link),
          ],
        ]);
      case 'location':
      case 'custom_geo':
      case 'streetview':
        return Column(children: [
          _tf('latitude', 'Latitude', icon: Icons.map, keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true)),
          _tf('longitude', 'Longitude', icon: Icons.map, keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true)),
          if (selectedType == 'streetview')
            _tf('uri', 'Override URL', optional: true, icon: Icons.link),
        ]);
      case 'address':
        return _tf('address', 'Street address', icon: Icons.home, lines: 2);
      case 'destination':
        return _tf('destination', 'Destination', icon: Icons.navigation, lines: 2);
      case 'proximity':
      case 'search':
        return _tf('query', 'Query', icon: Icons.search);
      case 'social':
        return Column(children: [
          _dropdown<String>(
            label: 'Platform',
            value: socialPlatform,
            items: NfcHelper.socialBaseUrls.keys
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: onSocialPlatformChanged,
          ),
          _tf('handle', 'Handle', icon: Icons.alternate_email),
        ]);
      case 'bitcoin':
        return Column(children: [
          _dropdown<String>(
            label: 'Scheme',
            value: btcScheme,
            items: const [
              DropdownMenuItem(value: 'bitcoin', child: Text('bitcoin')),
              DropdownMenuItem(value: 'ethereum', child: Text('ethereum')),
              DropdownMenuItem(value: 'lightning', child: Text('lightning')),
            ],
            onChanged: onBtcSchemeChanged,
          ),
          _tf('btcAddress', 'Address', icon: Icons.account_balance_wallet),
          _tf('amount', 'Amount', optional: true, icon: Icons.numbers),
        ]);
      case 'bluetooth':
        return _tf('mac', 'MAC AA:BB:CC:DD:EE:FF', icon: Icons.bluetooth);
      case 'aar':
      case 'application':
        return Column(
          children: [
            _tf('packageName', 'Package name', hint: 'com.example.app', icon: Icons.android),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final pkg = await showDialog<String>(
                    context: context,
                    builder: (_) => const AppPickerDialog(),
                  );
                  if (pkg != null) onPackageNamePicked(pkg);
                },
                icon: const Icon(Icons.apps),
                label: const Text('Pick installed app'),
              ),
            ),
          ],
        );
      case 'file':
        return _tf('path', 'file:// or content://', icon: Icons.insert_drive_file);
      case 'mime':
        return Column(children: [
          _tf('mimeType', 'MIME type', icon: Icons.category),
          _tf('payload', 'Payload', lines: 4, icon: Icons.description),
        ]);
      case 'custom':
        return Column(children: [
          _tf('tnf', 'TNF index 0-6', icon: Icons.numbers),
          _tf('type', 'Type string', icon: Icons.code),
          _tf('payload', 'Payload (base64 or text)', lines: 3, icon: Icons.data_object),
        ]);
      case 'task':
        return _tf(
          'payload',
          'Task JSON',
          lines: 8,
          icon: Icons.bolt,
          hint: '{"id":"...","kind":"wifi_state","params":{}}',
        );
      default:
        return _tf('text', 'Value', icon: Icons.edit);
    }
  }
}
