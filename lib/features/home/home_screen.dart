import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_info.dart';
import '../../core/theme/stackntrace_tokens.dart';
import '../../core/widgets/radar_pulse.dart';
import '../history/history_provider.dart';
import '../templates/templates_provider.dart';
import 'home_provider.dart';
import 'home_widgets.dart';

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

  @override
  Widget build(BuildContext context) {
    final actions = ref.read(homeActionsProvider);
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
                        child: Builder(
                          builder: (context) {
                            final glow = (MediaQuery.sizeOf(context).width * 0.55)
                                .clamp(160.0, 240.0);
                            return Container(
                              width: glow,
                              height: glow,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    signal.withValues(alpha: isDark ? 0.28 : 0.18),
                                    signal.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            );
                          },
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
                                      onPressed: () => actions.triggerRead(context),
                                      icon: const Icon(Icons.sensors),
                                      label: const Text('Read'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: signal,
                                        foregroundColor: isDark
                                            ? StackntraceTokens.darkOnAccent
                                            : StackntraceTokens.lightOnAccent,
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
                  HomeToolRow(
                    icon: Icons.copy_all_outlined,
                    title: 'Copy tag',
                    subtitle: 'Clone NDEF to another chip',
                    onTap: () => actions.triggerCopyTag(context),
                    delay: const Duration(milliseconds: 80),
                    controller: _enter,
                  ),
                  HomeToolRow(
                    icon: Icons.qr_code_scanner_outlined,
                    title: 'QR wizard',
                    subtitle: 'Turn a code into an NFC write',
                    onTap: () => context.push('/qr_wizard'),
                    delay: const Duration(milliseconds: 140),
                    controller: _enter,
                  ),
                  HomeToolRow(
                    icon: Icons.library_add_outlined,
                    title: 'Batch write',
                    subtitle: 'One template, many tags',
                    onTap: () => actions.triggerBatchWrite(context),
                    delay: const Duration(milliseconds: 200),
                    controller: _enter,
                  ),
                  HomeToolRow(
                    icon: Icons.delete_outline,
                    title: 'Erase',
                    subtitle: 'Clear NDEF records on a writable tag',
                    onTap: () => actions.triggerErase(context),
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
                    Expanded(
                      child: HomeLibraryLink(
                        label: 'Templates',
                        value: '${templates.length}',
                        onTap: () => context.push('/templates'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: HomeLibraryLink(
                        label: 'History',
                        value: '${history.length}',
                        onTap: () => context.push('/history'),
                      ),
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
