import 'package:digit_data_model/data_model.dart';

/// Clears session data while retaining localisation and downloaded ID pools.
Future<void> clearLogoutSqlTables(LocalSqlDataStore sql) async {
  await sql.transaction(() async {
    await sql.customStatement('PRAGMA foreign_keys = OFF;');
    try {
      final tables = await sql
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name NOT LIKE 'sqlite_%' "
            "AND name != 'moor_schema' "
            "AND LOWER(name) != 'localization';",
          )
          .get();

      for (final row in tables) {
        final tableName = row.data['name'] as String?;
        if (tableName == null || tableName.isEmpty) continue;
        // Pool rows are user/tenant scoped. Keep both unused IDs and assigned
        // or reserved metadata so logout cannot discard IDs or make them reusable.
        if (tableName == sql.uniqueIdPool.actualTableName) continue;
        final escaped = tableName.replaceAll('"', '""');
        await sql.customStatement('DELETE FROM "$escaped";');
      }
    } finally {
      await sql.customStatement('PRAGMA foreign_keys = ON;');
    }
  });
}
