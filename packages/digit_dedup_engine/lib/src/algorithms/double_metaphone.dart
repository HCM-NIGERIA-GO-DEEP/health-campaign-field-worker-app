import '../../utils/string_utils.dart';

/// Double Metaphone phonetic algorithm implementation.
///
/// More sophisticated than Soundex - handles international names better.
/// Returns two codes (primary and alternate) to handle names that
/// can be pronounced multiple ways.
///
/// Where Soundex keys off the first letter and collapses everything after it
/// into consonant groups, Double Metaphone models pronunciation: it recognises
/// silent letters, digraphs such as `CH`/`SCH`/`GN`, and language-specific
/// readings, then emits a second code when a spelling is genuinely ambiguous.
/// "Schmidt" reads as `XMT` in German and `SMT` in English, and both are
/// returned so either can match.
///
/// Codes are capped at four characters, as in Lawrence Philips' original.
class DoubleMetaphone {
  DoubleMetaphone._();

  static const int _maxLength = 4;
  static final RegExp _nonLetters = RegExp(r'[^A-Z]');

  /// Compute the Double Metaphone codes for a given string.
  /// Returns a tuple of (primary, alternate) phonetic codes.
  ///
  /// The two codes are equal when the spelling has only one plausible reading.
  /// An input with no letters yields two empty strings.
  static (String primary, String alternate) encode(String input) {
    final word = StringUtils.normalizeName(input)
        .toUpperCase()
        .replaceAll(_nonLetters, '');
    if (word.isEmpty) return ('', '');

    final encoder = _Encoder(word);
    encoder.run();
    return (encoder.primary, encoder.alternate);
  }
}

/// Mutable state for one encoding pass.
///
/// Kept separate from the public entry point so the rule methods can share the
/// cursor and the two output buffers without threading them through every
/// call.
class _Encoder {
  _Encoder(this.word) : _length = word.length;

  final String word;
  final int _length;

  final StringBuffer _primary = StringBuffer();
  final StringBuffer _alternate = StringBuffer();

  int _index = 0;

  String get primary => _truncate(_primary.toString());
  String get alternate => _truncate(_alternate.toString());

  static String _truncate(String code) =>
      code.length > DoubleMetaphone._maxLength
          ? code.substring(0, DoubleMetaphone._maxLength)
          : code;

  bool get _complete =>
      _primary.length >= DoubleMetaphone._maxLength &&
      _alternate.length >= DoubleMetaphone._maxLength;

  /// Character at [offset] from the start, or '' when out of range.
  String _at(int offset) =>
      (offset < 0 || offset >= _length) ? '' : word[offset];

  /// Substring of [count] characters from [start], clamped to the word.
  String _slice(int start, int count) {
    if (start < 0 || start >= _length) return '';
    final end = (start + count).clamp(0, _length);
    return word.substring(start, end);
  }

  /// Whether the slice at [start] of [count] characters is one of [options].
  bool _matches(int start, int count, List<String> options) =>
      options.contains(_slice(start, count));

  void _add(String value, [String? alternateValue]) {
    _primary.write(value);
    _alternate.write(alternateValue ?? value);
  }

  static const _vowels = {'A', 'E', 'I', 'O', 'U', 'Y'};

  bool _isVowel(int offset) => _vowels.contains(_at(offset));

  /// Whether the word is Slavic/Germanic enough that `W` and `J` keep a hard
  /// reading, e.g. "Wilkowski".
  bool get _slavoGermanic =>
      word.contains('W') ||
      word.contains('K') ||
      word.contains('CZ') ||
      word.contains('WITZ');

  void run() {
    _skipSilentStart();
    // An initial vowel is always 'A', whichever vowel it is.
    if (_vowels.contains(_at(0)) && _index == 0) {
      _add('A');
      _index = 1;
    }

    while (!_complete && _index < _length) {
      _step();
    }
  }

  /// Initial letter groups whose first letter is not pronounced.
  void _skipSilentStart() {
    if (_matches(0, 2, ['GN', 'KN', 'PN', 'WR', 'AE'])) {
      _index = 1;
    } else if (_at(0) == 'X') {
      // "Xavier" reads as an S.
      _add('S');
      _index = 1;
    }
  }

