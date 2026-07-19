import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_tool/core/widgets/hex_formatter.dart';

void main() {
  test('HexInputFormatter spaces pairs and uppercases', () {
    final f = HexInputFormatter();
    final result = f.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: 'ffa01',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );
    expect(result.text, 'FF A0 1');
  });

  test('HexInputFormatter respects maxBytes', () {
    final f = HexInputFormatter(maxBytes: 2);
    final result = f.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: 'aabbcc',
        selection: TextSelection.collapsed(offset: 6),
      ),
    );
    expect(result.text, 'AA BB');
  });

  test('HexInputFormatter.parse roundtrip', () {
    expect(HexInputFormatter.parse('FF AA 01'), [0xFF, 0xAA, 0x01]);
  });
}
