import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/nfc/nfc_dialog.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/nfc_task.dart';
import '../../models/tag_template.dart';
import '../../services/nfc_service.dart';
import '../../services/task_runner.dart';

/// Immutable snapshot of the read screen: last scanned tag, raw hex dump
/// (if requested) and whether a raw-hex read is currently in flight.
class ReadState {
  const ReadState({this.details, this.rawHex, this.loadingRaw = false});

  final NfcTagDetails? details;
  final String? rawHex;
  final bool loadingRaw;
}

class ReadNotifier extends Notifier<ReadState> {
  @override
  ReadState build() => const ReadState();

  /// Seeds the state with a tag handed off by the caller (e.g. Home's
  /// read flow), without touching raw-hex / loading fields.
  void setInitialDetails(NfcTagDetails? details) {
    if (details == null) return;
    state = ReadState(details: details, loadingRaw: state.loadingRaw);
  }

  Future<void> scanTag(BuildContext context) async {
    final details = await showNfcSession<NfcTagDetails>(
      context: context,
      title: 'Ready to Read',
      message: 'Place your tag near the back of your phone.',
      mode: NfcDialogMode.read,
    );

    if (details != null) {
      state = ReadState(details: details, loadingRaw: state.loadingRaw);
      if (!context.mounted) return;
      await _maybeRunTasks(context, details);
    }
  }

  Future<void> _maybeRunTasks(BuildContext context, NfcTagDetails details) async {
    final tasks = <NfcTask>[];
    for (final r in details.records) {
      final t = NfcTask.fromNdefRecord(r);
      if (t != null) tasks.add(t);
    }
    if (tasks.isEmpty || !context.mounted) return;

    final run = await confirmAppAction(
      context,
      title: 'Run ${tasks.length} task(s)?',
      message: tasks.map((t) => '• ${t.displayName}').join('\n'),
      confirmLabel: 'Run',
      cancelLabel: 'Skip',
    );
    if (!run || !context.mounted) return;

    final buf = StringBuffer();
    for (final t in tasks) {
      buf.writeln('${t.displayName}: ${await TaskRunner.run(t)}');
    }
    if (!context.mounted) return;
    showAppSnack(context, buf.toString().trim());
  }

  Future<void> lockTag(BuildContext context) async {
    final confirm = await confirmAppAction(
      context,
      title: 'Lock Tag?',
      message:
          'This will make the tag permanently READ-ONLY. This operation CANNOT be undone!',
      confirmLabel: 'Lock Permanently',
      destructive: true,
    );

    if (confirm && context.mounted) {
      final ok = await showNfcSession<bool>(
        context: context,
        title: 'Locking Tag',
        message: 'Hold your tag against the back of your device.',
        mode: NfcDialogMode.lock,
      );
      if (!context.mounted) return;
      showAppSnack(
        context,
        ok == true ? 'Tag locked to read-only' : 'Lock cancelled or failed',
        isError: ok != true,
      );
      if (ok == true) {
        state = ReadState(rawHex: state.rawHex, loadingRaw: state.loadingRaw);
      }
    }
  }

  Future<void> formatTag(BuildContext context) async {
    final confirm = await confirmAppAction(
      context,
      title: 'Format Tag?',
      message:
          'This will wipe all records and format the tag as empty NDEF. Proceed?',
      confirmLabel: 'Format',
    );

    if (confirm && context.mounted) {
      final ok = await showNfcSession<bool>(
        context: context,
        title: 'Formatting Tag',
        message: 'Hold your tag against the back of your device.',
        mode: NfcDialogMode.format,
      );
      if (!context.mounted) return;
      showAppSnack(
        context,
        ok == true ? 'Tag formatted' : 'Format cancelled or failed',
        isError: ok != true,
      );
      if (ok == true) {
        state = ReadState(rawHex: state.rawHex, loadingRaw: state.loadingRaw);
      }
    }
  }

  Future<void> eraseTag(BuildContext context) async {
    final confirm = await confirmAppAction(
      context,
      title: 'Erase Tag?',
      message:
          'Write empty NDEF message (clear records). Chip stays NDEF-formatted.',
      confirmLabel: 'Erase',
      destructive: true,
    );

    if (confirm && context.mounted) {
      final ok = await showNfcSession<bool>(
        context: context,
        title: 'Erase Tag',
        message: 'Hold your tag against the back of your device.',
        mode: NfcDialogMode.erase,
      );
      if (!context.mounted) return;
      showAppSnack(
        context,
        ok == true ? 'Tag erased' : 'Erase cancelled or failed',
        isError: ok != true,
      );
      if (ok == true) {
        state = ReadState(rawHex: state.rawHex, loadingRaw: state.loadingRaw);
      }
    }
  }

  void cloneToWrite(BuildContext context) {
    final details = state.details;
    if (details == null || details.records.isEmpty) {
      showAppSnack(context, 'No NDEF records to clone', isError: true);
      return;
    }
    context.push(
      '/write',
      extra: TagTemplate(
        id: 'clone_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Clone ${details.uid ?? 'tag'}',
        records: details.records,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> loadRawHex(BuildContext context) async {
    state = ReadState(details: state.details, loadingRaw: true);

    try {
      final res = await NfcService.readRawHex(
        onUpdate: (upd) {
          if (context.mounted) showAppSnack(context, upd);
        },
        onError: (err) {
          if (context.mounted) showAppSnack(context, err, isError: true);
        },
      );
      state = ReadState(details: state.details, rawHex: res, loadingRaw: state.loadingRaw);
    } catch (e) {
      if (context.mounted) showAppSnack(context, 'Failed raw read: $e', isError: true);
    } finally {
      state = ReadState(details: state.details, rawHex: state.rawHex, loadingRaw: false);
    }
  }
}

final readProvider = NotifierProvider<ReadNotifier, ReadState>(ReadNotifier.new);
