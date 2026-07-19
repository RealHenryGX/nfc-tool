import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/nfc/nfc_dialog.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/ndef_record.dart';
import '../../models/nfc_task.dart';
import '../../models/tag_template.dart';
import '../../services/nfc_service.dart';
import '../../services/task_runner.dart';
import 'record_info_screen.dart';

class ReadScreen extends StatefulWidget {
  final NfcTagDetails? initialDetails;

  const ReadScreen({super.key, this.initialDetails});

  @override
  State<ReadScreen> createState() => _ReadScreenState();
}

class _ReadScreenState extends State<ReadScreen> {
  NfcTagDetails? _details;
  bool _isLoadingRaw = false;
  String? _rawHex;

  @override
  void initState() {
    super.initState();
    _details = widget.initialDetails;
  }

  void _scanTag() async {
    final details = await showNfcSession<NfcTagDetails>(
      context: context,
      title: 'Ready to Read',
      message: 'Place your tag near the back of your phone.',
      mode: NfcDialogMode.read,
    );

    if (details != null) {
      setState(() {
        _details = details;
        _rawHex = null;
      });
      await _maybeRunTasks(details);
    }
  }

  Future<void> _maybeRunTasks(NfcTagDetails details) async {
    final tasks = <NfcTask>[];
    for (final r in details.records) {
      final t = NfcTask.fromNdefRecord(r);
      if (t != null) tasks.add(t);
    }
    if (tasks.isEmpty || !mounted) return;

    final run = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Run ${tasks.length} task(s)?'),
        content: Text(tasks.map((t) => '• ${t.displayName}').join('\n')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Run'),
          ),
        ],
      ),
    );
    if (run != true || !mounted) return;

    final buf = StringBuffer();
    for (final t in tasks) {
      buf.writeln('${t.displayName}: ${await TaskRunner.run(t)}');
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(buf.toString().trim())),
    );
  }

  void _lockTag() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lock Tag?'),
        content: const Text(
          'This will make the tag permanently READ-ONLY. This operation CANNOT be undone!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Lock Permanently'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final ok = await showNfcSession<bool>(
        context: context,
        title: 'Locking Tag',
        message: 'Hold your tag against the back of your device.',
        mode: NfcDialogMode.lock,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok == true ? 'Tag locked to read-only' : 'Lock cancelled or failed',
          ),
        ),
      );
      if (ok == true) {
        setState(() => _details = null);
      }
    }
  }

  void _formatTag() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Format Tag?'),
        content: const Text(
          'This will wipe all records and format the tag as empty NDEF. Proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Format'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final ok = await showNfcSession<bool>(
        context: context,
        title: 'Formatting Tag',
        message: 'Hold your tag against the back of your device.',
        mode: NfcDialogMode.format,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok == true ? 'Tag formatted' : 'Format cancelled or failed',
          ),
        ),
      );
      if (ok == true) {
        setState(() => _details = null);
      }
    }
  }

  void _eraseTag() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erase Tag?'),
        content: const Text(
          'Write empty NDEF message (clear records). Chip stays NDEF-formatted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Erase'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final ok = await showNfcSession<bool>(
        context: context,
        title: 'Erase Tag',
        message: 'Hold your tag against the back of your device.',
        mode: NfcDialogMode.erase,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok == true ? 'Tag erased' : 'Erase cancelled or failed'),
        ),
      );
      if (ok == true) {
        setState(() => _details = null);
      }
    }
  }

  void _cloneToWriter() {
    final details = _details;
    if (details == null || details.records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No NDEF records to clone')),
      );
      return;
    }
    context.push(
      '/write',
      extra: TagTemplate(
        id: 'clone_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Clone ${details.uid ?? 'tag'}',
        records: details.records,
        createdAt: DateTime.now(),
      ),
    );
  }

  void _loadRawHex() async {
    setState(() {
      _isLoadingRaw = true;
      _rawHex = null;
    });

    try {
      final res = await NfcService.readRawHex(
        onUpdate: (upd) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(upd)));
        },
        onError: (err) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        },
      );
      setState(() {
        _rawHex = res;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed raw read: $e')));
    } finally {
      setState(() {
        _isLoadingRaw = false;
      });
    }
  }

  Widget _buildRecordTile(NdefRecordModel record) {
    String typeLabel = record.type.toUpperCase();
    String content = record.payload.toString();
    IconData icon = Icons.info_outline;

    switch (record.type) {
      case 'text':
        icon = Icons.text_fields;
        content = record.payload['text'] ?? '';
        break;
      case 'uri':
        icon = Icons.link;
        content = record.payload['uri'] ?? '';
        break;
      case 'email':
        icon = Icons.email;
        content = 'To: ${record.payload['email']}\nSubject: ${record.payload['subject']}\nBody: ${record.payload['body']}';
        break;
      case 'phone':
        icon = Icons.phone;
        content = record.payload['phone'] ?? '';
        break;
      case 'sms':
        icon = Icons.message;
        content = 'To: ${record.payload['phone']}\nBody: ${record.payload['body']}';
        break;
      case 'wifi':
        icon = Icons.wifi;
        content = 'SSID: ${record.payload['ssid']}\nEncryption: ${record.payload['encryption']}';
        break;
      case 'vcard':
        icon = Icons.person;
        content = record.payload['vcard'] ?? '';
        break;
      case 'location':
        icon = Icons.map;
        content = 'Lat: ${record.payload['latitude']}, Lng: ${record.payload['longitude']}';
        break;
      case 'bluetooth':
        icon = Icons.bluetooth;
        content = 'MAC: ${record.payload['mac']}';
        break;
      case 'bitcoin':
        icon = Icons.currency_bitcoin;
        content =
            '${record.payload['scheme']}:${record.payload['address']}${record.payload['amount'] != null && record.payload['amount'].toString().isNotEmpty ? '\nAmount: ${record.payload['amount']}' : ''}';
        break;
      case 'social':
        icon = Icons.public;
        content = '${record.payload['platform']}: ${record.payload['handle']}';
        break;
      case 'search':
        icon = Icons.search;
        content = record.payload['query']?.toString() ?? '';
        break;
      case 'aar':
        icon = Icons.android;
        content = 'Package: ${record.payload['packageName']}';
        break;
      case 'mime':
        icon = Icons.category;
        content = 'MIME: ${record.payload['mimeType']}\nPayload: ${record.payload['payload']}';
        break;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(typeLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(content, style: const TextStyle(fontSize: 14)),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => RecordInfoScreen(record: record)),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = _details;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Read NFC Tag', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (details != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _scanTag,
            ),
        ],
      ),
      body: details == null
          ? AppEmptyState(
              icon: Icons.sensors,
              title: 'Ready to Scan',
              subtitle:
                  'Your phone’s NFC radio is waiting. Tap below, then hold a tag flat against the back of the device.',
              pulse: true,
              hint: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.phone_android,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tip: sensor is usually near the top camera area.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              action: FilledButton.icon(
                onPressed: _scanTag,
                icon: const Icon(Icons.nfc),
                label: const Text('Hold phone to tag'),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meta Info Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                details.type ?? 'NFC Tag',
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (details.isWritable ?? false)
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  (details.isWritable ?? false) ? 'Writable' : 'Read-Only',
                                  style: TextStyle(
                                    color: (details.isWritable ?? false) ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          _buildMetaRow('UID', details.uid ?? 'Unknown', theme),
                          _buildMetaRow('Capacity', '${details.maxSize ?? 0} Bytes', theme),
                          _buildMetaRow('Technologies', details.technologies.join(', '), theme),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        onPressed: details.records.isEmpty ? null : _cloneToWriter,
                        icon: const Icon(Icons.copy_all, size: 18),
                        label: const Text('Clone to Writer'),
                      ),
                      OutlinedButton.icon(
                        onPressed: (details.isWritable ?? false) ? _eraseTag : null,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Erase'),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      ),
                      OutlinedButton.icon(
                        onPressed: _formatTag,
                        icon: const Icon(Icons.delete_sweep, size: 18),
                        label: const Text('Format'),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                      ),
                      OutlinedButton.icon(
                        onPressed: (details.isWritable ?? false) ? _lockTag : null,
                        icon: const Icon(Icons.lock, size: 18),
                        label: const Text('Lock'),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isLoadingRaw ? null : _loadRawHex,
                        icon: _isLoadingRaw
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.code, size: 18),
                        label: const Text('Raw Hex'),
                      ),
                    ],
                  ),

                  if (_rawHex != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Raw Data output:',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _rawHex!,
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Text(
                    'NDEF Records (${details.records.length})',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (details.records.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(
                        child: Text(
                          'No records written to tag',
                          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ...details.records.map((r) => _buildRecordTile(r)),
                ],
              ),
            ),
    );
  }

  Widget _buildMetaRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
