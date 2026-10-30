// RC-04 (window), RC-08 and DS-01 (shared device):
// LoadUniqueIdPoolExecutor (load_unique_id_pool_executor.dart) queries the
// pool for the logged-in user, then writes the count and the oldest free ID
// into the screen state. Since fix F1 it also creates the state when none
// exists (the RC-08 test below was inverted when F1 landed).
import 'dart:async';

import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/action_handler/action_config.dart';
import 'package:digit_flow_builder/blocs/flow_crud_bloc.dart';
import 'package:digit_flow_builder/utils/flow_widget_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/executors/load_unique_id_pool_executor.dart';
import 'package:mocktail/mocktail.dart';

import 'support/unique_id_test_support.dart';

ActionConfig loadAction() => ActionConfig(
      action: '',
      actionType: 'LOAD_UNIQUE_ID_POOL',
      properties: {},
    );

Map<String, dynamic> contextFor(String key) =>
    {'wrappers': const [], '_compositeKey': key};

void main() {
  setUpAll(initTestEnv);
  setUp(resetRegistry);
  tearDown(() {
    resetRegistry();
    resetSingleton();
  });

  testWidgets('RC-04: no pool values until the query returns; then they land on an existing state',
      (tester) async {
    final repo = MockUniqueIdPoolRepo();
    final completer = Completer<List<UniqueIdPoolModel>>();
    when(() => repo.search(any())).thenAnswer((_) => completer.future);
    setSingleton(user: UserModel(uuid: 'U1'));
    final ctx = await pumpContext(tester, repo: repo);

    final pending =
        LoadUniqueIdPoolExecutor().execute(loadAction(), ctx, contextFor(kKey));

    // The query was issued synchronously, for this user's free rows only.
    final query = verify(() => repo.search(captureAny())).captured.single
        as UniqueIdPoolSearchModel;
    expect(query.status, 'UN_ASSIGNED');
    expect(query.userUuid, 'U1');

    // The window: nothing in the state while the database works.
    expect(FlowCrudStateRegistry().getByCompositeKey(kKey), isNull);

    // What the idSearch switch does in its post-frame callback
    // (switch_widget.dart:22-26 → flow_widget_state.dart:208-219).
    WidgetStateContext(compositeKey: kKey).updateWidgetData('idSearch', false);

    completer.complete([
      poolRow('ID-NEW', createdTime: 2000),
      poolRow('ID-OLD', createdTime: 1000),
    ]);
    final out = await pending;

    final state = FlowCrudStateRegistry().getByCompositeKey(kKey)!;
    expect(state.widgetData!['uniqueIdPoolCount'], 2);
    expect(state.widgetData!['latestBeneficiaryId'], 'ID-OLD',
        reason: '"latest" is the oldest row by createdTime (:49-54)');
    expect(state.widgetData!['idSearch'], false, reason: 'other keys kept');
    expect(out['uniqueIdPoolCount'], 2);
  });

  testWidgets('RC-08 fixed (F1): with no existing state the loader creates it',
      (tester) async {
    final repo = MockUniqueIdPoolRepo();
    when(() => repo.search(any()))
        .thenAnswer((_) async => [poolRow('ID-1', createdTime: 1)]);
    setSingleton(user: UserModel(uuid: 'U1'));
    final ctx = await pumpContext(tester, repo: repo);

    final out =
        await LoadUniqueIdPoolExecutor().execute(loadAction(), ctx, contextFor(kKey));

    final wd = FlowCrudStateRegistry().getByCompositeKey(kKey)!.widgetData!;
    expect(wd['uniqueIdPoolCount'], 1);
    expect(wd['latestBeneficiaryId'], 'ID-1');
    expect(out['uniqueIdPoolCount'], 1);
    expect(out['latestBeneficiaryId'], 'ID-1');
  });

  testWidgets('RC-13: a failing lookup is swallowed and the input returns unchanged',
      (tester) async {
    setSingleton(user: UserModel(uuid: 'U1'));
    final ctx = await pumpContext(tester); // no repository provider

    final input = contextFor(kKey);
    final out = await LoadUniqueIdPoolExecutor().execute(loadAction(), ctx, input);

    expect(identical(out, input), isTrue, reason: 'catch (e) { return contextData; }');
    expect(FlowCrudStateRegistry().getByCompositeKey(kKey), isNull);
  });

  testWidgets('DS-01: a second user on the same device sees none of the first user\'s rows',
      (tester) async {
    final repo = MockUniqueIdPoolRepo();
    // The local repository filters on userUuid (local/unique_id_pool.dart:61-67);
    // the stub mirrors that: rows exist for U1 only.
    when(() => repo.search(any())).thenAnswer((invocation) async {
      final q = invocation.positionalArguments.first as UniqueIdPoolSearchModel;
      return q.userUuid == 'U1'
          ? [poolRow('ID-A', userUuid: 'U1')]
          : <UniqueIdPoolModel>[];
    });
    setSingleton(user: UserModel(uuid: 'U2'));
    final ctx = await pumpContext(tester, repo: repo);
    FlowCrudStateRegistry()
        .updateByCompositeKey(kKey, const FlowCrudState(widgetData: {}));

    await LoadUniqueIdPoolExecutor().execute(loadAction(), ctx, contextFor(kKey));

    final query = verify(() => repo.search(captureAny())).captured.single
        as UniqueIdPoolSearchModel;
    expect(query.userUuid, 'U2');
    final state = FlowCrudStateRegistry().getByCompositeKey(kKey)!;
    expect(state.widgetData!['uniqueIdPoolCount'], 0,
        reason: 'the popup variant shows although U1\'s free rows are on the device');
    expect(state.widgetData!['latestBeneficiaryId'], isNull,
        reason: '"Skip and continue" will pass null → DEFAULT, <uuid>');
  });
}
