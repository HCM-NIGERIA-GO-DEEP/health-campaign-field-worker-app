@Timeout(Duration(minutes: 45))
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:digit_crud_bloc/digit_crud_bloc.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_dedup_engine/digit_dedup_engine.dart';
import 'package:digit_flow_builder/data/digit_crud_service.dart';
import 'package:digit_flow_builder/flow_builder.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqlite3/open.dart' as sqlite_open;

import 'package:digit_data_model/data_model.init.dart' as data_model_mappers;

import '../../lib/models/data_model.init.dart' as app_mappers;

/// Corpus sizes to measure. Kept small by default so a normal `flutter test`
/// run stays fast; the reported figures come from
///
///   flutter test --no-pub test/performance/dedup_performance_test.dart \
///     --dart-define=DEDUP_PERF_SIZES=10000,50000,200000
const _sizes = String.fromEnvironment('DEDUP_PERF_SIZES', defaultValue: '2000');

/// Everything the config's own `dedupCheck` block specifies.
const _boundaryCode = 'PERF_BOUNDARY';
const _matchThreshold = 0.85;
const _maxResults = 5;
const _maxCandidates = 5000;

/// Name pools shared with the accuracy corpus, so collision behaviour here
/// stays comparable to the figures reported for 1000 records.
const _givenNames = <String>[
  'Musa',
  'Ibrahim',
  'Aliyu',
  'Abubakar',
  'Sani',
  'Yusuf',
  'Umar',
  'Bello',
  'Hassan',
  'Husseini',
  'Ahmed',
  'Mohammed',
  'Muhammad',
  'Suleiman',
  'Adamu',
  'Danjuma',
  'Emmanuel',
  'John',
  'Peter',
  'Samuel',
  'Joseph',
  'Solomon',
  'Istifanus',
  'Yakubu',
  'Zakari',
  'Haruna',
  'Idris',
  'Nuhu',
  'Saidu',
  'Tanko',
  'Audu',
  'Garba',
  'Lawal',
  'Shehu',
  'Kabiru',
  'Nasiru',
  'Rabiu',
  'Bitrus',
  'Aisha',
  'Fatima',
  'Zainab',
  'Hauwa',
  'Maryam',
  'Halima',
  'Amina',
  'Safiya',
  'Rukayya',
  'Hadiza',
  'Grace',
  'Mary',
  'Esther',
  'Blessing',
  'Ruth',
  'Rebecca',
  'Comfort',
  'Patience',
  'Naomi',
  'Talatu',
  'Ladi',
  'Asabe',
];

const _familyNames = <String>[
  'Ibrahim',
  'Mohammed',
  'Musa',
  'Bello',
  'Danjuma',
  'Yakubu',
  'Adamu',
  'Sule',
  'Garba',
  'Haruna',
  'Abubakar',
  'Usman',
  'Aliyu',
  'Sani',
  'Lawal',
  'Bakari',
  'Nuhu',
  'Zakari',
  'Jauro',
  'Manu',
  'Buba',
  'Wakili',
  'Tukur',
  'Ardo',
  'Hamman',
  'Njobdi',
  'Dauda',
  'Yusufu',
  'Iliya',
  'Bitrus',
  'Ishaya',
  'Filibus',
  'Amos',
  'Barnabas',
  'Gambo',
  'Maigari',
  'Tijjani',
  'Abdullahi',
];

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.dir);
  final String dir;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
  @override
  Future<String?> getApplicationSupportPath() async => dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
}

/// Timing and memory for one corpus size.
class _Measurement {
  final int size;
  int candidates = 0;
  int cappedCandidates = 0;
  int queryCappedMs = 0;
  int queryFullMs = 0;
  int projectMs = 0;
  int buildBlocksMs = 0;
  double probeBlockedMs = 0;
  double probeUnblockedMs = 0;
  double probeIndexedMs = 0;
  int rssAfterSeedMb = 0;
  int rssAfterQueryMb = 0;
  int rssAfterProjectMb = 0;
  int matchesFound = 0;

  _Measurement(this.size);

  /// What a field worker waits for today: the query is capped at
  /// `maxCandidates`, so this is the production figure.
  int get cappedTotalMs => queryCappedMs + projectMs + probeBlockedMs.round();

  /// The same pipeline with the cap lifted, i.e. every candidate scored.
  int get uncappedTotalMs => queryFullMs + projectMs + probeBlockedMs.round();
}

int _rssMb() => (ProcessInfo.currentRss / (1024 * 1024)).round();

