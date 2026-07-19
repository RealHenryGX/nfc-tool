import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/debug/app_debug.dart';
import 'core/storage/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/read/read_screen.dart';
import 'features/write/write_screen.dart';
import 'features/templates/templates_screen.dart';
import 'features/history/history_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/about_screen.dart';
import 'features/settings/debug_console_screen.dart';
import 'features/qr_import/qr_wizard_screen.dart';
import 'features/settings/settings_provider.dart';
import 'features/settings/debug_provider.dart';
import 'features/tools/tools_screen.dart';
import 'features/tasks/tasks_screen.dart';
import 'features/more/more_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'models/tag_template.dart';
import 'services/nfc_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppDebug.instance.error(
      'FLUTTER',
      '${details.exceptionAsString()}\n${details.stack}',
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppDebug.instance.error('ZONE', '$error\n$stack');
    return false;
  };

  if (kDebugMode) {
    AppDebug.instance.info('APP', 'boot kDebugMode=true');
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: StorageService.isOnboardingDone() ? '/' : '/onboarding',
  routes: [
    GoRoute(
      path: '/onboarding',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const OnboardingScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return ScaffoldWithNavBar(child: child);
      },
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/read',
          builder: (context, state) {
            final details = state.extra as NfcTagDetails?;
            return ReadScreen(initialDetails: details);
          },
        ),
        GoRoute(
          path: '/write',
          builder: (context, state) {
            final template = state.extra;
            return WriteScreen(
              template: template is TagTemplate ? template : null,
            );
          },
        ),
        GoRoute(path: '/tasks', builder: (context, state) => const TasksScreen()),
        GoRoute(path: '/tools', builder: (context, state) => const ToolsScreen()),
        GoRoute(path: '/more', builder: (context, state) => const MoreScreen()),
        GoRoute(
          path: '/templates',
          builder: (context, state) => const TemplatesScreen(),
        ),
        GoRoute(
          path: '/history',
          builder: (context, state) => const HistoryScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/about',
          builder: (context, state) => const AboutScreen(),
        ),
        GoRoute(
          path: '/debug',
          builder: (context, state) => const DebugConsoleScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/qr_wizard',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const QrWizardScreen(),
    ),
  ],
);

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider);
    final dbg = ref.watch(debugSettingsProvider);

    return MaterialApp.router(
      title: 'NFC Toolbox',
      debugShowCheckedModeBanner: dbg.showBanner,
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: _router,
    );
  }
}

class ScaffoldWithNavBar extends StatefulWidget {
  final Widget child;

  const ScaffoldWithNavBar({required this.child, super.key});

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar> {
  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/read')) return 1;
    if (location.startsWith('/write')) return 2;
    if (location.startsWith('/tasks')) return 3;
    if (location.startsWith('/tools')) return 4;
    if (location.startsWith('/more') ||
        location.startsWith('/templates') ||
        location.startsWith('/history') ||
        location.startsWith('/settings') ||
        location.startsWith('/about') ||
        location.startsWith('/debug')) {
      return 5;
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
      case 1:
        context.go('/read');
      case 2:
        context.go('/write');
      case 3:
        context.go('/tasks');
      case 4:
        context.go('/tools');
      case 5:
        context.go('/more');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        child: widget.child,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: (idx) => _onItemTapped(idx, context),
        // 6 destinations — alwaysShow labels collide on ~360dp phones.
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.sensors),
            selectedIcon: Icon(Icons.sensors),
            label: 'Read',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_outlined),
            selectedIcon: Icon(Icons.edit),
            label: 'Write',
          ),
          NavigationDestination(
            icon: Icon(Icons.bolt_outlined),
            selectedIcon: Icon(Icons.bolt),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: 'Tools',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
