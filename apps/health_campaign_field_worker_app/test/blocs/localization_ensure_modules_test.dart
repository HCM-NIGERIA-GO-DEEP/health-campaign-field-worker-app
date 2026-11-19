import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:ui';

import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/blocs/app_localization.dart';
import 'package:digit_forms_engine/blocs/app_localization.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/blocs/localization/localization.dart';
import 'package:health_campaign_field_worker_app/data/repositories/local/localization.dart';
import 'package:health_campaign_field_worker_app/data/repositories/remote/localization.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqlite3/open.dart' as sqlite;

class _TestPaths extends PathProviderPlatform {
  final String path;
  _TestPaths(this.path);
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

/// Serves [modules] (module -> code -> message) and records each request.
class _FakeRemote extends LocalizationRepository {
  final Map<String, Map<String, String>> modules;
  final List<String> requested = [];

  _FakeRemote(LocalSqlDataStore sql, this.modules) : super(Dio(), sql);

  @override
  Future loadLocalization({
    required String path,
    required String locale,
    required String module,
    required String tenantId,
    String? codes,
  }) async {
    requested.add(module);
    return rows(locale, module, modules[module] ?? const {});
  }
}

List<LocalizationCompanion> rows(
        String locale, String module, Map<String, String> messages) =>
    messages.entries
        .map((e) => LocalizationCompanion(
              code: Value(e.key),
              locale: Value(locale),
              message: Value(e.value),
              module: Value(module),
            ))
        .toList();

const locale = 'en_NG';
const closeHousehold = 'hcm-closehousehold-ref';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalSqlDataStore sql;
  late _FakeRemote remote;
  late LocalizationBloc bloc;

  final flowBuilder =
      FlowBuilderLocalization(const Locale('en', 'NG'), Future.value([]), []);
  final forms =
      FormLocalization(const Locale('en', 'NG'), Future.value([]), []);

  Future<bool> ensure() => bloc.ensureModulesLoaded(
        modules: [closeHousehold],
        locale: locale,
        tenantId: 'ng',
        path: '/localization/messages/v1/_search',
      );

  setUp(() async {
    if (Platform.isLinux) {
      sqlite.open.overrideForAll(() => DynamicLibrary.open('libsqlite3.so.0'));
    }
    final directory = await Directory.systemTemp.createTemp('loc_ensure_');
    final previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPaths(directory.path);
    sql = LocalSqlDataStore();
    remote = _FakeRemote(sql, {
      closeHousehold: {'CLOSE_HOUSEHOLD_HEADER': 'Closed household'},
    });
    bloc = LocalizationBloc(const LocalizationState(), remote, sql);
    addTearDown(() async {
      await bloc.close();
      await sql.close();
      PathProviderPlatform.instance = previousPaths;
      await directory.delete(recursive: true);
    });
  });

  test('a missing module is fetched and reaches the flow and form copies',
      () async {
    expect(await ensure(), isFalse);

    expect(remote.requested, [closeHousehold]);
    expect(flowBuilder.translate('CLOSE_HOUSEHOLD_HEADER'), 'Closed household');
    expect(forms.translate('CLOSE_HOUSEHOLD_HEADER'), 'Closed household');
  });

  test('a stored module is not fetched again', () async {
    await ensure();
    remote.requested.clear();

    expect(await ensure(), isTrue);
    expect(remote.requested, isEmpty);
  });

  test(
      'rows stored after the last rebuild reach the copies even though the '
      'module was already stored', () async {
    await ensure();

    // The project-selection refresh stores modules one by one and rebuilds
    // the copies only when all of them are done. Store new text the way it
    // does, without a rebuild.
    await LocalizationLocalRepository().create(
      rows(locale, closeHousehold, {
        'CLOSE_HOUSEHOLD_HEADER': 'Closed household',
        'CLOSE_HOUSEHOLD_REASON': 'Reason',
      }),
      sql,
    );
    expect(flowBuilder.translate('CLOSE_HOUSEHOLD_REASON'),
        'CLOSE_HOUSEHOLD_REASON');

    expect(await ensure(), isTrue);
    expect(remote.requested, [closeHousehold]);
    expect(flowBuilder.translate('CLOSE_HOUSEHOLD_REASON'), 'Reason');
    expect(forms.translate('CLOSE_HOUSEHOLD_REASON'), 'Reason');
  });

  test('a reload keeps the current text until the new rows arrive', () async {
    await ensure();

    // The app root reloads these copies each time a load ends. The read can
    // take a while, and screens drawn meanwhile must not get raw keys.
    final pending = Completer<dynamic>();
    final flowReload =
        FlowBuilderLocalization(const Locale('en', 'NG'), pending.future, [])
            .load();
    final formReload =
        FormLocalization(const Locale('en', 'NG'), pending.future, []).load();
    await Future<void>.delayed(Duration.zero);
    expect(flowBuilder.translate('CLOSE_HOUSEHOLD_HEADER'), 'Closed household');
    expect(forms.translate('CLOSE_HOUSEHOLD_HEADER'), 'Closed household');

    pending.complete(await LocalizationLocalRepository()
        .fetchAllForLocale(sql: sql, locale: locale));
    await Future.wait([flowReload, formReload]);
    expect(flowBuilder.translate('CLOSE_HOUSEHOLD_HEADER'), 'Closed household');
    expect(forms.translate('CLOSE_HOUSEHOLD_HEADER'), 'Closed household');
  });
}
