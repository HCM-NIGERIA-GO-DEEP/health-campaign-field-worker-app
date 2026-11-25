import 'dart:ui';

import 'package:attendance_management/blocs/app_localization.dart'
    as attendance_localization;
import 'package:digit_data_model/data/local_store/sql_store/sql_store.dart';
import 'package:digit_dss/blocs/app_localization.dart'
    as digit_dss_localization;
import 'package:digit_flow_builder/blocs/app_localization.dart'
    as flow_builder_localization;
import 'package:digit_forms_engine/blocs/app_localization.dart'
    as forms_engine_localization;
import 'package:digit_scanner/blocs/app_localization.dart'
    as scanner_localization;
import 'package:digit_ui_components/services/AppLocalization.dart'
    as component_localization;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:survey_form/blocs/app_localization.dart'
    as survey_form_localization;
import 'package:transit_post/blocs/app_localization.dart'
    as transit_post_localization;

import '../blocs/localization/app_localization.dart';
import '../data/local_store/no_sql/schema/app_configuration.dart';
import '../data/repositories/local/localization.dart';

getAppLocalizationDelegates({
  required LocalSqlDataStore sql,
  required AppConfiguration appConfig,
  required Locale selectedLocale,
}) {
  final flowTexts = allTextsForLocale(sql, selectedLocale);

  return [
    AppLocalizations.getDelegate(appConfig, sql),
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,

    // INFO : Need to add package delegates here

    attendance_localization.AttendanceLocalization.getDelegate(
      LocalizationLocalRepository().returnLocalizationFromSQL(sql) as Future,
      appConfig.languages!,
    ),
    survey_form_localization.SurveyFormLocalization.getDelegate(
      LocalizationLocalRepository().returnLocalizationFromSQL(sql) as Future,
      appConfig.languages!,
    ),
    scanner_localization.ScannerLocalization.getDelegate(
      LocalizationLocalRepository().returnLocalizationFromSQL(sql) as Future,
      appConfig.languages!,
    ),
    digit_dss_localization.DashboardLocalization.getDelegate(
      LocalizationLocalRepository().returnLocalizationFromSQL(sql) as Future,
      appConfig.languages!,
    ),
    component_localization.ComponentLocalization.getDelegate(
      LocalizationLocalRepository().returnLocalizationFromSQL(sql) as Future,
      appConfig.languages!,
    ),
    transit_post_localization.TransitPostLocalization.getDelegate(
      LocalizationLocalRepository().returnLocalizationFromSQL(sql) as Future,
      appConfig.languages!,
    ),
    // The forms engine and the flow builder each translate from one static
    // copy that must hold the texts of EVERY flow module. These delegates are
    // reloaded on each MaterialApp rebuild (a rebuild follows every finished
    // text load), and returnLocalizationFromSQL reads only the modules and
    // codes of the latest load (LocalizationParams). Reading that here
    // replaced the full copy with the latest subset: opening Close Household
    // goes through the boundary page, whose load names only the common
    // modules, so the flow's own texts were dropped and it showed raw keys.
    // Read all texts of the locale, as LocalizationBloc._loadLocale does.
    // One read serves both delegates.
    forms_engine_localization.FormLocalization.getDelegate(
      flowTexts,
      appConfig.languages!,
    ),
    flow_builder_localization.FlowBuilderLocalization.getDelegate(
      flowTexts,
      appConfig.languages!,
    ),
  ];
}

/// Every stored text of [locale], whatever module it belongs to.
Future<dynamic> allTextsForLocale(LocalSqlDataStore sql, Locale locale) async {
  return LocalizationLocalRepository().fetchAllForLocale(
    sql: sql,
    locale: '${locale.languageCode}_${locale.countryCode}',
  );
}
