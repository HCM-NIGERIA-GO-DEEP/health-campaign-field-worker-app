// ignore_for_file: depend_on_referenced_packages
import 'dart:ffi';
import 'dart:io';

import 'package:digit_data_model/data/repositories/package_repository/local/unique_id_pool.dart';
import 'package:digit_data_model/data/repositories/package_repository/oplog/oplog.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data_model.init.dart' as dm;
import 'package:digit_data_model/models/entities/id_status.dart';
import 'package:digit_flow_builder/action_handler/action_config.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/executors/load_unique_id_pool_executor.dart';
import 'package:isar/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqlite3/open.dart';

/// LOAD_UNIQUE_ID_POOL over the real UniqueIdPoolLocalRepository on a real
/// SQLite file (the other pool tests use a fake repository that copies the
/// filter). Proves two things:
///  - a phone used by ONE user behaves exactly as before the user filter;
///  - on a shared phone each user gets and counts only their own ids.
///
/// On Windows it uses the sqlite3.dll shipped with Python (override with
/// SQLITE3_DLL=<path>); without one the cases are skipped.
class _Isar extends Mock implements Isar {}

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

/// Rows as UniqueIdPoolRemoteRepository.searchWithMetadata hands them to
/// bulkCreate: stamped with the downloading user's uuid.
List<UniqueIdPoolModel> _download(String user, List<String> ids, int time) => [
      for (var i = 0; i < ids.length; i++)
        UniqueIdPoolModel(
          id: ids[i],
          status: IdStatus.unAssigned.toValue(),
          userUuid: user,
          deviceUuid: 'device',
          tenantId: 'lr',
          auditDetails: AuditDetails(createdBy: user, createdTime: time + i),
        ),
    ];

void _login(String uuid) {
  FlowBuilderSingleton().setInitialData(
    loggedInUserUuid: uuid,
    maxRadius: 10,
    projectId: 'project',
    selectedBeneficiaryType: BeneficiaryType.household,
    projectType: null,
    selectedProject:
        ProjectModel(id: 'project', name: 'Project', tenantId: 'lr'),
    loggedInUser: UserModel(uuid: uuid),
  );
}

void main() {
  final dll = _sqliteDll();
  final skip = dll == null; // no sqlite3 library found

  late Directory tmp;
  late LocalSqlDataStore sql;
  late UniqueIdPoolLocalRepository repo;

  setUpAll(() {
    dm.initializeMappers();
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

  late BuildContext context;

  /// Opens a fresh database and mounts the repository the executor reads.
  Future<void> openDb(WidgetTester tester) async {
    tmp = Directory.systemTemp.createTempSync('id_pool');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    sql = LocalSqlDataStore();
    repo = UniqueIdPoolLocalRepository(sql, UniqueIdOpLogManager(_Isar()));
    await tester.pumpWidget(
      RepositoryProvider<
          LocalRepository<UniqueIdPoolModel, UniqueIdPoolSearchModel>>.value(
        value: repo,
        child: Builder(builder: (c) {
          context = c;
          return const SizedBox();
        }),
      ),
    );
  }

  Future<void> closeDb() async {
    await sql.close();
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may still hold the file; the temp dir is cleaned later.
    }
  }

  /// What the registration screen gets: the offered id and the count.
  Future<(String?, int)> load() async {
    final out = await LoadUniqueIdPoolExecutor().execute(
      ActionConfig(
        action: 'test',
        actionType: 'LOAD_UNIQUE_ID_POOL',
        properties: const {},
      ),
      context,
      {'_compositeKey': 'sharedPhoneSqliteTest'},
    );
    return (
      out['latestBeneficiaryId'] as String?,
      out['uniqueIdPoolCount'] as int,
    );
  }

  /// The pre-fix pick: every unassigned row, oldest first.
  Future<(String?, int)> unfiltered() async {
    final rows = await repo.search(
        UniqueIdPoolSearchModel(status: IdStatus.unAssigned.toValue()));
    rows.sort((a, b) => (a.auditDetails?.createdTime ?? 0)
        .compareTo(b.auditDetails?.createdTime ?? 0));
    final String? first = rows.isEmpty ? null : rows.first.id;
    return (first, rows.length);
  }

  Future<void> assign(String id) async {
    final row = (await repo.search(UniqueIdPoolSearchModel(id: id))).single;
    await repo.update(row.copyWith(status: IdStatus.assigned.toValue()));
  }

  testWidgets('one user on the phone: same id and count as before the filter',
      (tester) async {
    await openDb(tester);
    await tester.runAsync(() async {
      await repo.bulkCreate(_download('user-a', ['A-1', 'A-2', 'A-3'], 100));
      _login('user-a');

      expect(await load(), await unfiltered());
      expect(await load(), ('A-1', 3));

      // Registering uses A-1; the next registration gets A-2.
      await assign('A-1');
      expect(await load(), await unfiltered());
      expect(await load(), ('A-2', 2));

      // A second download by the same user is counted too.
      await repo.bulkCreate(_download('user-a', ['A-4', 'A-5'], 200));
      expect(await load(), await unfiltered());
      expect(await load(), ('A-2', 4));

      // Logout and login again as the same user: nothing changes.
      _login('user-a');
      expect(await load(), ('A-2', 4));
      await closeDb();
    });
  }, skip: skip);

  testWidgets('shared phone: each user gets and counts only their own ids',
      (tester) async {
    await openDb(tester);
    await tester.runAsync(() async {
      await repo.bulkCreate(_download('user-a', ['A-1', 'A-2', 'A-3'], 100));
      await repo.bulkCreate(_download('user-b', ['B-1', 'B-2'], 200));

      // Before the fix user B was offered A-1 (the oldest row on the phone).
      expect(await unfiltered(), ('A-1', 5));

      _login('user-b');
      expect(await load(), ('B-1', 2));
      await assign('B-1');
      expect(await load(), ('B-2', 1));

      // User A's ids were not touched by user B's work.
      _login('user-a');
      expect(await load(), ('A-1', 3));

      // A user who never downloaded gets nothing (Download IDs is shown).
      _login('user-c');
      expect(await load(), (null, 0));
      await closeDb();
    });
  }, skip: skip);
}
