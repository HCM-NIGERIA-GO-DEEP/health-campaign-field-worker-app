// T12 - the `disabled` rules the REGISTRATION config puts on the low-ID popup
// variants of Register (searchBeneficiary footer) and Add Member
// (householdOverview body) while LOAD_UNIQUE_ID_POOL is still reading the
// pool. Evaluated exactly as ResolvedFlowWidget does.
//
// Keep these strings identical to the config (config repo REGISTRATION.json
// and the MDMS FormConfig).
import 'package:digit_flow_builder/utils/conditional_evaluator.dart';
import 'package:digit_flow_builder/utils/interpolation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/unique_id_test_support.dart';

void main() {
  const searchRegisterDisabled =
      "{{searchBar}} == null || {{searchBar}} == '' || {{uniqueIdPoolLoading}} == true";
  const overviewAddMemberDisabled = '{{uniqueIdPoolLoading}} == true';

  setUpAll(setUpUniqueIdFlow);
  setUp(resetRegistry);
  tearDown(resetRegistry);

  bool disabled(String rule, Map<String, dynamic> widgetData) {
    return ConditionalEvaluator.evaluate(
          rule,
          evalContextWith(widgetData: widgetData),
          screenKey: 'searchBeneficiary::X',
          stateData: CrudStateData({}, []),
          widgetdata: widgetData,
        ) ==
        true;
  }

  group('T12: search screen Register (popup variant)', () {
    test('a name typed while the pool loads -> disabled', () {
      expect(
          disabled(searchRegisterDisabled,
              {'searchBar': 'John', 'uniqueIdPoolLoading': true}),
          isTrue);
    });

    test('a name typed after the pool loaded -> enabled', () {
      expect(
          disabled(searchRegisterDisabled, {
            'searchBar': 'John',
            'uniqueIdPoolLoading': false,
            'uniqueIdPoolCount': 0,
          }),
          isFalse);
    });

    test('no flag at all (an APK without the flag) -> enabled, as before', () {
      expect(disabled(searchRegisterDisabled, {'searchBar': 'John'}), isFalse);
    });

    test('no name -> disabled whatever the flag says', () {
      expect(disabled(searchRegisterDisabled, {'uniqueIdPoolLoading': false}),
          isTrue);
      expect(disabled(searchRegisterDisabled, {}), isTrue);
    });

    test("quirk (T3): searchBar '' breaks the whole expression -> enabled", () {
      // '' is substituted verbatim, the parser fails and evaluateExpression
      // returns false - even while the pool loads. Pre-existing, not changed.
      expect(
          disabled(searchRegisterDisabled,
              {'searchBar': '', 'uniqueIdPoolLoading': true}),
          isFalse);
    });
  });

  group('T12: household overview Add Member (popup variant)', () {
    test('while the pool loads -> disabled', () {
      expect(disabled(overviewAddMemberDisabled, {'uniqueIdPoolLoading': true}),
          isTrue);
    });

    test('after the pool loaded -> enabled', () {
      expect(
          disabled(overviewAddMemberDisabled,
              {'uniqueIdPoolLoading': false, 'uniqueIdPoolCount': 3}),
          isFalse);
    });

    test('no flag at all -> enabled, as before', () {
      expect(disabled(overviewAddMemberDisabled, {}), isFalse);
    });
  });
}
