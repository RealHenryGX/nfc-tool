import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/home_screen.dart';
import '../../features/read/read_screen.dart';
import '../../features/read/record_info_screen.dart';
import '../../features/write/write_screen.dart';
import '../../features/templates/templates_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/about_screen.dart';
import '../../features/settings/debug_console_screen.dart';
import '../../features/qr_import/qr_wizard_screen.dart';
import '../../features/tools/tools_screen.dart';
import '../../features/tasks/tasks_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../models/ndef_record.dart';
import '../../models/tag_template.dart';
import '../../models/nfc_tag_details.dart';
import '../storage/storage_service.dart';
import 'scaffold_with_nav_bar.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: StorageService.isOnboardingDone() ? '/' : '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
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
          GoRoute(
            path: '/tasks',
            builder: (context, state) => const TasksScreen(),
          ),
          GoRoute(
            path: '/tools',
            builder: (context, state) => const ToolsScreen(),
          ),
          GoRoute(
            path: '/more',
            builder: (context, state) => const MoreScreen(),
          ),
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
          GoRoute(
            path: '/record',
            builder: (context, state) {
              final record = state.extra;
              if (record is! NdefRecordModel) {
                return const Scaffold(
                  body: Center(child: Text('Missing record')),
                );
              }
              return RecordInfoScreen(record: record);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/qr_wizard',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const QrWizardScreen(),
      ),
    ],
  );
}