  void _step() {
    final current = _at(_index);

    switch (current) {
      case 'A':
      case 'E':
      case 'I':
      case 'O':
      case 'U':
      case 'Y':
        // Only an initial vowel is coded, and `run` handled that.
        _index++;
        return;

      case 'B':
        _add('P');
        // "Webb" is one B.
        _index += _at(_index + 1) == 'B' ? 2 : 1;
        return;

      case 'C':
        _encodeC();
        return;

      case 'D':
        if (_matches(_index, 2, ['DG'])) {
          if (_matches(_index + 2, 1, ['I', 'E', 'Y'])) {
            // "Edge"
            _add('J');
            _index += 3;
          } else {
            _add('TK');
            _index += 2;
          }
          return;
        }
        _add('T');
        _index += _matches(_index, 2, ['DT', 'DD']) ? 2 : 1;
        return;

      case 'F':
        _add('F');
        _index += _at(_index + 1) == 'F' ? 2 : 1;
        return;

      case 'G':
        _encodeG();
        return;

      case 'H':
        // Only pronounced between a vowel and a vowel, or word-initial.
        if ((_index == 0 || _isVowel(_index - 1)) && _isVowel(_index + 1)) {
          _add('H');
          _index += 2;
        } else {
          _index++;
        }
        return;

      case 'J':
        _encodeJ();
        return;

      case 'K':
        _add('K');
        _index += _at(_index + 1) == 'K' ? 2 : 1;
        return;

      case 'L':
        _add('L');
        _index += _at(_index + 1) == 'L' ? 2 : 1;
        return;

      case 'M':
        _add('M');
        // "Thomas", "Thumb" -- the B after MB is silent at the end.
        _index +=
            (_matches(_index - 1, 3, ['UMB']) && (_index + 1 == _length - 1)) ||
                    _at(_index + 1) == 'M'
                ? 2
                : 1;
        return;

      case 'N':
        _add('N');
        _index += _at(_index + 1) == 'N' ? 2 : 1;
        return;

      case 'P':
        if (_at(_index + 1) == 'H') {
          _add('F');
          _index += 2;
          return;
        }

        // Silent after M: "Thompson", "Hampson", "Sampson", "Kempton".
        if (_at(_index - 1) == 'M' && _matches(_index + 1, 1, ['S', 'T'])) {
          _index++;
          return;
        }

        _add('P');
        _index += _matches(_index + 1, 1, ['P', 'B']) ? 2 : 1;
        return;

      case 'Q':
        _add('K');
        _index += _at(_index + 1) == 'Q' ? 2 : 1;
        return;

      case 'R':
        _add('R');
        _index += _at(_index + 1) == 'R' ? 2 : 1;
        return;

      case 'S':
        _encodeS();
        return;

      case 'T':
        _encodeT();
        return;

      case 'V':
        _add('F');
        _index += _at(_index + 1) == 'V' ? 2 : 1;
        return;

      case 'W':
        _encodeW();
        return;

      case 'X':
        _add('KS');
        _index += _matches(_index + 1, 1, ['C', 'X']) ? 2 : 1;
        return;

      case 'Z':
        if (_at(_index + 1) == 'H') {
          // "Zhao"
          _add('J');
          _index += 2;
          return;
        }
        _add('S', _slavoGermanic ? 'TS' : 'S');
        _index += _at(_index + 1) == 'Z' ? 2 : 1;
        return;

      default:
        _index++;
        return;
    }
  }

  void _encodeC() {
    if (_matches(_index, 4, ['CHIA'])) {
      // Italian "Chianti"
      _add('K');
      _index += 2;
      return;
    }

    if (_matches(_index, 2, ['CH'])) {
      if (_index > 0 && _matches(_index, 4, ['CHAE'])) {
        _add('K', 'X');
        _index += 2;
        return;
      }

      // Greek roots: "Chemistry", "Chorus".
      final greek = _index == 0 &&
          (_matches(_index + 1, 5, ['HARAC', 'HARIS']) ||
              _matches(_index + 1, 3, ['HOR', 'HYM', 'HIA', 'HEM'])) &&
          !_matches(0, 5, ['CHORE']);

      final germanic = _matches(0, 4, ['VAN ', 'VON ']) ||
          _matches(0, 3, ['SCH']) ||
          _matches(_index - 2, 6, ['ORCHES', 'ARCHIT', 'ORCHID']) ||
          _matches(_index + 2, 1, ['T', 'S']);

      if (greek || germanic) {
        _add('K');
      } else {
        // Both readings everywhere, so "Richard"/"Rickard" and
        // "Michael"/"Mikael" can meet on the alternate code.
        _add('X', 'K');
      }
      _index += 2;
      return;
    }

    if (_matches(_index, 2, ['CZ']) && !_matches(_index - 2, 4, ['WICZ'])) {
      // "Czerny"
      _add('S', 'X');
      _index += 2;
      return;
    }

    if (_matches(_index + 1, 3, ['CIA'])) {
      // "Focaccia"
      _add('X');
      _index += 3;
      return;
    }

    if (_matches(_index, 2, ['CC']) && !(_index == 1 && _at(0) == 'M')) {
      if (_matches(_index + 2, 1, ['I', 'E', 'H']) &&
          !_matches(_index + 2, 2, ['HU'])) {
        // "Accident", "Accede"
        _add('KS');
        _index += 3;
        return;
      }
      _add('K');
      _index += 2;
      return;
    }

    if (_matches(_index, 2, ['CK', 'CG', 'CQ'])) {
      _add('K');
      _index += 2;
      return;
    }

    if (_matches(_index, 2, ['CI', 'CE', 'CY'])) {
      _add('S');
      _index += 2;
      return;
    }

    _add('K');
    _index += _matches(_index + 1, 1, [' ', 'C', 'K', 'Q']) ? 2 : 1;
  }

