import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/nfc/nfc_helper.dart';
import '../../core/nfc/record_catalog.dart';
import '../../core/theme/stackntrace_tokens.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/ndef_record.dart';
import '../../services/platform_apps.dart';

/// Opens the redesigned Add / Edit NFC Record sheet.
Future<NdefRecordModel?> showRecordEditor(
  BuildContext context, {
  NdefRecordModel? record,
}) {
  return showModalBottomSheet<NdefRecordModel>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => RecordEditorDialog(record: record),
  );
}

class RecordEditorDialog extends StatefulWidget {
  final NdefRecordModel? record;

  const RecordEditorDialog({super.key, this.record});

  @override
  State<RecordEditorDialog> createState() => _RecordEditorDialogState();
}

class _RecordEditorDialogState extends State<RecordEditorDialog> {
  late String _selectedType;
  late bool _pickingType;
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _c = {};
  final _searchCtrl = TextEditingController();
  String _groupFilter = 'all';
  String _query = '';
  String _wifiEncryption = 'WPA';
  String _socialPlatform = 'twitter';
  String _btcScheme = 'bitcoin';
  bool _vcardAdvanced = false;

  TextEditingController _ctl(String key) =>
      _c.putIfAbsent(key, TextEditingController.new);

  @override
  void initState() {
    super.initState();
    _selectedType = widget.record?.type ?? 'text';
    _pickingType = widget.record == null;
    _hydrate();
  }

  void _hydrate() {
    final p = widget.record?.payload ?? {};
    void set(String k, dynamic v) {
      if (v != null) _ctl(k).text = v.toString();
    }

    set('text', p['text']);
    set('uri', p['uri']);
    set('email', p['email']);
    set('subject', p['subject']);
    set('body', p['body']);
    set('cc', p['cc']);
    set('bcc', p['bcc']);
    set('phone', p['phone']);
    set('ssid', p['ssid']);
    set('password', p['password']);
    _wifiEncryption = p['encryption']?.toString() ?? 'WPA';
    set('vcard', p['vcard']);
    set('name', p['name']);
    set('org', p['org']);
    set('url', p['url']);
    set('latitude', p['latitude'] ?? '0');
    set('longitude', p['longitude'] ?? '0');
    set('packageName', p['packageName']);
    set('mimeType', p['mimeType']);
    set('payload', p['payload']);
    set('mac', p['mac']);
    set('address', p['address']);
    set('destination', p['destination']);
    set('query', p['query']);
    set('handle', p['handle']);
    set('path', p['path']);
    set('tnf', p['tnf']?.toString() ?? '0');
    set('type', p['type']);
    set('label', p['label']);
    set('btcAddress', p['address']);
    set('amount', p['amount']);
    _btcScheme = p['scheme']?.toString() ?? 'bitcoin';
    _socialPlatform = p['platform']?.toString() ?? 'twitter';
    if (p['vcard'] != null) _vcardAdvanced = true;
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    _searchCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final payload = <String, dynamic>{};

    switch (_selectedType) {
      case 'text':
        payload['text'] = _ctl('text').text;
      case 'uri':
      case 'custom_uri':
      case 'unit_link':
        payload['uri'] = _ctl('uri').text;
        if (_selectedType == 'unit_link') payload['url'] = _ctl('uri').text;
      case 'email':
        payload['email'] = _ctl('email').text;
        payload['subject'] = _ctl('subject').text;
        payload['body'] = _ctl('body').text;
        payload['cc'] = _ctl('cc').text;
        payload['bcc'] = _ctl('bcc').text;
      case 'phone':
      case 'emergency':
        payload['phone'] = _ctl('phone').text;
        payload['label'] = _ctl('label').text;
      case 'sms':
        payload['phone'] = _ctl('phone').text;
        payload['body'] = _ctl('body').text;
      case 'wifi':
        payload['ssid'] = _ctl('ssid').text;
        payload['password'] = _ctl('password').text;
        payload['encryption'] = _wifiEncryption;
      case 'vcard':
        if (_vcardAdvanced) {
          payload['vcard'] = _ctl('vcard').text;
        } else {
          payload['name'] = _ctl('name').text;
          payload['phone'] = _ctl('phone').text;
          payload['email'] = _ctl('email').text;
          payload['org'] = _ctl('org').text;
          payload['url'] = _ctl('url').text;
          payload['vcard'] = NfcHelper.buildVcard(payload);
        }
      case 'location':
      case 'custom_geo':
      case 'streetview':
        payload['latitude'] = _ctl('latitude').text;
        payload['longitude'] = _ctl('longitude').text;
        if (_ctl('uri').text.isNotEmpty) payload['url'] = _ctl('uri').text;
      case 'address':
        payload['address'] = _ctl('address').text;
      case 'destination':
        payload['destination'] = _ctl('destination').text;
      case 'proximity':
      case 'search':
        payload['query'] = _ctl('query').text;
      case 'social':
        payload['platform'] = _socialPlatform;
        payload['handle'] = _ctl('handle').text;
      case 'video':
        payload['url'] = _ctl('uri').text;
      case 'bitcoin':
        payload['scheme'] = _btcScheme;
        payload['address'] = _ctl('btcAddress').text;
        payload['amount'] = _ctl('amount').text;
      case 'bluetooth':
        payload['mac'] = _ctl('mac').text.trim().toUpperCase();
      case 'aar':
      case 'application':
        payload['packageName'] = _ctl('packageName').text;
      case 'file':
        payload['path'] = _ctl('path').text;
      case 'mime':
        payload['mimeType'] = _ctl('mimeType').text;
        payload['payload'] = _ctl('payload').text;
      case 'custom':
        payload['tnf'] = int.tryParse(_ctl('tnf').text) ?? 0;
        payload['type'] = _ctl('type').text;
        payload['payload'] = base64Encode(utf8.encode(_ctl('payload').text));
      case 'task':
        payload['payload'] = _ctl('payload').text;
        try {
          payload['task'] = jsonDecode(_ctl('payload').text);
        } catch (_) {}
    }

    Navigator.pop(
      context,
      NdefRecordModel(type: _selectedType, payload: payload),
    );
  }

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
        controller: _ctl(key),
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

