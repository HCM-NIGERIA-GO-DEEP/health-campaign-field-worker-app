import 'dart:ffi';
import 'dart:io';

import 'package:digit_data_model/data_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/services/logout_sql_cleanup.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqlite3/open.dart' as sqlite;

class TestPaths extends PathProviderPlatform {
  final String path;
  TestPaths(this.path);
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'logout preserves downloaded ID states and ownership across database reopen',
      () async {
    if (Platform.isLinux) {
      sqlite.open.overrideForAll(() => DynamicLibrary.open('libsqlite3.so.0'));
    }
    final directory = await Directory.systemTemp.createTemp('logout_id_pool_');
    final previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = TestPaths(directory.path);
    var sql = LocalSqlDataStore();
    addTearDown(() async {
      await sql.close();
      PathProviderPlatform.instance = previousPaths;
      await directory.delete(recursive: true);
    });

    // Include unused, consumed, reserved and another user's pool rows. Logout
    // must retain all states exactly, rather than reinsert everything as unused.
    for (final row in [
      ['unused', 'registrar', 'UNASSIGNED', '{}'],
      ['used', 'registrar', 'ASSIGNED', '{}'],
      [
        'reserved',
        'registrar',
        'UNASSIGNED',
        '{"fields":[{"key":"reservedFor","value":"household"}]}'
      ],
      ['other-user', 'other', 'UNASSIGNED', '{}'],
    ]) {
      await sql.customStatement(
        'INSERT INTO unique_id_pool (id, user_uuid, tenant_id, status, additional_fields) VALUES (?, ?, ?, ?, ?)',
        [row[0], row[1], 'si', row[2], row[3]],
      );
    }
    await sql.customStatement('CREATE TABLE session_marker (value TEXT)');
    await sql.customStatement(
        "INSERT INTO session_marker VALUES ('clear on logout')");
    final before = await sql
        .customSelect('SELECT * FROM unique_id_pool ORDER BY id')
        .get();

    await clearLogoutSqlTables(sql);
    expect(
        await sql.customSelect('SELECT * FROM session_marker').get(), isEmpty);
    await sql.close();
    sql = LocalSqlDataStore();
    final after = await sql
        .customSelect('SELECT * FROM unique_id_pool ORDER BY id')
        .get();
    expect(
        after.map((r) => r.data).toList(), before.map((r) => r.data).toList());

    // A second login/logout also retains the pool without duplicating rows.
    await clearLogoutSqlTables(sql);
    expect(await sql.customSelect('SELECT * FROM unique_id_pool').get(),
        hasLength(4));
  });
}