  void _encodeG() {
    if (_at(_index + 1) == 'H') {
      if (_index > 0 && !_isVowel(_index - 1)) {
        _add('K');
        _index += 2;
        return;
      }

      // "Ghislane" -- initial GH before a vowel reads as G.
      if (_index == 0) {
        _add(_at(_index + 2) == 'I' ? 'J' : 'K');
        _index += 2;
        return;
      }

      // "Hugh", "Laugh" -- otherwise silent.
      _index += 2;
      return;
    }

    if (_at(_index + 1) == 'N') {
      if (_index == 1 && _isVowel(0) && !_slavoGermanic) {
        _add('KN', 'N');
      } else if (!_matches(_index + 2, 2, ['EY']) &&
          _at(_index + 1) != 'Y' &&
          !_slavoGermanic) {
        _add('N', 'KN');
      } else {
        _add('KN');
      }
      _index += 2;
      return;
    }

    if (_matches(_index + 1, 2, ['LI']) && !_slavoGermanic) {
      // "Tagliaro"
      _add('KL', 'L');
      _index += 2;
      return;
    }

    // "Ges", "Gep", "Gel" and friends take a hard G.
    if (_index == 0 &&
        (_at(_index + 1) == 'Y' ||
            _matches(_index + 1, 2, [
              'ES',
              'EP',
              'EB',
              'EL',
              'EY',
              'IB',
              'IL',
              'IN',
              'IE',
              'EI',
              'ER'
            ]))) {
      _add('K', 'J');
      _index += 2;
      return;
    }

    if ((_matches(_index + 1, 2, ['ER']) || _at(_index + 1) == 'Y') &&
        !_matches(0, 6, ['DANGER', 'RANGER', 'MANGER']) &&
        !_matches(_index - 1, 1, ['E', 'I']) &&
        !_matches(_index - 1, 3, ['RGY', 'OGY'])) {
      _add('K', 'J');
      _index += 2;
      return;
    }

    if (_matches(_index + 1, 1, ['E', 'I', 'Y']) ||
        _matches(_index - 1, 4, ['AGGI', 'OGGI'])) {
      if (_matches(0, 4, ['VAN ', 'VON ']) ||
          _matches(0, 3, ['SCH']) ||
          _matches(_index + 1, 2, ['ET'])) {
        _add('K');
      } else {
        _add('J', 'K');
      }
      _index += 2;
      return;
    }

    _add('K');
    _index += _at(_index + 1) == 'G' ? 2 : 1;
  }

  void _encodeJ() {
    // Spanish "Jose", "San Jacinto".
    if (_matches(_index, 4, ['JOSE']) || _matches(0, 4, ['SAN '])) {
      if ((_index == 0 && _at(_index + 4) == ' ') || _matches(0, 4, ['SAN '])) {
        _add('H');
      } else {
        _add('J', 'H');
      }
      _index++;
      return;
    }

    if (_index == 0 && !_matches(_index, 4, ['JOSE'])) {
      _add('J', 'A');
    } else if (_isVowel(_index - 1) &&
        !_slavoGermanic &&
        (_at(_index + 1) == 'A' || _at(_index + 1) == 'O')) {
      _add('J', 'H');
    } else if (_index == _length - 1) {
      _add('J', '');
    } else if (!_matches(
            _index + 1, 1, ['L', 'T', 'K', 'S', 'N', 'M', 'B', 'Z']) &&
        !_matches(_index - 1, 1, ['S', 'K', 'L'])) {
      _add('J');
    }

    _index += _at(_index + 1) == 'J' ? 2 : 1;
  }

