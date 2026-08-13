import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/nfc/nfc_dialog.dart';
import '../../core/tasks/task_catalog.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/nfc_task.dart';
import '../../services/task_runner.dart';
import '../history/history_provider.dart';
import 'task_param_dialog.dart';

/// Run / write flow for a chosen [TaskKind]: prompt for params, then either
/// run on-device or write the resulting [NfcTask] to a tag, logging to
/// history either way (mirrors the home screen's NFC-session + history flow).
class TasksActions {
  TasksActions(this._ref);

  final Ref _ref;

  Future<void> openTask(BuildContext context, TaskKind kind) async {
    final params = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => TaskParamDialog(kind: kind),
    );
    if (params == null || !context.mounted) return;

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

    if (!context.mounted || action == null) return;

    if (action == 'run') {
      await _runTask(context, task);
    } else if (action == 'write') {
      await _writeTask(context, task, kind);
    }
  }

  Future<void> _runTask(BuildContext context, NfcTask task) async {
    final msg = await TaskRunner.run(task);
    if (!context.mounted) return;
    await _ref.read(historyProvider.notifier).addRecord(
          action: 'task_run',
          records: [task.toNdefRecord()],
          success: true,
          details: msg,
        );
    if (!context.mounted) return;
    showAppSnack(context, msg);
  }

  Future<void> _writeTask(BuildContext context, NfcTask task, TaskKind kind) async {
    final ok = await showNfcSession<bool>(
      context: context,
      title: 'Write Task',
      message: 'Writing task: ${kind.label}',
      mode: NfcDialogMode.write,
      records: [task.toNdefRecord()],
    );
    await _ref.read(historyProvider.notifier).addRecord(
          action: 'task_write',
          records: [task.toNdefRecord()],
          success: ok == true,
          details: kind.label,
        );
  }
}

final tasksActionsProvider = Provider<TasksActions>((ref) {
  return TasksActions(ref);
});
