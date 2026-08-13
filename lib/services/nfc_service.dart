import 'dart:typed_data';

import 'package:flutter_nfc_kit/flutter_nfc_kit.dart' as kit;
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

import '../core/debug/app_debug.dart';
import '../core/nfc/nfc_errors.dart';
import '../core/nfc/nfc_helper.dart';
import '../core/nfc/nfc_port.dart';
import '../core/utils/hex.dart';
import '../models/ndef_record.dart';
import '../models/nfc_tag_details.dart';

export '../models/nfc_tag_details.dart';

/// NDEF / Classic session use-cases on top of [NfcPort].
class NfcService {
  static Future<bool> isAvailable() => NfcPort.isManagerAvailable();

  static Future<bool> _ensureAvailable(Function(String error) onError) async {
    if (await isAvailable()) return true;
    AppDebug.instance.nfc('NFC unavailable', level: DebugLevel.error);
    onError('NFC not available or disabled');
    return false;
  }

  static Set<NfcPollingOption> get _polling => {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
        NfcPollingOption.iso18092,
      };

  static NfcTagDetails parseTag(NfcTag tag) {
    final techList = <String>[];
    Uint8List? idBytes;
    String? tagType;

    final atag = NfcTagAndroid.from(tag);
    if (atag != null) {
      idBytes = atag.id;
      techList.addAll(atag.techList);
    }

    if (techList.contains('android.nfc.tech.MifareClassic') ||
        techList.any((t) => t.contains('MifareClassic'))) {
      tagType = 'MIFARE Classic';
    } else if (techList.contains('android.nfc.tech.MifareUltralight') ||
        techList.any((t) => t.contains('MifareUltralight'))) {
      tagType = 'MIFARE Ultralight';
    } else if (techList.any((t) => t.contains('IsoDep'))) {
      tagType = 'ISO-DEP (Type 4)';
    } else if (techList.any((t) => t.contains('NfcA'))) {
      tagType = 'NFC-A (Type 2)';
    } else if (techList.any((t) => t.contains('NfcB'))) {
      tagType = 'NFC-B';
    } else if (techList.any((t) => t.contains('NfcF'))) {
      tagType = 'NFC-F (FeliCa)';
    } else if (techList.any((t) => t.contains('NfcV'))) {
      tagType = 'NFC-V (Vicinity)';
    } else {
      tagType = 'Unknown Tag';
    }

    final ndef = NdefAndroid.from(tag);
    final isNdefSupported = ndef != null;
    final isWritable = ndef?.isWritable;
    final maxSize = ndef?.maxSize;
    final records = <NdefRecordModel>[];

    if (ndef?.cachedNdefMessage != null) {
      for (final rec in ndef!.cachedNdefMessage!.records) {
        records.add(NfcHelper.convertToModel(rec));
      }
    }

    final uid = idBytes != null && idBytes.isNotEmpty
        ? bytesToHex(idBytes, separator: ':')
        : null;

    return NfcTagDetails(
      uid: uid,
      technologies: techList,
      isNdefSupported: isNdefSupported,
      isWritable: isWritable,
      maxSize: maxSize,
      records: records,
      type: tagType,
    );
  }

  static Future<void> startReadSession({
    required Function(NfcTagDetails tagDetails) onDiscovered,
    required Function(String error) onError,
  }) async {
    try {
      if (!await _ensureAvailable(onError)) return;
      await NfcPort.prepareManagerPath();

      AppDebug.instance.nfc('session start mode=read');
      await NfcManager.instance.startSession(
        pollingOptions: _polling,
        onDiscovered: (tag) async {
          try {
            final details = parseTag(tag);
            AppDebug.instance.nfc(
              'read uid=${details.uid} type=${details.type} '
              'tech=${details.technologies.join(",")} '
              'ndef=${details.isNdefSupported} records=${details.records.length} '
              'max=${details.maxSize}',
            );
            for (var i = 0; i < details.records.length; i++) {
              final r = details.records[i];
              AppDebug.instance.nfc(
                'record[$i] type=${r.type} payloadKeys=${r.payload.keys.join(",")}',
              );
            }
            onDiscovered(details);
          } catch (e) {
            AppDebug.instance.nfc('parse error: $e', level: DebugLevel.error);
            onError('Parse error: $e');
          } finally {
            await stopSession();
          }
        },
      );
    } catch (e) {
      AppDebug.instance.nfc('read start failed: $e', level: DebugLevel.error);
      onError('Start session failed: $e');
    }
  }

