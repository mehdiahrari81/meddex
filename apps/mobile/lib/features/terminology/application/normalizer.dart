abstract final class MedicalTermNormalizer {
  static String normalize(String input) {
    var normalized = input.trim().toLowerCase();
    normalized = normalized
        .replaceAll(RegExp(r"[‐‑‒–—−]"), '-')
        .replaceAll(RegExp(r"[^a-z0-9\s-]"), ' ')
        .replaceAll(RegExp(r"\s+"), ' ')
        .trim();
    return normalized;
  }

  static String compact(String input) =>
      normalize(input).replaceAll(RegExp(r'[\s-]'), '');
}
