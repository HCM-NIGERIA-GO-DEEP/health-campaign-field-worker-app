# Beneficiary Deduplication Engine - Flutter Package

Offline-capable fuzzy matching package for detecting duplicate beneficiary registrations in DIGIT HCM mobile app.

## Overview

Detects duplicate beneficiary registrations on mobile devices using:
- Phonetic algorithms (Soundex, Double Metaphone)
- String similarity (Jaro-Winkler, Levenshtein)
- GPS proximity scoring (Haversine distance)
- Multi-attribute weighted matching

Designed to work entirely offline on the mobile device.

## Package Structure

```
lib/
  digit_dedup_engine.dart        - Public API (library barrel file)
  src/
    dedup_engine.dart            - Main orchestrator
    matching_service.dart        - Multi-attribute scoring
    blocking_strategy.dart       - Phonetic blocking for search space reduction
    algorithms/
      soundex.dart               - Soundex phonetic encoding
      double_metaphone.dart      - Double Metaphone encoding (not implemented)
      jaro_winkler.dart          - Jaro-Winkler string similarity
      levenshtein.dart           - Levenshtein edit distance
  models/
    dedup_result.dart            - Duplicate pair found within a batch
    dedup_match.dart             - Corpus record matching a probe record
    candidate_pair.dart          - Candidate pair model
  utils/
    gps_utils.dart               - Haversine distance and proximity scoring
    string_utils.dart            - Name normalization utilities
```

## Implementation status

`DoubleMetaphone.encode` still throws `UnimplementedError`. Everything else is
implemented, and nothing in the package calls Double Metaphone -- phonetic
blocking and phonetic scoring both use Soundex. Implement it only when there is
a case Soundex demonstrably gets wrong.

## Pattern

This package follows the same structure as `digit_data_converter` in the Flutter packages. See `flutter/packages/digit_data_converter/` for reference.

## Usage

### Searching for duplicates of one record

The registration screens use this path: score an incoming registration against
the records already on the device.

```dart
import 'package:digit_dedup_engine/digit_dedup_engine.dart';

final engine = DedupEngine(matchThreshold: 0.85);

final matches = engine.findMatchesFor(
  {'givenName': 'Pitr', 'familyName': 'Okafor'},
  existingRecords,
  maxResults: 5,
);

for (final match in matches) {
  // `record` is the corpus entry as passed in, so callers can read their own
  // passthrough keys (ids, client reference ids) straight off it.
  print('${match.record['givenName']} scored ${match.scorePercentage}%');
}
```

### Deduplicating a whole batch

```dart
final results = engine.findDuplicates(beneficiaryRecords);

for (final result in results) {
  print('Records ${result.recordIndex1} and ${result.recordIndex2}: '
        'score ${result.score}');
}
```

## Scoring

A record is a `Map<String, dynamic>`. These keys are scored; any other key is
carried through untouched.

| Key | Weight | How it is scored |
| --- | --- | --- |
| `givenName` | 0.25 | Jaro-Winkler (70%) blended with normalized Levenshtein (30%) |
| `familyName` | 0.20 | same as `givenName` |
| `fatherName` | 0.10 | same as `givenName` |
| `phoneticMatch` | 0.10 | fraction of the compared name fields whose Soundex codes agree |
| `dateOfBirth` | 0.15 | 1.0 on the same day, 0.5 on the same year, else 0.0 |
| `gender` | 0.05 | exact match |
| `gpsProximity` | 0.15 | Haversine distance, 1.0 within 50m decaying to 0.0 at 500m |

Only attributes present on **both** records contribute, and the contributing
weights are renormalized to sum to 1.0. A pair carrying names alone therefore
scores on the same 0..1 scale as a fully populated pair, instead of being
capped at the names' share of the weights.

`dateOfBirth` accepts a `DateTime`, epoch milliseconds (as `int` or `String`),
an ISO-8601 string, or `dd/MM/yyyy`.

Pass `weights` to `MatchingService` to override the table:

```dart
DedupEngine(
  matchingService: MatchingService(weights: {'givenName': 0.6, 'familyName': 0.4}),
);
```

## Blocking

Comparing every record against every other is O(n^2), so records are grouped
into blocks by the Soundex code of each name field, and only records sharing a
block are scored. A record is filed under one block per name attribute, so a
typo in the given name can still be caught through the family name.

The trade-off is a small chance of a miss: a duplicate whose given *and* family
names both encode differently is never scored. Pass `useBlocking: false` to
compare against every record instead.

```dart
DedupEngine(useBlocking: false);
```

## Name normalization

Names are lowercased, stripped of diacriticals, and collapsed to single spaces
before matching, then run through `StringUtils.removeAffixes`, which drops
non-identifying prefixes (`al-`, `el-`, `m'`, `d'`, ...) and standalone
connector words (`bin`, `ibn`, `abu`, ...) common in the region's names. An
affix is only stripped when at least two characters remain, so short names
survive intact.

## Tests

```
flutter test
```
