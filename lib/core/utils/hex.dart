/// Shared hex encoding for APDU / raw buffers / MAC display.
String bytesToHex(List<int> bytes, {String separator = ' '}) {
  return bytes
      .map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(separator);
}

/// Grouped hex (e.g. group=2 → `AABB CCDD`).
String bytesToHexGrouped(List<int> bytes, {int group = 1}) {
  final parts = bytes
      .map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase())
      .toList();
  if (group <= 1) return parts.join(' ');
  final grouped = <String>[];
  for (var i = 0; i < parts.length; i += group) {
    final end = (i + group).clamp(0, parts.length);
    grouped.add(parts.sublist(i, end).join());
  }
  return grouped.join(' ');
}
