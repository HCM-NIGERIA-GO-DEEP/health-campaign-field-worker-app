import 'dart:math';

/// Jaro-Winkler string similarity algorithm.
///
/// Measures similarity between two strings with a bias towards
/// strings that share a common prefix. Returns a value between
/// 0.0 (no similarity) and 1.0 (identical strings).
///
/// Particularly effective for name matching where typos tend
/// to occur in the middle/end of names rather than the beginning.
class JaroWinkler {
  JaroWinkler._();

  /// The Winkler prefix bonus considers at most this many leading characters.
  static const int _maxPrefixLength = 4;

  /// Compute Jaro similarity between two strings.
  /// Returns a value between 0.0 and 1.0.
  static double jaroSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final len1 = s1.length;
    final len2 = s2.length;

    // Characters only count as matching if they fall within this many
    // positions of each other.
    final matchWindow = max(0, (max(len1, len2) ~/ 2) - 1);

    final s1Matched = List<bool>.filled(len1, false);
    final s2Matched = List<bool>.filled(len2, false);

    var matches = 0;
    for (var i = 0; i < len1; i++) {
      final start = max(0, i - matchWindow);
      final end = min(i + matchWindow + 1, len2);

      for (var j = start; j < end; j++) {
        if (s2Matched[j] || s1[i] != s2[j]) continue;
        s1Matched[i] = true;
        s2Matched[j] = true;
        matches++;
        break;
      }
    }

    if (matches == 0) return 0.0;

    // Walk both match sequences in step; a mismatch is half a transposition.
    var halfTranspositions = 0;
    var k = 0;
    for (var i = 0; i < len1; i++) {
      if (!s1Matched[i]) continue;
      while (!s2Matched[k]) {
        k++;
      }
      if (s1[i] != s2[k]) halfTranspositions++;
      k++;
    }
    final transpositions = halfTranspositions ~/ 2;

    return (matches / len1 +
            matches / len2 +
            (matches - transpositions) / matches) /
        3.0;
  }

  /// Compute Jaro-Winkler similarity (Jaro + prefix bonus).
  /// Returns a value between 0.0 and 1.0.
  static double similarity(String s1, String s2, {double prefixScale = 0.1}) {
    final jaro = jaroSimilarity(s1, s2);
    if (jaro == 0.0) return 0.0;

    var prefixLength = 0;
    final limit = min(_maxPrefixLength, min(s1.length, s2.length));
    while (prefixLength < limit && s1[prefixLength] == s2[prefixLength]) {
      prefixLength++;
    }

    final winkler = jaro + (prefixLength * prefixScale * (1 - jaro));
    return winkler > 1.0 ? 1.0 : winkler;
  }
}
