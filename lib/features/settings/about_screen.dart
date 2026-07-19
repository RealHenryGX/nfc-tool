import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_info.dart';
import '../../core/theme/stackntrace_tokens.dart';
import '../../core/widgets/app_ui.dart';

/// About screen aligned with stackntrace-android-ui `AboutScreen` v1.1.1
/// (app header + author card + icon action row + privacy footer).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        await Clipboard.setData(ClipboardData(text: url));
        if (context.mounted) {
          showAppSnack(context, 'Could not open — link copied');
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) {
        showAppSnack(context, 'Link copied to clipboard');
      }
    }
  }

  void _showLicenseDialog(BuildContext context) {
    final notice =
        '${AppInfo.name} — ${AppInfo.licenseLabel}\n'
        'Copyright (c) ${AppInfo.copyrightYear} ${AppInfo.authorName} (${AppInfo.authorEmail})\n'
        '${AppInfo.githubRepo}';

    showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        final strong = isDark
            ? StackntraceTokens.darkForegroundStrong
            : StackntraceTokens.lightForegroundStrong;
        final muted = isDark
            ? StackntraceTokens.darkMuted
            : StackntraceTokens.lightMuted;

        return AlertDialog(
          title: Text(
            AppInfo.licenseLabel,
            style: TextStyle(color: strong, fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Free to use, modify, and distribute. Include the copyright notice in copies. No warranty.',
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
              const SizedBox(height: 12),
              Text(
                'Copyright (c) ${AppInfo.copyrightYear} ${AppInfo.authorName}\n'
                '${AppInfo.authorEmail}\n'
                '${AppInfo.websiteUrl}\n'
                '${AppInfo.githubRepo}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: notice));
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  showAppSnack(context, 'License notice copied');
                }
              },
              child: const Text('Copy license notice'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;
    final strong = isDark
        ? StackntraceTokens.darkForegroundStrong
        : StackntraceTokens.lightForegroundStrong;
    final muted = isDark
        ? StackntraceTokens.darkMuted
        : StackntraceTokens.lightMuted;
    final accent = StackntraceTokens.accent(brightness);

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const SizedBox(height: 12),
          Text(
            AppInfo.name,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: strong,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Version ${AppInfo.version}',
            style: theme.textTheme.labelMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 10),
          Text(
            AppInfo.description,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 28),

          // Icon action row — Website / Source / Email / License
          DecoratedBox(
            decoration: BoxDecoration(
              color: StackntraceTokens.surface2(brightness),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: StackntraceTokens.border(brightness)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _AboutIconAction(
                    tooltip: 'Visit Website',
                    icon: Icons.language,
                    color: accent,
                    onPressed: () => _openUrl(context, AppInfo.websiteUrl),
                  ),
                  _AboutIconAction(
                    tooltip: 'View Source Code',
                    icon: Icons.code,
                    color: accent,
                    onPressed: () => _openUrl(context, AppInfo.githubRepo),
                  ),
                  _AboutIconAction(
                    tooltip: 'Email ${AppInfo.authorEmail}',
                    icon: Icons.email,
                    color: accent,
                    onPressed: () =>
                        _openUrl(context, 'mailto:${AppInfo.authorEmail}'),
                  ),
                  _AboutIconAction(
                    tooltip: 'View License',
                    icon: Icons.balance_outlined,
                    color: accent,
                    onPressed: () => _showLicenseDialog(context),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          Text(
            AppInfo.copyrightFooter,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 6),
          Text(
            AppInfo.privacyFooter,
            style: theme.textTheme.bodySmall?.copyWith(
              color: muted.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'FOSS reimplementation using public NFC Forum / Android APIs. '
            'Feature goals track commercial NFC Tools for parity — no proprietary code copied.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: AppInfo.name,
              applicationVersion: AppInfo.version,
              applicationLegalese: AppInfo.copyrightLine,
            ),
            child: const Text('Open-source licenses'),
          ),
        ],
      ),
    );
  }
}

class _AboutIconAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _AboutIconAction({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        iconSize: 24,
        constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
        icon: Icon(icon, color: color),
        tooltip: tooltip,
      ),
    );
  }
}
