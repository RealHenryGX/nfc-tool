import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_tool/core/nfc/nfc_helper.dart';
import 'package:nfc_tool/core/nfc/record_catalog.dart';
import 'package:nfc_tool/core/tasks/task_catalog.dart';
import 'package:nfc_tool/models/ndef_record.dart';
import 'package:nfc_tool/models/nfc_task.dart';

void main() {
  group('RecordCatalog', () {
    test('contains Pro parity record kinds', () {
      final ids = RecordCatalog.all.map((e) => e.id).toSet();
      expect(ids.contains('address'), isTrue);
      expect(ids.contains('destination'), isTrue);
      expect(ids.contains('streetview'), isTrue);
      expect(ids.contains('proximity'), isTrue);
      expect(ids.contains('video'), isTrue);
      expect(ids.contains('emergency'), isTrue);
      expect(ids.contains('custom'), isTrue);
      expect(ids.contains('task'), isTrue);
      expect(ids.contains('bluetooth'), isTrue);
    });
  });

  group('TaskCatalog', () {
    test('has 80+ tasks', () {
      expect(TaskCatalog.all.length, greaterThanOrEqualTo(80));
    });
  });

  group('NfcHelper WiFi WSC', () {
    test('build and parse roundtrip', () {
      final bytes = NfcHelper.buildWifiWscPayload(
        ssid: 'TestNet',
        password: 'secret',
        encryption: 'WPA',
      );
      expect(bytes.length, greaterThan(10));
      final model = NdefRecordModel(
        type: 'wifi',
        payload: {
          'ssid': 'TestNet',
          'password': 'secret',
          'encryption': 'WPA',
        },
      );
      final ndef = NfcHelper.convertToNdefRecord(model);
      final back = NfcHelper.convertToModel(ndef);
      expect(back.type, 'wifi');
      expect(back.payload['ssid'], 'TestNet');
    });
  });

  group('URI builders', () {
    test('address / destination / search', () {
      final address = NfcHelper.convertToNdefRecord(
        NdefRecordModel(type: 'address', payload: {'address': 'Times Square'}),
      );
      final back = NfcHelper.convertToModel(address);
      expect(['address', 'uri', 'search', 'proximity'], contains(back.type));

      final dest = NfcHelper.convertToModel(
        NfcHelper.convertToNdefRecord(
          NdefRecordModel(
            type: 'destination',
            payload: {'destination': 'Paris'},
          ),
        ),
      );
      expect(dest.type, anyOf('destination', 'uri'));
    });

    test('bluetooth OOB mac roundtrip', () {
      final ndef = NfcHelper.convertToNdefRecord(
        NdefRecordModel(
          type: 'bluetooth',
          payload: {'mac': 'AA:BB:CC:DD:EE:FF'},
        ),
      );
      final back = NfcHelper.convertToModel(ndef);
      expect(back.type, 'bluetooth');
      expect(back.payload['mac'], 'AA:BB:CC:DD:EE:FF');
    });
  });

  group('Email cc/bcc', () {
    test('roundtrip mailto with cc/bcc', () {
      final ndef = NfcHelper.convertToNdefRecord(
        NdefRecordModel(
          type: 'email',
          payload: {
            'email': 'a@b.c',
            'subject': 'Hi',
            'body': 'Body',
            'cc': 'c@d.e',
            'bcc': 'x@y.z',
          },
        ),
      );
      final back = NfcHelper.convertToModel(ndef);
      expect(back.type, 'email');
      expect(back.payload['email'], 'a@b.c');
      expect(back.payload['cc'], 'c@d.e');
      expect(back.payload['bcc'], 'x@y.z');
    });
  });

  group('NfcTask', () {
    test('encode decode via ndef model', () {
      final task = NfcTask(
        id: '1',
        kind: 'wifi_state',
        params: {'enabled': true},
        label: 'WiFi',
      );
      final rec = task.toNdefRecord();
      final back = NfcTask.fromNdefRecord(rec);
      expect(back, isNotNull);
      expect(back!.kind, 'wifi_state');
    });
  });
}
