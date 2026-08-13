import 'package:flutter/material.dart';

import '../../services/platform_apps.dart';

/// Modal list of launchable apps on the device — used by the "Android App" /
/// "Application" record types to pick a package name.
class AppPickerDialog extends StatefulWidget {
  const AppPickerDialog({super.key});

  @override
  State<AppPickerDialog> createState() => _AppPickerDialogState();
}

class _AppPickerDialogState extends State<AppPickerDialog> {
  late Future<List<LaunchableApp>> _future;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _future = PlatformApps.listLaunchable();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dialogW = (size.width * 0.92).clamp(280.0, 420.0);
    final dialogH = (size.height * 0.72).clamp(360.0, 520.0);

    return Dialog(
      child: SizedBox(
        width: dialogW,
        height: dialogH,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Pick application',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Filter…',
                ),
                onChanged: (v) => setState(() => _q = v.toLowerCase()),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<LaunchableApp>>(
                future: _future,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final apps = snap.data!
                      .where(
                        (a) =>
                            _q.isEmpty ||
                            a.label.toLowerCase().contains(_q) ||
                            a.packageName.toLowerCase().contains(_q),
                      )
                      .toList();
                  return ListView.builder(
                    itemCount: apps.length,
                    itemBuilder: (context, i) {
                      final a = apps[i];
                      return ListTile(
                        title: Text(a.label),
                        subtitle: Text(
                          a.packageName,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () => Navigator.pop(context, a.packageName),
                      );
                    },
                  );
                },
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
