import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/debug/app_debug.dart';
import '../core/storage/storage_service.dart';
import '../core/tasks/task_catalog.dart';
import '../models/nfc_task.dart';

class PlatformBridge {
  static const MethodChannel _ch = MethodChannel('com.songoku.nfctool/platform');

  static Future<Map<String, dynamic>> invoke(
    String method, [
    Map<String, dynamic>? args,
  ]) async {
    if (!Platform.isAndroid) {
      return {'ok': false, 'error': 'Android only'};
    }
    AppDebug.instance.platform('→ $method args=${args ?? {}}');
    try {
      final result = await _ch.invokeMethod<dynamic>(method, args ?? {});
      if (result is Map) {
        final map = Map<String, dynamic>.from(result);
        AppDebug.instance.platform('← $method ok=${map['ok']} keys=${map.keys.join(",")}');
        return map;
      }
      AppDebug.instance.platform('← $method result=$result');
      return {'ok': true, 'result': result};
    } on PlatformException catch (e) {
      AppDebug.instance.platform(
        '← $method PlatformException ${e.code}: ${e.message}',
        level: DebugLevel.error,
      );
      return {'ok': false, 'error': e.message ?? e.code};
    } catch (e) {
      AppDebug.instance.platform('← $method error: $e', level: DebugLevel.error);
      return {'ok': false, 'error': e.toString()};
    }
  }

  static Future<Uint8List?> pickBytes({String mime = '*/*'}) async {
    final res = await invoke('pickBytes', {'mime': mime});
    if (res['ok'] != true) return null;
    final b64 = res['base64']?.toString();
    if (b64 == null || b64.isEmpty) return null;
    return base64Decode(b64);
  }

  static Future<String?> saveBytes(Uint8List bytes, String filename) async {
    final res = await invoke('saveBytes', {
      'base64': base64Encode(bytes),
      'filename': filename,
    });
    if (res['ok'] != true) return res['error']?.toString();
    return res['uri']?.toString() ?? 'saved';
  }
}

