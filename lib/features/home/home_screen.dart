import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_info.dart';
import '../../core/nfc/nfc_dialog.dart';
import '../../core/theme/stackntrace_tokens.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/radar_pulse.dart';
import '../../features/history/history_provider.dart';
import '../../features/templates/templates_provider.dart';
import '../../models/ndef_record.dart';
import '../../models/tag_template.dart';
import '../../services/nfc_service.dart';

/// Brand-first home: hero scan composition, then secondary tools.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _fade = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic));
    _enter.forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  void _triggerRead() async {
    final context = this.context;
    final NfcTagDetails? details = await showNfcSession<NfcTagDetails>(
      context: context,
      title: 'Ready to Read',
      message: 'Place your tag near the back of your phone.',
      mode: NfcDialogMode.read,
    );

    if (details != null) {
      await ref.read(historyProvider.notifier).addRecord(
            uid: details.uid,
            action: 'read',
            records: details.records,
            success: true,
            details: '${details.type ?? 'Unknown'} (${details.maxSize ?? 0} Bytes)',
          );

      if (context.mounted) {
        context.push('/read', extra: details);
      }
    }
  }

  void _triggerCopyTag() async {
    final context = this.context;
    final source = await showNfcSession<NfcTagDetails>(
      context: context,
      title: 'Copy Tag — Source',
      message: 'Tap the SOURCE tag to clone its NDEF records.',
      mode: NfcDialogMode.read,
    );

    if (source == null || !context.mounted) return;

    if (source.records.isEmpty) {
      showAppSnack(context, 'Source tag has no NDEF records to copy', isError: true);
      return;
    }

    final ok = await showNfcSession<bool>(
      context: context,
      title: 'Copy Tag — Destination',
      message:
          'Now tap the DESTINATION tag.\nCloning ${source.records.length} record(s) from ${source.uid ?? 'source'}.',
      mode: NfcDialogMode.write,
      records: source.records,
    );

    await ref.read(historyProvider.notifier).addRecord(
          uid: source.uid,
          action: 'copy',
          records: source.records,
          success: ok == true,
          details: ok == true
              ? 'Cloned ${source.records.length} records'
              : 'Copy failed or cancelled',
        );

    if (context.mounted) {
      showAppSnack(
        context,
        ok == true ? 'Tag copied successfully' : 'Copy cancelled or failed',
        isError: ok != true,
      );
    }
  }

  void _triggerErase() async {
    final context = this.context;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erase Tag?'),
        content: const Text(
          'This writes an empty NDEF message and clears existing records. It does not reformat the chip.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Erase'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final ok = await showNfcSession<bool>(
      context: context,
      title: 'Erase Tag',
      message: 'Hold the tag against the phone to erase NDEF content.',
      mode: NfcDialogMode.erase,
    );

    await ref.read(historyProvider.notifier).addRecord(
          action: 'erase',
          records: const <NdefRecordModel>[],
          success: ok == true,
          details: ok == true ? 'NDEF erased' : 'Erase failed or cancelled',
        );
  }

  void _triggerBatchWrite() async {
    final context = this.context;
    final templates = ref.read(templatesProvider);
    if (templates.isEmpty) {
      showAppSnack(context, 'Create a template first — Write tab or Templates');
      return;
    }

    final selectedTemplate = await showDialog<TagTemplate?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Template for Batch'),
        children: templates
            .map(
              (t) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, t),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        child: Text('${t.records.length}', style: const TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );

    if (selectedTemplate == null || !context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _BatchWriteDialog(
        template: selectedTemplate,
        onWritten: (uid, index) {
          ref.read(historyProvider.notifier).addRecord(
                uid: uid,
                action: 'batch_write',
                records: selectedTemplate.records,
                success: true,
                details: 'Batch tag #$index',
              );
        },
        onError: (err) {
          ref.read(historyProvider.notifier).addRecord(
                action: 'batch_write',
                records: selectedTemplate.records,
                success: false,
                details: 'Batch error: $err',
              );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(templatesProvider);
    final history = ref.watch(historyProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final topPad = MediaQuery.paddingOf(context).top;

    // stackntrace.dev atmosphere — amber accent on ink / paper.
    final signal = StackntraceTokens.accent(theme.brightness);
    final mistTop = isDark
        ? StackntraceTokens.darkSurface2
        : StackntraceTokens.lightSurface2;
    final mistBottom = isDark
        ? StackntraceTokens.darkBackground
        : StackntraceTokens.lightBackground;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [mistTop, mistBottom],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -48,
                      top: topPad + 24,
                      child: IgnorePointer(
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                signal.withValues(alpha: isDark ? 0.28 : 0.18),
                                signal.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    FadeTransition(
                      opacity: _fade,
                      child: SlideTransition(
                        position: _slide,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(24, topPad + 28, 24, 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppInfo.name,
                                style: theme.textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.2,
                                  height: 1.05,
                                  color: isDark
                                      ? StackntraceTokens.darkForegroundStrong
                                      : StackntraceTokens.lightForegroundStrong,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Hold. Scan. Decide.',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.3,
                                  color: isDark
                                      ? StackntraceTokens.darkMuted
                                      : StackntraceTokens.lightMuted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'FOSS tag tooling for Android — no accounts, no telemetry.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.4,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 28),
                              Center(
                                child: RadarPulse(
                                  icon: Icons.nfc,
                                  size: 78,
                                  color: signal,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: _triggerRead,
                                      icon: const Icon(Icons.sensors),
                                      label: const Text('Read'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: signal,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FilledButton.tonalIcon(
                                      onPressed: () => context.push('/write'),
                                      icon: const Icon(Icons.edit_outlined),
                                      label: const Text('Write'),
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Text(
                  'More',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.list(
                children: [
                  _ToolRow(
                    icon: Icons.copy_all_outlined,
                    title: 'Copy tag',
                    subtitle: 'Clone NDEF to another chip',
                    onTap: _triggerCopyTag,
                    delay: const Duration(milliseconds: 80),
                    controller: _enter,
                  ),
                  _ToolRow(
                    icon: Icons.qr_code_scanner_outlined,
                    title: 'QR wizard',
                    subtitle: 'Turn a code into an NFC write',
                    onTap: () => context.push('/qr_wizard'),
                    delay: const Duration(milliseconds: 140),
                    controller: _enter,
                  ),
                  _ToolRow(
                    icon: Icons.library_add_outlined,
                    title: 'Batch write',
                    subtitle: 'One template, many tags',
                    onTap: _triggerBatchWrite,
                    delay: const Duration(milliseconds: 200),
                    controller: _enter,
                  ),
                  _ToolRow(
                    icon: Icons.delete_outline,
                    title: 'Erase',
                    subtitle: 'Clear NDEF records on a writable tag',
                    onTap: _triggerErase,
                    delay: const Duration(milliseconds: 260),
                    controller: _enter,
                    destructive: true,
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 96),
                child: Row(
                  children: [
                    _LibraryLink(
                      label: 'Templates',
                      value: '${templates.length}',
                      onTap: () => context.push('/templates'),
                    ),
                    const SizedBox(width: 28),
                    _LibraryLink(
                      label: 'History',
                      value: '${history.length}',
                      onTap: () => context.push('/history'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Duration delay;
  final AnimationController controller;
  final bool destructive;

  const _ToolRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.delay,
    required this.controller,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = (delay.inMilliseconds / 720).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
      parent: controller,
      curve: Interval(start, 1.0, curve: Curves.easeOutCubic),
    );
    final accent = destructive
        ? theme.colorScheme.error
        : StackntraceTokens.accent(theme.brightness);

    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(anim),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, color: accent, size: 26),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryLink extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _LibraryLink({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: StackntraceTokens.accent(theme.brightness),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BatchWriteDialog extends StatefulWidget {
  final TagTemplate template;
  final void Function(String uid, int index) onWritten;
  final void Function(String error) onError;

  const _BatchWriteDialog({
    required this.template,
    required this.onWritten,
    required this.onError,
  });

  @override
  State<_BatchWriteDialog> createState() => _BatchWriteDialogState();
}

class _BatchWriteDialogState extends State<_BatchWriteDialog> {
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
      records: widget.template.records,
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
        widget.onError(err);
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
              widget.template.name,
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
          const SizedBox(height: 8),
          Text(
            'Last UID: $_currentUid',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _friendlyBatchError(_error!),
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
        if (_error != null)
          TextButton(
            onPressed: () {
              setState(() => _error = null);
              _startBatch();
            },
            child: const Text('Retry'),
          ),
        FilledButton(
          onPressed: () {
            _running = false;
            NfcService.stopSession();
            Navigator.pop(context);
          },
          child: const Text('Finish'),
        ),
      ],
    );
  }

  String _friendlyBatchError(String err) {
    final lower = err.toLowerCase();
    if (lower.contains('out of date') || lower.contains('securityexception')) {
      return 'Write interrupted — keep the tag still and tap Retry.';
    }
    if (lower.contains('ioexception')) {
      return 'Write failed (contact lost). Hold steady, then Retry.';
    }
    final first = err.split('\n').first.trim();
    if (first.length > 120) return '${first.substring(0, 117)}…';
    return first;
  }
}
