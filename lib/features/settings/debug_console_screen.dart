import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/debug/app_debug.dart';
import 'debug_provider.dart';

class DebugConsoleScreen extends ConsumerStatefulWidget {
  const DebugConsoleScreen({super.key});

  @override
  ConsumerState<DebugConsoleScreen> createState() => _DebugConsoleScreenState();
}

class _DebugConsoleScreenState extends ConsumerState<DebugConsoleScreen> {
  String? _tagFilter;
  bool _autoScroll = true;
  final _scroll = ScrollController();

  void _onLog() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    AppDebug.instance.addListener(_onLog);
  }

  @override
  void dispose() {
    AppDebug.instance.removeListener(_onLog);
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    if (!_autoScroll || !_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _copyAll(List<DebugEntry> entries) async {
    final text = entries.map((e) => e.toString()).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Debug log copied')),
    );
  }

  Future<void> _shareAll(List<DebugEntry> entries) async {
    final text = entries.map((e) => e.toString()).join('\n');
    await Share.share(text, subject: 'NFC Toolbox debug log');
  }

  Color _levelColor(DebugLevel level, ColorScheme cs) {
    return switch (level) {
      DebugLevel.info => cs.onSurface,
      DebugLevel.warn => Colors.orange.shade800,
      DebugLevel.error => cs.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final dbg = ref.watch(debugSettingsProvider);
    final theme = Theme.of(context);
    var entries = AppDebug.instance.entries.toList();
    if (_tagFilter != null) {
      entries = entries.where((e) => e.tag == _tagFilter).toList();
    }
    _scrollToEnd();

    final tags = <String>{
      ...AppDebug.instance.entries.map((e) => e.tag),
    }.toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Debug Console (${entries.length})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: _autoScroll ? 'Auto-scroll on' : 'Auto-scroll off',
            icon: Icon(
              _autoScroll ? Icons.vertical_align_bottom : Icons.pause,
            ),
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: entries.isEmpty ? null : () => _copyAll(entries),
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_outlined),
            onPressed: entries.isEmpty ? null : () => _shareAll(entries),
          ),
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => AppDebug.instance.clear(),
          ),
        ],
      ),
      body: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.bug_report_outlined),
            title: const Text('Debug logging'),
            subtitle: Text(
              dbg.enabled
                  ? 'NFC / APDU / platform / tasks → log'
                  : 'Enable to capture sessions',
            ),
            value: dbg.enabled,
            onChanged: (v) =>
                ref.read(debugSettingsProvider.notifier).setEnabled(v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.flag_outlined),
            title: const Text('Show DEBUG banner'),
            value: dbg.showBanner,
            onChanged: (v) =>
                ref.read(debugSettingsProvider.notifier).setShowBanner(v),
          ),
          if (tags.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _tagFilter == null,
                    onSelected: (_) => setState(() => _tagFilter = null),
                  ),
                  const SizedBox(width: 6),
                  ...tags.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(t),
                        selected: _tagFilter == t,
                        onSelected: (_) => setState(() => _tagFilter = t),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      dbg.enabled
                          ? 'No log lines yet.\nScan a tag or run a tool.'
                          : 'Turn on debug logging to start.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: entries.length,
                    itemBuilder: (context, i) {
                      final e = entries[i];
                      return SelectableText(
                        e.toString(),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.35,
                          color: _levelColor(e.level, theme.colorScheme),
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