class TaskRunner {
  static Future<String> run(NfcTask task, {bool confirmed = true}) async {
    final kind = TaskCatalog.byId(task.kind);
    if (kind == null) {
      AppDebug.instance.task('unknown kind=${task.kind}', level: DebugLevel.error);
      return 'Unknown task: ${task.kind}';
    }

    AppDebug.instance.task('run kind=${task.kind} confirmed=$confirmed');
    if (task.kind.startsWith('cond_')) {
      final pass = await _evalCondition(task);
      AppDebug.instance.task('cond ${task.kind} → $pass');
      return pass ? 'Condition passed' : 'Condition failed (skip)';
    }

    if (task.kind == 'dialog' && !confirmed) {
      return 'Waiting for confirmation';
    }

    if (task.kind == 'set_var' || task.kind == 'edit_var') {
      final key = task.params['key']?.toString() ?? '';
      final value = task.params['value']?.toString() ?? '';
      await StorageService.setTaskVar(key, value);
      return 'Variable $key set';
    }
    if (task.kind == 'del_var') {
      await StorageService.delTaskVar(task.params['key']?.toString() ?? '');
      return 'Variable deleted';
    }
    if (task.kind == 'run_profile') {
      final steps = (task.params['steps'] as List?) ?? [];
      final buf = StringBuffer();
      for (final step in steps) {
        if (step is Map) {
          final nested = NfcTask.fromJson(Map<String, dynamic>.from(step));
          buf.writeln(await run(nested));
        }
      }
      final out = buf.toString().trim();
      return out.isEmpty ? 'Profile empty' : out;
    }
    if (task.kind == 'roll_dice') {
      final sides = int.tryParse(task.params['sides']?.toString() ?? '6') ?? 6;
      final roll = 1 + (DateTime.now().microsecondsSinceEpoch % sides);
      return 'Rolled $roll (1..$sides)';
    }

    final openUrl = _urlForTask(task);
    if (openUrl != null) {
      final uri = Uri.parse(openUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return 'Opened $openUrl';
      }
      return 'Cannot open $openUrl';
    }

    // Pure-Dart enriched handlers
    switch (task.kind) {
      case 'folder_zip':
        return _zipFolder(task);
      case 'file_unzip':
        return _unzip(task);
      case 'folder_copy':
        return _copyDir(
          task.params['src']?.toString() ?? '',
          task.params['dst']?.toString() ?? '',
        );
      case 'folder_move':
        final src = task.params['src']?.toString() ?? '';
        final dst = task.params['dst']?.toString() ?? '';
        await Directory(src).rename(dst);
        return 'Folder moved';
      case 'download_file':
        return _download(task);
      case 'ping':
        return _ping(task.params['host']?.toString() ?? '');
      case 'wol':
        return _wakeOnLan(task.params['mac']?.toString() ?? '');
      case 'send_udp':
        return _udpSend(task);
      case 'twitter':
        final text = Uri.encodeComponent(task.params['text']?.toString() ?? '');
        final uri = Uri.parse('https://twitter.com/intent/tweet?text=$text');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return 'Opened share tweet';
      case 'clipboard':
      case 'keyboard':
        await Clipboard.setData(
          ClipboardData(text: task.params['text']?.toString() ?? ''),
        );
        return 'Copied to clipboard';
      case 'morse':
        return _morse(task.params['text']?.toString() ?? '');
    }

    if (task.kind.startsWith('file_') ||
        task.kind == 'write_file' ||
        task.kind == 'timestamp_file') {
      return _runFileTask(task);
    }

    if (task.kind == 'http_get' ||
        task.kind == 'http_post' ||
        task.kind == 'http_rest') {
      return _runHttp(task);
    }

    final res = await PlatformBridge.invoke('runTask', {
      'kind': task.kind,
      'params': task.params,
    });
    if (res['ok'] == true) {
      return res['message']?.toString() ?? 'OK';
    }
    return res['error']?.toString() ?? 'Task failed';
  }

