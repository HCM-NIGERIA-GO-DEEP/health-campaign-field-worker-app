# Dedup Engine — Performance Report

Re-measured 2026-09-10 after the engine upgrade (reusable block index,
`mobileNumber` attribute, two-form name comparison, Double Metaphone).

Measured against the real on-device pipeline: a seeded SQLite database read
through `CrudService.searchEntities`, hydrated into `IndividualModel`,
projected by `DedupCheckUtils.projectCorpus`, then scored by
`DedupEngine.findMatchesFor`.

Three corpus sizes, **all candidates in a single boundary** — the worst case for
the engine, since the shipped config filters by `address.localityBoundaryCode`
and every seeded individual shares one code.

## Read this first

**These numbers come from a developer workstation, not a field device.** Treat
them as a lower bound on latency and an indication of *where* time goes.

| | Harness | Production device |
| --- | --- | --- |
| CPU | AMD Ryzen 7 7735HS, 16 cores, 14 GB RAM | low-end ARM, 2–4 GB RAM |
| Dart | `flutter test` — JIT | AOT release build |
| SQLite | system libsqlite3 3.45.1, **unencrypted** | SQLCipher (encrypted reads) |

Encrypted reads, a slower CPU and far less RAM all push the same direction:
slower and tighter than shown. No multiplier is given because none was
measured — an on-device `integration_test` would be needed for that.

**Run-to-run variance is large.** Repeating the same code three times gave
spreads of 9–21% on query time and 9–19% on scoring:

| Metric | 10,000 | 50,000 | 200,000 |
| --- | --- | --- | --- |
| Capped query | 10% | 14% | 2% |
| Full query | 13% | 21% | 16% |
| Scoring | 13% | 19% | 9% |

So **differences under ~20% are not meaningful here**, and none of the figures
below should be read to two significant figures. Anything load-bearing should
be re-measured several times.

There is **no agreed latency budget** for this feature, so this report presents
measurements and does not pass or fail anything.

## Results

`maxCandidates` in the shipped config is **5000**, so the query is capped in
production however large the boundary is. Both paths are measured: the capped
one is what a field worker waits for, the uncapped one is the engine carrying
the whole boundary.

### Production path (query capped at 5000 candidates)

| DB size | Query + hydrate | Project | Score 1 probe | **Total** | Peak RSS |
| --- | --- | --- | --- | --- | --- |
| 10,000 | 1674 ms | 36 ms | 57 ms | **1767 ms** | 326 MB |
| 50,000 | 1527 ms | 88 ms | 237 ms | **1852 ms** | 623 MB |
| 200,000 | 2602 ms | 431 ms | 964 ms | **3997 ms** | 1245 MB |

Project and score are measured on the *full* corpus, so these totals are
pessimistic for the capped path — with 5000 candidates both collapse to tens of
milliseconds. The query column is the honest production figure.

### Uncapped path (every candidate in the boundary scored)

| Candidates | Query + hydrate | Project | Score 1 probe | **Total** | Peak RSS |
| --- | --- | --- | --- | --- | --- |
| 10,000 | 2766 ms | 36 ms | 57 ms | **2859 ms** | 326 MB |
| 50,000 | 14,632 ms | 88 ms | 237 ms | **14,957 ms** | 623 MB |
| 200,000 | 87,032 ms | 431 ms | 964 ms | **88,427 ms** | 1335 MB |

### Blocking and index reuse

Phonetic blocking is a consistent ~4.8x saving. Reusing the index instead of
rebuilding it per call is a further ~5x.

| Candidates | Unblocked | Blocked (index per call) | Blocked (index reused) |
| --- | --- | --- | --- |
| 10,000 | 248.4 ms | 56.8 ms | **12.0 ms** |
| 50,000 | 1151.2 ms | 236.8 ms | **48.0 ms** |
| 200,000 | 4673.2 ms | 963.6 ms | **194.2 ms** |

Index construction alone costs 93 / 190 / 835 ms, which is where the
per-call figures go.

## Findings

### 1. The database read still dominates

Reading and hydrating rows costs far more than matching them: on the production
path the query is **30x** the scoring cost at 10k and still **2.7x** at 200k.
Effort spent making this feature feel faster belongs in the read path.

### 2. The upgrade did not measurably change latency

