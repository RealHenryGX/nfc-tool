import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nfc_tool/core/storage/storage_service.dart';
import 'package:nfc_tool/core/theme/app_theme.dart';
import 'package:nfc_tool/features/history/history_screen.dart';
import 'package:nfc_tool/features/home/home_screen.dart';
import 'package:nfc_tool/features/more/more_screen.dart';
import 'package:nfc_tool/features/onboarding/onboarding_screen.dart';
import 'package:nfc_tool/features/read/read_screen.dart';
import 'package:nfc_tool/features/settings/about_screen.dart';
import 'package:nfc_tool/features/settings/debug_console_screen.dart';
import 'package:nfc_tool/features/settings/settings_screen.dart';
import 'package:nfc_tool/features/tasks/tasks_screen.dart';
import 'package:nfc_tool/features/templates/templates_screen.dart';
import 'package:nfc_tool/features/tools/tools_screen.dart';
import 'package:nfc_tool/features/write/record_editor_dialog.dart';
import 'package:nfc_tool/features/write/write_screen.dart';

/// Smoke-tests every major screen for layout exceptions / missing chrome.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Hive.init('/tmp/nfc_tool_ui_smoke_hive');
    await Hive.openBox('templates');
    await Hive.openBox('history');
    await Hive.openBox('settings');
    await StorageService.setOnboardingDone(true);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: screen,
        ),
      ),
    );
    // Avoid pumpAndSettle — RadarPulse / entrance animations loop forever.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('Home shows brand + Read/Write + Erase', (tester) async {
    await pumpScreen(tester, const HomeScreen());
    expect(find.text('NFC Toolbox'), findsOneWidget);
    expect(find.text('Read'), findsWidgets);
    expect(find.text('Write'), findsWidgets);
    await scrollTo(tester, find.text('Erase'));
    expect(find.text('Erase'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Read empty state', (tester) async {
    await pumpScreen(tester, const ReadScreen());
    expect(find.textContaining('Read'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Write empty state + open Add Record sheet', (tester) async {
    await pumpScreen(tester, const WriteScreen());
    final add = find.textContaining('Add Record');
    expect(add, findsOneWidget);
    await tester.tap(add);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Add NFC Record'), findsOneWidget);
    expect(find.text('Text'), findsWidgets);
    await tester.tap(find.text('Text').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Text'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tasks catalog', (tester) async {
    await pumpScreen(tester, const TasksScreen());
    expect(find.text('Tasks'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tools cards without layout overflow', (tester) async {
    await pumpScreen(tester, const ToolsScreen());
    expect(find.text('Tools'), findsOneWidget);
    expect(find.text('Clone'), findsOneWidget);
    await scrollTo(tester, find.text('PWD (4 bytes)'));
    expect(find.text('PWD (4 bytes)'), findsOneWidget);
    expect(find.text('PACK (2 bytes)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('More destinations', (tester) async {
    await pumpScreen(tester, const MoreScreen());
    expect(find.text('Templates'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.textContaining('About'), findsOneWidget);
  });

  testWidgets('Templates empty', (tester) async {
    await pumpScreen(tester, const TemplatesScreen());
    expect(find.textContaining('Template'), findsWidgets);
  });

  testWidgets('History empty', (tester) async {
    await pumpScreen(tester, const HistoryScreen());
    expect(find.textContaining('History'), findsWidgets);
  });

  testWidgets('Settings', (tester) async {
    await pumpScreen(tester, const SettingsScreen());
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('About has no author tagline card', (tester) async {
    await pumpScreen(tester, const AboutScreen());
    expect(find.text('About'), findsOneWidget);
    expect(find.text('NFC Toolbox'), findsOneWidget);
    expect(find.textContaining('security researcher'), findsNothing);
    expect(find.text('helllguest'), findsNothing);
  });

  testWidgets('Debug console', (tester) async {
    await pumpScreen(tester, const DebugConsoleScreen());
    expect(find.textContaining('Debug'), findsWidgets);
  });

  testWidgets('Onboarding pages', (tester) async {
    await pumpScreen(tester, const OnboardingScreen());
    expect(tester.takeException(), isNull);
  });

  testWidgets('Record editor sheet type picker', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showRecordEditor(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Add NFC Record'), findsOneWidget);
    expect(find.text('Basic'), findsOneWidget);
  });
}
