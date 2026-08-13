import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/nfc/batch_write_dialog.dart';
import '../../core/nfc/nfc_dialog.dart';
import '../../core/widgets/app_ui.dart';
import '../history/history_provider.dart';
import '../templates/templates_provider.dart';
import '../../models/ndef_record.dart';
import '../../models/tag_template.dart';
import '../../services/nfc_service.dart';

/// Home-screen actions (read / copy / erase / batch write) that need
/// access to Riverpod state (history, templates) alongside a [BuildContext]
/// for dialogs and navigation.
final homeActionsProvider = Provider<HomeActions>((ref) => HomeActions(ref));

class HomeActions {
  HomeActions(this.ref);

  final Ref ref;

  Future<void> triggerRead(BuildContext context) async {
    final NfcTagDetails? details = await showNfcSession<NfcTagDetails>(
      context: context,
      title: 'Ready to Read',
      message: 'Place your tag near the back of your phone.',
      mode: NfcDialogMode.read,
    );

    if (details != null) {
      await ref.read(historyProvider.notifier).addRecord(
            uid: details.uid,
            action: 'read',
            records: details.records,
            success: true,
            details: '${details.type ?? 'Unknown'} (${details.maxSize ?? 0} Bytes)',
          );

      if (context.mounted) {
        context.push('/read', extra: details);
      }
    }
  }

  Future<void> triggerCopyTag(BuildContext context) async {
    final source = await showNfcSession<NfcTagDetails>(
      context: context,
      title: 'Copy Tag — Source',
      message: 'Tap the SOURCE tag to clone its NDEF records.',
      mode: NfcDialogMode.read,
    );

    if (source == null || !context.mounted) return;

    if (source.records.isEmpty) {
      final hint = _copyBlockedMessage(source);
      showAppSnack(context, hint, isError: true);
      return;
    }

    final ok = await showNfcSession<bool>(
      context: context,
      title: 'Copy Tag — Destination',
      message:
          'Now tap the DESTINATION tag.\nCloning ${source.records.length} record(s) from ${source.uid ?? 'source'}.',
      mode: NfcDialogMode.write,
      records: source.records,
    );

    await ref.read(historyProvider.notifier).addRecord(
          uid: source.uid,
          action: 'copy',
          records: source.records,
          success: ok == true,
          details: ok == true
              ? 'Cloned ${source.records.length} records'
              : 'Copy failed or cancelled',
        );

    if (context.mounted) {
      showAppSnack(
        context,
        ok == true ? 'Tag copied successfully' : 'Copy cancelled or failed',
        isError: ok != true,
      );
    }
  }

  Future<void> triggerErase(BuildContext context) async {
    final confirm = await confirmAppAction(
      context,
      title: 'Erase Tag?',
      message:
          'This writes an empty NDEF message and clears existing records. It does not reformat the chip.',
      confirmLabel: 'Erase',
      destructive: true,
    );

    if (!confirm || !context.mounted) return;

    final ok = await showNfcSession<bool>(
      context: context,
      title: 'Erase Tag',
      message: 'Hold the tag against the phone to erase NDEF content.',
      mode: NfcDialogMode.erase,
    );

    await ref.read(historyProvider.notifier).addRecord(
          action: 'erase',
          records: const <NdefRecordModel>[],
          success: ok == true,
          details: ok == true ? 'NDEF erased' : 'Erase failed or cancelled',
        );
  }

  Future<void> triggerBatchWrite(BuildContext context) async {
    final templates = ref.read(templatesProvider);
    if (templates.isEmpty) {
      showAppSnack(context, 'Create a template first — Write tab or Templates');
      return;
    }

    final selectedTemplate = await showDialog<TagTemplate?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Template for Batch'),
        children: templates
            .map(
              (t) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, t),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        child: Text('${t.records.length}', style: const TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );

    if (selectedTemplate == null || !context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => BatchWriteDialog(
        title: selectedTemplate.name,
        records: selectedTemplate.records,
        onWritten: (uid, index) {
          ref.read(historyProvider.notifier).addRecord(
                uid: uid,
                action: 'batch_write',
                records: selectedTemplate.records,
                success: true,
                details: 'Batch tag #$index',
              );
        },
        onError: (err) {
          ref.read(historyProvider.notifier).addRecord(
                action: 'batch_write',
                records: selectedTemplate.records,
                success: false,
                details: 'Batch error: $err',
              );
        },
      ),
    );
  }

  static String _copyBlockedMessage(NfcTagDetails source) {
    final type = source.type ?? '';
    if (type.contains('Classic')) {
      return 'MIFARE Classic has no NDEF on this tag. '
          'Use Tools → Mifare Classic to dump and write raw sector data.';
    }
    if (!source.isNdefSupported) {
      return 'This tag does not expose NDEF. Copy Tag only clones NDEF records '
          '(URLs, Wi‑Fi, text, etc.).';
    }
    return 'Source tag has no NDEF records to copy.';
  }
}
