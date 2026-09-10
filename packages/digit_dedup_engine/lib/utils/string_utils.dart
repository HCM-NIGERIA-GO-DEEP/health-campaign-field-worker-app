/// String utility functions for name preprocessing before matching.
class StringUtils {
  StringUtils._();

  /// Latin-1 Supplement and Latin Extended-A characters mapped to the ASCII
  /// letter they decompose to. Covers the accented forms that show up in
  /// transliterated West African names.
  static const Map<String, String> _diacriticals = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'ā': 'a',
    'ă': 'a',
    'ą': 'a',
    'ç': 'c',
    'ć': 'c',
    'ĉ': 'c',
    'ċ': 'c',
    'č': 'c',
    'ď': 'd',
    'đ': 'd',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ē': 'e',
    'ĕ': 'e',
    'ė': 'e',
    'ę': 'e',
    'ě': 'e',
    'ĝ': 'g',
    'ğ': 'g',
    'ġ': 'g',
    'ģ': 'g',
    'ĥ': 'h',
    'ħ': 'h',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ĩ': 'i',
    'ī': 'i',
    'ĭ': 'i',
    'į': 'i',
    'ı': 'i',
    'ĵ': 'j',
    'ķ': 'k',
    'ĺ': 'l',
    'ļ': 'l',
    'ľ': 'l',
    'ł': 'l',
    'ñ': 'n',
    'ń': 'n',
    'ņ': 'n',
    'ň': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ø': 'o',
    'ō': 'o',
    'ŏ': 'o',
    'ő': 'o',
    'ŕ': 'r',
    'ŗ': 'r',
    'ř': 'r',
    'ś': 's',
    'ŝ': 's',
    'ş': 's',
    'š': 's',
    'ţ': 't',
    'ť': 't',
    'ŧ': 't',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ũ': 'u',
    'ū': 'u',
    'ŭ': 'u',
    'ů': 'u',
    'ű': 'u',
    'ų': 'u',
    'ŵ': 'w',
    'ý': 'y',
    'ÿ': 'y',
    'ŷ': 'y',
    'ź': 'z',
    'ż': 'z',
    'ž': 'z',
    'æ': 'ae',
    'œ': 'oe',
    'ß': 'ss',
    'ð': 'd',
    'þ': 'th',
  };

  static final RegExp _whitespace = RegExp(r'\s+');

  /// Anything outside the letters, apostrophes and hyphens that make up a
  /// name. Replaced with a space rather than dropped so that "Peter/John"
  /// becomes two tokens instead of one.
  static final RegExp _nonNameChars = RegExp(r"[^a-z' -]");

  /// Affixes that carry no identifying information on their own. Matched
  /// against the start of each token of an already normalized name.
  static const List<String> _prefixes = [
    'al-',
    'el-',
    'ad-',
    'as-',
    'at-',
    'az-',
    "m'",
    "n'",
    "d'",
    "o'",
    "l'",
  ];

  /// Standalone words that are grammatical connectors rather than name parts.
  static const List<String> _connectorWords = [
    'bin',
    'ben',
    'ibn',
    'abu',
    'abd',
    'bint',
  ];

  /// Normalize a name for comparison:
  /// - Lowercase
  /// - Remove diacriticals (e.g., e with accent -> e)
  /// - Trim whitespace
  /// - Collapse multiple spaces
  static String normalizeName(String name) {
    final lowered = name.toLowerCase().trim();

    final unaccented = StringBuffer();
    for (final rune in lowered.runes) {
      final char = String.fromCharCode(rune);
      unaccented.write(_diacriticals[char] ?? char);
    }

    return unaccented
        .toString()
        .replaceAll(_nonNameChars, ' ')
        .replaceAll(_whitespace, ' ')
        .trim();
  }

  static final RegExp _separators = RegExp(r"[-']");

  /// Collapse the hyphens and apostrophes that separate an affix from the rest
  /// of a name, so "Al-Mustapha" and "Almustapha" converge.
  static String removeSeparators(String name) =>
      name.replaceAll(_separators, '');

  /// The forms a name should be compared through, best match winning.
  ///
  /// Two forms are needed because the two spelling variations pull in opposite
  /// directions: "Al-Mustapha" vs "Almustapha" only agree once the separator
  /// is gone, while "Al-Hassan" vs "Hassan" only agree once the affix is gone.
  /// Comparing through both means neither variation is penalised -- crucially,
  /// [removeAffixes] alone makes the first pair *less* similar than no
  /// normalization at all, because it strips only the separated spelling.
  ///
  /// Expects an already [normalizeName]d input.
  static List<String> comparisonForms(String normalized) {
    final separatorFree = removeSeparators(normalized);
    final affixStripped = removeSeparators(removeAffixes(normalized));

    return affixStripped == separatorFree
        ? [separatorFree]
        : [separatorFree, affixStripped];
  }

  /// Remove common prefixes/suffixes that don't affect identity
  /// (e.g., "Al-", "El-", "M'" in African/Arabic names)
  ///
  /// Expects an already [normalizeName]d input. A prefix is only stripped when
  /// at least two characters remain, so short names survive intact. Returns
  /// the input unchanged if stripping would leave nothing behind.
  static String removeAffixes(String name) {
    final tokens = name.split(' ').where((t) => t.isNotEmpty);
    final stripped = <String>[];

    for (final token in tokens) {
      if (_connectorWords.contains(token)) continue;

      var current = token;
      // A token can carry stacked affixes, e.g. "al-m'bala".
      var changed = true;
      while (changed) {
        changed = false;
        for (final prefix in _prefixes) {
          if (current.length > prefix.length + 1 &&
              current.startsWith(prefix)) {
            current = current.substring(prefix.length);
            changed = true;
            break;
          }
        }
      }
      stripped.add(current);
    }

    final result = stripped.join(' ');
    return result.isEmpty ? name : result;
  }
}
