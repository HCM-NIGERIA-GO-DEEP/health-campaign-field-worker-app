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

  group('spelling variations', () {
    final service = MatchingService();

    /// Pairs that are the same name written two ways.
    const variations = <List<String>>[
      ['Al-Mustapha', 'Almustapha'],
      ["M'Bala", 'Mbala'],
      ['Al-Hassan', 'Hassan'],
      ["N'Diaye", 'Ndiaye'],
      ['El-Yakubu', 'Elyakubu'],
    ];

    test('a separator or affix variation never lowers the score', () {
      // Normalizing by stripping affixes alone is a trap: it only rewrites the
      // separated spelling, so "Al-Mustapha" vs "Almustapha" scored 0.767 --
      // below the 0.85 default -- where the raw pair scored 0.976. Comparing
      // through both forms means normalization can only help.
      for (final pair in variations) {
        final normalizedScore = service.computeScore(
          {'givenName': StringUtils.normalizeName(pair[0])},
          {'givenName': StringUtils.normalizeName(pair[1])},
        );
        final rawScore = service.computeScore(
          {'givenName': pair[0]},
          {'givenName': pair[1]},
        );

        expect(rawScore, greaterThanOrEqualTo(normalizedScore - 1e-9),
            reason: '${pair[0]} vs ${pair[1]}');
      }
    });

    test('every variation clears the default threshold', () {
      final engine = DedupEngine();

      for (final pair in variations) {
        final matches = engine.findMatchesFor(
          {'givenName': pair[0], 'familyName': 'Danjuma'},
          [
            {'givenName': pair[1], 'familyName': 'Danjuma', 'id': 'x'}
          ],
        );
        expect(matches, isNotEmpty, reason: '${pair[0]} vs ${pair[1]}');
      }
    });

    test('variations share a block, or scoring never sees them', () {
      final strategy = BlockingStrategy();

      for (final pair in variations) {
        final a = strategy.blockKeysFor({'givenName': pair[0]});
        final b = strategy.blockKeysFor({'givenName': pair[1]});
        expect(a.intersection(b), isNotEmpty,
            reason: '${pair[0]} vs ${pair[1]} were filed apart');
      }
    });

    test('distinct names are still kept apart', () {
      final engine = DedupEngine();
      final matches = engine.findMatchesFor(
        {'givenName': 'Aliyu', 'familyName': 'Danjuma'},
        [
          {'givenName': 'Bitrus', 'familyName': 'Njobdi', 'id': 'x'}
        ],
      );
      expect(matches, isEmpty);
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

  group('absent attributes', () {
    final service = MatchingService();

    /// Values that all mean "not recorded", whatever the field.
    const emptyish = <dynamic>[null, '', '   ', '--'];

    test('every optional attribute drops out when either side is empty', () {
      // givenName is excluded on purpose: it is the one field a probe must
      // carry, since with no name there is nothing to match on.
      const attributes = [
        'familyName',
        'fatherName',
        'dateOfBirth',
        'gender',
        'mobileNumber',
      ];

      for (final attribute in attributes) {
        for (final empty in emptyish) {
          final scores = service.computeAttributeScores(
            {'givenName': 'Musa', attribute: empty},
            {'givenName': 'Musa', attribute: 'Ibrahim'},
          );
          expect(scores, isNot(contains(attribute)),
              reason: '$attribute should drop out for ${empty ?? "null"}');

          // And symmetrically, with the empty value on the other side.
          final flipped = service.computeAttributeScores(
            {'givenName': 'Musa', attribute: 'Ibrahim'},
            {'givenName': 'Musa', attribute: empty},
          );
          expect(flipped, isNot(contains(attribute)),
              reason: '$attribute should drop out for ${empty ?? "null"}');
        }
      }
    });

    test('a name of only punctuation counts as absent', () {
      final scores = service.computeAttributeScores(
        {'givenName': 'Musa', 'familyName': "-'-"},
        {'givenName': 'Musa', 'familyName': 'Ibrahim'},
      );
      expect(scores, isNot(contains('familyName')));
    });

    test('gpsProximity needs all four coordinates', () {
      for (final missing in [
        'latitude',
        'longitude',
      ]) {
        final a = {
          'givenName': 'Musa',
          'latitude': 9.05,
          'longitude': 7.49,
        }..remove(missing);

        final scores = service.computeAttributeScores(
          a,
          {'givenName': 'Musa', 'latitude': 9.05, 'longitude': 7.49},
        );
        expect(scores, isNot(contains('gpsProximity')),
            reason: 'missing $missing');
      }
    });

    test('an unparseable date or coordinate is treated as absent', () {
      final scores = service.computeAttributeScores(
        {
          'givenName': 'Musa',
          'dateOfBirth': 'not a date',
          'latitude': 'north',
          'longitude': 'east',
        },
        {
          'givenName': 'Musa',
          'dateOfBirth': '01/02/1990',
          'latitude': 9.05,
          'longitude': 7.49,
        },
      );
      expect(scores, isNot(contains('dateOfBirth')));
      expect(scores, isNot(contains('gpsProximity')));
    });

    test('a probe carrying only a given name still scores', () {
      // Everything except givenName may be absent, and the pair must still be
      // comparable rather than collapsing to zero.
      final score = service.computeScore(
        {'givenName': 'Musa'},
        {'givenName': 'Musa', 'familyName': 'Ibrahim', 'gender': 'MALE'},
      );
      expect(score, closeTo(1.0, 1e-9));
    });

    test('dropping an attribute never lowers the score', () {
      // Renormalization means an absent attribute is neither reward nor
      // penalty, so a sparser probe cannot score worse on what it does carry.
      final full = service.computeScore(
        {'givenName': 'Musa', 'familyName': 'Ibrahim', 'gender': 'MALE'},
        {'givenName': 'Musa', 'familyName': 'Ibrahim', 'gender': 'MALE'},
      );
      final sparse = service.computeScore(
        {'givenName': 'Musa'},
        {'givenName': 'Musa', 'familyName': 'Ibrahim', 'gender': 'MALE'},
      );
      expect(sparse, greaterThanOrEqualTo(full - 1e-9));
    });

    test('two records with nothing comparable score zero, not a crash', () {
      expect(service.computeScore({'gender': null}, {'gender': null}), 0.0);
      expect(service.computeScore(const {}, const {}), 0.0);
    });
  });

  group('DedupIndex', () {
    final corpus = [
      person('Peter', 'Okafor', id: 'a'),
      person('Aminatou', 'Bello', id: 'b'),
      person('Petr', 'Okafor', id: 'c'),
    ];

    test('reports the shape of the blocking it produced', () {
      final index = DedupIndex.build(corpus);
      expect(index.length, corpus.length);
      expect(index.blockCount, greaterThan(0));
      // Peter and Petr share a given-name block, so no block is a singleton.
      expect(index.largestBlock, greaterThanOrEqualTo(2));
    });

    test('narrows candidates to the probe\'s blocks', () {
      final index = DedupIndex.build(corpus);
      final candidates = index.candidatesFor(person('Peter', 'Okafor'));

      expect(candidates, contains(0));
      expect(candidates, isNot(contains(1)),
          reason: 'Aminatou Bello shares no block with Peter Okafor');
    });

    test('returns nothing for a probe with no blockable name', () {
      expect(DedupIndex.build(corpus).candidatesFor({'gender': 'MALE'}),
          isEmpty);
    });

    test('a prebuilt index gives the same matches as building per call', () {
      final engine = DedupEngine(matchThreshold: 0.5);
      final probe = person('Peter', 'Okafor');

      final perCall = engine.findMatchesFor(probe, corpus);
      final indexed =
          engine.findMatchesUsing(engine.buildIndex(corpus), probe);

      expect(indexed.map((m) => m.record['id']),
          perCall.map((m) => m.record['id']));
      expect(indexed.map((m) => m.score), perCall.map((m) => m.score));
    });

    test('an index built once serves many probes', () {
      final engine = DedupEngine(matchThreshold: 0.5);
      final index = engine.buildIndex(corpus);

      for (final record in corpus) {
        final matches = engine.findMatchesUsing(index, record);
        expect(matches.map((m) => m.record['id']), contains(record['id']),
            reason: 'a record should at least match itself');
      }
    });

    test('respects maxResults', () {
      final engine = DedupEngine(matchThreshold: 0.0);
      final index = engine.buildIndex(corpus);
      expect(
        engine.findMatchesUsing(index, person('Peter', 'Okafor'),
            maxResults: 1),
        hasLength(1),
      );
    });
  });

  group('mobile number', () {
    final service = MatchingService();

    test('a matching number scores 1.0', () {
      final scores = service.computeAttributeScores(
        {'givenName': 'Musa', 'mobileNumber': '9876543210'},
        {'givenName': 'Musa', 'mobileNumber': '9876543210'},
      );
      expect(scores['mobileNumber'], 1.0);
    });

    test('ignores a country code', () {
      final scores = service.computeAttributeScores(
        {'mobileNumber': '+234 987 654 3210'},
        {'mobileNumber': '9876543210'},
      );
      expect(scores['mobileNumber'], 1.0);
    });

    test('a different number scores 0.0', () {
      final scores = service.computeAttributeScores(
        {'mobileNumber': '9876543210'},
        {'mobileNumber': '9876500000'},
      );
      expect(scores['mobileNumber'], 0.0);
    });

    test('is skipped when either side is missing or too short', () {
      expect(
        service.computeAttributeScores(
            {'mobileNumber': '9876543210'}, {'givenName': 'Musa'}),
        isNot(contains('mobileNumber')),
      );
      expect(
        service.computeAttributeScores(
            {'mobileNumber': '123'}, {'mobileNumber': '123'}),
        isNot(contains('mobileNumber')),
      );
    });

    test('separates two people who share a name', () {
      // The collision this attribute exists to fix: names alone cannot tell
      // these apart, and in a dense boundary many people share a name.
      final engine = DedupEngine();
      final matches = engine.findMatchesFor(
        {
          'givenName': 'Musa',
          'familyName': 'Ibrahim',
          'mobileNumber': '9876543210'
        },
        [
          {
            'givenName': 'Musa',
            'familyName': 'Ibrahim',
            'mobileNumber': '9000000001',
            'id': 'other'
          }
        ],
      );
      expect(matches, isEmpty);
    });

    test('still matches when only one side recorded a number', () {
      // The field is optional, so a missing number must not suppress a match.
      final engine = DedupEngine();
      final matches = engine.findMatchesFor(
        {
          'givenName': 'Musa',
          'familyName': 'Ibrahim',
          'mobileNumber': '9876543210'
        },
        [
          {'givenName': 'Musa', 'familyName': 'Ibrahim', 'id': 'other'}
        ],
      );
      expect(matches, isNotEmpty);
    });

    test('adding the attribute leaves name-only pairs unchanged', () {
      // Weights are renormalized over present attributes, so a pair carrying
      // no number scores exactly as it did before the attribute existed.
      final score = service.computeScore(
        person('Peter', 'Okafor'),
        person('Peter', 'Okafor'),
      );
      expect(score, closeTo(1.0, 1e-9));
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
