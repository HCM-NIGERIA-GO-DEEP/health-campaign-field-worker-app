// RC-04 and RC-06: the gate that picks the direct Register button or the
// "IDs running low" popup (function_registry.dart:2819-2833), alone and
// through the config expression (REGISTRATION.json:2701/2791, :1769/1812).
//
// Production change that would flip the RC-06 case: treating a missing or
// zero minimum as "do not allow a registration without a pool ID".
import 'package:digit_flow_builder/utils/conditional_evaluator.dart';
import 'package:digit_flow_builder/utils/function_registry.dart';
import 'package:digit_flow_builder/utils/interpolation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/unique_id_test_support.dart';

const kPopupVisibleExpr =
    '{{fn:hasMinimumBeneficiaryId(singleton.beneficiaryIdMinCount, uniqueIdPoolCount)}}==false';

dynamic gate(List<dynamic> args) =>
    FunctionRegistry.get('hasMinimumBeneficiaryId')!(args, CrudStateData({}, []));

bool popupShows(Map<String, dynamic> wd) =>
    ConditionalEvaluator.evaluate(
      kPopupVisibleExpr,
      evalContextWith(wd),
      screenKey: kKey,
      stateData: null,
      widgetdata: wd,
    ) ==
    true;

void main() {
  setUpAll(initTestEnv);
  tearDown(resetSingleton);

  group('direct calls', () {
    test('a missing count counts as zero', () {
      expect(gate([10, null]), isFalse); // RC-04: popup until the loader writes
      expect(gate([10, 40]), isTrue);
      expect(gate(['10', '40']), isTrue);
    });

    test('a missing minimum always fails the gate', () {
      expect(gate([null, 40]), isFalse);
      expect(gate([]), isFalse);
    });

    test('RC-06: a minimum of zero passes the gate with an empty pool', () {
      expect(gate([0, null]), isTrue);
      expect(gate([0, 0]), isTrue);
    });
  });

  group('through the config expression', () {
    test('no count in the state → popup variant', () {
      setSingleton(minCount: 10);
      expect(popupShows({}), isTrue);
    });

    test('enough IDs → direct button', () {
      setSingleton(minCount: 10);
      expect(popupShows({'uniqueIdPoolCount': 40}), isFalse);
    });

    test('too few IDs → popup variant', () {
      setSingleton(minCount: 10);
      expect(popupShows({'uniqueIdPoolCount': 5}), isTrue);
    });

    test('minimum not configured → popup even with a full pool', () {
      resetSingleton();
      expect(popupShows({'uniqueIdPoolCount': 40}), isTrue);
    });

    test('RC-06: minimum zero → direct button even with no IDs', () {
      setSingleton(minCount: 0);
      expect(popupShows({}), isFalse);
      expect(popupShows({'uniqueIdPoolCount': 0}), isFalse);
    });
  });
}
