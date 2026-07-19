import 'task_runner.dart';

class LaunchableApp {
  final String label;
  final String packageName;
  const LaunchableApp({required this.label, required this.packageName});
}

class PlatformApps {
  static Future<List<LaunchableApp>> listLaunchable() async {
    final res = await PlatformBridge.invoke('listLaunchableApps');
    if (res['ok'] != true) return [];
    final apps = res['apps'];
    if (apps is! List) return [];
    return apps
        .whereType<Map>()
        .map(
          (e) => LaunchableApp(
            label: e['label']?.toString() ?? '',
            packageName: e['packageName']?.toString() ?? '',
          ),
        )
        .where((e) => e.packageName.isNotEmpty)
        .toList();
  }
}
