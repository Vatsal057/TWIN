/// Canonical form used to decide whether two words converged.
///
/// This is the entire scoring rule of the game, so it lives in one place: both
/// clients normalize identically and therefore always agree on a match.
String normalizeWord(String raw) {
  final lowered = raw.toLowerCase().trim();
  final collapsed = lowered.replaceAll(RegExp(r'\s+'), ' ');
  return collapsed;
}

/// Strips anything that is not a letter, digit, apostrophe, hyphen or space.
String sanitizeWordInput(String raw) {
  return raw.replaceAll(RegExp(r"[^A-Za-z0-9'\- ]"), '');
}

bool wordsMatch(String a, String b) => normalizeWord(a) == normalizeWord(b);

/// Presentation helper: "Sunlight" rather than "sunlight".
String titleCaseWord(String raw) {
  final w = normalizeWord(raw);
  if (w.isEmpty) return w;
  return w
      .split(' ')
      .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
}
