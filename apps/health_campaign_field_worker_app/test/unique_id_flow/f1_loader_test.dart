// F1: LoadUniqueIdPoolExecutor publishes the snapshot, never drops its write,
// and does not query without a logged-in user.
import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/action_handler/action_config.dart';
import 'package:digit_flow_builder/blocs/flow_crud_bloc.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/executors/load_unique_id_pool_executor.dart';
import 'package:mocktail/mocktail.dart';

import 'support/unique_id_test_support.dart';

ActionConfig loadAction() =>
    ActionConfig(action: '', actionType: 'LOAD_UNIQUE_ID_POOL', properties: {});

void main() {
  setUpAll(initTestEnv);
  setUp(resetRegistry);
  tearDown(() {
    resetRegistry();
    resetSingleton();
  });

  testWidgets('publishes the snapshot for the logged-in user', (tester) async {
    final repo = MockUniqueIdPoolRepo();
    when(() => repo.search(any()))
        .thenAnswer((_) async => [poolRow('A'), poolRow('B'), poolRow('C')]);
    setSingleton(user: UserModel(uuid: 'U1'));
    final ctx = await pumpContext(tester, repo: repo);

    await LoadUniqueIdPoolExecutor()
        .execute(loadAction(), ctx, {'wrappers': const [], '_compositeKey': kKey});

    expect(FlowBuilderSingleton().uniqueIdPoolCount, 3);
  });

  testWidgets('publishes the snapshot even when no screen key resolves', (tester) async {
    final repo = MockUniqueIdPoolRepo();
    when(() => repo.search(any())).thenAnswer((_) async => [poolRow('A')]);
    setSingleton(user: UserModel(uuid: 'U1'));
    final ctx = await pumpContext(tester, repo: repo);

    await LoadUniqueIdPoolExecutor().execute(loadAction(), ctx, {'wrappers': const []});

    expect(FlowBuilderSingleton().uniqueIdPoolCount, 1);
  });

  testWidgets('does not query when nobody is logged in', (tester) async {
    final repo = MockUniqueIdPoolRepo();
    setSingleton(user: null, userUuid: '');
    final ctx = await pumpContext(tester, repo: repo);

    await LoadUniqueIdPoolExecutor()
        .execute(loadAction(), ctx, {'wrappers': const [], '_compositeKey': kKey});

    verifyNever(() => repo.search(any()));
    expect(FlowCrudStateRegistry().getByCompositeKey(kKey), isNull);
  });

  testWidgets('keeps the other widgetData keys of an existing state', (tester) async {
    final repo = MockUniqueIdPoolRepo();
    when(() => repo.search(any())).thenAnswer((_) async => [poolRow('A')]);
    setSingleton(user: UserModel(uuid: 'U1'));
    final ctx = await pumpContext(tester, repo: repo);
    FlowCrudStateRegistry().updateByCompositeKey(
        kKey, const FlowCrudState(widgetData: {'searchBar': 'Ad', 'idSearch': false}));

    await LoadUniqueIdPoolExecutor()
        .execute(loadAction(), ctx, {'wrappers': const [], '_compositeKey': kKey});

    final wd = FlowCrudStateRegistry().getByCompositeKey(kKey)!.widgetData!;
    expect(wd['searchBar'], 'Ad');
    expect(wd['idSearch'], false);
    expect(wd['latestBeneficiaryId'], 'A');
    expect(wd['uniqueIdPoolCount'], 1);
  });
}
