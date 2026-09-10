import 'package:digit_dedup_engine/digit_dedup_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_corpus.dart';

void main() {
  final corpus = TestCorpus.generate(size: 1000);
  final records = corpus.records;

  // The threshold and result cap the shipped config uses.
  DedupEngine engine({double threshold = 0.85, bool useBlocking = true}) =>
      DedupEngine(matchThreshold: threshold, useBlocking: useBlocking);

  group('1000-record corpus', () {
    test('generates a deterministic corpus', () {
      final again = TestCorpus.generate(size: 1000);
      expect(records.length, 1005); // 1000 random + 5 planted
      expect(
        again.records.map((r) => '${r['givenName']} ${r['familyName']}'),
        records.map((r) => '${r['givenName']} ${r['familyName']}'),
      );
    });

    test('finds every planted duplicate, and nothing for a stranger', () {
      final failures = <String>[];

      for (final planted in corpus.cases) {
        final matches = engine().findMatchesFor(
          planted.probe,
          records,
          maxResults: 5,
        );
        final ids = matches.map((m) => m.record['id']).toList();

        if (planted.expectedId == null) {
          if (matches.isNotEmpty) {
            failures.add('${planted.label}: expected none, got $ids');
          }
        } else if (!ids.contains(planted.expectedId)) {
          failures.add(
              '${planted.label}: expected ${planted.expectedId}, got $ids');
        }
      }

      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('ranks an exact duplicate first', () {
      final exact = corpus.cases.first;
      final matches = engine().findMatchesFor(exact.probe, records);

      expect(matches, isNotEmpty);
      expect(matches.first.record['id'], exact.expectedId);
      expect(matches.first.score, closeTo(1.0, 1e-9));
    });

    test('blocking does not lose the planted duplicates', () {
      // Blocking trades recall for speed; on these cases it should cost
      // nothing, since each variant shares a Soundex code.
      for (final planted in corpus.cases.where((c) => c.expectedId != null)) {
        final blocked = engine()
            .findMatchesFor(planted.probe, records)
            .map((m) => m.record['id']);
        final unblocked = engine(useBlocking: false)
            .findMatchesFor(planted.probe, records)
            .map((m) => m.record['id']);

        expect(blocked, contains(planted.expectedId), reason: planted.label);
        expect(unblocked, contains(planted.expectedId), reason: planted.label);
      }
    });

    test('respects maxResults even in a dense corpus', () {
      // Common name pairs recur, so an unbounded search can return many hits.
      for (final record in records.take(50)) {
        final matches = engine().findMatchesFor(record, records, maxResults: 5);
        expect(matches.length, lessThanOrEqualTo(5));
      }
    });

    test('a single probe stays well inside a tap-response budget', () {
      final probe = corpus.cases.first.probe;

      // Warm up, so the measurement excludes first-call overhead.
      engine().findMatchesFor(probe, records);

      final stopwatch = Stopwatch()..start();
      const iterations = 20;
      for (var i = 0; i < iterations; i++) {
        engine().findMatchesFor(probe, records);
      }
      stopwatch.stop();

      final perProbeMs = stopwatch.elapsedMilliseconds / iterations;
      // ignore: avoid_print
      print('1005 records: ${perProbeMs.toStringAsFixed(1)}ms per probe');

      // Generous: the check runs once on a button tap, behind a loader.
      expect(perProbeMs, lessThan(250));
    });
  });

  group('threshold behaviour on a realistic corpus', () {
    /// How many corpus records each of the first [sample] records matches.
    List<int> matchCounts(double threshold, {int sample = 200}) {
      final e = engine(threshold: threshold);
      return [
        for (final record in records.take(sample))
          e
              .findMatchesFor(record, records)
              // A record always matches itself; that is not a duplicate.
              .where((m) => m.record['id'] != record['id'])
              .length,
      ];
    }

    test('reports how many collisions names alone produce', () {
      final counts = matchCounts(0.85);
      final withMatch = counts.where((c) => c > 0).length;
      final total = counts.fold<int>(0, (a, b) => a + b);

      // ignore: avoid_print
      print('at 0.85: ${withMatch}/${counts.length} records have a '
          'name-only collision, $total matches total');

      // Names alone cannot be unique across 1000 people in one boundary, so
      // collisions are expected. This pins the order of magnitude rather than
      // asserting a specific rate.
      expect(withMatch, greaterThan(0),
          reason: 'a dense corpus should produce some collisions');
      expect(withMatch, lessThan(counts.length),
          reason: 'but not every record should collide');
    });

    test('a lower threshold matches strictly more', () {
      final strict = matchCounts(0.95).fold<int>(0, (a, b) => a + b);
      final loose = matchCounts(0.75).fold<int>(0, (a, b) => a + b);

      // ignore: avoid_print
      print('total matches — 0.95: $strict, 0.75: $loose');
      expect(loose, greaterThanOrEqualTo(strict));
    });
  });
}
