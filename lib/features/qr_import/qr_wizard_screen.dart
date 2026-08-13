import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import '../../models/ndef_record.dart';
import '../../services/qr_service.dart';
import '../../core/nfc/nfc_dialog.dart';
import '../../core/widgets/app_ui.dart';
import '../templates/templates_provider.dart';
import '../history/history_provider.dart';

class QrWizardScreen extends ConsumerStatefulWidget {
  const QrWizardScreen({super.key});

  @override
  ConsumerState<QrWizardScreen> createState() => _QrWizardScreenState();
}

class _QrWizardScreenState extends ConsumerState<QrWizardScreen> {
  PermissionStatus _cameraPermission = PermissionStatus.denied;
  bool _isPermissionChecked = false;
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _checkPermission() async {
    final status = await Permission.camera.status;
    setState(() {
      _cameraPermission = status;
      _isPermissionChecked = true;
    });
    if (status != PermissionStatus.granted) {
      _requestPermission();
    }
  }

  void _requestPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      _cameraPermission = status;
    });
  }

  void _handleDetection(String data) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });
    _controller.stop();

    final record = QrService.parseQrString(data);

    if (mounted) {
      final success = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => _QrPreviewWidget(record: record),
      );

      if (success == true) {
        if (mounted) context.pop(); // Go back home
      } else {
        // Resume scanning
        setState(() {
          _isProcessing = false;
        });
        _controller.start();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_isPermissionChecked) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_cameraPermission != PermissionStatus.granted) {
      return Scaffold(
        appBar: AppBar(title: const Text('QR Wizard')),
        body: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam_off_outlined,
                size: 80,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 24),
              Text(
                'Camera Permission Required',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'We need camera access to scan QR codes and convert them directly into NFC tags.',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _requestPermission,
                icon: const Icon(Icons.videocam),
                label: const Text('Grant Camera Permission'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Wizard', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _handleDetection(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
          // Transparent frame overlay — scales with screen, not fixed 250dp
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = (constraints.biggest.shortestSide * 0.68)
                    .clamp(180.0, 280.0);
                return Container(
                  width: side,
                  height: side,
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.primary, width: 3),
                    borderRadius: BorderRadius.circular(24),
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Card(
              color: theme.colorScheme.scrim.withValues(alpha: 0.75),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Text(
                  'Align QR code inside the frame to convert and write to NFC tag.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onInverseSurface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrPreviewWidget extends ConsumerStatefulWidget {
  final NdefRecordModel record;

  const _QrPreviewWidget({required this.record});

  @override
  ConsumerState<_QrPreviewWidget> createState() => _QrPreviewWidgetState();
}

class _QrPreviewWidgetState extends ConsumerState<_QrPreviewWidget> {
  late Map<String, dynamic> _editablePayload;

  @override
  void initState() {
    super.initState();
    _editablePayload = Map<String, dynamic>.from(widget.record.payload);
  }

  void _writeToNfc() async {
    final finalRecord = NdefRecordModel(
      type: widget.record.type,
      payload: _editablePayload,
    );

    final success = await showNfcSession<bool>(
      context: context,
      title: 'Ready to Write',
      message: 'Place your tag near the back of your phone.',
      mode: NfcDialogMode.write,
      records: [finalRecord],
    );

    if (success == true && mounted) {
      await ref.read(historyProvider.notifier).addRecord(
            action: 'write',
            records: [finalRecord],
            success: true,
            details: 'Wizard write: ${widget.record.type.toUpperCase()}',
          );
      if (mounted) Navigator.pop(context, true);
    }
  }

  void _saveAsTemplate() async {
    final finalRecord = NdefRecordModel(
      type: widget.record.type,
      payload: _editablePayload,
    );

    final nameController = TextEditingController(text: 'QR Import: ${widget.record.type.toUpperCase()}');

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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );

    if (confirm == true && nameController.text.trim().isNotEmpty) {
      await ref.read(templatesProvider.notifier).addTemplate(nameController.text.trim(), [finalRecord]);
      if (mounted) {
        showAppSnack(context, 'Template saved successfully!');
      }
    }
  }

  Widget _buildEditableFields(ThemeData theme) {
    final list = <Widget>[];
    _editablePayload.forEach((key, value) {
      list.add(
        AppLabeledField(
          label: key.toUpperCase(),
          child: TextFormField(
            initialValue: value.toString(),
            decoration: const InputDecoration(),
            onChanged: (val) {
              _editablePayload[key] = val;
            },
          ),
        ),
      );
    });

    return Column(children: list);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'QR Content Detected',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Chip(
            label: Text(widget.record.type.toUpperCase()),
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            labelStyle: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildEditableFields(theme),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saveAsTemplate,
                  icon: const Icon(Icons.bookmark_outline),
                  label: const Text('Template'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _writeToNfc,
                  icon: const Icon(Icons.nfc),
                  label: const Text('Write NFC'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
