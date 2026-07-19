import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import '../../core/nfc/nfc_dialog.dart';
import '../../models/tag_template.dart';
import 'templates_provider.dart';

class TemplatesScreen extends ConsumerStatefulWidget {
  const TemplatesScreen({super.key});

  @override
  ConsumerState<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends ConsumerState<TemplatesScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _triggerWrite(TagTemplate template) async {
    await showNfcSession<bool>(
      context: context,
      title: 'Ready to Write',
      message: 'Writing template: ${template.name}',
      mode: NfcDialogMode.write,
      records: template.records,
    );
  }

  void _shareTemplate(TagTemplate template) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Share Template',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code),
              label: const Text('Share as QR Code'),
              onPressed: () {
                Navigator.pop(context);
                _showQrCodeDialog(template);
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Share JSON text'),
              onPressed: () {
                Navigator.pop(context);
                final jsonString = jsonEncode(template.toJson());
                Share.share(jsonString, subject: 'NFC Tag Template: ${template.name}');
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showQrCodeDialog(TagTemplate template) {
    final jsonString = jsonEncode(template.toJson());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          template.name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Scan this QR code from another NFC Toolbox app to import this template.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                data: jsonString,
                version: QrVersions.auto,
                size: 200.0,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _loadLibraryTemplates() async {
    await ref.read(templatesProvider.notifier).loadPresets();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preset library templates added!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final templates = ref.watch(templatesProvider);
    
    final filteredTemplates = templates.where((t) {
      return t.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Templates', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_library_outlined),
            tooltip: 'Load Sample Templates',
            onPressed: _loadLibraryTemplates,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search templates...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
          ),
          Expanded(
            child: filteredTemplates.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.style_outlined, size: 64, color: theme.colorScheme.primary.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty ? 'No templates match your search' : 'No Templates Saved',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Try typing a different name'
                                : 'Save templates from the Write screen or tap the book icon above to load examples.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredTemplates.length,
                    itemBuilder: (context, index) {
                      final template = filteredTemplates[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      template.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.play_circle_outline, color: Colors.green, size: 28),
                                    tooltip: 'Write to NFC Now',
                                    onPressed: () => _triggerWrite(template),
                                  ),
                                ],
                              ),
                              Text(
                                '${template.records.length} NDEF records',
                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_note_outlined, color: Colors.blue),
                                    tooltip: 'Edit records',
                                    onPressed: () => context.push('/write', extra: template),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy_all_outlined, color: Colors.teal),
                                    tooltip: 'Duplicate',
                                    onPressed: () {
                                      ref.read(templatesProvider.notifier).duplicateTemplate(template);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.share_outlined, color: Colors.purple),
                                    tooltip: 'Share',
                                    onPressed: () => _shareTemplate(template),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    tooltip: 'Delete',
                                    onPressed: () {
                                      ref.read(templatesProvider.notifier).deleteTemplate(template.id);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
