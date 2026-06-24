import 'package:digit_data_model/data/local_store/sql_store/sql_store.dart';
import 'package:flutter/material.dart';

import '../../data/local_store/no_sql/schema/app_configuration.dart';
import '../../data/local_store/no_sql/schema/localization.dart';
import '../../data/repositories/local/localization.dart';
import '../../utils/utils.dart';
import 'app_localizations_delegate.dart';

class AppLocalizations {
  final Locale locale;
  final LocalSqlDataStore sql;

  AppLocalizations(this.locale, this.sql);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static final List<Localization> _localizedStrings = <Localization>[];

  static LocalizationsDelegate<AppLocalizations> getDelegate(
          AppConfiguration config, LocalSqlDataStore sql) =>
      AppLocalizationsDelegate(config, sql);

  Future<bool> load() async {
    final listOfLocalizations =
        await LocalizationLocalRepository().returnLocalizationFromSQL(sql);

    // `returnLocalizationFromSQL` only returns rows for the module(s) currently
    // set on [LocalizationParams]. Replacing the in-memory cache with just
    // those would drop translations for every other module that was already
    // loaded — so their keys render raw the moment we navigate to a screen
    // that loads a narrower module set (e.g. moving between attendance pages,
    // where the boundary page loads modules without `hcm-attendance`).
    // Instead, merge the freshly loaded module(s) into the cache so
    // translations accumulate rather than being overwritten.
    final currentLocale = LocalizationParams().locale?.toString();

    final byCode = <String, Localization>{};
    // Keep previously loaded strings for the current locale only — a language
    // switch must not let a stale-locale translation shadow the new one.
    for (final loc in _localizedStrings) {
      if (currentLocale == null || loc.locale == currentLocale) {
        byCode[loc.code] = loc;
      }
    }
    // Merge/overwrite with the module(s) loaded for this call.
    for (final loc in listOfLocalizations) {
      byCode[loc.code] = loc;
    }

    _localizedStrings
      ..clear()
      ..addAll(byCode.values);

    return _localizedStrings.isNotEmpty;
  }

  String translate(String localizedValues) {
    if (_localizedStrings.isEmpty) {
      return localizedValues;
    } else {
      final index = _localizedStrings.indexWhere(
        (medium) => medium.code == localizedValues,
      );

      return index != -1 ? _localizedStrings[index].message : localizedValues;
    }
  }
}
