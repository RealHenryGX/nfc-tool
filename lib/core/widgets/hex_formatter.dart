import 'package:flutter/services.dart';

/// Uppercases hex digits and auto-inserts spaces every 2 nibbles: `FF AA 01`.
class HexInputFormatter extends TextInputFormatter {
  final int? maxBytes;

  HexInputFormatter({this.maxBytes});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
    var limited = raw;
    if (maxBytes != null && limited.length > maxBytes! * 2) {
      limited = limited.substring(0, maxBytes! * 2);
    }

    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i > 0 && i.isEven) buffer.write(' ');
      buffer.write(limited[i]);
    }
    final formatted = buffer.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Parse spaced hex into bytes.
  static List<int> parse(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (cleaned.isEmpty || cleaned.length.isOdd) {
      throw FormatException('Hex length must be even');
    }
    final out = <int>[];
    for (var i = 0; i < cleaned.length; i += 2) {
      out.add(int.parse(cleaned.substring(i, i + 2), radix: 16));
    }
    return out;
  }
}
