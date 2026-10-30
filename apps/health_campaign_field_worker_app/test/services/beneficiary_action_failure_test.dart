import 'package:digit_flow_builder/action_handler/action_config.dart';
import 'package:digit_flow_builder/action_handler/action_handler.dart';
import 'package:digit_flow_builder/action_handler/executors/action_executor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TestExecutor extends ActionExecutor {
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) callback;
  TestExecutor(this.callback);
  @override
  bool canHandle(String actionType) => true;
  @override
  Future<Map<String, dynamic>> execute(ActionConfig action,
          BuildContext context, Map<String, dynamic> data) =>
      callback(data);
}

void main() {
  for (final nested in [false, true]) {
    testWidgets(
        'failed persistence stops assignment and navigation (conditional=$nested)',
        (tester) async {
      var assigned = false;
      var navigated = false;
      final registry = ActionHandler.registry;
      registry.register('TEST_SAVE',
          TestExecutor((_) async => throw StateError('disk full')));
      registry.register('TEST_ASSIGN', TestExecutor((data) async {
        assigned = true;
        return data;
      }));
      registry.register('TEST_NAV', TestExecutor((data) async {
        navigated = true;
        return data;
      }));
      late BuildContext context;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
        context = c;
        return const SizedBox();
      })));
      final actions = [
        {
          'actionType': 'TEST_SAVE',
          'properties': {'stopOnError': true}
        },
        {'actionType': 'TEST_ASSIGN', 'properties': <String, dynamic>{}},
        {'actionType': 'TEST_NAV', 'properties': <String, dynamic>{}},
      ];
      final result = await ActionHandler.executeActions(
          nested
              ? [
                  {
                    'condition': {'expression': 'DEFAULT'},
                    'actions': actions
                  }
                ]
              : actions,
          context,
          {});
      expect(result['haltActionChain'], true);
      expect(assigned, false);
      expect(navigated, false);
      for (final key in ['TEST_SAVE', 'TEST_ASSIGN', 'TEST_NAV']) {
        registry.unregister(key);
      }
    });
  }
}
