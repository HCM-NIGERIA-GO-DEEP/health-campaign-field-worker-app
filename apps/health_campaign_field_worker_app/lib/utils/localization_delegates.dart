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
    // The forms engine and the flow builder render every JSON flow, so they
    // need every module's codes, not the subset of the last load. The app
    // root rebuilds (and these delegates reload) each time a load ends, and
    // with the filtered query that rebuild replaced the full list
    // LocalizationBloc._loadLocale had just set with only the last load's
    // modules: Closed Household opened with raw keys whenever the last load
    // to end was the boundary page's (hcm-common, hcm-login, ...).
    forms_engine_localization.FormLocalization.getDelegate(
      _allForLocale(sql, selectedLocale),
      appConfig.languages!,
    ),
    flow_builder_localization.FlowBuilderLocalization.getDelegate(
      _allForLocale(sql, selectedLocale),
      appConfig.languages!,
    ),
  ];
}

Future<dynamic> _allForLocale(LocalSqlDataStore sql, Locale locale) =>
    Future.value(LocalizationLocalRepository().fetchAllForLocale(
      sql: sql,
      locale: '${locale.languageCode}_${locale.countryCode}',
    ));
