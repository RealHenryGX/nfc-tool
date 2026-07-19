import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/nfc/nfc_dialog.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/ndef_record.dart';
import '../../models/tag_template.dart';
import '../templates/templates_provider.dart';
import '../history/history_provider.dart';
import 'record_editor_dialog.dart';

class WriteScreen extends ConsumerStatefulWidget {
  final TagTemplate? template;

  const WriteScreen({super.key, this.template});

  @override
  ConsumerState<WriteScreen> createState() => _WriteScreenState();
}

class _WriteScreenState extends ConsumerState<WriteScreen> {
  final List<NdefRecordModel> _records = [];

  @override
  void initState() {
    super.initState();
    if (widget.template != null) {
      _records.addAll(widget.template!.records);
    }
  }

  void _addRecord() async {
    final record = await showRecordEditor(context);

    if (record != null) {
      setState(() {
        _records.add(record);
      });
    }
  }

  void _editRecord(int index) async {
    final record = await showRecordEditor(
      context,
      record: _records[index],
    );

    if (record != null) {
      setState(() {
        _records[index] = record;
      });
    }
  }

  void _removeRecord(int index) {
    setState(() {
      _records.removeAt(index);
    });
  }

  void _saveAsTemplate() async {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot save empty records as template')),
      );
      return;
    }

    final nameController = TextEditingController(
      text: widget.template != null ? '${widget.template!.name} (Copy)' : 'My NFC Template',
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save as Template'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: 'Template name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirm == true && nameController.text.trim().isNotEmpty) {
      await ref.read(templatesProvider.notifier).addTemplate(
            nameController.text.trim(),
            _records,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template saved successfully!')),
        );
      }
    }
  }

  void _writeToTag() async {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one record to write')),
      );
      return;
    }

    final success = await showNfcSession<bool>(
      context: context,
      title: 'Ready to Write',
      message: 'Place your tag near the back of your phone.',
      mode: NfcDialogMode.write,
      records: _records,
    );

    if (success == true) {
      // Add success to history
      await ref.read(historyProvider.notifier).addRecord(
            action: 'write',
            records: _records,
            success: true,
            details: 'Wrote ${_records.length} records',
          );
    } else if (success == false) {
      // Add failure to history
      await ref.read(historyProvider.notifier).addRecord(
            action: 'write',
            records: _records,
            success: false,
            details: 'Write operation failed or cancelled',
          );
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'text':
        return Icons.text_fields;
      case 'uri':
        return Icons.link;
      case 'email':
        return Icons.email;
      case 'phone':
        return Icons.phone;
      case 'sms':
        return Icons.message;
      case 'wifi':
        return Icons.wifi;
      case 'vcard':
        return Icons.person;
      case 'location':
        return Icons.map;
      case 'bluetooth':
        return Icons.bluetooth;
      case 'bitcoin':
        return Icons.currency_bitcoin;
      case 'social':
        return Icons.public;
      case 'search':
        return Icons.search;
      case 'aar':
        return Icons.android;
      case 'mime':
        return Icons.category;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template != null ? 'Edit Template: ${widget.template!.name}' : 'Compose NFC Tag',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Save as Template',
              onPressed: _saveAsTemplate,
            ),
        ],
      ),
      body: _records.isEmpty
          ? AppEmptyState(
              icon: Icons.nfc,
              title: 'Compose a Tag',
              subtitle:
                  'Add Text, URLs, Wi‑Fi, vCard, tasks, and more. Drag to reorder before writing.',
              pulse: true,
              action: FilledButton.icon(
                onPressed: _addRecord,
                icon: const Icon(Icons.add),
                label: const Text('Add Record'),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _records.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (oldIndex < newIndex) {
                          newIndex -= 1;
                        }
                        final item = _records.removeAt(oldIndex);
                        _records.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final record = _records[index];
                      String subtitle = record.payload.values.firstWhere((e) => e != null, orElse: () => '').toString();
                      if (record.type == 'wifi') {
                        subtitle = 'SSID: ${record.payload['ssid']}';
                      } else if (record.type == 'email') {
                        subtitle = 'To: ${record.payload['email']}';
                      } else if (record.type == 'bluetooth') {
                        subtitle = record.payload['mac']?.toString() ?? '';
                      } else if (record.type == 'bitcoin') {
                        subtitle = record.payload['address']?.toString() ?? '';
                      } else if (record.type == 'social') {
                        subtitle =
                            '${record.payload['platform']}: ${record.payload['handle']}';
                      } else if (record.type == 'search') {
                        subtitle = record.payload['query']?.toString() ?? '';
                      }

                      return Card(
                        key: ValueKey('${record.type}_${record.payload}_$index'),
                        elevation: 0,
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                            child: Icon(_getIconForType(record.type), color: theme.colorScheme.primary),
                          ),
                          title: Text(
                            record.type.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () => _editRecord(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                onPressed: () => _removeRecord(index),
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: const Icon(Icons.drag_handle, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _addRecord,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Record'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _writeToTag,
                          icon: const Icon(Icons.nfc),
                          label: const Text('Write Tag'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