  static Future<void> startWriteSession({
    required List<NdefRecordModel> records,
    required Function(String successMessage) onComplete,
    required Function(String error) onError,
  }) async {
    try {
      if (!await _ensureAvailable(onError)) return;
      await NfcPort.prepareManagerPath();

      AppDebug.instance.nfc('session start mode=write records=${records.length}');
      await NfcManager.instance.startSession(
        pollingOptions: _polling,
        onDiscovered: (tag) async {
          try {
            // Write immediately — any delay risks "Tag is out of date"
            // SecurityException after RF reconnect on Samsung/Android 14+.
            await _writeRecordsToTag(tag, records);
            final uid = parseTag(tag).uid;
            AppDebug.instance.nfc('write OK uid=$uid');
            onComplete('Tag written successfully');
          } catch (e) {
            AppDebug.instance.nfc('write failed: $e', level: DebugLevel.error);
            onError(mapNfcWriteException(e, verb: 'Write'));
          } finally {
            await stopSession();
          }
        },
      );
    } catch (e) {
      AppDebug.instance.nfc('write start failed: $e', level: DebugLevel.error);
      onError('Start session failed: $e');
    }
  }

  /// Wipe NDEF content by writing a TNF_EMPTY record (NFC Tools "Erase").
  static Future<void> startEraseSession({
    required Function(String successMessage) onComplete,
    required Function(String error) onError,
  }) async {
    try {
      if (!await _ensureAvailable(onError)) return;
      await NfcPort.prepareManagerPath();

      AppDebug.instance.nfc('session start mode=erase');
      await NfcManager.instance.startSession(
        pollingOptions: _polling,
        onDiscovered: (tag) async {
          try {
            await _writeEmptyNdef(tag);
            AppDebug.instance.nfc('erase OK');
            onComplete('Tag erased successfully');
          } catch (e) {
            AppDebug.instance.nfc('erase failed: $e', level: DebugLevel.error);
            onError(mapNfcWriteException(e, verb: 'Erase'));
          } finally {
            await stopSession();
          }
        },
      );
    } catch (e) {
      onError('Start session failed: $e');
    }
  }

  static Future<void> startBatchWriteSession({
    required List<NdefRecordModel> records,
    required Function(String uid) onTagWritten,
    required Function(String error) onError,
    bool Function()? shouldContinue,
  }) async {
    try {
      if (!await _ensureAvailable(onError)) return;
      await NfcPort.prepareManagerPath();

      AppDebug.instance.nfc('session start mode=batch records=${records.length}');
      await NfcManager.instance.startSession(
        pollingOptions: _polling,
        onDiscovered: (tag) async {
          try {
            await _writeRecordsToTag(tag, records);
            final details = parseTag(tag);
            AppDebug.instance.nfc('batch write OK uid=${details.uid}');
            onTagWritten(details.uid ?? 'Unknown UID');
            await stopSession();
            if (shouldContinue == null || shouldContinue()) {
              await Future.delayed(const Duration(milliseconds: 600));
              if (shouldContinue == null || shouldContinue()) {
                await startBatchWriteSession(
                  records: records,
                  onTagWritten: onTagWritten,
                  onError: onError,
                  shouldContinue: shouldContinue,
                );
              }
            }
          } catch (e) {
            AppDebug.instance.nfc('batch write failed: $e', level: DebugLevel.error);
            onError(mapNfcWriteException(e, verb: 'Write'));
            await stopSession();
          }
        },
      );
    } catch (e) {
      onError('Start session failed: $e');
    }
  }

  static Future<void> stopSession() async {
    try {
      await NfcManager.instance.stopSession();
      AppDebug.instance.nfc('session stop');
    } catch (_) {}
  }

  static Future<void> makeReadOnly({
    required Function(String successMessage) onComplete,
    required Function(String error) onError,
  }) async {
    try {
      if (!await _ensureAvailable(onError)) return;
      await NfcPort.prepareManagerPath();
      await NfcManager.instance.startSession(
        pollingOptions: _polling,
        onDiscovered: (tag) async {
          try {
            final ndef = NdefAndroid.from(tag);
            if (ndef == null) {
              onError('Tag does not support NDEF');
              return;
            }
            await ndef.makeReadOnly();
            AppDebug.instance.nfc('lock OK (read-only)');
            onComplete('Tag locked to read-only successfully');
          } catch (e) {
            AppDebug.instance.nfc('lock failed: $e', level: DebugLevel.error);
            onError('Lock failed: $e');
          } finally {
            await stopSession();
          }
        },
      );
    } catch (e) {
      onError('Start session failed: $e');
    }
  }

