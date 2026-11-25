// ignore_for_file: depend_on_referenced_packages
import 'dart:ffi';
import 'dart:io';

import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data_model.init.dart' as dm;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/data/sync_service_mapper.dart';
import 'package:isar/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqlite3/open.dart';
import 'package:survey_form/survey_form.dart';
import 'package:survey_form/survey_form.init.dart' as sf;

/// Liberia QA: checklist services gave a not-null error and lost fields after
/// sync-down.
///
/// A checklist service now carries the project id as its `referenceId`, so
/// every checklist of a project shares one referenceId. Nothing may therefore
/// find "the" service by referenceId: the local update and the sync-down
/// pairing go by `clientId`.
///
/// The server copy here holds only what the service-request persister stores:
/// no createdAt on the service, and attributes with no clientReferenceId.
///
/// The SQLite cases run on a real file. On Windows they use the sqlite3.dll
/// shipped with Python (override with SQLITE3_DLL=<path>); without one they
/// are skipped.
class _Isar extends Mock implements Isar {}

class _Remote extends Mock
    implements RemoteRepository<EntityModel, EntitySearchModel> {}

class _Local extends Mock
    implements LocalRepository<EntityModel, EntitySearchModel> {}

class _OpLog extends Mock implements OpLogManager<EntityModel> {}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.dir);
  final String dir;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
}

String? _sqliteDll() {
  if (!Platform.isWindows) return '';
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

const _project = 'project-1';
const _audit = AuditDetails(createdBy: 'u1', createdTime: 1);

/// A checklist as the device creates it.
ServiceModel _local(String key) => ServiceModel(
      clientId: 'svc-$key',
      referenceId: _project,
      accountId: _project,
      serviceDefId: 'def-1',
      tenantId: 'lr',
      createdAt: '25/11/2026',
      rowVersion: 1,
      auditDetails: _audit,
      attributes: [
        ServiceAttributesModel(
          clientReferenceId: 'att-$key',
          serviceClientReferenceId: 'svc-$key',
          referenceId: 'svc-$key',
          attributeCode: 'Q1',
          dataType: 'String',
          value: 'YES',
          auditDetails: _audit,
        ),
      ],
    );

/// The same checklist as the server returns it.
ServiceModel _server(String key, {bool attributeHasClientId = false}) =>
    ServiceModel(
      id: 'srv-$key',
      clientId: 'svc-$key',
      referenceId: _project,
      accountId: _project,
      serviceDefId: 'def-1',
      tenantId: 'lr',
      auditDetails: _audit,
      attributes: [
        ServiceAttributesModel(
          id: 'srv-att-$key',
          clientReferenceId: attributeHasClientId ? 'att-$key' : null,
          referenceId: 'srv-$key',
          attributeCode: 'Q1',
          value: 'YES',
          auditDetails: _audit,
        ),
      ],
    );

void main() {
  final dll = _sqliteDll();
  final skip = dll == null ? 'no native sqlite3 found (set SQLITE3_DLL)' : null;

  setUpAll(() {
    dm.initializeMappers();
    sf.initializeMappers();
    registerFallbackValue(ServiceSearchModel());
    registerFallbackValue(const UpdateServerGeneratedIdModel(
      clientReferenceId: '',
      serverGeneratedId: '',
      dataOperation: DataOperation.singleCreate,
    ));
    if (dll != null && dll.isNotEmpty) {
      // Python's sqlite3.dll is built with SQLITE_OMIT_AUTOINIT: without an
      // explicit sqlite3_initialize() the first open crashes flutter_tester.
      open.overrideFor(OperatingSystem.windows, () {
        final lib = DynamicLibrary.open(dll);
        lib.lookupFunction<Int32 Function(), int Function()>(
            'sqlite3_initialize')();
        return lib;
      });
    }
  });

  group('local update of one checklist of a project', () {
    late Directory tmp;
    late LocalSqlDataStore sql;
    late ServiceLocalRepository repo;

    setUp(() async {
      if (dll == null) return;
      tmp = await Directory.systemTemp.createTemp('service_ref');
      PathProviderPlatform.instance = _FakePathProvider(tmp.path);
      sql = LocalSqlDataStore();
      repo = ServiceLocalRepository(sql, ServiceOpLogManager(_Isar()));
      await repo.bulkCreate([_local('A'), _local('B')]);
    });

    tearDown(() async {
      if (dll == null) return;
      await sql.close();
      try {
        tmp.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows may still hold the file; the temp dir is cleaned later.
      }
    });

    Future<Map<String, ServiceData>> rows() async => {
          for (final r in await sql.select(sql.service).get()) r.clientId: r,
        };

    test('the server copy changes only its own row and keeps local values',
        () async {
      await repo.update(_server('A'), createOpLog: false);

      final byClient = await rows();
      expect(byClient.keys, unorderedEquals(['svc-A', 'svc-B']));
      expect(byClient['svc-A']!.id, 'srv-A');
      expect(byClient['svc-A']!.createdAt, '25/11/2026',
          reason: 'the server copy has no createdAt');
      expect(byClient['svc-B']!.id, isNull);
    }, skip: skip);

    test('an attribute with a client id gets its server id', () async {
      await repo.update(_server('A', attributeHasClientId: true),
          createOpLog: false);

      final attributes = {
        for (final a in await sql.select(sql.serviceAttributes).get())
          a.clientReferenceId: a.id,
      };
      expect(attributes, {'att-A': 'srv-att-A', 'att-B': null});
      expect((await rows())['svc-B']!.id, isNull);
    }, skip: skip);

    test('a failed checklist is flagged on its own row', () async {
      await repo.update(_local('B').copyWith(nonRecoverableError: true),
          createOpLog: false);

      final byClient = await rows();
      expect(byClient['svc-B']!.nonRecoverableError, isTrue);
      expect(byClient['svc-A']!.nonRecoverableError, isFalse);
    }, skip: skip);
  });

  test('sync-down gives each checklist the server id of its own clientId',
      () async {
    final remote = _Remote();
    final local = _Local();
    final opLog = _OpLog();
    final asked = <ServiceSearchModel>[];
    when(() => local.opLogManager).thenReturn(opLog);
    when(() => remote.search(any())).thenAnswer((invocation) async {
      final query = invocation.positionalArguments.first as ServiceSearchModel;
      asked.add(query);
      // Newest first, as a server would list a project's checklists.
      return [_server('B'), _server('A')]
          .where((e) => query.clientId == null || e.clientId == query.clientId)
          .toList();
    });
    final saved = <UpdateServerGeneratedIdModel>[];
    when(() => opLog.updateServerGeneratedIds(model: any(named: 'model')))
        .thenAnswer((invocation) async {
      saved.add(invocation.namedArguments[#model]);
    });
    final entries = [
      for (final (i, key) in ['A', 'B'].indexed)
        OpLogEntry<EntityModel>(
          _local(key),
          DataOperation.singleCreate,
          id: i + 1,
          createdAt: DateTime(2026, 11, 25),
          createdBy: 'u1',
          type: DataModelType.service,
        ),
    ];

    await SyncServiceMapper().syncDownEntityResponse(
      MapEntry(DataModelType.service, entries),
      MapEntry(DataOperation.singleCreate, entries),
      entries.map((e) => e.entity).toList(),
      remote,
      local,
    );

    expect({for (final s in saved) s.clientReferenceId: s.serverGeneratedId},
        {'svc-A': 'srv-A', 'svc-B': 'srv-B'});
    expect(asked.map((q) => q.clientId), ['svc-A', 'svc-B'],
        reason: 'one project can hold more checklists than a search page');
  });
}
