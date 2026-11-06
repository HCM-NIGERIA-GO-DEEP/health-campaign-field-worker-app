// Probe for the Kaduna QA report "I created a record and proximity search
// does not show it" (2026-11-06).
//
// Runs the REAL proximity pipeline on a real SQLite file:
//   local repositories (household / individual / member create)
//   -> CrudService.searchEntities -> SearchEntityRepository -> QueryBuilder
//   -> FlowCrudBloc.onTransition -> WrapperBuilder (Kaduna wrapperConfig)
//   -> SearchStateManager pagination window (what REFRESH_SEARCH reads).
// The search parameters are exactly what ProximitySearchWidget + SearchExecutor
// send for Kaduna's REGISTRATION config: one `within` filter rooted on
// `address`, radius 5 (km), primary `household`, limit 5, maxItems 15.
//
// Needs a native sqlite3 on the test host. On Windows it uses the
// sqlite3.dll shipped with Python (override with SQLITE3_DLL=<path>).
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:digit_crud_bloc/bloc/crud_bloc.dart';
import 'package:digit_crud_bloc/models/global_search_params.dart';
import 'package:digit_crud_bloc/repositories/local/search_entity_repository.dart';
import 'package:digit_crud_bloc/service/crud_service.dart';
import 'package:digit_crud_bloc/utils/utils.dart';
import 'package:digit_data_model/data/repositories/package_repository/local/household.dart';
import 'package:digit_data_model/data/repositories/package_repository/local/household_member.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data_model.init.dart' as data_model_mappers;
import 'package:digit_flow_builder/blocs/flow_crud_bloc.dart';
import 'package:digit_flow_builder/blocs/search_state_manager.dart';
import 'package:digit_flow_builder/data/digit_crud_service.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqlite3/open.dart';

const _tenant = 'kd';
const _user = 'probe-user';
const _boundary = 'KD_PROBE_SETTLEMENT';
const _screen = 'searchBeneficiary';
const _instance = 'probe';
const _compositeKey = '$_screen::$_instance';

// The phone's position when the user toggles proximity ON. The new household
// is registered standing at this exact spot (distance 0).
const _meLat = 10.5200;
const _meLng = 7.4400;

String? _sqliteDll() {
  final fromEnv = Platform.environment['SQLITE3_DLL'];
  if (fromEnv != null && File(fromEnv).existsSync()) return fromEnv;
  final local = Platform.environment['LOCALAPPDATA'];
  if (local == null) return null;
  final programs = Directory('$local\\Programs\\Python');
  if (!programs.existsSync()) return null;
  for (final dir in programs.listSync().whereType<Directory>()) {
    final dll = File('${dir.path}\\DLLs\\sqlite3.dll');
    if (dll.existsSync()) return dll.path;
  }
  return null;
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.dir);
  final String dir;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
}

class _NoOpLog<T extends EntityModel> extends Mock implements OpLogManager<T> {
  // IndividualLocalRepository.create ignores createOpLog:false and always
  // writes an op-log entry; swallow it (sync is out of scope here).
  @override
  Future<void> put(OpLogEntry<dynamic> entry) async {}
}

// Relationship graph and nested mappings exactly as home.dart registers them
// for the REGISTRATION module (beneficiaryType = individual branch).
const _relationships = [
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
      from: 'householdMember',
      to: 'individual',
      localKey: 'individualClientReferenceId',
      foreignKey: 'clientReferenceId'),
  RelationshipMapping(
      from: 'address',
      to: 'household',
      localKey: 'relatedClientReferenceId',
      foreignKey: 'clientReferenceId'),
  RelationshipMapping(
      from: 'householdMember',
      to: 'household',
      localKey: 'householdClientReferenceId',
      foreignKey: 'clientReferenceId'),
  RelationshipMapping(
      from: 'projectBeneficiary',
      to: 'task',
      localKey: 'clientReferenceId',
      foreignKey: 'projectBeneficiaryClientReferenceId'),
  RelationshipMapping(
      from: 'identifier',
      to: 'hFReferral',
      localKey: 'identifierId',
      foreignKey: 'beneficiaryId'),
  RelationshipMapping(
      from: 'projectBeneficiary',
      to: 'individual',
      localKey: 'beneficiaryClientReferenceId',
      foreignKey: 'clientReferenceId'),
];

const _nested = [
  NestedModelMapping(rootModel: 'individual', fields: {
    'name': NestedFieldMapping(
        table: 'name',
        localKey: 'clientReferenceId',
        foreignKey: 'individualClientReferenceId',
        type: NestedMappingType.one),
    'address': NestedFieldMapping(
        table: 'address',
        localKey: 'clientReferenceId',
        foreignKey: 'relatedClientReferenceId',
        type: NestedMappingType.many),
    'identifiers': NestedFieldMapping(
        table: 'identifier',
        localKey: 'clientReferenceId',
        foreignKey: 'individualClientReferenceId',
        type: NestedMappingType.many),
  }),
  NestedModelMapping(rootModel: 'household', fields: {
    'address': NestedFieldMapping(
        table: 'address',
        localKey: 'clientReferenceId',
        foreignKey: 'relatedClientReferenceId',
        type: NestedMappingType.one),
  }),
];

