/// Shared NFC / batch error strings for UI surfaces.
String friendlyNfcError(String err) {
  final lower = err.toLowerCase();
  if (lower.contains('out of date') || lower.contains('securityexception')) {
    return 'Tag moved or RF dropped mid-write. Hold still and retry.';
  }
  if (lower.contains('ioexception') || lower.contains('tag was lost')) {
    return 'Hold the tag steady against the phone for 2–3 seconds '
        '(or the tag may be locked / full).';
  }
  if (lower.contains('read-only') || lower.contains('not writable')) {
    return 'Tag is read-only / locked. Cannot write.';
  }
  if (lower.contains('does not support ndef')) {
    return 'Tag does not support NDEF.';
  }
  if (lower.contains('nfc not available') || lower.contains('unavailable')) {
    return 'NFC is off or unavailable. Enable NFC in Settings.';
  }
  final firstLine = err.split('\n').first.trim();
  if (firstLine.length > 160) return '${firstLine.substring(0, 157)}…';
  return firstLine;
}

/// Service-layer write/erase failure message (slightly more actionable).
String mapNfcWriteException(Object e, {required String verb}) {
  final msg = e.toString().toLowerCase();
  if (msg.contains('out of date') || msg.contains('securityexception')) {
    return '$verb interrupted — keep the tag still against the phone and try again.';
  }
  if (msg.contains('ioexception')) {
    return '$verb failed (IOException). Hold tag steady, ensure it is '
        'writable / not locked, then retry.';
  }
  return '$verb failed: $e';
}
