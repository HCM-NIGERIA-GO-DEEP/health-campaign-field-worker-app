import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/id_status.dart';
import 'package:digit_flow_builder/action_handler/executors/transformer_executor.dart';
import 'package:digit_data_converter/src/transformer_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:digit_flow_builder/action_handler/action_config.dart';
import 'package:health_campaign_field_worker_app/executors/update_identifier_status_executor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/data/local_store/app_shared_preferences.dart';
import 'package:health_campaign_field_worker_app/data/repositories/remote/boundary_beneficiary_id.dart';
import 'package:health_campaign_field_worker_app/models/boundary_beneficiary_id.dart';
import 'package:health_campaign_field_worker_app/services/beneficiary_id_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryPool extends Fake
    implements LocalRepository<UniqueIdPoolModel, UniqueIdPoolSearchModel> {
  final rows = <String, UniqueIdPoolModel>{};
  @override
  Future<List<UniqueIdPoolModel>> search(UniqueIdPoolSearchModel query) async =>
      rows.values
          .where((r) =>
              (query.id == null || r.id == query.id) &&
              (query.userUuid == null || r.userUuid == query.userUuid) &&
              (query.status == null || r.status == query.status))
          .toList();
  @override
  Future<void> update(UniqueIdPoolModel entity,
      {bool createOpLog = true,
      DataOperation dataOperation = DataOperation.update}) async {
    expect(createOpLog, false);
    rows[entity.id] = entity;
  }

  @override
  Future<void> bulkCreate(List<UniqueIdPoolModel> entities) async {
    for (final row in entities) {
      rows[row.id] = row;
    }
  }
}

class MemoryBoundaries extends Fake
    implements LocalRepository<BoundaryModel, BoundarySearchModel> {
  final rows = [
    BoundaryModel(
        code: 'COMMUNITY',
        name: 'Community',
        label: 'Community',
        materializedPath: 'COUNTRY.DP.COMMUNITY'),
    BoundaryModel(
        code: 'DP',
        name: 'Yebaya MCHP',
        label: 'Distribution Point',
        materializedPath: 'COUNTRY.DP'),
    BoundaryModel(
        code: 'OTHER',
        name: 'Other_Point',
        label: 'Distribution Point',
        materializedPath: 'COUNTRY.OTHER'),
  ];
  @override
  Future<List<BoundaryModel>> search(BoundarySearchModel query) async =>
      rows.where((r) => r.code == query.codes).toList();
}

