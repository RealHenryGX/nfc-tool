import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_tool/services/qr_service.dart';

void main() {
  test('QR Service parses Wi-Fi string correctly', () {
    const wifiStr = 'WIFI:S:MyHomeWifi;T:WPA;P:SecretPassword123;;';
    final record = QrService.parseQrString(wifiStr);
    expect(record.type, equals('wifi'));
    expect(record.payload['ssid'], equals('MyHomeWifi'));
    expect(record.payload['password'], equals('SecretPassword123'));
  });

  test('QR Service parses URL string correctly', () {
    const urlStr = 'https://github.com/google';
    final record = QrService.parseQrString(urlStr);
    expect(record.type, equals('uri'));
    expect(record.payload['uri'], equals('https://github.com/google'));
  });
}
