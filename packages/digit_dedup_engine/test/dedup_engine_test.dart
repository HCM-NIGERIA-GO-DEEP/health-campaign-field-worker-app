import 'package:digit_dedup_engine/digit_dedup_engine.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> person(
  String givenName,
  String familyName, {
  String? id,
  String? gender,
  String? dateOfBirth,
}) =>
    {
      'givenName': givenName,
      'familyName': familyName,
      if (id != null) 'id': id,
      if (gender != null) 'gender': gender,
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
    };

void main() {
  group('MatchingService', () {
    final service = MatchingService();

    test('identical names score 1.0', () {
      expect(
        service.computeScore(
          person('Peter', 'Okafor'),
          person('Peter', 'Okafor'),
        ),
        1.0,
      );
    });

    test('only attributes present on both sides are scored', () {
      final scores = service.computeAttributeScores(
        person('Peter', 'Okafor'),
        person('Peter', 'Okafor', gender: 'MALE'),
      );
      expect(scores.keys,
          containsAll(<String>['givenName', 'familyName', 'phoneticMatch']));
      expect(scores.containsKey('gender'), isFalse);
      expect(scores.containsKey('dateOfBirth'), isFalse);
      expect(scores.containsKey('gpsProximity'), isFalse);
    });

    test('a names-only pair can still reach 1.0 after renormalization', () {
      // Names plus the phonetic signal carry 0.55 of the default weights; the
      // score would be capped there without renormalization.
      final score = service.computeScore(
        person('Peter', 'Okafor'),
        person('Peter', 'Okafor'),
      );
      expect(score, closeTo(1.0, 1e-9));
    });

    test('a typo pair scores high but below an exact match', () {
      final typo = service.computeScore(
        person('Pitr', 'Okafor'),
        person('Peter', 'Okafor'),
      );
      expect(typo, greaterThan(0.7));
      expect(typo, lessThan(1.0));
    });

    test('unrelated names score low', () {
      final score = service.computeScore(
        person('Peter', 'Okafor'),
        person('Aminatou', 'Bello'),
      );
      expect(score, lessThan(0.5));
    });

    test('a shared birth year earns partial credit', () {
      final scores = service.computeAttributeScores(
        person('Peter', 'Okafor', dateOfBirth: '01/01/1990'),
        person('Peter', 'Okafor', dateOfBirth: '05/06/1990'),
      );
      expect(scores['dateOfBirth'], 0.5);
    });

    test('an exact birth date scores 1.0 across formats', () {
      final scores = service.computeAttributeScores(
        person('Peter', 'Okafor', dateOfBirth: '01/02/1990'),
        person('Peter', 'Okafor', dateOfBirth: '1990-02-01'),
      );
      expect(scores['dateOfBirth'], 1.0);
    });

    test('custom weights are honoured', () {
      final familyNameOnly = MatchingService(weights: {'familyName': 1.0});
      expect(
        familyNameOnly.computeScore(
          person('Peter', 'Okafor'),
          person('Aminatou', 'Okafor'),
        ),
        1.0,
      );
    });

    test('records with nothing in common score 0.0', () {
      expect(service.computeScore({}, {}), 0.0);
    });
  });

  group('BlockingStrategy', () {
    test('files a record under one block per name attribute', () {
      final keys = BlockingStrategy().blockKeysFor(person('Peter', 'Okafor'));
      expect(keys, contains('givenName:${Soundex.encode('Peter')}'));
      expect(keys, contains('familyName:${Soundex.encode('Okafor')}'));
    });

    test('multi-word names contribute a key per word', () {
      final keys =
          BlockingStrategy().blockKeysFor(person('Peter John', 'Okafor'));
      expect(keys, contains('givenName:${Soundex.encode('Peter')}'));
      expect(keys, contains('givenName:${Soundex.encode('John')}'));
    });

    test('groups phonetically similar records together', () {
      final blocks = BlockingStrategy().buildBlocks([
        person('Peter', 'Okafor'),
        person('Pitr', 'Okafor'),
        person('Aminatou', 'Bello'),
      ]);
      final block = blocks['givenName:${Soundex.encode('Peter')}']!;
      expect(block, containsAll(<int>[0, 1]));
      expect(block, isNot(contains(2)));
    });

    test('returns no keys for a record with no name', () {
      expect(BlockingStrategy().blockKeysFor({'gender': 'MALE'}), isEmpty);
    });
  });

  group('DedupEngine.findMatchesFor', () {
    final corpus = [
      person('Peter', 'Okafor', id: 'a'),
      person('Aminatou', 'Bello', id: 'b'),
      person('Petr', 'Okafor', id: 'c'),
    ];

    test('finds an exact duplicate', () {
      final matches = DedupEngine().findMatchesFor(
        person('Peter', 'Okafor'),
        corpus,
      );
      expect(matches, isNotEmpty);
      expect(matches.first.record['id'], 'a');
      expect(matches.first.score, closeTo(1.0, 1e-9));
      expect(matches.first.recordIndex, 0);
    });

    test('finds a near-duplicate at a relaxed threshold', () {
      final matches = DedupEngine(matchThreshold: 0.8).findMatchesFor(
        person('Pitr', 'Okafor'),
        corpus,
      );
      expect(matches.map((m) => m.record['id']), contains('c'));
    });

    test('returns matches highest score first', () {
      final matches = DedupEngine(matchThreshold: 0.5).findMatchesFor(
        person('Peter', 'Okafor'),
        corpus,
      );
      for (var i = 1; i < matches.length; i++) {
        expect(matches[i - 1].score, greaterThanOrEqualTo(matches[i].score));
      }
    });

    test('caps the result count at maxResults', () {
      final matches = DedupEngine(matchThreshold: 0.0).findMatchesFor(
        person('Peter', 'Okafor'),
        corpus,
        maxResults: 1,
      );
      expect(matches, hasLength(1));
    });

    test('excludes records below the threshold', () {
      final matches = DedupEngine(matchThreshold: 0.99).findMatchesFor(
        person('Aminatou', 'Bello'),
        corpus,
      );
      expect(matches, hasLength(1));
      expect(matches.first.record['id'], 'b');
    });

    test('returns nothing for an empty corpus', () {
      expect(
        DedupEngine().findMatchesFor(person('Peter', 'Okafor'), const []),
        isEmpty,
      );
    });

    test('returns nothing when the probe has no blockable name', () {
      expect(
        DedupEngine().findMatchesFor({'gender': 'MALE'}, corpus),
        isEmpty,
      );
    });

    test('an unblocked engine reaches records blocking would skip', () {
      // "Zeta" shares no Soundex code with any corpus given or family name,
      // so blocking rules the corpus out before any scoring happens.
      final probe = person('Zeta', 'Xylo');
      expect(
        DedupEngine(matchThreshold: 0.0).findMatchesFor(probe, corpus),
        isEmpty,
      );
      expect(
        DedupEngine(matchThreshold: 0.0, useBlocking: false)
            .findMatchesFor(probe, corpus),
        hasLength(corpus.length),
      );
    });

    test('reports the attribute scores behind a match', () {
      final matches = DedupEngine().findMatchesFor(
        person('Peter', 'Okafor'),
        corpus,
      );
      expect(matches.first.attributeScores['givenName'], 1.0);
      expect(matches.first.attributeScores['familyName'], 1.0);
    });

    test('exposes the score as a percentage for display', () {
      final matches = DedupEngine().findMatchesFor(
        person('Peter', 'Okafor'),
        corpus,
      );
      expect(matches.first.scorePercentage, 100);
    });
  });

  group('DedupEngine.findDuplicates', () {
    test('finds a duplicate pair within a batch', () {
      final results = DedupEngine(matchThreshold: 0.8).findDuplicates([
        person('Peter', 'Okafor'),
        person('Aminatou', 'Bello'),
        person('Peter', 'Okafor'),
      ]);
      expect(results, hasLength(1));
      expect(results.first.recordIndex1, 0);
      expect(results.first.recordIndex2, 2);
      expect(results.first.isDuplicate, isTrue);
    });

    test('reports each pair once even when several blocks match', () {
      // Both given and family name agree, so the pair surfaces from two
      // blocks and must still be reported a single time.
      final results = DedupEngine(matchThreshold: 0.8).findDuplicates([
        person('Peter', 'Okafor'),
        person('Peter', 'Okafor'),
      ]);
      expect(results, hasLength(1));
    });

    test('returns nothing for fewer than two records', () {
      expect(
          DedupEngine().findDuplicates([person('Peter', 'Okafor')]), isEmpty);
      expect(DedupEngine().findDuplicates(const []), isEmpty);
    });

    test('returns nothing when no pair clears the threshold', () {
      final results = DedupEngine().findDuplicates([
        person('Peter', 'Okafor'),
        person('Aminatou', 'Bello'),
      ]);
      expect(results, isEmpty);
    });
  });
}
