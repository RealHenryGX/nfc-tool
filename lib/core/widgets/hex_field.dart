import 'package:flutter/material.dart';

import 'app_ui.dart';
import 'hex_formatter.dart';

/// Hex TextField with automatic `FF AA` spacing and optional byte limit.
///
/// Uses [AppLabeledField] so labels never collide with values on dense forms.
class HexField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int? maxBytes;
  final bool enabled;

  const HexField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.maxBytes,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppLabeledField(
      label: label,
      padding: EdgeInsets.zero,
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.visiblePassword,
        textCapitalization: TextCapitalization.characters,
        autocorrect: false,
        enableSuggestions: false,
        style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1.1),
        inputFormatters: [HexInputFormatter(maxBytes: maxBytes)],
        decoration: InputDecoration(
          hintText: hint ??
              (maxBytes != null
                  ? List.filled(maxBytes!.clamp(1, 4), 'FF').join(' ')
                  : null),
        ),
      ),
    );
  }
}
