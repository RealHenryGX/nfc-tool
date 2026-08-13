import 'package:flutter/material.dart';

import '../../core/tasks/task_catalog.dart';
import '../../core/widgets/app_ui.dart';

/// Parameter-entry dialog shown before running/writing a [TaskKind].
class TaskParamDialog extends StatefulWidget {
  final TaskKind kind;
  const TaskParamDialog({super.key, required this.kind});

  @override
  State<TaskParamDialog> createState() => _TaskParamDialogState();
}

class _TaskParamDialogState extends State<TaskParamDialog> {
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