Comparing against the pre-upgrade report, scoring moved by +5% to +19% — all
inside the 9–19% run-to-run spread, so **no cost can be attributed to the
upgrade**. This is worth stating plainly because the upgrade did add work to
the scoring path: each name is now compared through two spelling forms (up to
four string comparisons instead of one), phonetic matching encodes every form,
and blocking emits keys for both. That work is real but too small to separate
from noise at these sizes, and it is invisible end to end because the read
dominates.

### 3. Hydration degrades super-linearly

| Candidates | Query + hydrate | Rows/second |
| --- | --- | --- |
| 10,000 | 2766 ms | 3615 |
| 50,000 | 14,632 ms | 3417 |
| 200,000 | 87,032 ms | 2298 |

Throughput falls by a third between 10k and 200k, so cost grows faster than
volume: 20x the rows takes 31x the time.

### 4. `maxCandidates` is load-bearing, not a nicety

Without the 5000 cap, a 200,000-person boundary takes **87 seconds** to read.
The cap is the only reason this feature is usable at that scale. It should not
be raised without re-measuring, and the accuracy cost is worth stating plainly:
above 5000 candidates the corpus is silently truncated, so a duplicate outside
the first 5000 rows is never found, with no ordering guarantee on which 5000
are kept.

### 5. Memory is the hard limit on the uncapped path

Peak RSS reaches **1245 MB** at 200k and 1335 MB after projection — roughly
4.5 KB per hydrated individual above a ~340 MB baseline. A typical Android app
heap is a few hundred megabytes, so the uncapped path would be killed on a
field device long before the 87 seconds elapsed. The capped path stays bounded.

### 6. Reuse the index when scoring more than one record

`findMatchesFor` builds the index per call. `buildIndex` plus
`findMatchesUsing` build it once:

```dart
final index = engine.buildIndex(corpus);
for (final incoming in batch) {
  engine.findMatchesUsing(index, incoming, maxResults: 5);
}
```

That is a measured 4.7–5.0x per probe. It changes nothing for the current
one-probe-per-submission flow, which pays the build once either way, but it
matters for any batch pass.

### 7. The boundary scan grows even at a fixed result count

Capped query time rises 1674 → 1527 → 2602 ms while always returning 5000 rows.
The 10k and 50k figures are within noise of each other, but 200k is clearly
higher, so the filter scan scales with total table size rather than with rows
returned. Worth watching as downsynced datasets grow.

### 8. What this report does *not* measure

- **The `mobileNumber` attribute.** The seeded corpus carries no phone numbers,
  so the attribute is skipped throughout. Its value is accuracy, not latency:
  it exists to separate the ~37% of records that collide on name alone. To
  quantify that, the corpus would need phone numbers seeded and the collision
  rate compared with and without.
- **Double Metaphone.** Implemented but not wired in; blocking and phonetic
  scoring still use Soundex.
- **Accuracy.** Match quality is covered by the corpus tests in
  `test/corpus_scale_test.dart`, not here.

## Reproducing

```bash
cd apps/health_campaign_field_worker_app
flutter test --no-pub test/performance/dedup_performance_test.dart \
  --dart-define=DEDUP_PERF_SIZES=10000,50000,200000
```

The harness lives at
`apps/health_campaign_field_worker_app/test/performance/dedup_performance_test.dart`
and defaults to a single 2000-row corpus so a normal `flutter test` run stays
fast. The full run above takes about three minutes. Run it several times before
drawing conclusions from any difference under ~20%.

It must live in the app rather than this package: it needs `digit_data_model`,
`digit_crud_bloc` and `digit_flow_builder` together, and `digit_flow_builder`
cannot resolve its own dependencies standalone.

### Harness notes

Four environment details were needed to exercise the real path, all specific to
running off-device:

- Desktop Linux ships only `libsqlite3.so.0`; the `sqlite3` package looks for
  the unversioned name, so the loader is overridden. On Android the library
  comes from `sqlite3_flutter_libs`.
- `PathProviderPlatform` is faked to a temp directory so `LocalSqlDataStore`
  can open a real database file.
- Hydration decodes through dart_mappable and needs **both** mapper sets —
  `digit_data_model`'s and the app's.
- Seeded rows must carry audit fields, or rebuilding `AuditDetails` throws.

`Isar.initializeIsarCore(download: true)` fetches `libisar.so` into the app
directory on first run. It is gitignored.
