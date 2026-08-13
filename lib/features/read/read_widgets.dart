import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_ui.dart';
import '../../models/ndef_record.dart';
import '../../services/nfc_service.dart';

/// Ready-to-scan placeholder shown before any tag has been read.
class ReadEmptyState extends StatelessWidget {
  final VoidCallback onScan;

  const ReadEmptyState({super.key, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
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
            Icon(Icons.phone_android, color: Theme.of(context).colorScheme.primary),
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
        onPressed: onScan,
        icon: const Icon(Icons.nfc),
        label: const Text('Hold phone to tag'),
      ),
    );
  }
}

/// Tag metadata card: type badge, UID, capacity, technologies.
class ReadTagMetaCard extends StatelessWidget {
  final NfcTagDetails details;

  const ReadTagMetaCard({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
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
                Expanded(
                  child: Text(
                    details.type ?? 'NFC Tag',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (details.isWritable ?? false)
                        ? theme.colorScheme.tertiary.withValues(alpha: 0.15)
                        : theme.colorScheme.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    (details.isWritable ?? false) ? 'Writable' : 'Read-Only',
                    style: TextStyle(
                      color: (details.isWritable ?? false)
                          ? theme.colorScheme.tertiary
                          : theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _metaRow('UID', details.uid ?? 'Unknown', theme),
            _metaRow('Capacity', '${details.maxSize ?? 0} Bytes', theme),
            _metaRow('Technologies', details.technologies.join(', '), theme),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
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

/// Row of secondary actions available for a scanned tag.
class ReadActionsBar extends StatelessWidget {
  final NfcTagDetails details;
  final bool isLoadingRaw;
  final VoidCallback onClone;
  final VoidCallback onErase;
  final VoidCallback onFormat;
  final VoidCallback onLock;
  final VoidCallback onLoadRawHex;

  const ReadActionsBar({
    super.key,
    required this.details,
    required this.isLoadingRaw,
    required this.onClone,
    required this.onErase,
    required this.onFormat,
    required this.onLock,
    required this.onLoadRawHex,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        OutlinedButton.icon(
          onPressed: details.records.isEmpty ? null : onClone,
          icon: const Icon(Icons.copy_all, size: 18),
          label: const Text('Clone to Writer'),
        ),
        OutlinedButton.icon(
          onPressed: (details.isWritable ?? false) ? onErase : null,
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Erase'),
          style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
        ),
        OutlinedButton.icon(
          onPressed: onFormat,
          icon: const Icon(Icons.delete_sweep, size: 18),
          label: const Text('Format'),
          style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.tertiary),
        ),
        OutlinedButton.icon(
          onPressed: (details.isWritable ?? false) ? onLock : null,
          icon: const Icon(Icons.lock, size: 18),
          label: const Text('Lock'),
          style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
        ),
        OutlinedButton.icon(
          onPressed: isLoadingRaw ? null : onLoadRawHex,
          icon: isLoadingRaw
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.code, size: 18),
          label: const Text('Raw Hex'),
        ),
      ],
    );
  }
}

/// Monospace panel displaying the raw hex dump of a tag, once loaded.
class ReadRawHexPanel extends StatelessWidget {
  final String rawHex;

  const ReadRawHexPanel({super.key, required this.rawHex});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Raw Data output:',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            rawHex,
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

/// NDEF record list, or an italic placeholder when the tag has none.
class ReadRecordsList extends StatelessWidget {
  final List<NdefRecordModel> records;

  const ReadRecordsList({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (records.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: Text(
            'No records written to tag',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return Column(
      children: records.map((r) => ReadRecordTile(record: r)).toList(),
    );
  }
}

/// Single NDEF record summary tile; taps push to the record info screen.
class ReadRecordTile extends StatelessWidget {
  final NdefRecordModel record;

  const ReadRecordTile({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
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
          child: Text(
            content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/record', extra: record),
      ),
    );
  }
}
