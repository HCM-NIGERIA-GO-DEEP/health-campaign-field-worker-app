import 'dart:math';

/// Levenshtein edit distance algorithm.
///
/// Computes the minimum number of single-character edits
/// (insertions, deletions, substitutions) required to transform
/// one string into another.
class Levenshtein {
  Levenshtein._();

  /// Compute the Levenshtein edit distance between two strings.
  static int distance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    // Two-row dynamic programming: only the previous row is ever read, so the
    // full matrix never has to be held in memory.
    var previousRow = List<int>.generate(s2.length + 1, (i) => i);
    var currentRow = List<int>.filled(s2.length + 1, 0);

    for (var i = 0; i < s1.length; i++) {
      currentRow[0] = i + 1;

      for (var j = 0; j < s2.length; j++) {
        final substitutionCost = s1[i] == s2[j] ? 0 : 1;
        currentRow[j + 1] = min(
          min(
            currentRow[j] + 1, // insertion
            previousRow[j + 1] + 1, // deletion
          ),
          previousRow[j] + substitutionCost, // substitution
        );
      }

      final swap = previousRow;
      previousRow = currentRow;
      currentRow = swap;
    }

    return previousRow[s2.length];
  }

  /// Compute normalized similarity (0.0 to 1.0) from edit distance.
  static double similarity(String s1, String s2) {
    if (s1.isEmpty && s2.isEmpty) return 1.0;
    final longest = max(s1.length, s2.length);
    if (longest == 0) return 1.0;
    return 1.0 - (distance(s1, s2) / longest);
  }
}
