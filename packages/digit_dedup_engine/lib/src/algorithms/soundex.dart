import '../../utils/string_utils.dart';

/// Soundex phonetic algorithm implementation.
///
/// Converts a name into a 4-character phonetic code where
/// similar-sounding names produce the same code.
/// Example: "Mahamat" and "Muhammad" both produce "M530".
class Soundex {
  Soundex._();

  static final RegExp _nonLetters = RegExp(r'[^a-z]');

  /// Consonant groups. Vowels plus 'h', 'w' and 'y' are absent on purpose:
  /// they carry no code of their own.
  static const Map<String, String> _codes = {
    'b': '1',
    'f': '1',
    'p': '1',
    'v': '1',
    'c': '2',
    'g': '2',
    'j': '2',
    'k': '2',
    'q': '2',
    's': '2',
    'x': '2',
    'z': '2',
    'd': '3',
    't': '3',
    'l': '4',
    'm': '5',
    'n': '5',
    'r': '6',
  };

  /// Compute the Soundex code for a given string.
  /// Returns a 4-character code (letter + 3 digits), or an empty string when
  /// [input] holds no letters to encode.
  static String encode(String input) {
    final letters =
        StringUtils.normalizeName(input).replaceAll(_nonLetters, '');
    if (letters.isEmpty) return '';

    final code = StringBuffer(letters[0].toUpperCase());

    // Adjacent letters sharing a code collapse into one digit. 'h' and 'w' are
    // transparent -- they do not break up such a run -- while vowels and 'y'
    // do, which is why they reset [previousCode] to null.
    String? previousCode = _codes[letters[0]];

    for (var i = 1; i < letters.length && code.length < 4; i++) {
      final char = letters[i];
      final charCode = _codes[char];

      if (charCode == null) {
        if (char != 'h' && char != 'w') previousCode = null;
        continue;
      }

      if (charCode != previousCode) code.write(charCode);
      previousCode = charCode;
    }

    return code.toString().padRight(4, '0');
  }
}
