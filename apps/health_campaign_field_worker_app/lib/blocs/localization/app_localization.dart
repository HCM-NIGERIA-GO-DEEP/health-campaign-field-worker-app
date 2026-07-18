import 'package:digit_data_model/data/local_store/sql_store/sql_store.dart';
import 'package:flutter/material.dart';

import '../../data/local_store/no_sql/schema/app_configuration.dart';
import '../../data/repositories/local/localization.dart';
import 'app_localizations_delegate.dart';

class AppLocalizations {
  final Locale locale;
  final LocalSqlDataStore sql;

  AppLocalizations(this.locale, this.sql);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static final Map<String, String> _localizedStrings = <String, String>{};

  static LocalizationsDelegate<AppLocalizations> getDelegate(
          AppConfiguration config, LocalSqlDataStore sql) =>
      AppLocalizationsDelegate(config, sql);

  Future<bool> load() async {
    final listOfLocalizations =
        await LocalizationLocalRepository().returnLocalizationFromSQL(sql);

    _localizedStrings.clear();

    for (final localization in listOfLocalizations) {
      // putIfAbsent keeps the first entry per code, matching the previous
      // indexWhere (first-match) behavior when duplicates exist.
      _localizedStrings.putIfAbsent(
        localization.code,
        () => localization.message,
      );
    }

    return _localizedStrings.isNotEmpty ? true : false;
  }

  String translate(String localizedValues) {
    return _localizedStrings[localizedValues] ?? localizedValues;
  }
}