  void _encodeS() {
    // "Island", "Isle" -- silent S.
    if (_matches(_index - 1, 3, ['ISL', 'YSL'])) {
      _index++;
      return;
    }

    if (_index == 0 && _matches(_index, 5, ['SUGAR'])) {
      _add('X', 'S');
      _index++;
      return;
    }

    if (_matches(_index, 2, ['SH'])) {
      // Germanic "Sholz", "Sheim".
      if (_matches(_index + 1, 4, ['HEIM', 'HOEK', 'HOLM', 'HOLZ'])) {
        _add('S');
      } else {
        _add('X');
      }
      _index += 2;
      return;
    }

    if (_matches(_index, 3, ['SIO', 'SIA']) || _matches(_index, 4, ['SIAN'])) {
      _add(_slavoGermanic ? 'S' : 'S', _slavoGermanic ? 'S' : 'X');
      _index += 3;
      return;
    }

    if ((_index == 0 && _matches(_index + 1, 1, ['M', 'N', 'L', 'W'])) ||
        _at(_index + 1) == 'Z') {
      _add('S', 'X');
      _index += _at(_index + 1) == 'Z' ? 2 : 1;
      return;
    }

    if (_matches(_index, 2, ['SC'])) {
      _encodeSC();
      return;
    }

    // A trailing S in French-derived "Illinois", "Delacroix" is silent.
    if (_index == _length - 1 && _matches(_index - 2, 2, ['AI', 'OI'])) {
      _index++;
      return;
    }

    _add('S');
    _index += _matches(_index + 1, 1, ['S', 'Z']) ? 2 : 1;
  }

  void _encodeSC() {
    if (_at(_index + 2) == 'H') {
      // Dutch "Schenker", "Schermerhorn".
      if (_matches(_index + 3, 2, ['OO', 'ER', 'EN', 'UY', 'ED', 'EM'])) {
        if (_matches(_index + 3, 2, ['ER', 'EN'])) {
          _add('X', 'SK');
        } else {
          _add('SK');
        }
        _index += 3;
        return;
      }

      if (_index == 0 && !_isVowel(3) && _at(3) != 'W') {
        _add('X', 'S');
      } else {
        _add('X');
      }
      _index += 3;
      return;
    }

    if (_matches(_index + 2, 1, ['I', 'E', 'Y'])) {
      _add('S');
      _index += 3;
      return;
    }

    _add('SK');
    _index += 3;
  }

  void _encodeT() {
    if (_matches(_index, 4, ['TION'])) {
      _add('X');
      _index += 3;
      return;
    }

    if (_matches(_index, 3, ['TIA', 'TCH'])) {
      _add('X');
      _index += 3;
      return;
    }

    if (_matches(_index, 2, ['TH']) || _matches(_index, 3, ['TTH'])) {
      // "Thomas", "Thames" keep a hard T.
      if (_matches(_index + 2, 2, ['OM', 'AM']) ||
          _matches(0, 4, ['VAN ', 'VON ']) ||
          _matches(0, 3, ['SCH'])) {
        _add('T');
      } else {
        _add('0', 'T');
      }
      _index += 2;
      return;
    }

    _add('T');
    _index += _matches(_index + 1, 1, ['T', 'D']) ? 2 : 1;
  }

  void _encodeW() {
    // "Wr" was handled as a silent start; here handle WH and vowel readings.
    if (_matches(_index, 2, ['WR'])) {
      _add('R');
      _index += 2;
      return;
    }

    if (_index == 0 && (_isVowel(_index + 1) || _matches(_index, 2, ['WH']))) {
      if (_isVowel(_index + 1)) {
        // "Wasserman" -- the alternate treats W as a vowel.
        _add('A', 'F');
      } else {
        // "Why"
        _add('A');
      }
      _index++;
      return;
    }

    // Polish "Tchaikowski" and French "Arnow".
    if ((_index == _length - 1 && _isVowel(_index - 1)) ||
        _matches(_index - 1, 5, ['EWSKI', 'EWSKY', 'OWSKI', 'OWSKY']) ||
        _matches(0, 3, ['SCH'])) {
      _add('', 'F');
      _index++;
      return;
    }

    if (_matches(_index, 4, ['WICZ', 'WITZ'])) {
      _add('TS', 'FX');
      _index += 4;
      return;
    }

    _index++;
  }
}
