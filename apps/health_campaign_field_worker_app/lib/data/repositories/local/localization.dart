import 'dart:async';

import 'package:digit_data_model/data/local_store/sql_store/sql_store.dart';
import 'package:digit_data_model/utils/utils.dart';
import 'package:drift/drift.dart';

import '../../../utils/utils.dart';
import '../../local_store/no_sql/schema/localization.dart';

class LocalizationLocalRepository {
  FutureOr<List<Localization>> returnLocalizationFromSQL(
      LocalSqlDataStore sql) async {
    return retryLocalCallOperation(() async {
      final selectQuery = sql.select(sql.localization).join([]);

      // List to hold the AND conditions
      final andConditions = <Expression<bool>>[];

      // Add condition for locale if provided
      if (LocalizationParams().locale != null) {
        final localeString = '${LocalizationParams().locale!}';
        andConditions.add(sql.localization.locale.equals(localeString));
      }

      // Add conditions for modules and codes
      if (LocalizationParams().module != null &&
          LocalizationParams().module!.isNotEmpty) {
        final moduleToExclude = LocalizationParams().module!;

        if (LocalizationParams().exclude == true) {
          // Exclude modules but include records where the code matches
          final moduleCondition =
          sql.localization.module.contains(moduleToExclude).not();
          final codeCondition = LocalizationParams().code != null &&
              LocalizationParams().code!.isNotEmpty
              ? sql.localization.code.isIn(LocalizationParams().code!.toList())
              : const Constant(false); // True if no code filter

          // Combine conditions: exclude module unless code matches
          andConditions.add(buildAnd([moduleCondition | codeCondition]));
        } else {
          // Include specified modules and optionally filter by code
          final moduleCondition =
          sql.localization.module.contains(moduleToExclude);
          final codeCondition = LocalizationParams().code != null &&
              LocalizationParams().code!.isNotEmpty
              ? sql.localization.code.isIn(LocalizationParams().code!.toList())
              : const Constant(false);

          final moduleList =
          moduleToExclude.split(',').map((e) => e.trim()).toList();

          // Combine conditions: module matches and optionally code filter
          andConditions.add(
            buildOr([
              sql.localization.module.isIn(moduleList),
              codeCondition,
            ]),
          );
        }
      } else if (LocalizationParams().code != null &&
          LocalizationParams().code!.isNotEmpty) {
        // If no module filter, just apply code filter
        andConditions.add(
            sql.localization.code.isIn(LocalizationParams().code!.toList()));
      }

      // Apply the combined conditions to the query
      if (andConditions.isNotEmpty) {
        selectQuery.where(buildAnd(andConditions));
      }

      final result = await selectQuery.get();

      return result.map((row) {
        final data = row.readTableOrNull(sql.localization);
        if (data == null) {
          throw StateError('No data found for localization');
        }

        return Localization()
          ..code = data.code
          ..locale = data.locale
          ..module = data.module
          ..message = data.message;
      }).toList();
    });
  }

  FutureOr<List<Localization>> fetchLocalization(
      {required LocalSqlDataStore sql,
        required String locale,
        required String module}) async {
    return retryLocalCallOperation(() async {
      final moduleList = module.split(',').map((e) => e.trim()).toList();

      final query = sql.select(sql.localization).join([])
        ..where(
          buildAnd([
            sql.localization.locale.equals(locale),
            sql.localization.module.isIn(moduleList),
          ]),
        );

      final results = await query.get();

      return results.map((e) {
        final data = e.readTableOrNull(sql.localization);

        if (data == null) {
          throw StateError('No data found for localization');
        }

        return Localization()
          ..code = data.code
          ..locale = data.locale
          ..module = data.module
          ..message = data.message;
      }).toList();
    });
  }

  /// Fetches cached localizations for a specific set of [codes] and [locale],
  /// regardless of module. Used by the boundary-by-codes flow to determine
  /// which codes still need to be fetched from the server.
  FutureOr<List<Localization>> fetchLocalizationByCodes(
      {required LocalSqlDataStore sql,
      required String locale,
      required List<String> codes}) async {
    if (codes.isEmpty) return <Localization>[];

    return retryLocalCallOperation(() async {
      final query = sql.select(sql.localization).join([])
        ..where(
          buildAnd([
            sql.localization.locale.equals(locale),
            sql.localization.code.isIn(codes),
          ]),
        );

      final results = await query.get();

      return results.map((e) {
        final data = e.readTableOrNull(sql.localization);

        if (data == null) {
          throw StateError('No data found for localization');
        }

        return Localization()
          ..code = data.code
          ..locale = data.locale
          ..module = data.module
          ..message = data.message;
      }).toList();
    });
  }

  /// Returns EVERY cached localization for the given [locale], regardless of
  /// module or code, ignoring the global [LocalizationParams] filters. The
  /// flow-builder localization cache must hold ALL modules at once; using the
  /// filtered query rebuilt that cache from only the last load's module/code
  /// subset, so a later load (e.g. boundary codes) clobbered earlier modules
  /// (e.g. inventory helptexts) and they rendered as raw codes.
  FutureOr<List<Localization>> fetchAllForLocale(
      {required LocalSqlDataStore sql, required String locale}) async {
    return retryLocalCallOperation(() async {
      final query = sql.select(sql.localization).join([])
        ..where(sql.localization.locale.equals(locale));
      final results = await query.get();
      return results.map((e) {
        final data = e.readTableOrNull(sql.localization);
        if (data == null) {
          throw StateError('No data found for localization');
        }
        return Localization()
          ..code = data.code
          ..locale = data.locale
          ..module = data.module
          ..message = data.message;
      }).toList();
    });
  }

  FutureOr create(
      List<LocalizationCompanion> result, LocalSqlDataStore sql) async {
    if (result.isEmpty) return;
    return retryLocalCallOperation(() async {
      return sql.batch((batch) {
        batch.insertAllOnConflictUpdate(sql.localization, result);
      });
    });
  }
}