  static String? _urlForTask(NfcTask task) {
    switch (task.kind) {
      case 'url_uri':
        return task.params['url']?.toString();
      case 'geocode':
        return 'geo:${task.params['latitude'] ?? '0'},${task.params['longitude'] ?? '0'}';
      case 'address':
        return 'https://maps.google.com/?q=${Uri.encodeComponent(task.params['address']?.toString() ?? '')}';
      case 'destination':
        return 'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(task.params['destination']?.toString() ?? '')}';
      case 'street_view':
        return task.params['url']?.toString() ??
            'https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=${task.params['latitude']},${task.params['longitude']}';
      case 'proximity_search':
        return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(task.params['query']?.toString() ?? '')}';
      case 'mail':
        final email = task.params['email'] ?? '';
        final subject =
            Uri.encodeComponent(task.params['subject']?.toString() ?? '');
        final body = Uri.encodeComponent(task.params['body']?.toString() ?? '');
        final cc = Uri.encodeComponent(task.params['cc']?.toString() ?? '');
        final bcc = Uri.encodeComponent(task.params['bcc']?.toString() ?? '');
        return 'mailto:$email?subject=$subject&body=$body&cc=$cc&bcc=$bcc';
      case 'phone_call':
        return 'tel:${task.params['phone'] ?? ''}';
      case 'send_sms':
        final phone = task.params['phone'] ?? '';
        final body = Uri.encodeComponent(task.params['body']?.toString() ?? '');
        return 'sms:$phone?body=$body';
      default:
        return null;
    }
  }

  static Future<bool> _evalCondition(NfcTask task) async {
    switch (task.kind) {
      case 'cond_time':
        final now = DateTime.now();
        final start =
            int.tryParse(task.params['startHour']?.toString() ?? '0') ?? 0;
        final end =
            int.tryParse(task.params['endHour']?.toString() ?? '23') ?? 23;
        return now.hour >= start && now.hour <= end;
      case 'cond_date':
        final day = int.tryParse(task.params['day']?.toString() ?? '');
        return day == null || DateTime.now().day == day;
      case 'cond_battery':
        final res = await PlatformBridge.invoke('batteryLevel');
        final level = int.tryParse(res['level']?.toString() ?? '100') ?? 100;
        final min = int.tryParse(task.params['min']?.toString() ?? '0') ?? 0;
        final max = int.tryParse(task.params['max']?.toString() ?? '100') ?? 100;
        return level >= min && level <= max;
      case 'cond_wifi':
        final res = await PlatformBridge.invoke('wifiEnabled');
        final want = task.params['enabled'] != false;
        return (res['enabled'] == true) == want;
      default:
        return true;
    }
  }

  static Future<String> _runFileTask(NfcTask task) async {
    try {
      final src = task.params['src']?.toString() ?? '';
      final dst = task.params['dst']?.toString() ?? '';
      switch (task.kind) {
        case 'file_copy':
          await File(src).copy(dst);
          return 'Copied file';
        case 'file_move':
          await File(src).rename(dst);
          return 'Moved file';
        case 'file_delete':
          await File(src).delete();
          return 'Deleted file';
        case 'folder_create':
          await Directory(dst.isEmpty ? src : dst).create(recursive: true);
          return 'Folder created';
        case 'folder_delete':
          await Directory(src).delete(recursive: true);
          return 'Folder deleted';
        case 'write_file':
          await File(dst.isEmpty ? src : dst)
              .writeAsString(task.params['content']?.toString() ?? '');
          return 'File written';
        case 'timestamp_file':
          final path = task.params['path']?.toString() ?? src;
          final f = File(path);
          final prev = await f.exists() ? await f.readAsString() : '';
          await f.writeAsString('$prev${DateTime.now().toIso8601String()}\n');
          return 'Timestamp appended';
        default:
          return 'Unhandled file task ${task.kind}';
      }
    } on FileSystemException catch (e) {
      return 'File error: ${e.message} (check path exists and readable)';
    }
  }

  static Future<String> _runHttp(NfcTask task) async {
    final url = task.params['url']?.toString() ?? '';
    if (url.isEmpty) return 'URL required';
    final client = HttpClient();
    try {
      final uri = Uri.parse(url);
      final HttpClientRequest req = task.kind == 'http_get'
          ? await client.getUrl(uri)
          : await client.postUrl(uri);
      if (task.kind != 'http_get') {
        final body = task.params['body']?.toString() ?? '';
        req.headers.contentType = ContentType.json;
        req.write(body);
      }
      final res = await req.close().timeout(const Duration(seconds: 20));
      final text = await res.transform(utf8.decoder).join();
      final saveKey = task.params['saveAs']?.toString();
      if (saveKey != null && saveKey.isNotEmpty) {
        await StorageService.setTaskVar(saveKey, text);
      }
      final preview = text.length > 200 ? '${text.substring(0, 200)}…' : text;
      return 'HTTP ${res.statusCode}: $preview';
    } catch (e) {
      return 'HTTP error: $e';
    } finally {
      client.close(force: true);
    }
  }

  static Future<String> _zipFolder(NfcTask task) async {
    final src = task.params['src']?.toString() ?? '';
    final dst = task.params['dst']?.toString() ?? '';
    if (src.isEmpty || dst.isEmpty) return 'src/dst required';
    final dir = Directory(src);
    if (!await dir.exists()) return 'Source folder missing';
    final archive = Archive();
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final bytes = await entity.readAsBytes();
        final rel = entity.path.substring(src.length).replaceFirst(RegExp(r'^/+'), '');
        archive.addFile(ArchiveFile(rel, bytes.length, bytes));
      }
    }
    final bytes = ZipEncoder().encodeBytes(archive);
    await File(dst).writeAsBytes(bytes, flush: true);
    return 'Zipped to $dst (${bytes.length} bytes)';
  }

  static Future<String> _unzip(NfcTask task) async {
    final src = task.params['src']?.toString() ?? '';
    final dst = task.params['dst']?.toString() ?? '';
    if (src.isEmpty || dst.isEmpty) return 'src/dst required';
    final bytes = await File(src).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      final outPath = '$dst/${file.name}';
      if (file.isFile) {
        final out = File(outPath);
        await out.parent.create(recursive: true);
        await out.writeAsBytes(file.content);
      } else {
        await Directory(outPath).create(recursive: true);
      }
    }
    return 'Unzipped to $dst';
  }

  static Future<String> _copyDir(String src, String dst) async {
    if (src.isEmpty || dst.isEmpty) return 'src/dst required';
    final source = Directory(src);
    if (!await source.exists()) return 'Source missing';
    await Directory(dst).create(recursive: true);
    await for (final entity in source.list(recursive: true)) {
      final rel = entity.path.substring(src.length);
      final target = '$dst$rel';
      if (entity is Directory) {
        await Directory(target).create(recursive: true);
      } else if (entity is File) {
        await File(target).parent.create(recursive: true);
        await entity.copy(target);
      }
    }
    return 'Folder copied';
  }

  static Future<String> _download(NfcTask task) async {
    final url = task.params['url']?.toString() ?? '';
    final dst = task.params['dst']?.toString() ?? '';
    if (url.isEmpty || dst.isEmpty) return 'url/dst required';
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close();
      final bytes = await consolidateHttpClientResponseBytes(res);
      await File(dst).writeAsBytes(bytes, flush: true);
      return 'Downloaded ${bytes.length} bytes → $dst';
    } catch (e) {
      return 'Download failed: $e';
    } finally {
      client.close(force: true);
    }
  }

  static Future<Uint8List> consolidateHttpClientResponseBytes(
    HttpClientResponse response,
  ) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  static Future<String> _ping(String host) async {
    if (host.isEmpty) return 'host required';
    try {
      final sw = Stopwatch()..start();
      final list = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 5));
      sw.stop();
      if (list.isEmpty) return 'No address for $host';
      return 'Resolved $host → ${list.first.address} in ${sw.elapsedMilliseconds}ms';
    } catch (e) {
      return 'Ping/lookup failed: $e';
    }
  }

  static Future<String> _wakeOnLan(String mac) async {
    final cleaned = mac.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (cleaned.length != 12) return 'MAC must be 6 bytes';
    final macBytes = Uint8List(6);
    for (var i = 0; i < 6; i++) {
      macBytes[i] = int.parse(cleaned.substring(i * 2, i * 2 + 2), radix: 16);
    }
    final packet = BytesBuilder();
    packet.add(List.filled(6, 0xFF));
    for (var i = 0; i < 16; i++) {
      packet.add(macBytes);
    }
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    socket.send(packet.toBytes(), InternetAddress('255.255.255.255'), 9);
    socket.close();
    return 'WoL magic packet sent to $mac';
  }

  static Future<String> _udpSend(NfcTask task) async {
    final host = task.params['host']?.toString() ?? '';
    final port = int.tryParse(task.params['port']?.toString() ?? '') ?? 0;
    final payload = task.params['payload']?.toString() ?? '';
    if (host.isEmpty || port == 0) return 'host/port required';
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final addrs = await InternetAddress.lookup(host);
    socket.send(utf8.encode(payload), addrs.first, port);
    socket.close();
    return 'UDP sent to $host:$port';
  }

  static Future<String> _morse(String text) async {
    // Delegate pattern timing to platform vibrate
    final res = await PlatformBridge.invoke('runTask', {
      'kind': 'morse',
      'params': {'text': text},
    });
    return res['ok'] == true
        ? (res['message']?.toString() ?? 'Morse done')
        : (res['error']?.toString() ?? 'Morse failed');
  }

  static Future<String> cacheBytesToTemp(Uint8List bytes, String name) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$name');
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }
}