// searchBeneficiary.wrapperConfig from the Kaduna REGISTRATION snapshot
// (~/Downloads, campaign CMP-2026-06-09-000345, taken 2026-11-04) — identical
// in REGISTRATION_kd_fix.json and the local assets/configs REGISTRATION.json.
final Map<String, dynamic> _kadunaWrapperConfig = {
  'rootEntity': 'HouseholdModel',
  'wrapperName': 'HouseholdWrapper',
  'filters': [
    {
      'entity': 'HouseholdMemberModel',
      'condition': {'field': 'isDeleted', 'equals': false},
      'join': {
        'sourceField': 'householdClientReferenceId',
        'targetField': 'clientReferenceId',
      },
    },
  ],
  'relations': [
    {
      'name': 'members',
      'match': {
        'field': 'householdClientReferenceId',
        'equalsFrom': 'clientReferenceId',
      },
      'entity': 'HouseholdMemberModel',
    },
    {
      'name': 'headOfHousehold',
      'match': {
        'field': 'householdClientReferenceId',
        'equalsFrom': 'clientReferenceId',
      },
      'entity': 'HouseholdMemberModel',
      'filters': [
        {'field': 'isHeadOfHousehold', 'equals': true},
      ],
    },
    {
      'name': 'headIndividual',
      'match': {
        'field': 'clientReferenceId',
        'equalsFrom': 'headOfHousehold.individualClientReferenceId',
      },
      'entity': 'IndividualModel',
    },
    {
      'name': 'individuals',
      'match': {
        'field': 'clientReferenceId',
        'inFrom': 'members.individualClientReferenceId',
      },
      'entity': 'IndividualModel',
    },
  ],
  'searchConfig': {
    'select': [
      'household',
      'individual',
      'householdMember',
      'projectBeneficiary',
      'task',
    ],
    'primary': 'household',
    'pagination': {'limit': 5, 'maxItems': 15},
  },
};

const _limit = 5;
const _fullSelect = [
  'household',
  'individual',
  'householdMember',
  'projectBeneficiary',
  'task',
];
const _maxItems = 15;

/// [radius] is what the widget passes from validations.proximityRadius (5).
/// Passing 5 * 180 / pi makes the current (radian-as-degree) box exactly the
/// intended 5 km — a way to preview "radius fixed, nothing else changed".
GlobalSearchParameters _proximity(int offset,
        {num radius = 5,
        int limit = _limit,
        List<String> select = _fullSelect}) =>
    GlobalSearchParameters(
      filters: [
        SearchFilter(
          root: 'address',
          field: 'proximitySearch',
          operator: 'within',
          value: radius,
          coordinates: const LatLng(latitude: _meLat, longitude: _meLng),
        ),
      ],
      primaryModel: 'household',
      select: select,
      pagination: PaginationParams(offset: offset, limit: limit),
    );

/// Deterministic UUID-shaped id; [prefix] (hex) controls where it sorts.
String _uuid(Random r, {String prefix = ''}) {
  const hex = '0123456789abcdef';
  final chars = List.generate(32, (_) => hex[r.nextInt(16)]);
  for (var i = 0; i < prefix.length; i++) {
    chars[i] = prefix[i];
  }
  final s = chars.join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-4${s.substring(13, 16)}-'
      '${s.substring(16, 20)}-${s.substring(20, 32)}';
}

class _Db {
  _Db(this.sql)
      : households = HouseholdLocalRepository(sql, _NoOpLog<HouseholdModel>()),
        individuals =
            IndividualLocalRepository(sql, _NoOpLog<IndividualModel>()),
        members = HouseholdMemberLocalRepository(
            sql, _NoOpLog<HouseholdMemberModel>()),
        service = CrudService(
          relationshipMap: _relationships,
          nestedModelMappings: _nested,
          searchEntityRepository:
              SearchEntityRepository(sql, _NoOpLog<EntityModel>()),
        )..init();

  final LocalSqlDataStore sql;
  final HouseholdLocalRepository households;
  final IndividualLocalRepository individuals;
  final HouseholdMemberLocalRepository members;
  final CrudService service;
  var _clock = DateTime(2026, 11, 6, 8).millisecondsSinceEpoch;

  AuditDetails _audit(int t) => AuditDetails(createdBy: _user, createdTime: t);
  ClientAuditDetails _client(int t) =>
      ClientAuditDetails(createdBy: _user, createdTime: t);

  Future<int> count(String table) async {
    final row = await sql
        .customSelect('SELECT COUNT(*) AS c FROM $table')
        .getSingle();
    return row.read<int>('c');
  }