class Prefixes extends BoundaryBeneficiaryIdRepository {
  Map<String, int> values = {'DP': 42, 'OTHER': 43};
  bool fail = false;
  bool dummy = false;
  int calls = 0;
  Prefixes() : super(Dio(), tenantId: 'si');
  @override
  Future<BoundaryBeneficiaryIdMap> fetch() async {
    calls++;
    if (fail) throw StateError('offline');
    return BoundaryBeneficiaryIdMap(values, isDummy: dummy);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryPool pool;
  late MemoryBoundaries boundaries;
  late Prefixes prefixes;
  late AppSharedPreferences cache;
  late BeneficiaryIdService service;
  var sequence = 0;
  UniqueIdPoolModel row(String id,
      {String user = 'registrar', String tenant = 'si', bool server = true}) {
    final result = UniqueIdPoolModel(
        id: id,
        status: IdStatus.unAssigned.toValue(),
        deviceUuid: 'device',
        userUuid: user,
        tenantId: tenant);
    return server
        ? result.copyWith(
            additionalFields: BeneficiaryIdService.metadata(result,
                {'beneficiaryIdSource': BeneficiaryIdService.serverSource}))
        : result;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cache = AppSharedPreferences();
    await cache.init();
    pool = MemoryPool();
    boundaries = MemoryBoundaries();
    prefixes = Prefixes();
    service = BeneficiaryIdService(
        pool: pool,
        boundaries: boundaries,
        cache: cache,
        prefixes: prefixes,
        scope: 'campaign-${sequence++}',
        userUuid: 'registrar',
        tenantId: 'si');
  });
  test(
      'numeric prefix is cached; raw pool ID stays raw and unassigned until save',
      () async {
    pool.rows['raw_123'] = row('raw_123');
    await service.prepare(boundaries.rows.first);
    final result = await service.allocate(boundaries.rows.first, 'household-1');
    expect(result.rawId, 'raw_123');
    expect(result.identifier, '42_raw_123');
    expect(pool.rows.keys, ['raw_123']);
    expect(pool.rows['raw_123']!.status, IdStatus.unAssigned.toValue());
    expect(
        BeneficiaryIdService.field(
            pool.rows['raw_123']!, 'composedBeneficiaryId'),
        result.identifier);
    await service.prepare(boundaries.rows.first);
    expect(prefixes.calls, 1);
    await cache.init();
    expect(await service.compose(boundaries.rows.first, 'raw_123'),
        result.identifier);
  });
  test('offline fallback uses the actual DP name, including underscores',
      () async {
    prefixes.fail = true;
    pool.rows['raw_1'] = row('raw_1');
    await service.prepare(boundaries.rows.last);
    expect((await service.allocate(boundaries.rows.last, 'h')).identifier,
        'Other_Point_raw_1');
  });
  test(
      'a reservation keeps its displayed ID across boundary and prefix changes',
      () async {
    prefixes.fail = true;
    pool.rows['raw'] = row('raw');
    final first = await service.allocate(boundaries.rows.first, 'h');
    await service.prepare(boundaries.rows.last);
    final retry = await service.allocate(boundaries.rows.last, 'h');
    expect(first.identifier, 'Yebaya MCHP_raw');
    expect(retry.identifier, first.identifier);
    expect(await service.available(), isEmpty);
  });
  test(
      'parallel households cannot reserve the same ID; retry reuses its own ID',
      () async {
    pool.rows.addAll({'1': row('1'), '2': row('2')});
    final allocated = await Future.wait([
      service.allocate(boundaries.rows.first, 'a'),
      service.allocate(boundaries.rows.first, 'b')
    ]);
    expect(allocated.map((r) => r.rawId).toSet().length, 2);
    expect((await service.allocate(boundaries.rows.first, 'a')).identifier,
        allocated.first.identifier);
  });
  test(
      'old locally generated, other-user and other-tenant rows cannot be allocated',
      () async {
    pool.rows.addAll({
      'local': row('local', server: false),
      'other': row('other', user: 'other'),
      'tenant': row('tenant', tenant: 'lr')
    });
    expect(await service.available(), isEmpty);
    expect(service.allocate(boundaries.rows.first, 'h'), throwsStateError);
  });
  test(
      're-download preserves consumed and reserved rows and marks fresh server rows',
      () async {
    pool.rows['used'] =
        row('used').copyWith(status: IdStatus.assigned.toValue());
    pool.rows['reserved'] = row('reserved');
    final allocated = await service.allocate(boundaries.rows.first, 'h');
    await BeneficiaryIdService.saveDownloaded(pool, [
      row('used', server: false),
      row('reserved', server: false),
      row('new', server: false)
    ]);
    expect(pool.rows['used']!.status, IdStatus.assigned.toValue());
    expect(
        BeneficiaryIdService.field(
            pool.rows['reserved']!, 'composedBeneficiaryId'),
        allocated.identifier);
    expect((await service.available()).map((r) => r.id), ['new']);
  });
  test('missing DP name fails instead of substituting a boundary code',
      () async {
    boundaries.rows[1] =
        BoundaryModel(code: 'DP', name: 'DP', label: 'Distribution Point');
    expect(service.distributionPoint(boundaries.rows.first), throwsStateError);
  });
  test('dummy mapping composes numeric IDs without polluting persistent cache',
      () async {
    prefixes.dummy = true;
    prefixes.values = {'DP': 89};
    pool.rows['raw'] = row('raw');
    final result =
        await service.allocate(boundaries.rows.first, 'dummy-household');
    expect(result.identifier, '89_raw');
    expect(cache.getBoundaryNumericId(service.scope, 'DP'), isNull);
  });
  test('cache does not leak a prefix across campaigns', () async {
    await service.prepare(boundaries.rows.first);
    final next = BeneficiaryIdService(
        pool: pool,
        boundaries: boundaries,
        cache: cache,
        prefixes: prefixes,
        scope: 'another',
        userUuid: 'registrar',
        tenantId: 'si');
    expect(await next.compose(boundaries.rows.first, 'raw'), 'Yebaya MCHP_raw');
  });
  test(
      'displayed composed identifier passes unchanged into the individual transformer',
      () async {
    pool.rows['raw'] = row('raw');
    await service.prepare(boundaries.rows.first);
    final allocated = await service.allocate(boundaries.rows.first, 'h');
    final entries = TransformerExecutor.buildIdentifierEntries({
      'householdDetails': {
        'identifiers': 'UNIQUE_BENEFICIARY_ID,${allocated.identifier}'
      }
    }, FormEntityMapper(config: {}));
    expect(entries.single['identifierId'], allocated.identifier);
    expect(entries.single['identifierType'], 'UNIQUE_BENEFICIARY_ID');
  });
  testWidgets(
      'assignment finds the raw pool row from the persisted composite ID',
      (tester) async {
    FlowBuilderSingleton().setInitialData(
        loggedInUserUuid: 'registrar',
        maxRadius: 0,
        projectId: 'campaign',
        selectedBeneficiaryType: BeneficiaryType.household,
        projectType: null,
        selectedProject:
            ProjectModel(id: 'campaign', name: 'Campaign', tenantId: 'si'),
        loggedInUser: null);
    pool.rows['raw_with_underscores'] = row('raw_with_underscores');
    final allocation = (await tester
        .runAsync(() => service.allocate(boundaries.rows.last, 'household')))!;
    final individual = IndividualModel(
        clientReferenceId: 'head',
        tenantId: 'si',
        identifiers: [
          IdentifierModel(
              clientReferenceId: 'identifier',
              individualClientReferenceId: 'head',
              identifierType: 'UNIQUE_BENEFICIARY_ID',
              identifierId: allocation.identifier),
        ]);
    late BuildContext context;
    await tester.pumpWidget(RepositoryProvider<
            LocalRepository<UniqueIdPoolModel, UniqueIdPoolSearchModel>>.value(
        value: pool,
        child: MaterialApp(home: Builder(builder: (c) {
          context = c;
          return const SizedBox();
        }))));
    await UpdateIdentifierStatusExecutor().execute(
        ActionConfig(
            action: 'UPDATE_IDENTIFIER_STATUS',
            actionType: 'UPDATE_IDENTIFIER_STATUS',
            properties: {}),
        context,
        {
          'entities': [individual]
        });
    expect(
        pool.rows['raw_with_underscores']!.status, IdStatus.assigned.toValue());
    expect(individual.identifiers!.single.identifierId, allocation.identifier);
    final retry = await tester
        .runAsync(() => service.allocate(boundaries.rows.last, 'household'));
    expect(retry!.identifier, allocation.identifier);
    expect(await service.available(), isEmpty);
  });
  test('numeric map rejects malformed prefixes and accepts zero', () {
    expect(
        BoundaryBeneficiaryIdMap.fromJson({'DP': 0}).boundaryToNumericId['DP'],
        0);
    expect(() => BoundaryBeneficiaryIdMap.fromJson({'DP': 'bad'}),
        throwsFormatException);
    expect(() => BoundaryBeneficiaryIdMap.fromJson({'DP': -1}),
        throwsFormatException);
  });
}
