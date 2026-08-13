import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/nfc_service.dart';
import 'read_provider.dart';
import 'read_widgets.dart';

class ReadScreen extends ConsumerStatefulWidget {
  final NfcTagDetails? initialDetails;

  const ReadScreen({super.key, this.initialDetails});

  @override
  ConsumerState<ReadScreen> createState() => _ReadScreenState();
}

class _ReadScreenState extends ConsumerState<ReadScreen> {
  @override
  void initState() {
    super.initState();
    final initial = widget.initialDetails;
    if (initial != null) {
      // Riverpod forbids provider writes during initState — defer one frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(readProvider.notifier).setInitialDetails(initial);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final readState = ref.watch(readProvider);
    final notifier = ref.read(readProvider.notifier);
    final details = readState.details;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Read NFC Tag', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (details != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => notifier.scanTag(context),
            ),
        ],
      ),
      body: details == null
          ? ReadEmptyState(onScan: () => notifier.scanTag(context))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ReadTagMetaCard(details: details),
                  const SizedBox(height: 24),
                  ReadActionsBar(
                    details: details,
                    isLoadingRaw: readState.loadingRaw,
                    onClone: () => notifier.cloneToWrite(context),
                    onErase: () => notifier.eraseTag(context),
                    onFormat: () => notifier.formatTag(context),
                    onLock: () => notifier.lockTag(context),
                    onLoadRawHex: () => notifier.loadRawHex(context),
                  ),
                  if (readState.rawHex != null) ...[
                    const SizedBox(height: 24),
                    ReadRawHexPanel(rawHex: readState.rawHex!),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'NDEF Records (${details.records.length})',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ReadRecordsList(records: details.records),
                ],
              ),
            ),
    );
  }
}