  Widget _fields() {
    switch (_selectedType) {
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
            value: _wifiEncryption,
            items: const [
              DropdownMenuItem(value: 'WPA', child: Text('WPA/WPA2')),
              DropdownMenuItem(value: 'WEP', child: Text('WEP')),
              DropdownMenuItem(value: 'nopass', child: Text('Open')),
            ],
            onChanged: (v) => setState(() => _wifiEncryption = v ?? 'WPA'),
          ),
        ]);
      case 'vcard':
        return Column(children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Raw vCard'),
            value: _vcardAdvanced,
            onChanged: (v) => setState(() => _vcardAdvanced = v),
          ),
          if (_vcardAdvanced)
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
          if (_selectedType == 'streetview')
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
            value: _socialPlatform,
            items: NfcHelper.socialBaseUrls.keys
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _socialPlatform = v ?? 'twitter'),
          ),
          _tf('handle', 'Handle', icon: Icons.alternate_email),
        ]);
      case 'bitcoin':
        return Column(children: [
          _dropdown<String>(
            label: 'Scheme',
            value: _btcScheme,
            items: const [
              DropdownMenuItem(value: 'bitcoin', child: Text('bitcoin')),
              DropdownMenuItem(value: 'ethereum', child: Text('ethereum')),
              DropdownMenuItem(value: 'lightning', child: Text('lightning')),
            ],
            onChanged: (v) => setState(() => _btcScheme = v ?? 'bitcoin'),
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
                    builder: (_) => const _AppPickerDialog(),
                  );
                  if (pkg != null) {
                    setState(() => _ctl('packageName').text = pkg);
                  }
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

  List<RecordKind> get _filteredKinds {
    return RecordCatalog.all.where((k) {
      final gOk = _groupFilter == 'all' || k.group == _groupFilter;
      final q = _query.toLowerCase();
      final qOk = q.isEmpty ||
          k.label.toLowerCase().contains(q) ||
          k.id.toLowerCase().contains(q) ||
          (RecordCatalog.groupLabels[k.group] ?? '').toLowerCase().contains(q);
      return gOk && qOk;
    }).toList();
  }

  Widget _buildTypePicker(ThemeData theme, Brightness brightness) {
    final accent = StackntraceTokens.accent(brightness);
    final kinds = _filteredKinds;
    final groups = <String, List<RecordKind>>{};
    for (final k in kinds) {
      groups.putIfAbsent(k.group, () => []).add(k);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(
            hintText: 'Search record types…',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: const Text('All'),
                  selected: _groupFilter == 'all',
                  onSelected: (_) => setState(() => _groupFilter = 'all'),
                ),
              ),
              ...RecordCatalog.groups.map((g) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(RecordCatalog.groupLabels[g] ?? g),
                    selected: _groupFilter == g,
                    onSelected: (_) => setState(() => _groupFilter = g),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: kinds.isEmpty
              ? Center(
                  child: Text(
                    'No matching types',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView(
                  children: [
                    for (final entry in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                        child: Text(
                          (RecordCatalog.groupLabels[entry.key] ?? entry.key)
                              .toUpperCase(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      ...entry.value.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: StackntraceTokens.surface2(brightness),
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                setState(() {
                                  _selectedType = item.id;
                                  _pickingType = false;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: StackntraceTokens.accentSoft(
                                          brightness,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(item.icon, color: accent),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        item.label,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildForm(ThemeData theme, Brightness brightness) {
    final accent = StackntraceTokens.accent(brightness);
    final kind = RecordCatalog.byId(_selectedType);

    return Column(
      children: [
        Material(
          color: StackntraceTokens.surface2(brightness),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: widget.record == null
                ? () => setState(() => _pickingType = true)
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: StackntraceTokens.accentSoft(brightness),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(kind?.icon ?? Icons.nfc, color: accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kind?.label ?? _selectedType,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.record == null)
                          Text(
                            'Tap to change type',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.record == null)
                    Icon(
                      Icons.swap_horiz,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Form(key: _formKey, child: _fields()),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: brightness == Brightness.dark
                      ? StackntraceTokens.darkOnAccent
                      : StackntraceTokens.lightOnAccent,
                ),
                child: Text(widget.record == null ? 'Add record' : 'Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final media = MediaQuery.of(context);
    final height = media.size.height * 0.92;

    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16 + media.viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _pickingType
                  ? 'Add NFC Record'
                  : (widget.record == null ? 'Configure record' : 'Edit NFC Record'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _pickingType
                  ? 'Choose what to write on the tag'
                  : 'Fill in the payload fields',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _pickingType
                  ? _buildTypePicker(theme, brightness)
                  : _buildForm(theme, brightness),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppPickerDialog extends StatefulWidget {
  const _AppPickerDialog();

  @override
  State<_AppPickerDialog> createState() => _AppPickerDialogState();
}

class _AppPickerDialogState extends State<_AppPickerDialog> {
  late Future<List<LaunchableApp>> _future;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _future = PlatformApps.listLaunchable();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 420,
        height: 520,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Pick application',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Filter…',
                ),
                onChanged: (v) => setState(() => _q = v.toLowerCase()),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<LaunchableApp>>(
                future: _future,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final apps = snap.data!
                      .where(
                        (a) =>
                            _q.isEmpty ||
                            a.label.toLowerCase().contains(_q) ||
                            a.packageName.toLowerCase().contains(_q),
                      )
                      .toList();
                  return ListView.builder(
                    itemCount: apps.length,
                    itemBuilder: (context, i) {
                      final a = apps[i];
                      return ListTile(
                        title: Text(a.label),
                        subtitle: Text(
                          a.packageName,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () => Navigator.pop(context, a.packageName),
                      );
                    },
                  );
                },
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
