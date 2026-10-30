// RC-01 (mechanism): FETCH_TRANSFORMER_CONFIG replaces the calling screen's
// whole registry state (transformer_executor.dart:84 and :98), so the pool
// values written by LOAD_UNIQUE_ID_POOL, the typed name and the search results
// are gone. The write happens before the entity mapping (:300-315) and outside
// any try/catch.
//
// Production change that would flip this: the executor merging into the
// existing state (`existing.copyWith(formData: ...)`) instead of replacing it.
import 'package:digit_flow_builder/action_handler/action_config.dart';
import 'package:digit_flow_builder/action_handler/executors/transformer_executor.dart';
import 'package:digit_flow_builder/blocs/flow_crud_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/unique_id_test_support.dart';

void main() {
  setUpAll(initTestEnv);
  setUp(resetRegistry);
  tearDown(() {
    resetRegistry();
    resetSingleton();
  });

  testWidgets('the search-result card action wipes widgetData, results and form data',
      (tester) async {
    final ctx = await pumpContext(tester);
    FlowCrudStateRegistry().updateByCompositeKey(kKey, seededSearchState());

    final before = FlowCrudStateRegistry().getByCompositeKey(kKey)!;
    expect(before.widgetData!['latestBeneficiaryId'], 'ID-1');
    expect(before.widgetData!['uniqueIdPoolCount'], 40);
    expect(before.widgetData!['searchBar'], 'ab');

    // REGISTRATION.json:2533-2543, the first branch of the OPEN card action.
    final out = await TransformerExecutor().execute(
      ActionConfig(
        action: 'transform',
        actionType: 'FETCH_TRANSFORMER_CONFIG',
        properties: {'configName': 'bulkProjectBeneficiaryFromMembers'},
      ),
      ctx,
      {'wrappers': const [], '_compositeKey': kKey},
    );

    final after = FlowCrudStateRegistry().getByCompositeKey(kKey)!;
    expect(after.widgetData, isNull, reason: 'pool ID, count and name gone');
    expect(after.stateWrapper, isNull, reason: 'search results gone');
    expect(after.formData, isNull, reason: 'no form data was passed in');
    expect(out['entities'], isEmpty,
        reason: 'no individuals in context → nothing mapped, nothing thrown');
  });
}
