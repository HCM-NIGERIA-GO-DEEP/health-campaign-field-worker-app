# Dedup Engine — Performance Report

Measured 2026-09-10 against the real on-device pipeline: a seeded SQLite
database read through `CrudService.searchEntities`, hydrated into
`IndividualModel`, projected by `DedupCheckUtils.projectCorpus`, then scored by
`DedupEngine.findMatchesFor`.

Three corpus sizes, **all candidates in a single boundary** — the worst case for
the engine, since the shipped config filters by
`address.localityBoundaryCode` and every seeded individual shares one code.

## Read this first

These numbers come from a **developer workstation, not a field device**. Treat
them as a lower bound on latency and an indication of *where* time goes, not as
the figures a field worker will see. Specifically:

| | Harness | Production device |
| --- | --- | --- |
| CPU | AMD Ryzen 7 7735HS, 16 cores, 14 GB RAM | low-end ARM, 2–4 GB RAM |
| Dart | `flutter test` — JIT | AOT release build |
| SQLite | system libsqlite3 3.45.1, **unencrypted** | SQLCipher (encrypted reads) |

Encrypted reads, a slower CPU and far less RAM all push the same direction:
slower and tighter than shown. No multiplier is given because none was
measured — an on-device `integration_test` would be needed for authoritative
figures.

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
| 10,000 | 1487 ms | 26 ms | 47 ms | **1560 ms** | 328 MB |
| 50,000 | 1510 ms | 70 ms | 235 ms | **1815 ms** | 574 MB |
| 200,000 | 2566 ms | 263 ms | 944 ms | **3773 ms** | 1244 MB |

Project and score are measured on the *full* corpus, so the totals above are
pessimistic for the capped path — with 5000 candidates both collapse to tens of
milliseconds. The query column is the honest production figure.

### Uncapped path (every candidate in the boundary scored)

| Candidates | Query + hydrate | Project | Score 1 probe | **Total** | Peak RSS |
| --- | --- | --- | --- | --- | --- |
| 10,000 | 2596 ms | 26 ms | 47 ms | **2669 ms** | 328 MB |
| 50,000 | 14,508 ms | 70 ms | 235 ms | **14,813 ms** | 574 MB |
| 200,000 | 85,168 ms | 263 ms | 944 ms | **86,375 ms** | 1313 MB |

### Blocking

Phonetic blocking is a consistent **4.8× speed-up** at every size.

| Candidates | Blocked | Unblocked | Speed-up |
| --- | --- | --- | --- |
| 10,000 | 47.2 ms | 225.8 ms | 4.8× |
| 50,000 | 235.2 ms | 1138.4 ms | 4.8× |
| 200,000 | 943.8 ms | 4539.0 ms | 4.8× |

## Findings

### 1. The database read dominates; the engine is not the bottleneck

At every size, reading and hydrating rows costs far more than matching them.
On the production path the query is **31×** the scoring cost at 10k and still
**2.7×** at 200k. Any effort to make this feature feel faster should go into the
read path — projection and scoring are already cheap.

### 2. Hydration degrades super-linearly

| Candidates | Query + hydrate | Rows/second |
| --- | --- | --- |
| 10,000 | 2596 ms | 3852 |
| 50,000 | 14,508 ms | 3446 |
| 200,000 | 85,168 ms | 2348 |

Throughput falls by a third between 10k and 200k, so cost grows faster than
volume: 20× the rows takes 33× the time.

### 3. `maxCandidates` is load-bearing, not a nicety

Without the 5000 cap, a 200,000-person boundary takes **85 seconds** to read.
The cap is the only reason this feature is usable at that scale. It should not
be raised without re-measuring, and the accuracy cost is worth stating plainly:
above 5000 candidates the corpus is silently truncated, so a duplicate outside
the first 5000 rows is never found. There is no ordering guarantee on which
5000 are kept.

### 4. Memory is the hard limit on the uncapped path

Peak RSS reaches **1244 MB** at 200k and 1313 MB after projection — roughly
4.6 KB per hydrated individual on top of a ~340 MB baseline. A typical Android
app heap is a few hundred megabytes, so the uncapped path would be killed on a
field device long before the 85 seconds elapsed. The capped path stays bounded.

### 5. Most of a probe is rebuilding the block index

`DedupEngine.findMatchesFor` calls `BlockingStrategy.buildBlocks(records)` on
**every** invocation, so the index is rebuilt per probe rather than reused.

| Candidates | `buildBlocks` alone | Whole probe | Share |
| --- | --- | --- | --- |
| 10,000 | 63 ms* | 47.2 ms | — |
| 50,000 | 189 ms | 235.2 ms | 80 % |
| 200,000 | 750 ms | 943.8 ms | 79 % |

\* measured cold and once, whereas the probe figure averages five warm calls, so
the small-corpus number is inflated by JIT warm-up. The 50k and 200k rows are
the reliable ones.

Roughly **80 %** of a probe is index construction. Building the index once and
reusing it across probes would cut probe cost by about 5× and matters most for
any future flow that scores several records in one pass — the current
single-probe-per-submission flow pays it once.

### 6. The boundary scan grows even at a fixed result count

Capped query time rises 1487 → 1510 → 2566 ms while always returning 5000 rows,
so the filter scan itself scales with total table size, not just with rows
returned. Worth watching as downsynced datasets grow.

## Reproducing

```bash
cd apps/health_campaign_field_worker_app
flutter test --no-pub test/performance/dedup_performance_test.dart \
  --dart-define=DEDUP_PERF_SIZES=10000,50000,200000
```

The harness lives at
`apps/health_campaign_field_worker_app/test/performance/dedup_performance_test.dart`
and defaults to a single 2000-row corpus so a normal `flutter test` run stays
fast. The full run above takes about three minutes.

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