void main() {
  final sizes = _sizes
      .split(',')
      .map((s) => int.tryParse(s.trim()))
      .whereType<int>()
      .toList();

  final results = <_Measurement>[];

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);

    // Hydration decodes rows through dart_mappable, which the app initializes
    // at startup.
    data_model_mappers.initializeMappers();
    app_mappers.initializeMappers();

    // Desktop Linux ships only the versioned soname, while the sqlite3 package
    // looks for the unversioned one. On Android the app gets its library from
    // sqlite3_flutter_libs instead, so this only affects the harness.
    if (Platform.isLinux) {
      sqlite_open.open
          .overrideForAll(() => DynamicLibrary.open('libsqlite3.so.0'));
    }
  });

  tearDownAll(() {
    // ignore: avoid_print
    print('\n=== DEDUP PERFORMANCE ===');
    for (final r in results) {
      // ignore: avoid_print
      print('SIZE=${r.size} '
          'queryCapped=${r.queryCappedMs}ms(${r.cappedCandidates}) '
          'queryFull=${r.queryFullMs}ms(${r.candidates}) '
          'project=${r.projectMs}ms buildBlocks=${r.buildBlocksMs}ms '
          'probeBlocked=${r.probeBlockedMs.toStringAsFixed(1)}ms '
          'probeUnblocked=${r.probeUnblockedMs.toStringAsFixed(1)}ms '
          'probeIndexed=${r.probeIndexedMs.toStringAsFixed(1)}ms '
          'cappedTotal=${r.cappedTotalMs}ms '
          'uncappedTotal=${r.uncappedTotalMs}ms '
          'rssSeed=${r.rssAfterSeedMb}MB rssQuery=${r.rssAfterQueryMb}MB '
          'rssProject=${r.rssAfterProjectMb}MB matches=${r.matchesFound}');
    }
  });

  for (final size in sizes) {
    test('corpus of $size individuals in one boundary', () async {
      final measurement = _Measurement(size);
      final tempDir = Directory.systemTemp.createTempSync('dedup_perf_$size');
      PathProviderPlatform.instance = _FakePathProvider(tempDir.path);

      final isar = Isar.instanceNames.isEmpty
          ? await Isar.open([OpLogSchema], directory: tempDir.path)
          : Isar.getInstance()!;
      final sql = LocalSqlDataStore();

      try {
        // ---- Seed -------------------------------------------------------
        // Batched so seeding does not dominate the run; the figures below
        // measure the read path, not this.
        final random = Random(20260910 + size);
        const chunk = 5000;

        // Hydration rebuilds AuditDetails from these, and throws without them,
        // so real rows always carry them.
        final now = DateTime.now().millisecondsSinceEpoch;
        final audit = Value<String>('perf-user');
        final auditTime = Value<int>(now);

        for (var start = 0; start < size; start += chunk) {
          final end = min(start + chunk, size);
          await sql.batch((batch) {
            for (var i = start; i < end; i++) {
              final ref = 'perf-$i';
              batch.insert(
                sql.individual,
                IndividualCompanion.insert(
                  clientReferenceId: ref,
                  tenantId: const Value('perf'),
                  auditCreatedBy: audit,
                  auditCreatedTime: auditTime,
                  clientCreatedBy: audit,
                  clientCreatedTime: auditTime,
                ),
              );
              batch.insert(
                sql.name,
                NameCompanion.insert(
                  individualClientReferenceId: Value(ref),
                  givenName:
                      Value(_givenNames[random.nextInt(_givenNames.length)]),
                  familyName:
                      Value(_familyNames[random.nextInt(_familyNames.length)]),
                  auditCreatedBy: audit,
                  auditCreatedTime: auditTime,
                  clientCreatedBy: audit,
                  clientCreatedTime: auditTime,
                ),
              );
              batch.insert(
                sql.address,
                AddressCompanion.insert(
                  relatedClientReferenceId: Value(ref),
                  localityBoundaryCode: const Value(_boundaryCode),
                  auditCreatedBy: audit,
                  auditCreatedTime: auditTime,
                  clientCreatedBy: audit,
                  clientCreatedTime: auditTime,
                ),
              );
              batch.insert(
                sql.identifier,
                IdentifierCompanion.insert(
                  clientReferenceId: 'ident-$i',
                  individualClientReferenceId: ref,
                  identifierType: const Value('UNIQUE_BENEFICIARY_ID'),
                  identifierId: Value('ID$i'),
                  auditCreatedBy: audit,
                  auditCreatedTime: auditTime,
                  clientCreatedBy: audit,
                  clientCreatedTime: auditTime,
                ),
              );
            }
          });
        }
        measurement.rssAfterSeedMb = _rssMb();

        // ---- Query: exactly what DedupCheckUtils runs -------------------
        CrudBlocSingleton().setData(
          crudService: CrudService(
            searchEntityRepository:
                SearchEntityRepository(sql, IndividualOpLogManager(isar)),
            relationshipMap: const [
              RelationshipMapping(
                  from: 'name',
                  to: 'individual',
                  localKey: 'individualClientReferenceId',
                  foreignKey: 'clientReferenceId'),
              RelationshipMapping(
                  from: 'identifier',
                  to: 'individual',
                  localKey: 'individualClientReferenceId',
                  foreignKey: 'clientReferenceId'),
              RelationshipMapping(
                  from: 'address',
                  to: 'individual',
                  localKey: 'relatedClientReferenceId',
                  foreignKey: 'clientReferenceId'),
            ],
            nestedModelMappings: const [
              NestedModelMapping(
                rootModel: 'individual',
                fields: {
                  'name': NestedFieldMapping(
                    table: 'name',
                    localKey: 'clientReferenceId',
                    foreignKey: 'individualClientReferenceId',
                    type: NestedMappingType.one,
                  ),
                  'identifiers': NestedFieldMapping(
                    table: 'identifier',
                    localKey: 'clientReferenceId',
                    foreignKey: 'individualClientReferenceId',
                    type: NestedMappingType.many,
                  ),
                },
              ),
            ],
          ),
          dynamicEntityModelListener: EntityModelMapMapper(),
        );

        final service = CrudBlocSingleton().crudService;
        if (!service.isInitialized) service.init();

        Future<List<EntityModel>> runQuery(int limit) async {
          final (grouped, _) = await service.searchEntities(
            query: GlobalSearchParameters(
              filters: const [
                SearchFilter(
                  field: 'localityBoundaryCode',
                  operator: 'equals',
                  value: _boundaryCode,
                  root: 'address',
                ),
              ],
              select: const ['individual'],
              primaryModel: 'individual',
              pagination: PaginationParams(limit: limit, offset: 0),
            ),
          );
          return grouped['individual'] ?? const <EntityModel>[];
        }

        // The shipped config caps the corpus at maxCandidates, so measure the
        // query twice: once as production runs it, once with every candidate
        // returned so the engine sees the whole boundary.
        final cappedWatch = Stopwatch()..start();
        final capped = await runQuery(_maxCandidates);
        cappedWatch.stop();
        measurement.queryCappedMs = cappedWatch.elapsedMilliseconds;
        measurement.cappedCandidates = capped.length;

        final fullWatch = Stopwatch()..start();
        final entities = await runQuery(size);
        fullWatch.stop();
        measurement.queryFullMs = fullWatch.elapsedMilliseconds;
        measurement.rssAfterQueryMb = _rssMb();

        // ---- Projection -------------------------------------------------
        final projectWatch = Stopwatch()..start();
        final corpus = DedupCheckUtils.projectCorpus(entities);
        projectWatch.stop();
        measurement.projectMs = projectWatch.elapsedMilliseconds;
        measurement.candidates = corpus.length;
        measurement.rssAfterProjectMb = _rssMb();

        // ---- Scoring ----------------------------------------------------
        final probe = {'givenName': 'Musa', 'familyName': 'Ibrahim'};

        // Blocking is rebuilt inside every findMatchesFor call, so time it
        // on its own to show how much of a probe that accounts for.
        final blocksWatch = Stopwatch()..start();
        BlockingStrategy().buildBlocks(corpus);
        blocksWatch.stop();
        measurement.buildBlocksMs = blocksWatch.elapsedMilliseconds;

        final engine = DedupEngine(matchThreshold: _matchThreshold);
        engine.findMatchesFor(probe, corpus, maxResults: _maxResults); // warm

        const probes = 5;
        final blockedWatch = Stopwatch()..start();
        List<DedupMatch> matches = const [];
        for (var i = 0; i < probes; i++) {
          matches =
              engine.findMatchesFor(probe, corpus, maxResults: _maxResults);
        }
        blockedWatch.stop();
        measurement.probeBlockedMs = blockedWatch.elapsedMilliseconds / probes;
        measurement.matchesFound = matches.length;

        // With the index built once up front, a probe skips the rebuild that
        // dominated the per-call path.
        final reusableIndex = engine.buildIndex(corpus);
        engine.findMatchesUsing(reusableIndex, probe, maxResults: _maxResults);
        final indexedWatch = Stopwatch()..start();
        for (var i = 0; i < probes; i++) {
          engine.findMatchesUsing(reusableIndex, probe,
              maxResults: _maxResults);
        }
        indexedWatch.stop();
        measurement.probeIndexedMs = indexedWatch.elapsedMilliseconds / probes;
        final unblocked =
            DedupEngine(matchThreshold: _matchThreshold, useBlocking: false);
        unblocked.findMatchesFor(probe, corpus, maxResults: _maxResults);
        final unblockedWatch = Stopwatch()..start();
        for (var i = 0; i < probes; i++) {
          unblocked.findMatchesFor(probe, corpus, maxResults: _maxResults);
        }
        unblockedWatch.stop();
        measurement.probeUnblockedMs =
            unblockedWatch.elapsedMilliseconds / probes;

        results.add(measurement);

        // The run is a measurement, not a threshold check: there is no agreed
        // budget yet. Assert only that the pipeline actually did work, so a
        // silent no-op cannot be reported as fast.
        expect(measurement.candidates, greaterThan(0));
      } finally {
        await sql.close();
        tempDir.deleteSync(recursive: true);
      }
    });
  }
}