  Future<void> _waitFor(String table, int n) async {
    for (var i = 0; i < 300; i++) {
      if (await count(table) >= n) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('timed out waiting for $n rows in $table');
  }

  /// Registers a household the way the HOUSEHOLD flow does: household +
  /// address (with the latLng captured at beneficiaryLocation) and, unless
  /// [consentRefused], a head-of-household individual + member.
  /// Consent refusal (householdConsentRegistration) creates the household
  /// and its address ONLY.
  Future<HouseholdModel> register(
    String id,
    double lat,
    double lng, {
    bool consentRefused = false,
    bool deleted = false,
  }) async {
    final t = _clock += 60000;
    final hh = HouseholdModel(
      clientReferenceId: id,
      tenantId: _tenant,
      memberCount: consentRefused ? 0 : 1,
      latitude: lat,
      longitude: lng,
      isDeleted: deleted,
      address: AddressModel(
        relatedClientReferenceId: id,
        latitude: lat,
        longitude: lng,
        locationAccuracy: 4.0,
        tenantId: _tenant,
        locality: LocalityModel(code: _boundary, name: 'Probe'),
        auditDetails: _audit(t),
        clientAuditDetails: _client(t),
      ),
      auditDetails: _audit(t),
      clientAuditDetails: _client(t),
    );
    final before = await count('household');
    await households.create(hh, createOpLog: false);
    await _waitFor('household', before + 1);

    if (!consentRefused) {
      final indId = 'ind-$id';
      final ind = IndividualModel(
        clientReferenceId: indId,
        tenantId: _tenant,
        isDeleted: deleted,
        name: NameModel(
          individualClientReferenceId: indId,
          givenName: 'Head',
          familyName: id.substring(0, 4),
          auditDetails: _audit(t),
          clientAuditDetails: _client(t),
        ),
        auditDetails: _audit(t),
        clientAuditDetails: _client(t),
      );
      final beforeInd = await count('individual');
      await individuals.create(ind, createOpLog: false);
      await _waitFor('individual', beforeInd + 1);

      final beforeHm = await count('household_member');
      await members.create(
        HouseholdMemberModel(
          clientReferenceId: 'hm-$id',
          householdClientReferenceId: id,
          individualClientReferenceId: indId,
          isHeadOfHousehold: true,
          tenantId: _tenant,
          isDeleted: deleted,
          auditDetails: _audit(t),
          clientAuditDetails: _client(t),
        ),
        createOpLog: false,
      );
      await _waitFor('household_member', beforeHm + 1);
    }
    return hh;
  }

  /// Writes server records the way the beneficiary download does
  /// (SyncServiceMapper.createDbRecords): JSON -> <Model>Mapper.fromJson ->
  /// local.bulkCreate, in response-key order Individuals, Households,
  /// HouseholdMembers. Each entry: (lat, lng, withMember, deleted).
  Future<List<String>> download(
      List<({double lat, double lng, bool withMember, bool deleted})> rows,
      Random r,
      {String firstIdPrefix = ''}) async {
    final t = _clock += 60000;
    Map<String, dynamic> audit() => {
          'createdBy': 'other-user',
          'createdTime': t,
          'lastModifiedBy': 'other-user',
          'lastModifiedTime': t,
        };
    final individualsJson = <Map<String, dynamic>>[];
    final householdsJson = <Map<String, dynamic>>[];
    final membersJson = <Map<String, dynamic>>[];
    final ids = <String>[];
    var n = 0;
    for (final row in rows) {
      n++;
      final hhRef = _uuid(r, prefix: n == 1 ? firstIdPrefix : '');
      ids.add(hhRef);
      householdsJson.add({
        'id': 'H-2026-11-0$n',
        'tenantId': _tenant,
        'clientReferenceId': hhRef,
        'memberCount': row.withMember ? 1 : 0,
        'rowVersion': 1,
        'isDeleted': row.deleted,
        'address': {
          'id': 'A-$n',
          'tenantId': _tenant,
          'latitude': row.lat,
          'longitude': row.lng,
          'locationAccuracy': 5.0,
          'locality': {'code': _boundary},
          'rowVersion': 1,
        },
        'auditDetails': audit(),
        'clientAuditDetails': audit(),
      });
      if (row.withMember) {
        final indRef = _uuid(r);
        individualsJson.add({
          'id': 'IND-$n',
          'tenantId': _tenant,
          'clientReferenceId': indRef,
          'name': {'givenName': 'Downloaded', 'familyName': 'H$n'},
          // Registered individuals carry the household location too
          // (individualRegistration AddressModel mapping). bulkCreate reads
          // address[0] unguarded, so an individual without one would throw.
          'address': [
            {
              'id': 'IA-$n',
              'tenantId': _tenant,
              'latitude': row.lat,
              'longitude': row.lng,
              'locationAccuracy': 5.0,
              'locality': {'code': _boundary},
              'rowVersion': 1,
            },
          ],
          'rowVersion': 1,
          'isDeleted': row.deleted,
          'auditDetails': audit(),
          'clientAuditDetails': audit(),
        });
        membersJson.add({
          'id': 'HM-$n',
          'tenantId': _tenant,
          'householdId': 'H-2026-11-0$n',
          'householdClientReferenceId': hhRef,
          'individualId': 'IND-$n',
          'individualClientReferenceId': indRef,
          'isHeadOfHousehold': true,
          'clientReferenceId': _uuid(r),
          'rowVersion': 1,
          'isDeleted': row.deleted,
          'auditDetails': audit(),
          'clientAuditDetails': audit(),
        });
      }
    }
    final beforeInd = await count('individual');
    final beforeHh = await count('household');
    final beforeHm = await count('household_member');
    await individuals.bulkCreate(individualsJson
        .map((e) => IndividualModelMapper.fromJson(jsonEncode(e)))
        .toList());
    await households.bulkCreate(householdsJson
        .map((e) => HouseholdModelMapper.fromJson(jsonEncode(e)))
        .toList());
    await members.bulkCreate(membersJson
        .map((e) => HouseholdMemberModelMapper.fromJson(jsonEncode(e)))
        .toList());
    await _waitFor('individual', beforeInd + individualsJson.length);
    await _waitFor('household', beforeHh + householdsJson.length);
    await _waitFor('household_member', beforeHm + membersJson.length);
    return ids;
  }

  /// Raw proximity result order (household ids), page by page, straight
  /// from the repository — what SQLite returns, before any wrapper filter.
  Future<List<String>> rawOrder({num radius = 5}) async {
    final ids = <String>[];
    for (var offset = 0;; offset += _limit) {
      final (results, _) = await service.searchEntities(
          query: _proximity(offset, radius: radius));
      final page = (results['household'] ?? const [])
          .whereType<HouseholdModel>()
          .map((h) => h.clientReferenceId)
          .toList();
      ids.addAll(page);
      if (page.length < _limit) return ids;
    }
  }
}

/// Drives the screen exactly like the app: SEARCH_EVENT on toggle-ON, then
/// REFRESH_SEARCH(direction: down) for each scroll, through FlowCrudBloc.
class _SearchScreen {
  _SearchScreen(CrudService service, {this.grouped = false})
      : bloc = FlowCrudBloc(
          flowConfig: {
            'name': _screen,
            'wrapperConfig': grouped
                ? {
                    'rootEntity': 'HouseholdModel',
                    'groupByType': true,
                    'searchConfig': {
                      'select': ['household'],
                      'primary': 'household',
                      'pagination': {'limit': _limit, 'maxItems': _maxItems},
                    },
                  }
                : _kadunaWrapperConfig,
          },
          service: service,
          instanceId: _instance,
        ) {
    FlowCrudStateRegistry().registerInstance(_screen, _instance);
  }

