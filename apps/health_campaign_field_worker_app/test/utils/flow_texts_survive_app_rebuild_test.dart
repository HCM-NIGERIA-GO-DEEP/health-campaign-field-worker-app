// ignore_for_file: depend_on_referenced_packages
import 'dart:ffi';
import 'dart:io';

import 'package:digit_data_model/data/local_store/sql_store/sql_store.dart';
import 'package:digit_flow_builder/blocs/app_localization.dart';
import 'package:digit_forms_engine/blocs/app_localization.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/data/local_store/no_sql/schema/app_configuration.dart';
import 'package:health_campaign_field_worker_app/data/local_store/no_sql/schema/localization.dart';
import 'package:health_campaign_field_worker_app/data/repositories/local/localization.dart';
import 'package:health_campaign_field_worker_app/utils/localization_delegates.dart';
import 'package:health_campaign_field_worker_app/utils/utils.dart'
    show LocalizationParams;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqlite3/open.dart';

/// Liberia QA: Close Household showed raw keys on the first entry.
///
/// MaterialApp is rebuilt whenever a text load finishes, and every rebuild
/// reloads the localization delegates. The flow builder and the forms engine
/// each keep ONE static copy of the texts, and their delegates read only the
/// modules and codes of the latest load. The Close Household tile opens the
/// boundary page first, whose load names only the common modules - so the
/// rebuild that followed replaced the full copy with those modules and the
/// flow's own texts were gone when it opened.
///
/// Runs on a real SQLite file. On Windows it uses the sqlite3.dll shipped
/// with Python (override with SQLITE3_DLL=<path>); without one it is skipped.
String? _sqliteDll() {
  if (!Platform.isWindows) return '';
  final fromEnv = Platform.environment['SQLITE3_DLL'];
  if (fromEnv != null && File(fromEnv).existsSync()) return fromEnv;
  final local = Platform.environment['LOCALAPPDATA'];
  if (local == null) return null;
  final programs = Directory('$local\\Programs\\Python');
  if (!programs.existsSync()) return null;
  for (final dir in programs.listSync().whereType<Directory>()) {
    final dll = File('${dir.path}\\DLLs\\sqlite3.dll');
    if (dll.existsSync()) return dll.path;
  }
  return null;
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.dir);
  final String dir;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
}

void main() {
  const locale = Locale('en', 'LR');
  const flowModule = 'hcm-closehousehold-LR-ITN-2026';
  final dll = _sqliteDll();
  final skip = dll == null ? 'no native sqlite3 found (set SQLITE3_DLL)' : null;

  late Directory tmp;
  late LocalSqlDataStore sql;

  setUpAll(() {
    if (dll != null && dll.isNotEmpty) {
      // Python's sqlite3.dll is built with SQLITE_OMIT_AUTOINIT: without an
      // explicit sqlite3_initialize() the first open crashes flutter_tester.
      open.overrideFor(OperatingSystem.windows, () {
        final lib = DynamicLibrary.open(dll);
        lib.lookupFunction<Int32 Function(), int Function()>(
            'sqlite3_initialize')();
        return lib;
      });
    }
  });

  setUp(() async {
    if (dll == null) return;
    tmp = await Directory.systemTemp.createTemp('flow_texts');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    sql = LocalSqlDataStore();
    LocalizationCompanion row(String module, String code, String message) =>
        LocalizationCompanion(
          code: Value(code),
          locale: const Value('en_LR'),
          module: Value(module),
          message: Value(message),
        );
    await LocalizationLocalRepository().create([
      row('hcm-common', 'CORE_COMMON_SUBMIT', 'Submit'),
      row(flowModule, 'CLOSE_HOUSEHOLD_HEADING', 'Close household'),
      row(flowModule, 'CLOSE_HOUSEHOLD_REASON_LABEL', 'Reason'),
      row('hcm-registration-LR-ITN-2026', 'REGISTRATION_HEADING', 'Register'),
      // Another language must stay out.
      const LocalizationCompanion(
        code: Value('CLOSE_HOUSEHOLD_HEADING'),
        locale: Value('fr_LR'),
        module: Value(flowModule),
        message: Value('Fermer'),
      ),
    ], sql);
  });

  tearDown(() async {
    if (dll == null) return;
    LocalizationParams()
      ..setModule('boundary', true)
      ..setCode(null);
    await sql.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// Reloads the app's delegates the way a MaterialApp rebuild does, then
  /// returns the flow builder's and the forms engine's translators.
  Future<(String Function(String), String Function(String))>
      rebuildApp() async {
    final delegates = getAppLocalizationDelegates(
      sql: sql,
      appConfig: AppConfiguration()
        ..languages = [
          Languages()
            ..label = 'English'
            ..value = 'en_LR',
        ],
      selectedLocale: locale,
    ) as List;
    final flow = await delegates
        .whereType<LocalizationsDelegate<FlowBuilderLocalization>>()
        .single
        .load(locale);
    final forms = await delegates
        .whereType<LocalizationsDelegate<FormLocalization>>()
        .single
        .load(locale);
    return (flow.translate, forms.translate);
  }

  test(
      'a rebuild after the boundary page\'s load keeps the flow module texts',
      () async {
    // What LocalizationBloc leaves behind after the boundary page's load:
    // only the common modules plus the boundary codes.
    LocalizationParams()
      ..setLocale(const Locale('en_LR'))
      ..setModule(
          'hcm-common,hcm-login,hcm-scanner,hcm-checklist,hcm-beneficiary',
          false)
      ..setCode(['LR_GBEAPO']);

    final (flow, forms) = await rebuildApp();

    expect(flow('CLOSE_HOUSEHOLD_HEADING'), 'Close household');
    expect(flow('CLOSE_HOUSEHOLD_REASON_LABEL'), 'Reason');
    expect(forms('CLOSE_HOUSEHOLD_REASON_LABEL'), 'Reason');
    expect(flow('REGISTRATION_HEADING'), 'Register',
        reason: 'every flow module stays, not only the one just opened');
    expect(flow('CORE_COMMON_SUBMIT'), 'Submit');
  }, skip: skip);

  test('a rebuild after one flow\'s load keeps the other flows\' texts',
      () async {
    LocalizationParams()
      ..setLocale(const Locale('en_LR'))
      ..setModule('hcm-registration-LR-ITN-2026,hcm-common', false)
      ..setCode(null);

    final (flow, forms) = await rebuildApp();

    expect(flow('CLOSE_HOUSEHOLD_HEADING'), 'Close household');
    expect(forms('CLOSE_HOUSEHOLD_HEADING'), 'Close household');
  }, skip: skip);

  test('the flows are given every text of the selected language, and no other',
      () async {
    LocalizationParams()
      ..setLocale(const Locale('en_LR'))
      ..setModule('hcm-common', false)
      ..setCode(null);

    final rows = await allTextsForLocale(sql, locale) as List;

    expect(rows.map((r) => (r as Localization).locale).toSet(), {'en_LR'});
    expect(
        rows.map((r) => (r as Localization).code),
        unorderedEquals([
          'CORE_COMMON_SUBMIT',
          'CLOSE_HOUSEHOLD_HEADING',
          'CLOSE_HOUSEHOLD_REASON_LABEL',
          'REGISTRATION_HEADING',
        ]));
  }, skip: skip);
}
