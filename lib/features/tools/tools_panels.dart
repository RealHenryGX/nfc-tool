import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nfc/batch_write_dialog.dart';
import '../../core/nfc/nfc_dialog.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/hex_field.dart';
import '../../services/nfc_service.dart';
import '../../services/task_runner.dart';
import '../history/history_provider.dart';
import 'tools_provider.dart';

/// Consistent gap between stacked fields (avoids floating-label collisions).
const kToolsFieldGap = SizedBox(height: 16);

/// Card shell shared by every Tools panel.
class ToolCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final List<Widget> children;

  const ToolCard({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: accent.withValues(alpha: 0.15),
                  child: Icon(icon, size: 18, color: accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// "Infinite Copy" clone entry point — taps a source tag then loops
/// [BatchWriteDialog] onto as many destination tags as wanted.
class CloneCard extends ConsumerWidget {
  const CloneCard({super.key});

  Future<void> _infiniteCopy(BuildContext context, WidgetRef ref) async {
    final source = await showNfcSession<NfcTagDetails>(
      context: context,
      title: 'Infinite Copy — Source',
      message: 'Tap SOURCE tag once.',
      mode: NfcDialogMode.read,
    );
    if (source == null || !context.mounted) return;
    if (source.records.isEmpty) {
      showAppSnack(context, 'Source has no NDEF records', isError: true);
      return;
    }
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BatchWriteDialog(
        title: 'Infinite Copy',
        subtitle: 'Source: ${source.uid ?? 'unknown'}',
        records: source.records,
        finishLabel: 'Stop',
        showRetry: false,
        onWritten: (uid, n) {
          ref.read(historyProvider.notifier).addRecord(
                uid: uid,
                action: 'infinite_copy',
                records: source.records,
                success: true,
                details: 'Clone #$n from ${source.uid}',
              );
        },
        onError: (err) {
          if (context.mounted) showAppSnack(context, friendlyNfcError(err), isError: true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(toolsProvider.select((s) => s.busy));
    return ToolCard(
      title: 'Clone',
      icon: Icons.all_inclusive,
      accent: const Color(0xFF0EA5E9),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.copy_all),
          title: const Text('Infinite Copy'),
          subtitle: const Text('Clone source NDEF onto many tags'),
          trailing: const Icon(Icons.chevron_right),
          onTap: busy ? null : () => _infiniteCopy(context, ref),
        ),
      ],
    );
  }
}

Widget _memoryGrid(BuildContext context, Uint8List bytes) {
  final pages = (bytes.length / 4).ceil();
  final theme = Theme.of(context);
  return LayoutBuilder(
    builder: (context, constraints) {
      final crossAxisCount = constraints.maxWidth >= 480
          ? 4
          : constraints.maxWidth >= 320
              ? 3
              : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: pages,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 1.2,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemBuilder: (context, index) {
          final start = index * 4;
          final slice = bytes.sublist(start, (start + 4).clamp(0, bytes.length));
          final hex = slice
              .map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase())
              .join(' ');
          return Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'P$index',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    hex,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontFamily: 'monospace',
                      fontSize: 10,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Ultralight/NTAG memory dump: read/export/import/write-back + grid/text view.
class UltralightMemoryPanel extends ConsumerWidget {
  const UltralightMemoryPanel({super.key});

  void _report(BuildContext context, String message, {bool isError = false}) {
    if (!context.mounted) return;
    showAppSnack(context, message, isError: isError);
  }

  Future<void> _writeDumpBack(BuildContext context, WidgetRef ref) async {
    final confirm = await confirmAppAction(
      context,
      title: 'Write memory dump?',
      message:
          'Writes bytes starting at page 4 (skips UID/lock). Wrong data can brick the tag.',
      confirmLabel: 'Write',
      destructive: true,
    );
    if (!confirm) return;
    await ref.read(toolsProvider.notifier).writeDumpBack(
          report: (msg, {isError = false}) => _report(context, msg, isError: isError),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(toolsProvider);
    final notifier = ref.read(toolsProvider.notifier);

    return ToolCard(
      title: 'Ultralight / NTAG Memory',
      icon: Icons.memory,
      accent: const Color(0xFF6366F1),
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.tonal(
                onPressed: state.busy
                    ? null
                    : () => notifier.readMemory(
                          report: (msg, {isError = false}) =>
                              _report(context, msg, isError: isError),
                        ),
                child: const Text('Read dump'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: state.gridView ? 'Text view' : 'Grid view',
              onPressed: notifier.toggleGridView,
              icon: Icon(state.gridView ? Icons.view_list : Icons.grid_view),
            ),
          ],
        ),
        if (state.memoryBytes != null) ...[
          const SizedBox(height: 12),
          if (state.gridView)
            _memoryGrid(context, state.memoryBytes!)
          else
            SelectableText(
              state.memoryHex ?? '',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: () => notifier.exportBin(
                  report: (msg, {isError = false}) => _report(context, msg, isError: isError),
                ),
                child: const Text('Export .bin'),
              ),
              TextButton(
                onPressed: () => notifier.importBin(
                  report: (msg, {isError = false}) => _report(context, msg, isError: isError),
                ),
                child: const Text('Import .bin'),
              ),
              TextButton(
                onPressed: state.busy ? null : () => _writeDumpBack(context, ref),
                child: const Text('Write dump'),
              ),
              TextButton(
                onPressed: () => shareAppText(state.memoryHex ?? ''),
                child: const Text('Share text'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Raw APDU transceive tool.
class TransceivePanel extends ConsumerWidget {
  final TextEditingController controller;

  const TransceivePanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(toolsProvider);
    final notifier = ref.read(toolsProvider.notifier);

    return ToolCard(
      title: 'Advanced Transceive',
      icon: Icons.terminal,
      accent: const Color(0xFF059669),
      children: [
        HexField(
          controller: controller,
          label: 'Hex command',
          hint: '30 00',
        ),
        kToolsFieldGap,
        FilledButton(
          onPressed: state.busy ? null : () => notifier.transceive(controller.text),
          child: const Text('Transceive'),
        ),
        if (state.txLog != null) ...[
          const SizedBox(height: 8),
          SelectableText(state.txLog!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ],
      ],
    );
  }
}

/// Mifare Classic dump / write-block / import-write tool.
class ClassicPanel extends ConsumerWidget {
  final TextEditingController keyController;
  final TextEditingController sectorController;
  final TextEditingController blockController;
  final TextEditingController dataController;

  const ClassicPanel({
    super.key,
    required this.keyController,
    required this.sectorController,
    required this.blockController,
    required this.dataController,
  });

  void _report(BuildContext context, String message, {bool isError = false}) {
    if (!context.mounted) return;
    showAppSnack(context, message, isError: isError);
  }

  Future<void> _classicImportBinWrite(BuildContext context, WidgetRef ref) async {
    final bytes = await PlatformBridge.pickBytes();
    if (bytes == null || bytes.isEmpty) return;
    if (!context.mounted) return;
    if (bytes.length % 16 != 0) {
      showAppSnack(context, 'Classic dump must be multiple of 16 bytes', isError: true);
      return;
    }
    final confirm = await confirmAppAction(
      context,
      title: 'Write Classic dump?',
      message:
          'Will write ${bytes.length ~/ 16} blocks starting sector 0 with current key. Continue?',
      confirmLabel: 'Write',
      destructive: true,
    );
    if (!confirm) return;
    await ref.read(toolsProvider.notifier).classicImportAndWrite(
          bytes: bytes,
          keyHex: keyController.text,
          report: (msg, {isError = false}) => _report(context, msg, isError: isError),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(toolsProvider);
    final notifier = ref.read(toolsProvider.notifier);

    return ToolCard(
      title: 'Mifare Classic',
      icon: Icons.credit_card,
      accent: const Color(0xFFEA580C),
      children: [
        HexField(
          controller: keyController,
          label: 'Key (6 bytes)',
          maxBytes: 6,
        ),
        kToolsFieldGap,
        OutlinedButton(
          onPressed: state.busy ? null : () => notifier.classicDump(keyController.text),
          child: const Text('Dump all sectors'),
        ),
        if (state.classicInfo != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SelectableText(
              state.classicInfo!,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AppLabeledField(
                label: 'Sector',
                padding: EdgeInsets.zero,
                child: TextField(
                  controller: sectorController,
                  keyboardType: TextInputType.number,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppLabeledField(
                label: 'Block',
                padding: EdgeInsets.zero,
                child: TextField(
                  controller: blockController,
                  keyboardType: TextInputType.number,
                ),
              ),
            ),
          ],
        ),
        kToolsFieldGap,
        HexField(
          controller: dataController,
          label: '16-byte block data',
          maxBytes: 16,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: state.busy
                  ? null
                  : () => notifier.classicWriteBlock(
                        keyHex: keyController.text,
                        dataHex: dataController.text,
                        sectorText: sectorController.text,
                        blockText: blockController.text,
                        report: (msg, {isError = false}) => _report(context, msg, isError: isError),
                      ),
              child: const Text('Write block'),
            ),
            OutlinedButton(
              onPressed: () => notifier.classicExportBin(
                report: (msg, {isError = false}) => _report(context, msg, isError: isError),
              ),
              child: const Text('Export .bin'),
            ),
            OutlinedButton(
              onPressed: state.busy ? null : () => _classicImportBinWrite(context, ref),
              child: const Text('Import & write'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Ultralight EV1 password auth / set / unset tool.
class PasswordPanel extends ConsumerWidget {
  final TextEditingController pwdController;
  final TextEditingController packController;
  final TextEditingController pwdPageController;
  final TextEditingController packPageController;

  const PasswordPanel({
    super.key,
    required this.pwdController,
    required this.packController,
    required this.pwdPageController,
    required this.packPageController,
  });

  void _report(BuildContext context, String message, {bool isError = false}) {
    if (!context.mounted) return;
    showAppSnack(context, message, isError: isError);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(toolsProvider);
    final notifier = ref.read(toolsProvider.notifier);

    return ToolCard(
      title: 'Ultralight EV1 Password',
      icon: Icons.lock_outline,
      accent: const Color(0xFFDC2626),
      children: [
        HexField(controller: pwdController, label: 'PWD (4 bytes)', maxBytes: 4),
        kToolsFieldGap,
        HexField(controller: packController, label: 'PACK (2 bytes)', maxBytes: 2),
        kToolsFieldGap,
        Row(
          children: [
            Expanded(
              child: AppLabeledField(
                label: 'PWD page',
                padding: EdgeInsets.zero,
                child: TextField(
                  controller: pwdPageController,
                  keyboardType: TextInputType.number,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppLabeledField(
                label: 'PACK page',
                padding: EdgeInsets.zero,
                child: TextField(
                  controller: packPageController,
                  keyboardType: TextInputType.number,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: state.busy
                  ? null
                  : () => notifier.passwordAuth(
                        pwdHex: pwdController.text,
                        packHex: packController.text,
                        report: (msg, {isError = false}) => _report(context, msg, isError: isError),
                      ),
              child: const Text('PWD_AUTH'),
            ),
            OutlinedButton(
              onPressed: state.busy
                  ? null
                  : () => notifier.passwordSet(
                        pwdHex: pwdController.text,
                        packHex: packController.text,
                        pwdPageText: pwdPageController.text,
                        packPageText: packPageController.text,
                        report: (msg, {isError = false}) => _report(context, msg, isError: isError),
                      ),
              child: const Text('Set PWD'),
            ),
            OutlinedButton(
              onPressed: state.busy
                  ? null
                  : () => notifier.passwordUnset(
                        pwdHex: pwdController.text,
                        packHex: packController.text,
                        pwdPageText: pwdPageController.text,
                        packPageText: packPageController.text,
                        report: (msg, {isError = false}) => _report(context, msg, isError: isError),
                      ),
              child: const Text('Unset PWD'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Wrong page numbers can permanently lock the tag. Confirm chip datasheet values first.',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ],
    );
  }
}
