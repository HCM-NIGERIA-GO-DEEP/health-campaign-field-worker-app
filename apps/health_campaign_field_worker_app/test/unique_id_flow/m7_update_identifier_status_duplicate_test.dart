// RC-03 regression guard. Before fix F2, UPDATE_IDENTIFIER_STATUS looked the
// pool row up by id only and marked an already ASSIGNED row ASSIGNED again,
// so a stale screen state could give one pool ID to two individuals.
// Since F2 it reads the user's free rows and never writes a used ID again.
import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/action_handler/action_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/executors/update_identifier_status_executor.dart';
import 'package:mocktail/mocktail.dart';

import 'support/unique_id_test_support.dart';

ActionConfig statusAction() => ActionConfig(
      action: '',
      actionType: 'UPDATE_IDENTIFIER_STATUS',
      properties: {},
    );

void main() {
  setUpAll(initTestEnv);
  setUp(() {
    resetRegistry();
    setSingleton(user: UserModel(uuid: 'U1'));
  });
  tearDown(() {
    resetRegistry();
    resetSingleton();
  });

  testWidgets('an ID that is already ASSIGNED is not written again', (tester) async {
    final repo = MockUniqueIdPoolRepo();
    // A mock does not filter: it returns the used row too, as a defence check.
    when(() => repo.search(any())).thenAnswer((_) async => [
          poolRow('ID-1', status: 'ASSIGNED', createdTime: 1),
          poolRow('ID-2', createdTime: 2),
        ]);
    when(() => repo.update(any())).thenAnswer((_) async {});
    final ctx = await pumpContext(tester, repo: repo);

    final out = await UpdateIdentifierStatusExecutor().execute(statusAction(), ctx, {
      'wrappers': const [],
      'entities': [individualWith('UNIQUE_BENEFICIARY_ID', 'ID-1')],
    });

    final written = verify(() => repo.update(captureAny())).captured.single
        as UniqueIdPoolModel;
    expect(written.id, 'ID-2');
    expect(written.status, 'ASSIGNED');
    final saved = (out['entities'] as List).single as IndividualModel;
    expect(saved.identifiers!.single.identifierId, 'ID-2');
  });

  testWidgets('the lookup asks for free rows of the user, not for one id', (tester) async {
    final repo = MockUniqueIdPoolRepo();
    when(() => repo.search(any())).thenAnswer((_) async => <UniqueIdPoolModel>[]);
    final ctx = await pumpContext(tester, repo: repo);

    await UpdateIdentifierStatusExecutor().execute(statusAction(), ctx, {
      'wrappers': const [],
      'entities': [individualWith('UNIQUE_BENEFICIARY_ID', 'ID-404')],
    });
    await tester.pump(const Duration(seconds: 6)); // empty pool → warning toast

    final query = verify(() => repo.search(captureAny())).captured.single
        as UniqueIdPoolSearchModel;
    expect(query.id, isNull);
    expect(query.status, 'UN_ASSIGNED');
    expect(query.userUuid, 'U1');
    verifyNever(() => repo.update(any()));
  });
}
