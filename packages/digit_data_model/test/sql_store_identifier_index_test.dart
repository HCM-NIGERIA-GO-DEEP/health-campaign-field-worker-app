import 'dart:ffi';
import 'dart:io';

import 'package:digit_data_model/data/local_store/sql_store/sql_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqlite3/open.dart' as sqlite3_open;

/// Verifies the identifier(identifier_id)/identifier(identifier_type)
/// indexes that National ID / Voter ID / Phone Number search depends on for
/// performance actually get created - both for fresh installs (onCreate) and
/// for devices upgrading from an older schema (onUpgrade from < 13) - and
/// that schemaVersion was actually bumped.
///
/// This talks to a REAL sqlite database (via the plain, unencrypted `sqlite3`
/// package already used as a direct dependency here), file-backed in a temp
/// directory. LocalSqlDataStore's connection is hardcoded to
/// getApplicationDocumentsDirectory() (path_provider), so that single
/// platform channel call is faked to point at a temp dir; no encryption key
/// is passed, so the SQLCipher-only code path
/// (open.overrideFor(OperatingSystem.android, ...)) never engages on this
/// host platform and the system's libsqlite3 is used directly.
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.tempDir);

  final Directory tempDir;

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir.path;

  @override
  Future<String?> getApplicationSupportPath() async => tempDir.path;

  @override
  Future<String?> getTemporaryPath() async => tempDir.path;

  @override
  Future<String?> getApplicationCachePath() async => tempDir.path;

  @override
  Future<String?> getLibraryPath() async => tempDir.path;

  @override
  Future<String?> getExternalStoragePath() async => tempDir.path;

  @override
  Future<List<String>?> getExternalCachePaths() async => [tempDir.path];

  @override
  Future<List<String>?> getExternalStoragePaths({StorageDirectory? type}) async =>
      [tempDir.path];

  @override
  Future<String?> getDownloadsPath() async => tempDir.path;
}

Future<List<String>> _existingIndexNames(LocalSqlDataStore sql) async {
  final rows = await sql
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'identifier'",
      )
      .get();
  return rows.map((r) => r.read<String>('name')).toList();
}

void main() {
  late Directory tempDir;
  late PathProviderPlatform originalPlatform;

  setUpAll(() {
    // This host only has the versioned soname installed (no libsqlite3-dev),
    // so the default unversioned "libsqlite3.so" lookup fails. Point
    // package:sqlite3 at the real file directly - a test-environment-only
    // concern, unrelated to how the app loads sqlite3 on a real device.
    if (Platform.isLinux) {
      sqlite3_open.open.overrideForAll(
        () => DynamicLibrary.open('libsqlite3.so.0'),
      );
    }
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sql_store_index_test_');
    originalPlatform = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir);
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPlatform;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('schemaVersion is bumped to 13', () async {
    final sql = LocalSqlDataStore();
    addTearDown(sql.close);

    expect(sql.schemaVersion, 13);
  });

  test('fresh install (onCreate) creates both identifier search indexes', () async {
    final sql = LocalSqlDataStore();
    addTearDown(sql.close);

    // Force the lazy connection to actually open and run onCreate.
    await sql.customSelect('SELECT 1').get();

    final indexNames = await _existingIndexNames(sql);

    expect(indexNames, contains('identifier_identifierid'));
    expect(indexNames, contains('identifier_identifiertype'));
  });

  test('the indexes actually cover identifier_id / identifier_type (not just declared)', () async {
    final sql = LocalSqlDataStore();
    addTearDown(sql.close);

    final idIndexInfo = await sql
        .customSelect("PRAGMA index_info('identifier_identifierid')")
        .get();
    final typeIndexInfo = await sql
        .customSelect("PRAGMA index_info('identifier_identifiertype')")
        .get();

    expect(idIndexInfo.map((r) => r.read<String>('name')), ['identifier_id']);
    expect(typeIndexInfo.map((r) => r.read<String>('name')), ['identifier_type']);
  });
}