  final FlowCrudBloc bloc;
  final bool grouped;
  List<String> get _select => grouped ? const ['household'] : _fullSelect;

  /// See [_proximity]; 5 is what the Kaduna config sends.
  num radius = 5;

  Future<void> _search(GlobalSearchParameters p) async {
    final done = bloc.stream.firstWhere(
        (s) => s is CrudStateLoaded || s is CrudStateError);
    bloc.add(CrudEvent.search(p));
    final s = await done;
    if (s is CrudStateError) fail('search failed: ${s.message}');
    // onTransition ran before the state was emitted; let microtasks settle.
    await Future<void>.delayed(Duration.zero);
  }

  /// SearchExecutor path (proximity switch turned ON).
  Future<void> toggleProximityOn() async {
    SearchStateManager().initPaginationWindow(_compositeKey, '_pagination',
        limit: _limit, maxItems: _maxItems);
    FlowCrudStateRegistry()
        .setPaginationInfo(_screen, limit: _limit, maxItems: _maxItems);
    await _search(_proximity(0, radius: radius, select: _select));
  }

  /// RefreshSearchExecutor path (scrollListener onScrollDown).
  /// Returns false when the screen refuses to load more.
  Future<bool> scrollDown() async {
    final offset =
        SearchStateManager().prepareLoadDown(_compositeKey, '_pagination');
    if (offset == null) return false;
    FlowCrudStateRegistry().setScrollDirection(_screen, 'down');
    FlowCrudStateRegistry().setPaginationInfo(_screen,
        limit: _limit, maxItems: _maxItems, offset: offset);
    await _search(_proximity(offset, radius: radius, select: _select));
    return true;
  }

  /// RefreshSearchExecutor path (scrollListener onScrollUp).
  Future<bool> scrollUp() async {
    final offset =
        SearchStateManager().prepareLoadUp(_compositeKey, '_pagination');
    if (offset == null) return false;
    final pageLimit = SearchStateManager().loadUpLimit(
        _compositeKey, '_pagination',
        offset: offset, limit: _limit);
    FlowCrudStateRegistry().setScrollDirection(_screen, 'up');
    FlowCrudStateRegistry().setPaginationInfo(_screen,
        limit: _limit, maxItems: _maxItems, offset: offset);
    await _search(_proximity(offset, radius: radius, limit: pageLimit, select: _select));
    return true;
  }

  /// Every household held in the list window, in order (visible or not).
  List<String> get wrapperIds => _wrapper.expand((w) {
        final v = w['HouseholdModel'];
        final list = v is List ? v : [v];
        return list.whereType<HouseholdModel>().map((h) => h.clientReferenceId);
      }).toList();

  List<Map> get _wrapper =>
      (FlowCrudStateRegistry().getByCompositeKey(_compositeKey)?.stateWrapper ??
              const [])
          .whereType<Map>()
          .toList();

  /// Cards actually drawn: listView child `visible:
  /// {{fn:length(item.headOfHousehold)}} > 0`.
  List<String> get visibleCards => _wrapper
      .where((w) => (w['headOfHousehold'] as List?)?.isNotEmpty ?? false)
      .map((w) => (w['HouseholdModel'] as HouseholdModel).clientReferenceId)
      .toList();

  /// Scrolls like a user looking for [id]; returns how many scroll loads it
  /// took to see it, or null if the screen stopped loading first.
  Future<({int? scrollsToFind, int scrollsDone, Set<String> everShown})>
      hunt(String id, {int maxScrolls = 50}) async {
    final shown = <String>{...visibleCards};
    if (shown.contains(id)) {
      return (scrollsToFind: 0, scrollsDone: 0, everShown: shown);
    }
    for (var i = 1; i <= maxScrolls; i++) {
      if (!await scrollDown()) {
        return (scrollsToFind: null, scrollsDone: i - 1, everShown: shown);
      }
      shown.addAll(visibleCards);
      if (visibleCards.contains(id)) {
        return (scrollsToFind: i, scrollsDone: i, everShown: shown);
      }
    }
    return (scrollsToFind: null, scrollsDone: maxScrolls, everShown: shown);
  }

