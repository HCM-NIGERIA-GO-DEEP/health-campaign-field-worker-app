import 'package:digit_dedup_engine/digit_dedup_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StringUtils.normalizeName', () {
    test('lowercases, trims and collapses whitespace', () {
      expect(StringUtils.normalizeName('  Peter   John  '), 'peter john');
    });

    test('strips diacriticals to their ASCII base letter', () {
      expect(StringUtils.normalizeName('Amïnâtou'), 'aminatou');
      expect(StringUtils.normalizeName('Zoë'), 'zoe');
    });

    test('expands multi-letter decompositions', () {
      expect(StringUtils.normalizeName('Æsop'), 'aesop');
    });

    test('replaces punctuation with a separator', () {
      expect(StringUtils.normalizeName('Peter/John'), 'peter john');
      expect(StringUtils.normalizeName('Musa 3'), 'musa');
    });

    test('keeps apostrophes and hyphens', () {
      expect(StringUtils.normalizeName("M'Bala-Sow"), "m'bala-sow");
    });
  });

  group('StringUtils.removeAffixes', () {
    test('strips a leading affix', () {
      expect(StringUtils.removeAffixes('al-hassan'), 'hassan');
      expect(StringUtils.removeAffixes("m'bala"), 'bala');
    });

    test('strips stacked affixes', () {
      expect(StringUtils.removeAffixes("al-m'bala"), 'bala');
    });

    test('drops standalone connector words', () {
      expect(StringUtils.removeAffixes('ahmed bin salem'), 'ahmed salem');
    });

    test('leaves short names intact', () {
      expect(StringUtils.removeAffixes('al'), 'al');
      expect(StringUtils.removeAffixes("m'b"), "m'b");
    });

    test('returns the input when stripping would empty it', () {
      expect(StringUtils.removeAffixes('bin'), 'bin');
    });
  });

  group('Soundex.encode', () {
    test('encodes similar-sounding names identically', () {
      expect(Soundex.encode('Mahamat'), 'M530');
      expect(Soundex.encode('Muhammad'), 'M530');
    });

    test('encodes a vowel-typo pair identically', () {
      expect(Soundex.encode('Pitr'), Soundex.encode('Peter'));
    });

    test('always returns four characters', () {
      expect(Soundex.encode('Lee'), 'L000');
      expect(Soundex.encode('Washington'), hasLength(4));
      expect(Soundex.encode('Tymczak'), hasLength(4));
    });

    test('collapses adjacent letters sharing a code', () {
      expect(Soundex.encode('Pfister'), 'P236');
    });

    test('treats h and w as transparent', () {
      expect(Soundex.encode('Ashcraft'), 'A261');
    });

    test('lets a vowel separate a repeated code', () {
      expect(Soundex.encode('Tymczak'), 'T522');
    });

    test('returns empty for input with no letters', () {
      expect(Soundex.encode('123'), '');
      expect(Soundex.encode(''), '');
    });
  });

  group('Levenshtein', () {
    test('distance is zero for identical strings', () {
      expect(Levenshtein.distance('peter', 'peter'), 0);
    });

    test('distance counts single-character edits', () {
      expect(Levenshtein.distance('kitten', 'sitting'), 3);
      expect(Levenshtein.distance('peter', 'pitr'), 2);
    });

    test('distance against an empty string is the other length', () {
      expect(Levenshtein.distance('', 'peter'), 5);
      expect(Levenshtein.distance('peter', ''), 5);
    });

    test('similarity is normalized to 0..1', () {
      expect(Levenshtein.similarity('peter', 'peter'), 1.0);
      expect(Levenshtein.similarity('', ''), 1.0);
      expect(Levenshtein.similarity('abc', 'xyz'), 0.0);
      expect(Levenshtein.similarity('kitten', 'sitting'),
          closeTo(1 - 3 / 7, 1e-9));
    });
  });

  group('JaroWinkler', () {
    test('identical strings score 1.0', () {
      expect(JaroWinkler.similarity('peter', 'peter'), 1.0);
      expect(JaroWinkler.jaroSimilarity('peter', 'peter'), 1.0);
    });

    test('empty input scores 0.0', () {
      expect(JaroWinkler.similarity('peter', ''), 0.0);
      expect(JaroWinkler.similarity('', ''), 1.0);
    });

    test('matches the reference Jaro values', () {
      expect(JaroWinkler.jaroSimilarity('MARTHA', 'MARHTA'),
          closeTo(0.944444, 1e-5));
      expect(JaroWinkler.jaroSimilarity('DIXON', 'DICKSONX'),
          closeTo(0.766667, 1e-5));
      expect(JaroWinkler.jaroSimilarity('CRATE', 'TRACE'),
          closeTo(0.733333, 1e-5));
    });

    test('matches the reference Jaro-Winkler values', () {
      expect(
          JaroWinkler.similarity('MARTHA', 'MARHTA'), closeTo(0.961111, 1e-5));
      expect(
          JaroWinkler.similarity('DIXON', 'DICKSONX'), closeTo(0.813333, 1e-5));
    });

    test('the prefix bonus never pushes the score past 1.0', () {
      expect(JaroWinkler.similarity('abcd', 'abcd'), 1.0);
      expect(JaroWinkler.similarity('peterr', 'peter'), lessThanOrEqualTo(1.0));
    });

    test('scores a typo pair well above an unrelated pair', () {
      final typo = JaroWinkler.similarity('peter', 'pitr');
      final unrelated = JaroWinkler.similarity('peter', 'aminatou');
      expect(typo, greaterThan(unrelated));
    });
  });

  group('GpsUtils', () {
    test('distance between identical points is zero', () {
      expect(
          GpsUtils.haversineDistance(9.05, 7.49, 9.05, 7.49), closeTo(0, 1e-6));
    });

    test('nearby points score 1.0 and far points 0.0', () {
      expect(GpsUtils.proximityScore(9.05, 7.49, 9.05, 7.49), 1.0);
      expect(GpsUtils.proximityScore(9.05, 7.49, 10.05, 8.49), 0.0);
    });
  });
}