  static Future<void> formatTag({
    required Function(String successMessage) onComplete,
    required Function(String error) onError,
  }) async {
    try {
      if (!await _ensureAvailable(onError)) return;
      await NfcPort.prepareManagerPath();
      AppDebug.instance.nfc('session start mode=format');
      await NfcManager.instance.startSession(
        pollingOptions: _polling,
        onDiscovered: (tag) async {
          try {
            final ndefFormatable = NdefFormatableAndroid.from(tag);
            if (ndefFormatable == null) {
              onError('Tag is not NDEF formatable');
              return;
            }
            await ndefFormatable.format(
              NdefMessage(records: [_emptyNdefRecord]),
            );
            AppDebug.instance.nfc('format OK');
            onComplete('Tag formatted successfully');
          } catch (e) {
            AppDebug.instance.nfc('format failed: $e', level: DebugLevel.error);
            onError('Format failed: $e');
          } finally {
            await stopSession();
          }
        },
      );
    } catch (e) {
      onError('Start session failed: $e');
    }
  }

  /// Single TNF_EMPTY record — Android rejects zero-record NdefMessages.
  static final NdefRecord _emptyNdefRecord = NdefRecord(
    typeNameFormat: TypeNameFormat.empty,
    type: Uint8List(0),
    identifier: Uint8List(0),
    payload: Uint8List(0),
  );

  static Future<void> _writeEmptyNdef(NfcTag tag) async {
    final ndef = NdefAndroid.from(tag);
    if (ndef == null) {
      throw Exception('Tag does not support NDEF');
    }
    if (!ndef.isWritable) {
      throw Exception('Tag is read-only');
    }
    AppDebug.instance.nfc('writeNdef erase (TNF_EMPTY) maxSize=${ndef.maxSize}');
    await ndef.writeNdefMessage(NdefMessage(records: [_emptyNdefRecord]));
  }

  static Future<void> _writeRecordsToTag(
    NfcTag tag,
    List<NdefRecordModel> records,
  ) async {
    if (records.isEmpty) {
      await _writeEmptyNdef(tag);
      return;
    }
    final ndef = NdefAndroid.from(tag);
    if (ndef == null) {
      throw Exception('Tag does not support NDEF');
    }
    if (!ndef.isWritable) {
      throw Exception('Tag is read-only');
    }
    final ndefRecords =
        records.map((r) => NfcHelper.convertToNdefRecord(r)).toList();
    AppDebug.instance.nfc(
      'writeNdef count=${ndefRecords.length} maxSize=${ndef.maxSize}',
    );
    await ndef.writeNdefMessage(NdefMessage(records: ndefRecords));
  }

  /// Kit path — releases any manager session first ([NfcPort.prepareKitPath]).
  static Future<String> readRawHex({
    required Function(String update) onUpdate,
    required Function(String error) onError,
  }) async {
    try {
      await NfcPort.prepareKitPath();
      AppDebug.instance.nfc('raw hex poll…');
      final tag = await kit.FlutterNfcKit.poll(
        timeout: const Duration(seconds: 15),
        androidPlatformSound: true,
      );

      onUpdate('Tag discovered: ${tag.type}');
      AppDebug.instance.nfc(
        'raw uid=${tag.id} type=${tag.type} atqa=${tag.atqa} sak=${tag.sak}',
      );

      final lines = <String>[
        'Type: ${tag.type}',
        'UID: ${tag.id}',
        'Standard: ${tag.standard}',
        'ATQA: ${tag.atqa}',
        'SAK: ${tag.sak}',
      ];

      if (tag.ndefAvailable ?? false) {
        final records = await kit.FlutterNfcKit.readNDEFRecords();
        lines.add('NDEF records: ${records.length}');
        for (var i = 0; i < records.length; i++) {
          final e = records[i];
          final payload = e.payload ?? '';
          lines.add('[$i] TNF=${e.tnf} type=${e.type} payload=$payload');
        }
      } else {
        lines.add('No NDEF payload found.');
      }

      await kit.FlutterNfcKit.finish();
      return lines.join('\n');
    } catch (e) {
      AppDebug.instance.nfc('raw hex error: $e', level: DebugLevel.error);
      onError(e.toString());
      try {
        await kit.FlutterNfcKit.finish();
      } catch (_) {}
      return 'Error: $e';
    }
  }
}
