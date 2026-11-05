import 'package:digit_flow_builder/utils/function_registry.dart';
import 'package:digit_flow_builder/utils/interpolation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/function_registries.dart';

/// Exercises interpolation with navigation values supplied only through the
/// explicit navigationParams argument. Live stock flows can supply a richer
/// context, and device probes have observed navigation arguments resolving.
void main() {
  final stateData = CrudStateData(const {}, const []);

  Future<void> withRegistry(WidgetTester tester, VoidCallback body) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            FunctionRegistries(context).registerAll();
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    body();
  }

  String render(String template) => interpolateWithCrudStates(
        template: template,
        stateData: stateData,
        navigationParams: const {'someKey': 'someValue'},
      );

  testWidgets('navigation.* resolves as a plain placeholder', (tester) async {
    await withRegistry(tester, () {
      expect(render('{{navigation.someKey}}').trim(), 'someValue');
    });
  });

  testWidgets('function arguments miss explicit nav params in this harness',
      (tester) async {
    await withRegistry(tester, () {
      final out = render('{{fn:getCommentValue(navigation.someKey, 1)}}');

      expect(out.trim(), isNot('someValue'));
    });
  });

  testWidgets('a coalesce over navigation.* collapses to empty',
      (tester) async {
    await withRegistry(tester, () {
      final out = render(
        '{{fn:getCommentValue(navigation.someKey, navigation.someKey)}}',
      );
      expect(out.trim(), isEmpty);
    });
  });

  testWidgets('quoted literal arguments still resolve', (tester) async {
    await withRegistry(tester, () {
      expect(render("{{fn:getCommentValue('', 'literal-value')}}").trim(),
          'literal-value');
    });
  });
}
