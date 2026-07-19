import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_ui.dart';
import '../settings/settings_provider.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  String _themeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'System',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
  }

  IconData _themeIcon(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => Icons.brightness_auto,
      ThemeMode.light => Icons.light_mode,
      ThemeMode.dark => Icons.dark_mode,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const AppSectionHeader(
            title: 'Appearance',
            subtitle: 'Tap theme to cycle · long-press for settings',
          ),
          AppSettingsGroup(
            children: [
              AppSettingsTile(
                icon: _themeIcon(themeMode),
                title: 'Theme',
                subtitle: _themeLabel(themeMode),
                onTap: () => ref.read(settingsProvider.notifier).cycleThemeMode(),
                onLongPress: () => context.push('/settings'),
              ),
            ],
          ),
          const AppSectionHeader(title: 'Library'),
          AppSettingsGroup(
            children: [
              AppSettingsTile(
                icon: Icons.style_outlined,
                title: 'Templates',
                subtitle: 'Saved NDEF payloads',
                onTap: () => context.push('/templates'),
              ),
              AppSettingsTile(
                icon: Icons.history,
                title: 'History',
                subtitle: 'Read / write / task logs + CSV',
                onTap: () => context.push('/history'),
              ),
            ],
          ),
          const AppSectionHeader(title: 'App'),
          AppSettingsGroup(
            children: [
              AppSettingsTile(
                icon: Icons.settings_outlined,
                title: 'Settings',
                subtitle: 'Backup & reset',
                onTap: () => context.push('/settings'),
              ),
              AppSettingsTile(
                icon: Icons.bug_report_outlined,
                title: 'Debug Console',
                subtitle: 'NFC / APDU / platform logs',
                onTap: () => context.push('/debug'),
              ),
              AppSettingsTile(
                icon: Icons.info_outline,
                title: 'About & Licenses',
                onTap: () => context.push('/about'),
              ),
              AppSettingsTile(
                icon: Icons.school_outlined,
                title: 'Show onboarding again',
                onTap: () => context.go('/onboarding'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
