import 'package:digit_data_model/data/local_store/sql_store/sql_store.dart';
import 'package:flutter/material.dart';

import '../../data/local_store/no_sql/schema/app_configuration.dart';
import '../../data/local_store/no_sql/schema/localization.dart';
import '../../data/repositories/local/localization.dart';
import 'app_localizations_delegate.dart';

class AppLocalizations {
  final Locale locale;
  final LocalSqlDataStore sql;

  AppLocalizations(this.locale, this.sql);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static final List<Localization> _localizedStrings = <Localization>[];
  // O(1) lookup index (code -> message), rebuilt on each load().
  static final Map<String, String> _localizedMap = <String, String>{};

  static LocalizationsDelegate<AppLocalizations> getDelegate(
          AppConfiguration config, LocalSqlDataStore sql) =>
      AppLocalizationsDelegate(config, sql);

  Future<bool> load() async {
    // Load ALL rows for the locale (not the LocalizationParams-filtered
    // subset). Custom flow components (e.g. ResourceCard) resolve labels via
    // AppLocalizations, so it must hold every module's codes just like the
    // flow-builder/forms caches -- otherwise on-demand modules (registration,
    // inventory, ...) render as raw codes in those components.
    final listOfLocalizations = await LocalizationLocalRepository()
        .fetchAllForLocale(
            sql: sql,
            locale: '${locale.languageCode}_${locale.countryCode}');

    _localizedStrings.clear();
    _localizedStrings.addAll(listOfLocalizations);

    _localizedMap.clear();
    for (final l in listOfLocalizations) {
      _localizedMap[l.code] = l.message;
    }

    return _localizedStrings.isNotEmpty ? true : false;
  }

  String translate(String localizedValues) {
    return _localizedMap[localizedValues] ?? localizedValues;
  }
}