  Future<void> close() => bloc.close();
}

void main() {
  final dll = _sqliteDll();
  final skip = dll == null ? 'no native sqlite3 found (set SQLITE3_DLL)' : null;

  late Directory tmp;
  late _Db db;
  late _SearchScreen screen;

  setUpAll(() {
    data_model_mappers.initializeMappers();
    if (dll != null) {
      // Python's sqlite3.dll is built with SQLITE_OMIT_AUTOINIT: without an
      // explicit sqlite3_initialize() the first sqlite3_open_v2 crashes the
      // flutter_tester process (0xC0000005).
      open.overrideFor(OperatingSystem.windows, () {
        final lib = DynamicLibrary.open(dll);
        lib.lookupFunction<Int32 Function(), int Function()>(
            'sqlite3_initialize')();
        return lib;
      });
    }
  });

  setUp(() async {
    if (dll == null) return;
    tmp = await Directory.systemTemp.createTemp('prox_probe');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    db = _Db(LocalSqlDataStore());
    // As FlowNavigationUtils.navigateToFlowModule does for REGISTRATION.
    CrudBlocSingleton().setData(
      crudService: db.service,
      dynamicEntityModelListener: EntityModelMapMapper(),
    );
    screen = _SearchScreen(db.service);
  });

  tearDown(() async {
    if (dll == null) return;
    await screen.close();
    SearchStateManager().disposeAll();
    FlowCrudStateRegistry().disposeByCompositeKey(_compositeKey);
    await db.sql.close();
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  // Random offsets within ±0.0004° (~±44 m) of the user, i.e. inside the
  // box the query really applies (see the radius test), so the ordering and
  // paging tests below are not confounded by it.
  (double, double) near(Random r) => (
        _meLat + (r.nextDouble() - 0.5) * 0.0008,
        _meLng + (r.nextDouble() - 0.5) * 0.0008,
      );

  test(
      'radius: config says 5 km, but households more than ~87 m away are '
      'not returned (bounding box uses radians as degrees)', () async {
    const metersPerDegLat = 111320.0;
    final metersPerDegLng = 111320.0 * cos(_meLat * pi / 180);
    const distances = [10, 50, 80, 95, 150, 300, 1000, 4900];
    final north = <int, String>{};
    final east = <int, String>{};
    final r = Random(8);
    for (final d in distances) {
      north[d] = _uuid(r);
      await db.register(north[d]!, _meLat + d / metersPerDegLat, _meLng);
      east[d] = _uuid(r);
      await db.register(east[d]!, _meLat, _meLng + d / metersPerDegLng);
    }

    final raw = await db.rawOrder();
    final foundNorth = distances.where((d) => raw.contains(north[d])).toList();
    final foundEast = distances.where((d) => raw.contains(east[d])).toList();
    const halfWidthDeg = 5 / 6371.0; // what QueryBuilder adds to the latitude
    // ignore: avoid_print
    print('PROBE|radius|configuredKm=5'
        '|boxHalfWidthLatM=${(halfWidthDeg * metersPerDegLat).round()}'
        '|foundNorthM=$foundNorth|foundEastM=$foundEast');
    expect(foundNorth, [10, 50, 80]);
    expect(foundEast, [10, 50, 80]);
  }, skip: skip);

  test('control: a new household alone nearby IS shown on the first page',
      () async {
    final r = Random(1);
    final id = _uuid(r);
    await db.register(id, _meLat, _meLng);

    await screen.toggleProximityOn();
    // ignore: avoid_print
    print('PROBE|control|cards=${screen.visibleCards.length}');
    expect(screen.visibleCards, [id]);
  }, skip: skip);

  test(
      'consent refused: the household matches the SQL but is never drawn '
      '(no member -> wrapper filter + headOfHousehold card rule)', () async {
    final r = Random(2);
    final id = _uuid(r);
    await db.register(id, _meLat, _meLng, consentRefused: true);

    final raw = await db.rawOrder();
    await screen.toggleProximityOn();
    // ignore: avoid_print
    print('PROBE|consentRefused|rawRows=${raw.length}'
        '|cards=${screen.visibleCards.length}');
    expect(raw, [id], reason: 'SQL proximity query does return it');
    expect(screen.visibleCards, isEmpty,
        reason: 'but FlowCrudBloc/WrapperBuilder + card rule drop it');
  }, skip: skip);

  test(
      'order: no ORDER BY, so the engine picks the order (registration order '
      'here, id order on the phone) — never distance, never newest first',
      () async {
    final r = Random(3);
    final older = <String>[];
    for (var i = 0; i < 30; i++) {
      final (lat, lng) = near(r);
      final id = _uuid(r);
      older.add(id);
      await db.register(id, lat, lng);
    }
    // Registered last, standing exactly at the user's spot (distance 0); its
    // id sorts last, so both engine orders put it last.
    final mine = _uuid(r, prefix: 'fff');
    await db.register(mine, _meLat, _meLng);

    final raw = await db.rawOrder();
    final registrationOrder = [...older, mine];
    final sortedIds = [...registrationOrder]..sort();
    final rank = raw.indexOf(mine);

    // Plan for the statement Drift sends (captured with
    // --dart-define=DRIFT_LOG_STATEMENTS=true), with bound parameters.
    final plan = await db.sql
        .customSelect('EXPLAIN QUERY PLAN SELECT * FROM "household" WHERE '
            '"household"."client_reference_id" IN (SELECT DISTINCT '
            '"address"."related_client_reference_id" FROM "address" WHERE '
            '"address"."latitude" BETWEEN ? AND ? AND '
            '"address"."longitude" BETWEEN ? AND ?) LIMIT ? OFFSET ?',
            variables: [
              Variable.withReal(_meLat - 0.0008),
              Variable.withReal(_meLat + 0.0008),
              Variable.withReal(_meLng - 0.0008),
              Variable.withReal(_meLng + 0.0008),
              Variable.withInt(_limit),
              Variable.withInt(0),
            ])
        .get();
    final version = await db.sql
        .customSelect('SELECT sqlite_version() AS v')
        .getSingle();
    // ignore: avoid_print
    print('PROBE|order|sqlite=${version.read<String>('v')}'
        '|rows=${raw.length}|newestNearestRank=${rank + 1}'
        '|page=${rank ~/ _limit + 1}'
        '|registrationOrder=${_listEq(raw, registrationOrder)}'
        '|sortedByClientRef=${_listEq(raw, sortedIds)}'
        '|plan=${plan.map((p) => p.data['detail']).join(' / ')}');
    // No ORDER BY: the engine decides. SQLite 3.43.1 (this host) returns
    // registration order; the phone's SQLCipher 3.50.4 returned id order
    // (TEMP-table check over the VM service, 2026-11-06). Neither is distance
    // or recency, so the nearest, newest household lands anywhere.
    expect(_listEq(raw, registrationOrder) || _listEq(raw, sortedIds), isTrue);
    expect(rank, raw.length - 1);
  }, skip: skip);

  test(
      'paging with only active households: the new one is reachable, but '
      'only after scrolling through the earlier pages', () async {
    final r = Random(4);
    for (var i = 0; i < 30; i++) {
      final (lat, lng) = near(r);
      await db.register(_uuid(r), lat, lng);
    }
    final mine = _uuid(r, prefix: 'fff');
    await db.register(mine, _meLat, _meLng);

    await screen.toggleProximityOn();
    final firstPage = screen.visibleCards;
    final hunt = await screen.hunt(mine);
    // ignore: avoid_print
    print('PROBE|activeOnly|firstPageHasIt=${firstPage.contains(mine)}'
        '|scrollsToFind=${hunt.scrollsToFind}'
        '|cardsInWindowAtEnd=${screen.visibleCards.length}');
    expect(firstPage.contains(mine), isFalse);
    expect(hunt.scrollsToFind, 6);
  }, skip: skip);

  test(
      'paging stops for good when a page holds a consent-refused household: '
      'the new household is never loaded', () async {
    final r = Random(5);
    // One consent-refused household nearby whose id sorts into page 1.
    final (rLat, rLng) = near(r);
    await db.register(_uuid(r, prefix: '000'), rLat, rLng, consentRefused: true);
    for (var i = 0; i < 30; i++) {
      final (lat, lng) = near(r);
      await db.register(_uuid(r), lat, lng);
    }
    final mine = _uuid(r, prefix: 'fff');
    await db.register(mine, _meLat, _meLng);

    await screen.toggleProximityOn();
    final cardsPage1 = screen.visibleCards.length;
    final hunt = await screen.hunt(mine);
    final raw = await db.rawOrder();
    // ignore: avoid_print
    print('PROBE|refusedOnPage1|rawRows=${raw.length}|cardsPage1=$cardsPage1'
        '|scrollsAllowed=${hunt.scrollsDone}'
        '|everShown=${hunt.everShown.length}'
        '|found=${hunt.scrollsToFind != null}');
    expect(cardsPage1, 4);
    expect(hunt.scrollsToFind, isNotNull,
        reason: 'FIXED: paging counts DB rows, so a hidden row no longer stops it');
  }, skip: skip);

  test(
      'paging stops the same way for a deleted household on the page '
      '(search never filters household.isDeleted)', () async {
    final r = Random(6);
    final (dLat, dLng) = near(r);
    await db.register(_uuid(r, prefix: '000'), dLat, dLng, deleted: true);
    for (var i = 0; i < 30; i++) {
      final (lat, lng) = near(r);
      await db.register(_uuid(r), lat, lng);
    }
    final mine = _uuid(r, prefix: 'fff');
    await db.register(mine, _meLat, _meLng);

    await screen.toggleProximityOn();
    final hunt = await screen.hunt(mine);
    // ignore: avoid_print
    print('PROBE|deletedOnPage1|cardsPage1=${hunt.everShown.length}'
        '|scrollsAllowed=${hunt.scrollsDone}'
        '|found=${hunt.scrollsToFind != null}');
    expect(hunt.scrollsToFind, isNotNull, reason: 'FIXED');
  }, skip: skip);

  test(
      'sync-down control: the server copy keeps address lat/long (household '
      'service row mapper), so the record stays findable after sync',
      () async {
    final r = Random(7);
    final id = _uuid(r);
    final hh = await db.register(id, _meLat, _meLng);
    // What PerformSyncDown writes back: the server's household. The household
    // service has no household-level lat/long, but returns address lat/long.
    final serverCopy = hh.copyWith(
      id: 'H-2026-11-06-000001',
      latitude: null,
      longitude: null,
      rowVersion: 1,
      address: hh.address!.copyWith(id: 'addr-server-id'),
    );
    await db.households.update(serverCopy, createOpLog: false);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    await screen.toggleProximityOn();
    // ignore: avoid_print
    print('PROBE|afterSyncDown|cards=${screen.visibleCards.length}');
    expect(screen.visibleCards, [id]);
  }, skip: skip);

  // QA (2026-11-06): "no data -> works; download data, then create a new
  // record -> proximity does not show it". Same order as QA: download first
  // (real download write path), then register at the user's spot, then
  // switch proximity ON.
  group('QA sequence: download, register, proximity ON', () {
    const mPerDegLat = 111320.0;
    final mPerDegLng = 111320.0 * cos(_meLat * pi / 180);
    ({double lat, double lng, bool withMember, bool deleted}) at(
      double northM,
      double eastM, {
      bool withMember = true,
      bool deleted = false,
    }) =>
        (
          lat: _meLat + northM / mPerDegLat,
          lng: _meLng + eastM / mPerDegLng,
          withMember: withMember,
          deleted: deleted,
        );

    // Field households 300 m – 3 km away in random directions.
    List<({double lat, double lng, bool withMember, bool deleted})> fieldData(
        Random r, int n) {
      return List.generate(n, (_) {
        final d = 300 + r.nextDouble() * 2700;
        final a = r.nextDouble() * 2 * pi;
        return at(d * cos(a), d * sin(a));
      });
    }

    // Other registrations at the same desk/office (within ±60 m).
    List<({double lat, double lng, bool withMember, bool deleted})> deskData(
        Random r, int n) {
      return List.generate(n,
          (_) => at((r.nextDouble() - 0.5) * 120, (r.nextDouble() - 0.5) * 120));
    }

    // Sorts last in BOTH engine orders: the unlucky case on the phone, which
    // happens there with probability (N - 5) / N for N households in the box.
    Future<String> registerNew(Random r) async {
      final id = _uuid(r, prefix: 'fff');
      await db.register(id, _meLat, _meLng);
      return id;
    }

    test('S1 no download: the new household is the first card', () async {
      final r = Random(11);
      final mine = await registerNew(r);
      await screen.toggleProximityOn();
      // ignore: avoid_print
      print('PROBE|S1-noData|cards=${screen.visibleCards.length}'
          '|newShown=${screen.visibleCards.contains(mine)}');
      expect(screen.visibleCards, [mine]);
    }, skip: skip);

    test(
        'S2 download 200 field households 0.3–3 km away: the new household is '
        'still the first card (they are outside the ±87 m box)', () async {
      final r = Random(12);
      await db.download(fieldData(r, 200), r);
      final mine = await registerNew(r);
      final raw = await db.rawOrder();
      await screen.toggleProximityOn();
      // ignore: avoid_print
      print('PROBE|S2-fieldData|households=${await db.count('household')}'
          '|inBox=${raw.length}|cards=${screen.visibleCards.length}'
          '|newShown=${screen.visibleCards.contains(mine)}');
      expect(screen.visibleCards, [mine]);
    }, skip: skip);

    test(
        'S3 download 12 households registered at the same spot: the new one '
        'is NOT on the first page (it is last); shows only after 2 scrolls',
        () async {
      final r = Random(13);
      await db.download(deskData(r, 12), r);
      final mine = await registerNew(r);
      final raw = await db.rawOrder();
      await screen.toggleProximityOn();
      final firstPage = screen.visibleCards;
      final hunt = await screen.hunt(mine);
      // ignore: avoid_print
      print('PROBE|S3-deskData|inBox=${raw.length}'
          '|newRank=${raw.indexOf(mine) + 1}'
          '|firstPageCards=${firstPage.length}'
          '|newOnFirstPage=${firstPage.contains(mine)}'
          '|scrollsToFind=${hunt.scrollsToFind}');
      expect(raw.last, mine);
      expect(firstPage.contains(mine), isFalse);
      expect(hunt.scrollsToFind, 2);
    }, skip: skip);

    test(
        'S4 same, but one downloaded household on page 1 has no member '
        '(consent refused on another phone): paging stops, the new household '
        'is never shown', () async {
      final r = Random(14);
      final rows = deskData(r, 12);
      final first = rows.first;
      rows[0] = (
        lat: first.lat,
        lng: first.lng,
        withMember: false,
        deleted: false,
      );
      await db.download(rows, r, firstIdPrefix: '000');
      final mine = await registerNew(r);
      final raw = await db.rawOrder();
      await screen.toggleProximityOn();
      final firstPageCards = screen.visibleCards.length;
      final hunt = await screen.hunt(mine);
      // ignore: avoid_print
      print('PROBE|S4-deskData+memberless|inBox=${raw.length}'
          '|newRank=${raw.indexOf(mine) + 1}'
          '|firstPageCards=$firstPageCards'
          '|scrollsAllowed=${hunt.scrollsDone}'
          '|newEverShown=${hunt.scrollsToFind != null}');
      expect(firstPageCards, 4);
      expect(hunt.scrollsToFind, 2, reason: 'FIXED: reachable by scrolling');
    }, skip: skip);

    test(
        'S5 fixing ONLY the radius (simulated 5 km box) with S2 field data: '
        'every downloaded household enters the box and the new one is #201',
        () async {
      final r = Random(12);
      await db.download(fieldData(r, 200), r);
      final mine = await registerNew(r);
      const fixedRadius = 5 * 180 / pi;
      final raw = await db.rawOrder(radius: fixedRadius);
      screen.radius = fixedRadius;
      await screen.toggleProximityOn();
      final firstPage = screen.visibleCards;
      final hunt = await screen.hunt(mine, maxScrolls: 100);
      // ignore: avoid_print
      print('PROBE|S5-radiusFixedOnly|inBox=${raw.length}'
          '|newRank=${raw.indexOf(mine) + 1}'
          '|newOnFirstPage=${firstPage.contains(mine)}'
          '|scrollsToFind=${hunt.scrollsToFind}');
      expect(raw.length, 201);
      expect(raw.last, mine);
      expect(hunt.scrollsToFind, 40);
    }, skip: skip);
  });

  // Paging-fix checks: scroll to the bottom, then back to the top, and check
  // every window the user sees. "displayable" = household with an active
  // member (what WrapperBuilder keeps), in DB order.
  group('paging traversal (down to end, then up to top)', () {
    Future<Map<String, Object>> traverse(Set<String> memberless,
        {bool downAgain = false}) async {
      final raw = await db.rawOrder();
      final displayable = raw.where((id) => !memberless.contains(id)).toList();
      final pos = {for (var i = 0; i < displayable.length; i++) displayable[i]: i};
      final windows = <List<String>>[];
      await screen.toggleProximityOn();
      windows.add(screen.wrapperIds);
      var downLoads = 0;
      while (downLoads < 100 && await screen.scrollDown()) {
        downLoads++;
        windows.add(screen.wrapperIds);
      }
      final seenDown = windows.expand((w) => w).toSet();
      final downWindows = windows.length;
      var upLoads = 0;
      while (upLoads < 100 && await screen.scrollUp()) {
        upLoads++;
        windows.add(screen.wrapperIds);
      }
      if (downAgain) {
        var again = 0;
        while (again < 100 && await screen.scrollDown()) {
          again++;
          windows.add(screen.wrapperIds);
        }
      }
      var gapWindows = 0;
      var dupWindows = 0;
      for (final w in windows) {
        if (w.toSet().length != w.length) dupWindows++;
        final idx = w.map((id) => pos[id] ?? -1).toList();
        for (var i = 1; i < idx.length; i++) {
          if (idx[i] != idx[i - 1] + 1) {
            gapWindows++;
            break;
          }
        }
      }
      final topWindow = windows.last;
      return {
        'rows': raw.length,
        'displayable': displayable.length,
        'downLoads': downLoads,
        'upLoads': upLoads,
        'missingGoingDown': displayable.where((id) => !seenDown.contains(id)).length,
        'gapWindows': gapWindows,
        'dupWindows': dupWindows,
        'windows': windows.length,
        'downWindows': downWindows,
        'endsAtTop': topWindow.isNotEmpty && pos[topWindow.first] == 0,
        'signature': windows.map((w) => w.map((id) => pos[id]).join(',')).join('|').hashCode,
      };
    }

    test('T1 30 households, none hidden (like attendance: card = row)',
        () async {
      final r = Random(21);
      final rows = List.generate(30, (_) => (
            lat: _meLat + (r.nextDouble() - 0.5) * 0.0008,
            lng: _meLng + (r.nextDouble() - 0.5) * 0.0008,
            withMember: true,
            deleted: false,
          ));
      await db.download(rows, r);
      final res = await traverse(const {});
      // ignore: avoid_print
      print('PROBE|T1-noHidden|$res');
      expect(res['missingGoingDown'], 0);
      expect(res['gapWindows'], 0);
      expect(res['dupWindows'], 0);
    }, skip: skip);

    test('T2 30 households, 3 hidden spread out (consent refused)', () async {
      final r = Random(22);
      final rows = List.generate(30, (i) => (
            lat: _meLat + (r.nextDouble() - 0.5) * 0.0008,
            lng: _meLng + (r.nextDouble() - 0.5) * 0.0008,
            withMember: !(i == 2 || i == 13 || i == 24),
            deleted: false,
          ));
      final ids = await db.download(rows, r);
      final memberless = {ids[2], ids[13], ids[24]};
      final res = await traverse(memberless);
      // ignore: avoid_print
      print('PROBE|T2-3hidden|$res');
      expect(res['missingGoingDown'], 0);
      expect(res['gapWindows'], 0);
      expect(res['dupWindows'], 0);
    }, skip: skip);
    test('T1b 33 households, none hidden, partial last page, down-up-down',
        () async {
      final r = Random(31);
      final rows = List.generate(33, (_) => (
            lat: _meLat + (r.nextDouble() - 0.5) * 0.0008,
            lng: _meLng + (r.nextDouble() - 0.5) * 0.0008,
            withMember: true,
            deleted: false,
          ));
      await db.download(rows, r);
      final res = await traverse(const {}, downAgain: true);
      // ignore: avoid_print
      print('PROBE|T1b-33-noHidden|$res');
      expect(res['missingGoingDown'], 0);
    }, skip: skip);

    test('T3 20 random layouts with hidden households, down-up-down',
        () async {
      var totalGaps = 0, totalDups = 0, totalMissing = 0, layouts = 0;
      final sigs = <int>[];
      for (var seed = 100; seed < 120; seed++) {
        final r = Random(seed);
        final n = 21 + r.nextInt(48);
        final hiddenAt = <int>{0, n - 1};
        while (hiddenAt.length < 2 + r.nextInt(n ~/ 5)) {
          hiddenAt.add(r.nextInt(n));
        }
        final rows = List.generate(n, (i) => (
              lat: _meLat + (r.nextDouble() - 0.5) * 0.0008,
              lng: _meLng + (r.nextDouble() - 0.5) * 0.0008,
              withMember: !hiddenAt.contains(i),
              deleted: false,
            ));
        // fresh screen + data per layout
        await screen.close();
        SearchStateManager().disposeAll();
        FlowCrudStateRegistry().disposeByCompositeKey(_compositeKey);
        await db.sql.customStatement('DELETE FROM household');
        await db.sql.customStatement('DELETE FROM address');
        await db.sql.customStatement('DELETE FROM household_member');
        await db.sql.customStatement('DELETE FROM individual');
        await db.sql.customStatement('DELETE FROM name');
        screen = _SearchScreen(db.service);
        final ids = await db.download(rows, r);
        final hidden = {for (final i in hiddenAt) ids[i]};
        final res = await traverse(hidden, downAgain: true);
        totalGaps += res['gapWindows'] as int;
        totalDups += res['dupWindows'] as int;
        totalMissing += res['missingGoingDown'] as int;
        sigs.add(res['signature'] as int);
        layouts++;
      }
      // ignore: avoid_print
      print('PROBE|T3-random|layouts=$layouts|missingGoingDown=$totalMissing'
          '|gapWindows=$totalGaps|dupWindows=$totalDups'
          '|sig=${Object.hashAll(sigs)}');
      expect(totalMissing, 0);
      expect(totalGaps, 0);
      expect(totalDups, 0);
    }, skip: skip);

    test('T4 grouped screen (groupByType, primary only), down-up-down',
        () async {
      await screen.close();
      screen = _SearchScreen(db.service, grouped: true);
      final r = Random(41);
      final rows = List.generate(33, (_) => (
            lat: _meLat + (r.nextDouble() - 0.5) * 0.0008,
            lng: _meLng + (r.nextDouble() - 0.5) * 0.0008,
            withMember: true,
            deleted: false,
          ));
      await db.download(rows, r);
      final res = await traverse(const {}, downAgain: true);
      // ignore: avoid_print
      print('PROBE|T4-grouped|$res');
      expect(res['missingGoingDown'], 0);
    }, skip: skip);
  });
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
