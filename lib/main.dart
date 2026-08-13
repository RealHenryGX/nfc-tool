import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/debug/app_debug.dart';
import 'core/routing/app_router.dart';
import 'core/storage/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/debug_provider.dart';
import 'features/settings/settings_provider.dart';

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
      routerConfig: createAppRouter(),
    );
  }
}
