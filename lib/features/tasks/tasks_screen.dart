import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/nfc/nfc_dialog.dart';
import '../../core/tasks/task_catalog.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/nfc_task.dart';
import '../../services/task_runner.dart';
import '../history/history_provider.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  String _group = 'all';
  String _query = '';

  static const _groupMeta = <String, (String, IconData, Color)>{
    'connectivity': ('Connectivity', Icons.wifi, Color(0xFF2563EB)),
    'sound': ('Sound & Media', Icons.volume_up, Color(0xFF7C3AED)),
    'display': ('Display', Icons.brightness_6, Color(0xFFF59E0B)),
    'apps': ('Apps & System', Icons.apps, Color(0xFFEA580C)),
    'input': ('Input & Speech', Icons.keyboard, Color(0xFF059669)),
    'files': ('Files', Icons.folder, Color(0xFF0D9488)),
    'comms': ('Communications', Icons.call, Color(0xFF16A34A)),
    'maps': ('Maps & Location', Icons.map, Color(0xFFDC2626)),
    'logic': ('Logic & Variables', Icons.account_tree, Color(0xFF6366F1)),
    'misc': ('Misc', Icons.more_horiz, Color(0xFF64748B)),
  };

  (String, IconData, Color) _meta(String group) =>
      _groupMeta[group] ?? (group, Icons.bolt, const Color(0xFF6366F1));

  String _titleCase(String g) {
    if (g == 'all') return 'All';
    return _meta(g).$1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = ['all', ...TaskCatalog.groups];
    final filtered = TaskCatalog.all.where((t) {
      final gOk = _group == 'all' || t.group == _group;
      final q = _query.toLowerCase();
      final qOk = q.isEmpty ||
          t.label.toLowerCase().contains(q) ||
          t.id.contains(q) ||
          t.description.toLowerCase().contains(q);
      return gOk && qOk;
    }).toList();

    // Build sections preserving catalog order of first appearance.
    final sectionOrder = <String>[];
    final byGroup = <String, List<TaskKind>>{};
    for (final t in filtered) {
      byGroup.putIfAbsent(t.group, () {
        sectionOrder.add(t.group);
        return <TaskKind>[];
      }).add(t);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search tasks…',
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: groups.map((g) {
                final selected = _group == g;
                final color = g == 'all' ? theme.colorScheme.primary : _meta(g).$3;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Icon(
                      g == 'all' ? Icons.grid_view : _meta(g).$2,
                      size: 16,
                      color: selected ? color : null,
                    ),
                    label: Text(_titleCase(g)),
                    selected: selected,
                    onSelected: (_) => setState(() => _group = g),
                    selectedColor: color.withValues(alpha: 0.18),
                    checkmarkColor: color,
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No matching tasks',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      for (final g in sectionOrder) ...[
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _StickyGroupHeader(
                            title: _meta(g).$1,
                            icon: _meta(g).$2,
                            color: _meta(g).$3,
                            background: theme.scaffoldBackgroundColor,
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          sliver: SliverList.separated(
                            itemCount: byGroup[g]!.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 4),
                            itemBuilder: (context, i) {
                              final t = byGroup[g]![i];
                              final meta = _meta(t.group);
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: meta.$3.withValues(alpha: 0.15),
                                    child: Icon(
                                      t.rootRecommended
                                          ? Icons.warning_amber_rounded
                                          : meta.$2,
                                      color: t.rootRecommended
                                          ? Colors.orange.shade700
                                          : meta.$3,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    t.label,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    t.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Icon(
                                    Icons.add_circle_outline,
                                    color: meta.$3,
                                  ),
                                  onTap: () => _openTask(t),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTask(TaskKind kind) async {
    final params = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _TaskParamDialog(kind: kind),
    );
    if (params == null || !mounted) return;

    final task = NfcTask(
      id: const Uuid().v4(),
      kind: kind.id,
      params: params,
      label: kind.label,
    );

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow_rounded),
              title: const Text('Run now'),
              subtitle: const Text('Execute on this device'),
              onTap: () => Navigator.pop(ctx, 'run'),
            ),
            ListTile(
              leading: Icon(Icons.add_circle_outline,
                  color: Theme.of(ctx).colorScheme.primary),
              title: const Text('Add to NFC tag'),
              subtitle: const Text('Write this task onto a tag'),
              onTap: () => Navigator.pop(ctx, 'write'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    if (action == 'run') {
      final msg = await TaskRunner.run(task);
      if (!mounted) return;
      await ref.read(historyProvider.notifier).addRecord(
            action: 'task_run',
            records: [task.toNdefRecord()],
            success: true,
            details: msg,
          );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } else if (action == 'write') {
      final ok = await showNfcSession<bool>(
        context: context,
        title: 'Write Task',
        message: 'Writing task: ${kind.label}',
        mode: NfcDialogMode.write,
        records: [task.toNdefRecord()],
      );
      await ref.read(historyProvider.notifier).addRecord(
            action: 'task_write',
            records: [task.toNdefRecord()],
            success: ok == true,
            details: kind.label,
          );
    }
  }
}

class _StickyGroupHeader extends SliverPersistentHeaderDelegate {
  final String title;
  final IconData icon;
  final Color color;
  final Color background;

  _StickyGroupHeader({
    required this.title,
    required this.icon,
    required this.color,
    required this.background,
  });

  @override
  double get minExtent => 40;
  @override
  double get maxExtent => 40;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1.05,
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyGroupHeader oldDelegate) =>
      title != oldDelegate.title ||
      color != oldDelegate.color ||
      background != oldDelegate.background;
}

class _TaskParamDialog extends StatefulWidget {
  final TaskKind kind;
  const _TaskParamDialog({required this.kind});

  @override
  State<_TaskParamDialog> createState() => _TaskParamDialogState();
}

class _TaskParamDialogState extends State<_TaskParamDialog> {
  final Map<String, TextEditingController> _c = {};
  bool _enabled = true;

  TextEditingController ctl(String k) =>
      _c.putIfAbsent(k, TextEditingController.new);

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<Widget> _fields() {
    final id = widget.kind.id;
    Widget f(String key, String label, {String? hint}) => AppLabeledField(
          label: label,
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: ctl(key),
            decoration: InputDecoration(hintText: hint),
          ),
        );

    if (id.contains('wifi_state') ||
        id.contains('bluetooth_state') ||
        id == 'flashlight' ||
        id == 'speaker_state' ||
        id == 'auto_rotate' ||
        id == 'adaptive_brightness') {
      return [
        SwitchListTile(
          title: const Text('Enabled / ON'),
          value: _enabled,
          onChanged: (v) => setState(() => _enabled = v),
        ),
      ];
    }
    if (id == 'wifi_network') {
      return [f('ssid', 'SSID'), f('password', 'Password (optional)')];
    }
    if (id.startsWith('bluetooth_') && id != 'bluetooth_state' && id != 'bluetooth_discoverable') {
      return [f('mac', 'MAC address', hint: 'AA:BB:CC:DD:EE:FF')];
    }
    if (id == 'volume') {
      return [f('level', 'Level 0–100', hint: '50'), f('stream', 'Stream', hint: 'music')];
    }
    if (id == 'brightness' || id == 'display_timeout') {
      return [f('value', 'Value')];
    }
    if (id == 'sound_mode') {
      return [f('mode', 'Mode', hint: 'silent / vibrate / normal')];
    }
    if (id == 'launch_app' ||
        id == 'app_details' ||
        id == 'enable_app' ||
        id == 'disable_app' ||
        id == 'kill_app' ||
        id == 'kill_app_root' ||
        id == 'uninstall_app') {
      return [f('package', 'Package name', hint: 'com.example.app')];
    }
    if (id == 'clipboard' || id == 'keyboard' || id == 'tts' || id == 'notification_alert') {
      return [f('text', 'Text')];
    }
    if (id == 'vibrate') {
      return [f('pattern', 'Pattern ms', hint: '200,100,200')];
    }
    if (id == 'http_request' || id == 'download') {
      return [f('url', 'URL'), f('method', 'Method', hint: 'GET')];
    }
    if (id == 'send_intent') {
      return [
        f('action', 'Action'),
        f('package', 'Package (optional)'),
        f('data', 'Data URI (optional)'),
      ];
    }
    if (id == 'open_file' || id == 'delete_file' || id == 'timestamp_file') {
      return [f('path', 'Path / URI')];
    }
    if (id == 'maps_navigate' || id == 'maps_search') {
      return [f('query', 'Query / destination')];
    }
    if (id == 'set_var' || id == 'edit_var' || id == 'del_var') {
      return [f('key', 'Variable key'), if (id != 'del_var') f('value', 'Value')];
    }
    if (id == 'alarm_set' || id == 'timer_set' || id == 'alarm_in') {
      return [f('minutes', 'Minutes', hint: '10'), f('message', 'Label')];
    }
    if (id == 'roll_dice') {
      return [f('sides', 'Sides', hint: '6')];
    }
    if (id == 'wol') {
      return [f('mac', 'MAC'), f('ip', 'Broadcast IP', hint: '255.255.255.255')];
    }
    if (id == 'udp_send') {
      return [f('host', 'Host'), f('port', 'Port'), f('payload', 'Payload')];
    }
    if (id == 'ping' || id == 'lookup') {
      return [f('host', 'Host')];
    }
    // Default freeform key/value
    return [f('value', 'Parameter')];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.kind.label),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.kind.description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ..._fields(),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final out = <String, dynamic>{};
            final toggleIds = {
              'wifi_state',
              'bluetooth_state',
              'flashlight',
              'speaker_state',
              'auto_rotate',
              'adaptive_brightness',
              'hotspot_state',
            };
            if (toggleIds.contains(widget.kind.id)) {
              out['enabled'] = _enabled;
            }
            for (final e in _c.entries) {
              if (e.value.text.trim().isNotEmpty) {
                out[e.key] = e.value.text.trim();
              }
            }
            Navigator.pop(context, out);
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
