// RC-02 (outcome a): the footer Register button's `disabled` gate, evaluated
// exactly as ResolvedFlowWidget.build does (resolved_flow_widget.dart:334-342).
// The config expression is REGISTRATION.json:2700 and :2790.
//
// An unresolved `{{searchBar}}` becomes the string `null` (utils.dart:336-337);
// the formula parser reads `null` as an identifier and `eq` compares strings
// (math_functions.dart:204-215), so a footer that cannot see `searchBar` is
// disabled. Production change that would flip this: the footer reading its
// own instance's state (layout_renderer.dart:448-485).
import 'package:digit_flow_builder/blocs/flow_crud_bloc.dart';
import 'package:digit_flow_builder/utils/conditional_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/unique_id_test_support.dart';

const kDisabledExpr = "{{searchBar}} == null || {{searchBar}} == ''";

bool disabledFor(Map<String, dynamic> wd, {String? screenKey}) =>
    ConditionalEvaluator.evaluate(
      kDisabledExpr,
      evalContextWith(wd),
      screenKey: screenKey,
      stateData: null,
      widgetdata: wd,
    ) ==
    true;

void main() {
  setUp(resetRegistry);
  tearDown(resetRegistry);

  test('no searchBar in the state → Register is disabled', () {
    expect(disabledFor({}), isTrue);
  });

  test('a typed name → Register is enabled', () {
    expect(disabledFor({'searchBar': 'John'}), isFalse);
  });

  test('registry fallback: the gate follows the state the key resolves to', () {
    // conditional_evaluator.dart:26-29 falls back to the registry when the
    // passed widgetData is empty.
    FlowCrudStateRegistry().updateByCompositeKey(
      kKey,
      const FlowCrudState(widgetData: {'searchBar': 'John'}),
    );
    expect(disabledFor({}, screenKey: kKey), isFalse);

    // The RC-01 outcome: the transformer replaced the state with one that has
    // no widgetData at all.
    FlowCrudStateRegistry().updateByCompositeKey(kKey, const FlowCrudState());
    expect(disabledFor({}, screenKey: kKey), isTrue);
  });

  test('documented quirk, not a cause: an empty string does not disable', () {
    // '' replaces the placeholder with nothing → the expression no longer
    // parses → evaluateExpression returns false (conditional_evaluator.dart
    // :150-157) → the button is enabled with an empty search box.
    expect(disabledFor({'searchBar': ''}), isFalse);
  });
}
