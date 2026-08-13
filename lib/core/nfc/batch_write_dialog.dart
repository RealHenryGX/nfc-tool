import 'package:flutter/material.dart';

import '../../models/ndef_record.dart';
import '../../services/nfc_service.dart';
import 'nfc_errors.dart';

export 'nfc_errors.dart' show friendlyNfcError;

/// Multi-tag NDEF write loop with progress UI (home batch + tools infinite copy).
class BatchWriteDialog extends StatefulWidget {
  final String title;
  final List<NdefRecordModel> records;
  final void Function(String uid, int index) onWritten;
  final void Function(String error)? onError;
  final String? subtitle;
  final String finishLabel;
  final bool showRetry;

  const BatchWriteDialog({
    super.key,
    required this.title,
    required this.records,
    required this.onWritten,
    this.onError,
    this.subtitle,
    this.finishLabel = 'Finish',
    this.showRetry = true,
  });

  @override
  State<BatchWriteDialog> createState() => _BatchWriteDialogState();
}

class _BatchWriteDialogState extends State<BatchWriteDialog> {
  int _count = 0;
  String _currentUid = 'Waiting for tag…';
  String? _error;
  bool _running = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startBatch());
  }

  void _startBatch() {
    NfcService.startBatchWriteSession(
      records: widget.records,
      shouldContinue: () => _running && mounted,
      onTagWritten: (uid) {
        if (!mounted || !_running) return;
        final next = _count + 1;
        widget.onWritten(uid, next);
        setState(() {
          _count = next;
          _currentUid = uid;
          _error = null;
        });
      },
      onError: (err) {
        if (!mounted || !_running) return;
        widget.onError?.call(err);
        setState(() {
          _error = err;
          _currentUid = 'Hold tag steady and wait for the beep';
        });
      },
    );
  }

  @override
  void dispose() {
    _running = false;
    NfcService.stopSession();
    super.dispose();
  }

  void _stop() {
    _running = false;
    NfcService.stopSession();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.library_add, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            ),
            child: Icon(Icons.nfc, size: 56, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 20),
          Text(
            '$_count',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          Text('tags written', style: theme.textTheme.labelLarge),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.subtitle!,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Last UID: $_currentUid',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              friendlyNfcError(_error!),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Hold device near each tag. Wait for success before the next.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        if (widget.showRetry && _error != null)
          TextButton(
            onPressed: () {
              setState(() => _error = null);
              _startBatch();
            },
            child: const Text('Retry'),
          ),
        FilledButton(
          onPressed: _stop,
          child: Text(widget.finishLabel),
        ),
      ],
    );
  }
}
