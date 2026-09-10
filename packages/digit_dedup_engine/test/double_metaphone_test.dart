import 'package:digit_dedup_engine/digit_dedup_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DoubleMetaphone.encode', () {
    test('returns empty codes for input with no letters', () {
      expect(DoubleMetaphone.encode(''), ('', ''));
      expect(DoubleMetaphone.encode('123'), ('', ''));
    });

    test('caps codes at four characters', () {
      for (final name in ['Wilkowski', 'Tchaikowski', 'Schermerhorn']) {
        final (primary, alternate) = DoubleMetaphone.encode(name);
        expect(primary.length, lessThanOrEqualTo(4), reason: name);
        expect(alternate.length, lessThanOrEqualTo(4), reason: name);
      }
    });

    test('gives a German and an English reading of the same spelling', () {
      // The whole point of two codes: "Schmidt" is X-M-T to a German speaker
      // and S-M-T to an English one, so either can match.
      final (primary, alternate) = DoubleMetaphone.encode('Schmidt');
      expect(primary, isNot(alternate));
    });

    test('agrees on a spelling with only one reading', () {
      final (primary, alternate) = DoubleMetaphone.encode('Thompson');
      expect(primary, alternate);
    });

    test('silent initial letters are dropped', () {
      // GN/KN/PN/WR all lose their first letter.
      expect(DoubleMetaphone.encode('Knight').$1, startsWith('N'));
      expect(DoubleMetaphone.encode('Gnome').$1, startsWith('N'));
      expect(DoubleMetaphone.encode('Wright').$1, startsWith('R'));
      expect(DoubleMetaphone.encode('Pneumatic').$1, startsWith('N'));
    });

    test('an initial X reads as S', () {
      expect(DoubleMetaphone.encode('Xavier').$1, startsWith('S'));
    });

    test('PH reads as F', () {
      expect(DoubleMetaphone.encode('Philip').$1, startsWith('F'));
      expect(DoubleMetaphone.encode('Stephen').$1, contains('F'));
    });

    test('any initial vowel codes as A', () {
      for (final name in ['Aisha', 'Emmanuel', 'Ibrahim', 'Umar']) {
        expect(DoubleMetaphone.encode(name).$1, startsWith('A'), reason: name);
      }
    });

    test('separates names Soundex conflates', () {
      // Soundex keys on the first letter, so it can only ever agree here.
      expect(Soundex.encode('Knight'), isNot(Soundex.encode('Night')));
      // Double Metaphone models the silent K and matches them.
      expect(DoubleMetaphone.encode('Knight').$1,
          DoubleMetaphone.encode('Night').$1);
    });

    test('matches phonetically equivalent spellings', () {
      final pairs = <List<String>>[
        ['Smith', 'Smyth'],
        ['Katherine', 'Catherine'],
        ['Jon', 'John'],
        ['Muhammad', 'Muhammed'],
      ];

      for (final pair in pairs) {
        final a = DoubleMetaphone.encode(pair[0]);
        final b = DoubleMetaphone.encode(pair[1]);
        final overlap = {a.$1, a.$2}.intersection({b.$1, b.$2})
          ..removeWhere((code) => code.isEmpty);
        expect(overlap, isNotEmpty,
            reason: '${pair[0]} ($a) vs ${pair[1]} ($b)');
      }
    });

    test('keeps clearly different names apart', () {
      final pairs = <List<String>>[
        ['Ibrahim', 'Danjuma'],
        ['Aisha', 'Bitrus'],
        ['Musa', 'Yakubu'],
      ];

      for (final pair in pairs) {
        final a = DoubleMetaphone.encode(pair[0]);
        final b = DoubleMetaphone.encode(pair[1]);
        expect(a.$1, isNot(b.$1), reason: '${pair[0]} vs ${pair[1]}');
      }
    });

    test('P is silent after M', () {
      // "Thompson", not "Thomp-son".
      expect(DoubleMetaphone.encode('Thompson').$1, isNot(contains('P')));
      expect(DoubleMetaphone.encode('Sampson').$1, isNot(contains('P')));
      // But a P that is genuinely pronounced survives.
      expect(DoubleMetaphone.encode('Campbell').$1, contains('P'));
    });

    test('CH offers both a soft and a hard reading', () {
      final richard = DoubleMetaphone.encode('Richard');
      final rickard = DoubleMetaphone.encode('Rickard');
      expect({richard.$1, richard.$2}.intersection({rickard.$1, rickard.$2}),
          isNotEmpty,
          reason: 'Richard $richard vs Rickard $rickard');
    });

    test('normalizes accents before encoding', () {
      expect(DoubleMetaphone.encode('Amïnâtou'),
          DoubleMetaphone.encode('Aminatou'));
    });
  });
}
