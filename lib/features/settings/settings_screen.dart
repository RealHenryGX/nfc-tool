import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_ui.dart';
import 'settings_provider.dart';
import '../templates/templates_provider.dart';
import '../history/history_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _exportBackup(BuildContext context, WidgetRef ref) async {
    final jsonStr = ref.read(templatesProvider.notifier).exportToJson();
    try {
      await shareAppTempFile(
        fileName: 'nfc_toolbox_backup.json',
        contents: jsonStr,
        mimeType: 'application/json',
        subject: 'NFC Toolbox Backup JSON',
      );
    } catch (e) {
      if (context.mounted) {
        showAppSnack(context, 'Backup failed: $e', isError: true);
      }
    }
  }

  void _importBackup(BuildContext context, WidgetRef ref) async {
    final textController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Paste the JSON backup string below to import templates.',
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                hintText: '[{"id":"...","name":"...","records":...}]',
              ),
              maxLines: 8,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Import')),
        ],
      ),
    );

    if (confirm == true && textController.text.trim().isNotEmpty && context.mounted) {
      final success =
          await ref.read(templatesProvider.notifier).importFromJson(textController.text.trim());
      if (context.mounted) {
        showAppSnack(
          context,
          success ? 'Backup restored successfully' : 'Invalid backup JSON format',
          isError: !success,
        );
      }
    }
  }

  void _resetApp(BuildContext context, WidgetRef ref) async {
    final confirm = await confirmAppAction(
      context,
      title: 'Reset Application?',
      message:
          'This will delete all saved templates, history records, and configurations. This is permanent!',
      confirmLabel: 'Reset Everything',
      destructive: true,
    );

    if (confirm) {
      await ref.read(templatesProvider.notifier).clearAll();
      await ref.read(historyProvider.notifier).clearAll();
      if (context.mounted) {
        showAppSnack(context, 'App database cleared');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const AppSectionHeader(title: 'Appearance'),
          AppSettingsGroup(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Theme', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      'Light, dark, or follow system',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto), label: Text('System')),
                          ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Light')),
                          ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Dark')),
                        ],
                        selected: {themeMode},
                        onSelectionChanged: (set) {
                          ref.read(settingsProvider.notifier).setThemeMode(set.first);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const AppSectionHeader(title: 'Backup & Restore'),
          AppSettingsGroup(
            children: [
              AppSettingsTile(
                icon: Icons.cloud_upload_outlined,
                title: 'Export Templates Backup',
                subtitle: 'Share backup JSON file',
                onTap: () => _exportBackup(context, ref),
              ),
              AppSettingsTile(
                icon: Icons.cloud_download_outlined,
                title: 'Import Backup',
                subtitle: 'Restore from backup JSON string',
                onTap: () => _importBackup(context, ref),
              ),
            ],
          ),
          const AppSectionHeader(title: 'Database'),
          AppSettingsGroup(
            children: [
              AppSettingsTile(
                icon: Icons.delete_forever_outlined,
                title: 'Reset App Data',
                subtitle: 'Delete templates, logs, and settings cache',
                destructive: true,
                onTap: () => _resetApp(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
