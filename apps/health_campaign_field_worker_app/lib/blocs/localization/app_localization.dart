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

  /// Last-resort English text for codes the server has never delivered a
  /// usable message for.
  ///
  /// These codes exist in more than one module with an empty message on at
  /// least one of them, so whether the device ends up with text depends on
  /// which module was fetched and in what order. When the result is empty the
  /// screen renders nothing at all - a blank button the user cannot act on -
  /// which is strictly worse than showing the raw code, because it gives no
  /// hint that anything is missing.
  ///
  /// Deliberately limited to the Beneficiary ID screens rather than a generic
  /// SCREAMING_SNAKE humaniser: a blanket fallback would silently paper over
  /// every genuinely missing localisation and emit English into non-English
  /// locales. A real server message always wins over these.
  static const Map<String, String> _fallbackMessages = <String, String>{
    'DOWNLOAD_BENEFICIARY_IDS': 'Download Beneficiary IDs',
    'BENEFICIARY_IDS_LABEL': 'Beneficiary IDs',
    'NO_OF_BENEFICIARY_IDS_LEFT': 'Number of Beneficiary IDs left',
    'AVAILABLE_BENEFICIARY_IDS_TEXT': 'Available Beneficiary IDs',
    'TOTAL_BENEFICIARY_IDS': 'Total Beneficiary IDs',
    'LOW_BENEFICIARY_IDS_LABEL': 'Low on Beneficiary IDs',
    'NO_BENEFICIARY_IDS_LABEL': 'No Beneficiary IDs',
    'BENEFICIARY_IDS_RE_FETCH': 'Retry download',
    'FAILED_BENEFICIARY_IDS': 'Failed to download Beneficiary IDs',
    'HOME_DISTRIBUTION_LABEL': 'Distribution',
    'APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_memberCount_max_message':
        'Household member count cannot exceed 10',
    'APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount_maxField_message':
        'Number of children cannot exceed total household members',
  };

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
      // This map is keyed by code ONLY, but the rows come from every module at
      // once in no guaranteed order, so two modules defining the same code
      // race and the row read last wins. DOWNLOAD_BENEFICIARY_IDS exists in
      // hcm-beneficiary with text AND in hcm-registration-<campaign> with an
      // empty message; whenever the empty row landed second it blanked the
      // button. Re-upserting the good value could never fix that - the losing
      // side was never the problem.
      //
      // An empty message carries no information, so it must not overwrite one
      // that has text. Ordering between two non-empty rows is unchanged.
      if (l.message.trim().isEmpty &&
          (_localizedMap[l.code]?.trim().isNotEmpty ?? false)) {
        continue;
      }
      _localizedMap[l.code] = l.message;
    }

    return _localizedStrings.isNotEmpty ? true : false;
  }

  String translate(String localizedValues) {
    final message = _localizedMap[localizedValues];
    // An empty message is as useless as a missing one - it renders as nothing
    // at all - so treat both as "not localised" and fall back.
    if (message != null && message.trim().isNotEmpty) return message;

    return _fallbackMessages[localizedValues] ?? localizedValues;
  }
}
