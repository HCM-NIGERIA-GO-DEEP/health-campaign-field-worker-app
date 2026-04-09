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
import '../blocs/registration_deliver/app_localization.dart';
import '../data/local_store/no_sql/schema/app_configuration.dart';
import '../data/repositories/local/localization.dart';

getAppLocalizationDelegates({
  required LocalSqlDataStore sql,
  required AppConfiguration appConfig,
  required Locale selectedLocale,
}) {
  // Each returnLocalizationFromSQL call is deferred via Future.microtask so
  // that the DB query runs AFTER LocalizationBloc._loadLocale has updated
  // LocalizationParams (module list + locale). Previously these Futures were
  // evaluated eagerly at widget-build time, before the bloc had set the
  // correct module filter — causing all package delegates to receive an empty
  // or wrong result and display raw translation keys.
  Future<List> lazyLocalizations() =>
      Future.microtask(() => LocalizationLocalRepository().returnLocalizationFromSQL(sql));

  return [
    AppLocalizations.getDelegate(appConfig, sql),
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,

    // INFO : Need to add package delegates here

    attendance_localization.AttendanceLocalization.getDelegate(
      lazyLocalizations(),
      appConfig.languages!,
    ),
    survey_form_localization.SurveyFormLocalization.getDelegate(
      lazyLocalizations(),
      appConfig.languages!,
    ),
    scanner_localization.ScannerLocalization.getDelegate(
      lazyLocalizations(),
      appConfig.languages!,
    ),
    digit_dss_localization.DashboardLocalization.getDelegate(
      lazyLocalizations(),
      appConfig.languages!,
    ),
    component_localization.ComponentLocalization.getDelegate(
      lazyLocalizations(),
      appConfig.languages!,
    ),
    transit_post_localization.TransitPostLocalization.getDelegate(
      lazyLocalizations(),
      appConfig.languages!,
    ),
    forms_engine_localization.FormLocalization.getDelegate(
      lazyLocalizations(),
      appConfig.languages!,
    ),
    flow_builder_localization.FlowBuilderLocalization.getDelegate(
      lazyLocalizations(),
      appConfig.languages!,
    ),
    RegistrationDeliveryLocalization.getDelegate(
      lazyLocalizations(),
      appConfig.languages!,
    ),
  ];
}
