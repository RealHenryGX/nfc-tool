import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/app_ui.dart';
import '../../models/ndef_record.dart';

class RecordInfoScreen extends StatelessWidget {
  final NdefRecordModel record;

  const RecordInfoScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final jsonPretty = const JsonEncoder.withIndent('  ').convert(record.toJson());
    return Scaffold(
      appBar: AppBar(
        title: Text('${record.type.toUpperCase()} record'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonPretty));
              showAppSnack(context, 'Copied JSON');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Chip(label: Text(record.type)),
          const SizedBox(height: 12),
          ...record.payload.entries.map(
            (e) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: SelectableText('${e.value}'),
            ),
          ),
          const Divider(),
          Text('Raw JSON', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              jsonPretty,
              style: TextStyle(color: theme.colorScheme.primary, fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
