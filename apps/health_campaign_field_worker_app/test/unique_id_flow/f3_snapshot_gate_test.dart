// F0 + F3: the process-wide pool snapshot and the gate that prefers it.
// Fixes RC-04 (count missing while loading) and the RC-01 popup after a wipe.
import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/utils/function_registry.dart';
import 'package:digit_flow_builder/utils/interpolation.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/unique_id_test_support.dart';

dynamic gate(List<dynamic> args) =>
    FunctionRegistry.get('hasMinimumBeneficiaryId')!(args, CrudStateData({}, []));

void main() {
  setUpAll(initTestEnv);
  setUp(() => setSingleton(user: UserModel(uuid: 'U1')));
  tearDown(resetSingleton);

  test('no snapshot: the gate uses the screen count as before', () {
    expect(FlowBuilderSingleton().uniqueIdPoolCount, isNull);
    expect(gate([10, 40]), isTrue);
    expect(gate([10, 5]), isFalse);
    expect(gate([null, 40]), isFalse);
  });

  test('the snapshot wins over a stale screen count', () {
    FlowBuilderSingleton().setUniqueIdPoolSnapshot(userUuid: 'U1', count: 2);
    expect(gate([10, 40]), isFalse);
  });

  test('the snapshot is used when the screen count is missing', () {
    FlowBuilderSingleton().setUniqueIdPoolSnapshot(userUuid: 'U1', count: 40);
    expect(gate([10, null]), isTrue);
  });

  test('another user\'s snapshot is ignored', () {
    FlowBuilderSingleton().setUniqueIdPoolSnapshot(userUuid: 'U2', count: 40);
    expect(FlowBuilderSingleton().uniqueIdPoolCount, isNull);
    expect(gate([10, null]), isFalse);
  });

  test('consume decreases the count and stops at 0; clear removes it', () {
    final s = FlowBuilderSingleton();
    s.setUniqueIdPoolSnapshot(userUuid: 'U1', count: 1);
    s.consumeUniqueIdPoolId();
    expect(s.uniqueIdPoolCount, 0);
    s.consumeUniqueIdPoolId();
    expect(s.uniqueIdPoolCount, 0);
    s.clearUniqueIdPoolSnapshot();
    expect(s.uniqueIdPoolCount, isNull);
  });

  test('consume does not lower another user\'s snapshot', () {
    final s = FlowBuilderSingleton();
    s.setUniqueIdPoolSnapshot(userUuid: 'U2', count: 5);
    s.consumeUniqueIdPoolId(); // U1 is logged in
    setSingleton(user: UserModel(uuid: 'U2'));
    expect(s.uniqueIdPoolCount, 5);
  });
}
