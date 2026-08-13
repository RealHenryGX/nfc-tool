import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/ndef_record.dart';
import '../../services/nfc_service.dart';
import '../widgets/radar_pulse.dart';
import 'nfc_errors.dart';

enum NfcDialogMode { read, write, erase, lock, format }

/// Wallet-style NFC session as a modal bottom sheet (preferred Android UX).
Future<T?> showNfcSession<T>({
  required BuildContext context,
  required String title,
  required String message,
  NfcDialogMode mode = NfcDialogMode.read,
  List<NdefRecordModel>? records,
  bool isWrite = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => NfcSessionSheet(
      title: title,
      message: message,
      mode: isWrite && mode == NfcDialogMode.read ? NfcDialogMode.write : mode,
      records: records,
    ),
  );
}

/// Back-compat dialog wrapper → same session UI as a [Dialog].
class NfcDialog extends StatelessWidget {
  final String title;
  final String message;
  final NfcDialogMode mode;
  final List<NdefRecordModel>? records;
  final Function(NfcTagDetails details)? onReadComplete;
  final Function(String successMessage)? onWriteComplete;
  final bool isWrite;

  const NfcDialog({
    super.key,
    required this.title,
    required this.message,
    this.mode = NfcDialogMode.read,
    this.isWrite = false,
    this.records,
    this.onReadComplete,
    this.onWriteComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: NfcSessionSheet(
        title: title,
        message: message,
        mode: isWrite && mode == NfcDialogMode.read ? NfcDialogMode.write : mode,
        records: records,
        onReadComplete: onReadComplete,
        onWriteComplete: onWriteComplete,
        asDialog: true,
      ),
    );
  }
}

class NfcSessionSheet extends StatefulWidget {
  final String title;
  final String message;
  final NfcDialogMode mode;
  final List<NdefRecordModel>? records;
  final Function(NfcTagDetails details)? onReadComplete;
  final Function(String successMessage)? onWriteComplete;
  final bool asDialog;

  const NfcSessionSheet({
    super.key,
    required this.title,
    required this.message,
    this.mode = NfcDialogMode.read,
    this.records,
    this.onReadComplete,
    this.onWriteComplete,
    this.asDialog = false,
  });

  @override
  State<NfcSessionSheet> createState() => _NfcSessionSheetState();
}

class _NfcSessionSheetState extends State<NfcSessionSheet> {
  String _statusMessage = '';
  bool _isSuccess = false;
  bool _isError = false;

  String get _modeLabel => switch (widget.mode) {
        NfcDialogMode.read => 'READY TO SCAN',
        NfcDialogMode.write => 'READY TO WRITE',
        NfcDialogMode.erase => 'READY TO ERASE',
        NfcDialogMode.lock => 'READY TO LOCK',
        NfcDialogMode.format => 'READY TO FORMAT',
      };

  @override
  void initState() {
    super.initState();
    _statusMessage = widget.message;
    WidgetsBinding.instance.addPostFrameCallback((_) => _startNfcOperation());
  }

  @override
  void dispose() {
    NfcService.stopSession();
    super.dispose();
  }

  void _finishOk([dynamic result = true]) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSuccess = true);
    Future.delayed(const Duration(milliseconds: 850), () {
      if (mounted) Navigator.of(context).pop(result);
    });
  }

  void _finishErr(String err) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _isError = true;
      _statusMessage = friendlyNfcError(err);
    });
  }

  void _dismiss() {
    NfcService.stopSession();
    Navigator.of(context).pop(
      _isSuccess
          ? true
          : (widget.mode == NfcDialogMode.read ? null : false),
    );
  }

  void _startNfcOperation() {
    switch (widget.mode) {
      case NfcDialogMode.write:
        NfcService.startWriteSession(
          records: widget.records ?? <NdefRecordModel>[],
          onComplete: (msg) {
            if (!mounted) return;
            setState(() => _statusMessage = msg);
            widget.onWriteComplete?.call(msg);
            _finishOk(true);
          },
          onError: _finishErr,
        );
      case NfcDialogMode.erase:
        NfcService.startEraseSession(
          onComplete: (msg) {
            if (!mounted) return;
            setState(() => _statusMessage = msg);
            _finishOk(true);
          },
          onError: _finishErr,
        );
      case NfcDialogMode.lock:
        NfcService.makeReadOnly(
          onComplete: (msg) {
            if (!mounted) return;
            setState(() => _statusMessage = msg);
            _finishOk(true);
          },
          onError: _finishErr,
        );
      case NfcDialogMode.format:
        NfcService.formatTag(
          onComplete: (msg) {
            if (!mounted) return;
            setState(() => _statusMessage = msg);
            _finishOk(true);
          },
          onError: _finishErr,
        );
      case NfcDialogMode.read:
        NfcService.startReadSession(
          onDiscovered: (details) {
            if (!mounted) return;
            setState(() => _statusMessage = 'Tag read successfully');
            widget.onReadComplete?.call(details);
            _finishOk(details);
          },
          onError: _finishErr,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final writing = widget.mode != NfcDialogMode.read;
    final listening = !_isSuccess && !_isError;

    final content = Padding(
      padding: EdgeInsets.fromLTRB(24, widget.asDialog ? 28 : 12, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.asDialog)
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          Text(
            _modeLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.title,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          if (_isSuccess)
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.tertiary,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.tertiary.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(Icons.check_rounded, size: 48, color: theme.colorScheme.onTertiary),
            )
          else if (_isError)
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.error,
              ),
              child: Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.onError),
            )
          else
            RadarPulse(
              icon: writing ? Icons.nfc : Icons.sensors,
              size: 72,
              active: listening,
            ),
          const SizedBox(height: 20),
          // Placement hint graphic
          if (listening)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone_android, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Hold the tag flat against the back of your phone '
                      '(near the top/camera area on most devices).',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.18,
            ),
            child: SingleChildScrollView(
              child: Text(
                _statusMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _isError
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (listening)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _dismiss,
                child: const Text('Cancel'),
              ),
            )
          else if (_isError)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _dismiss,
                child: const Text('Close'),
              ),
            ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );

    if (widget.asDialog) return content;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(top: false, child: content),
    );
  }
}
