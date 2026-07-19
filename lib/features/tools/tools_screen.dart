import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/nfc/nfc_dialog.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/hex_field.dart';
import '../../models/ndef_record.dart';
import '../../services/mifare_classic_service.dart';
import '../../services/nfc_service.dart';
import '../../services/tag_memory_service.dart';
import '../../services/task_runner.dart';
import '../history/history_provider.dart';

class ToolsScreen extends ConsumerStatefulWidget {
  const ToolsScreen({super.key});

  @override
  ConsumerState<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends ConsumerState<ToolsScreen> {
  Uint8List? _memoryBytes;
  String? _memoryHex;
  String? _txLog;
  String? _classicInfo;
  bool _busy = false;
  bool _gridView = true;

  final _txController = TextEditingController(text: '30 00');
  final _pwdController = TextEditingController(text: 'FF FF FF FF');
  final _packController = TextEditingController(text: '00 00');
  final _pwdPageController = TextEditingController(text: '229');
  final _packPageController = TextEditingController(text: '230');
  final _classicKeyController = TextEditingController(text: 'FF FF FF FF FF FF');
  final _classicSectorController = TextEditingController(text: '0');
  final _classicBlockController = TextEditingController(text: '0');
  final _classicDataController =
      TextEditingController(text: '00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00');

  @override
  void dispose() {
    _txController.dispose();
    _pwdController.dispose();
    _packController.dispose();
    _pwdPageController.dispose();
    _packPageController.dispose();
    _classicKeyController.dispose();
    _classicSectorController.dispose();
    _classicBlockController.dispose();
    _classicDataController.dispose();
    super.dispose();
  }

  Future<void> _infiniteCopy() async {
    final source = await showNfcSession<NfcTagDetails>(
      context: context,
      title: 'Infinite Copy — Source',
      message: 'Tap SOURCE tag once.',
      mode: NfcDialogMode.read,
    );
    if (source == null || !mounted) return;
    if (source.records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Source has no NDEF records')),
      );
      return;
    }
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _InfiniteCopyDialog(
        records: source.records,
        sourceUid: source.uid ?? 'unknown',
        onWritten: (uid, n) {
          ref.read(historyProvider.notifier).addRecord(
                uid: uid,
                action: 'infinite_copy',
                records: source.records,
                success: true,
                details: 'Clone #$n from ${source.uid}',
              );
        },
      ),
    );
  }

  Future<void> _readMemory() async {
    setState(() => _busy = true);
    try {
      final bytes = await TagMemoryService.readUltralightPages(
        startPage: 0,
        pageCount: 16,
      );
      setState(() {
        _memoryBytes = bytes;
        _memoryHex = _formatDump(bytes);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Memory read failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportBin() async {
    final bytes = _memoryBytes;
    if (bytes == null) return;
    final uri = await PlatformBridge.saveBytes(bytes, 'nfc_ul_dump.bin');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(uri == null ? 'Export cancelled' : 'Saved: $uri')),
      );
    }
  }

  Future<void> _importBin() async {
    setState(() => _busy = true);
    try {
      final bytes = await PlatformBridge.pickBytes(mime: '*/*');
      if (bytes == null) return;
      setState(() {
        _memoryBytes = bytes;
        _memoryHex = _formatDump(bytes);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loaded ${bytes.length} bytes')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _writeDumpBack() async {
    final bytes = _memoryBytes;
    if (bytes == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Write memory dump?'),
        content: const Text(
          'Writes bytes starting at page 4 (skips UID/lock). Wrong data can brick the tag.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Write')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      // If dump includes pages 0.., skip first 16 bytes (pages 0-3)
      final payload = bytes.length > 16 ? bytes.sublist(16) : bytes;
      await TagMemoryService.writeUltralightDump(dump: payload, startPage: 4);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dump written')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Write dump failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _transceive() async {
    setState(() => _busy = true);
    try {
      final log = await TagMemoryService.transceiveHex(_txController.text);
      setState(() => _txLog = log);
    } catch (e) {
      setState(() => _txLog = 'Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _passwordAuth() async {
    setState(() => _busy = true);
    try {
      final msg = await TagMemoryService.ultralightPasswordAuth(
        pwd4: _hexToBytes(_pwdController.text),
        pack2: _hexToBytes(_packController.text),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _passwordSet() async {
    setState(() => _busy = true);
    try {
      final msg = await TagMemoryService.setUltralightPassword(
        pwd4: _hexToBytes(_pwdController.text),
        pack2: _hexToBytes(_packController.text),
        pwdPage: int.parse(_pwdPageController.text.trim()),
        packPage: int.parse(_packPageController.text.trim()),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _passwordUnset() async {
    setState(() => _busy = true);
    try {
      final msg = await TagMemoryService.unsetUltralightPassword(
        pwdPage: int.parse(_pwdPageController.text.trim()),
        packPage: int.parse(_packPageController.text.trim()),
        pwd4ForAuth: _hexToBytes(_pwdController.text),
        pack2ForAuth: _hexToBytes(_packController.text),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _classicDump() async {
    setState(() => _busy = true);
    try {
      final key = MifareClassicService.parseKey(_classicKeyController.text);
      final info = await MifareClassicService.dumpWithKey(key6: key);
      setState(() => _classicInfo = info['dump']?.toString() ?? info.toString());
    } catch (e) {
      setState(() => _classicInfo = 'Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _classicWriteBlock() async {
    setState(() => _busy = true);
    try {
      final key = MifareClassicService.parseKey(_classicKeyController.text);
      final data = _hexToBytes(_classicDataController.text);
      if (data.length != 16) throw FormatException('Need exactly 16 bytes');
      await MifareClassicService.writeBlock(
        sectorIndex: int.parse(_classicSectorController.text.trim()),
        blockInSector: int.parse(_classicBlockController.text.trim()),
        data16: data,
        key6: key,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Classic block written')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _classicExportBin() async {
    final text = _classicInfo;
    if (text == null || text.startsWith('Error')) return;
    final bytes = _classicDumpTextToBytes(text);
    final uri = await PlatformBridge.saveBytes(bytes, 'mifare_classic_dump.bin');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(uri == null ? 'Export cancelled' : 'Saved: $uri')),
      );
    }
  }

  Future<void> _classicImportBinWrite() async {
    final bytes = await PlatformBridge.pickBytes();
    if (bytes == null || bytes.isEmpty) return;
    if (bytes.length % 16 != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Classic dump must be multiple of 16 bytes')),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Write Classic dump?'),
        content: Text(
          'Will write ${bytes.length ~/ 16} blocks starting sector 0 with current key. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Write')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      final key = MifareClassicService.parseKey(_classicKeyController.text);
      var sector = 0;
      var blockInSector = 0;
      for (var i = 0; i < bytes.length; i += 16) {
        final blocksInSector = sector < 32 ? 4 : 16;
        // skip trailer block (last in sector)
        if (blockInSector == blocksInSector - 1) {
          sector++;
          blockInSector = 0;
          continue;
        }
        await MifareClassicService.writeBlock(
          sectorIndex: sector,
          blockInSector: blockInSector,
          data16: bytes.sublist(i, i + 16),
          key6: key,
        );
        blockInSector++;
        if (blockInSector >= blocksInSector) {
          sector++;
          blockInSector = 0;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Classic dump write finished')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Uint8List _classicDumpTextToBytes(String text) {
    final out = BytesBuilder();
    for (final line in text.split('\n')) {
      if (!line.contains(' B')) continue;
      final idx = line.indexOf(':');
      if (idx < 0) continue;
      out.add(_hexToBytes(line.substring(idx + 1)));
    }
    return out.toBytes();
  }

  Uint8List _hexToBytes(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    final out = Uint8List(cleaned.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(cleaned.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  String _formatDump(Uint8List bytes) {
    final buf = StringBuffer();
    for (var i = 0; i < bytes.length; i += 4) {
      final page = i ~/ 4;
      final slice = bytes.sublist(i, (i + 4).clamp(0, bytes.length));
      final hex = slice
          .map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(' ');
      buf.writeln('Page ${page.toString().padLeft(2, '0')}: $hex');
    }
    return buf.toString();
  }

  Widget _memoryGrid() {
    final bytes = _memoryBytes;
    if (bytes == null) return const SizedBox.shrink();
    final pages = (bytes.length / 4).ceil();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: pages,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
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
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'P$index',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
                const SizedBox(height: 2),
                Text(
                  hex,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontFamily: 'monospace',
                    fontSize: 10,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _toolCard({
    required String title,
    required IconData icon,
    required Color accent,
    required List<Widget> children,
  }) {
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

  /// Consistent gap between stacked fields (avoids floating-label collisions).
  static const _fieldGap = SizedBox(height: 16);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tools')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _toolCard(
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
                onTap: _busy ? null : _infiniteCopy,
              ),
            ],
          ),
          _toolCard(
            title: 'Ultralight / NTAG Memory',
            icon: Icons.memory,
            accent: const Color(0xFF6366F1),
            children: [
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _busy ? null : _readMemory,
                      child: const Text('Read dump'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: _gridView ? 'Text view' : 'Grid view',
                    onPressed: () => setState(() => _gridView = !_gridView),
                    icon: Icon(_gridView ? Icons.view_list : Icons.grid_view),
                  ),
                ],
              ),
              if (_memoryBytes != null) ...[
                const SizedBox(height: 12),
                if (_gridView)
                  _memoryGrid()
                else
                  SelectableText(
                    _memoryHex ?? '',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton(onPressed: _exportBin, child: const Text('Export .bin')),
                    TextButton(onPressed: _importBin, child: const Text('Import .bin')),
                    TextButton(onPressed: _busy ? null : _writeDumpBack, child: const Text('Write dump')),
                    TextButton(
                      onPressed: () => Share.share(_memoryHex ?? ''),
                      child: const Text('Share text'),
                    ),
                  ],
                ),
              ],
            ],
          ),
          _toolCard(
            title: 'Advanced Transceive',
            icon: Icons.terminal,
            accent: const Color(0xFF059669),
            children: [
              HexField(
                controller: _txController,
                label: 'Hex command',
                hint: '30 00',
              ),
              _fieldGap,
              FilledButton(
                onPressed: _busy ? null : _transceive,
                child: const Text('Transceive'),
              ),
              if (_txLog != null) ...[
                const SizedBox(height: 8),
                SelectableText(_txLog!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ],
            ],
          ),
          _toolCard(
            title: 'Mifare Classic',
            icon: Icons.credit_card,
            accent: const Color(0xFFEA580C),
            children: [
              HexField(
                controller: _classicKeyController,
                label: 'Key (6 bytes)',
                maxBytes: 6,
              ),
              _fieldGap,
              OutlinedButton(
                onPressed: _busy ? null : _classicDump,
                child: const Text('Dump all sectors'),
              ),
              if (_classicInfo != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SelectableText(
                    _classicInfo!,
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
                        controller: _classicSectorController,
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
                        controller: _classicBlockController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
                ],
              ),
              _fieldGap,
              HexField(
                controller: _classicDataController,
                label: '16-byte block data',
                maxBytes: 16,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(onPressed: _busy ? null : _classicWriteBlock, child: const Text('Write block')),
                  OutlinedButton(onPressed: _classicExportBin, child: const Text('Export .bin')),
                  OutlinedButton(onPressed: _busy ? null : _classicImportBinWrite, child: const Text('Import & write')),
                ],
              ),
            ],
          ),
          _toolCard(
            title: 'Ultralight EV1 Password',
            icon: Icons.lock_outline,
            accent: const Color(0xFFDC2626),
            children: [
              HexField(controller: _pwdController, label: 'PWD (4 bytes)', maxBytes: 4),
              _fieldGap,
              HexField(controller: _packController, label: 'PACK (2 bytes)', maxBytes: 2),
              _fieldGap,
              Row(
                children: [
                  Expanded(
                    child: AppLabeledField(
                      label: 'PWD page',
                      padding: EdgeInsets.zero,
                      child: TextField(
                        controller: _pwdPageController,
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
                        controller: _packPageController,
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
                  OutlinedButton(onPressed: _busy ? null : _passwordAuth, child: const Text('PWD_AUTH')),
                  OutlinedButton(onPressed: _busy ? null : _passwordSet, child: const Text('Set PWD')),
                  OutlinedButton(onPressed: _busy ? null : _passwordUnset, child: const Text('Unset PWD')),
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
          ),
        ],
      ),
    );
  }
}

class _InfiniteCopyDialog extends StatefulWidget {
  final List<NdefRecordModel> records;
  final String sourceUid;
  final void Function(String uid, int index) onWritten;

  const _InfiniteCopyDialog({
    required this.records,
    required this.sourceUid,
    required this.onWritten,
  });

  @override
  State<_InfiniteCopyDialog> createState() => _InfiniteCopyDialogState();
}

class _InfiniteCopyDialogState extends State<_InfiniteCopyDialog> {
  int _count = 0;
  String _last = 'Waiting…';
  bool _running = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loop());
  }

  void _loop() {
    NfcService.startBatchWriteSession(
      records: widget.records,
      shouldContinue: () => _running && mounted,
      onTagWritten: (uid) {
        if (!mounted || !_running) return;
        final n = _count + 1;
        widget.onWritten(uid, n);
        setState(() {
          _count = n;
          _last = uid;
        });
      },
      onError: (err) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      },
    );
  }

  @override
  void dispose() {
    _running = false;
    NfcService.stopSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Infinite Copy'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Source: ${widget.sourceUid}'),
          const SizedBox(height: 12),
          Text('Clones: $_count', style: Theme.of(context).textTheme.headlineSmall),
          Text('Last: $_last'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _running = false;
            NfcService.stopSession();
            Navigator.pop(context);
          },
          child: const Text('Stop'),
        ),
      ],
    );
  }
}
