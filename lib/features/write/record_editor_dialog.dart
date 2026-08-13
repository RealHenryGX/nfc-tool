import 'package:flutter/material.dart';

import '../../core/nfc/record_catalog.dart';
import '../../core/theme/stackntrace_tokens.dart';
import '../../models/ndef_record.dart';
import 'record_payload_mapper.dart';
import 'record_type_fields.dart';
import 'record_type_picker.dart';

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
    final hydration = hydrateRecordPayload(widget.record?.payload ?? {});
    for (final entry in hydration.controllerValues.entries) {
      _ctl(entry.key).text = entry.value;
    }
    _wifiEncryption = hydration.wifiEncryption;
    _socialPlatform = hydration.socialPlatform;
    _btcScheme = hydration.btcScheme;
    _vcardAdvanced = hydration.vcardAdvanced;
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
    final texts = {for (final e in _c.entries) e.key: e.value.text};
    final payload = buildRecordPayload(
      type: _selectedType,
      texts: texts,
      wifiEncryption: _wifiEncryption,
      socialPlatform: _socialPlatform,
      btcScheme: _btcScheme,
      vcardAdvanced: _vcardAdvanced,
    );

    Navigator.pop(
      context,
      NdefRecordModel(type: _selectedType, payload: payload),
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
            child: Form(
              key: _formKey,
              child: RecordTypeFields(
                selectedType: _selectedType,
                controllerFor: _ctl,
                wifiEncryption: _wifiEncryption,
                onWifiEncryptionChanged: (v) =>
                    setState(() => _wifiEncryption = v ?? 'WPA'),
                socialPlatform: _socialPlatform,
                onSocialPlatformChanged: (v) =>
                    setState(() => _socialPlatform = v ?? 'twitter'),
                btcScheme: _btcScheme,
                onBtcSchemeChanged: (v) =>
                    setState(() => _btcScheme = v ?? 'bitcoin'),
                vcardAdvanced: _vcardAdvanced,
                onVcardAdvancedChanged: (v) =>
                    setState(() => _vcardAdvanced = v),
                onPackageNamePicked: (pkg) =>
                    setState(() => _ctl('packageName').text = pkg),
              ),
            ),
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
                  ? RecordTypePicker(
                      theme: theme,
                      brightness: brightness,
                      searchController: _searchCtrl,
                      groupFilter: _groupFilter,
                      query: _query,
                      onGroupFilterChanged: (g) => setState(() => _groupFilter = g),
                      onQueryChanged: (q) => setState(() => _query = q),
                      onSelect: (id) => setState(() {
                        _selectedType = id;
                        _pickingType = false;
                      }),
                    )
                  : _buildForm(theme, brightness),
            ),
          ],
        ),
      ),
    );
  }
}
