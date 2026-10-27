import 'package:digit_flow_builder/utils/function_registry.dart';
import 'package:digit_flow_builder/utils/interpolation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/function_registries.dart';

/// A closed household captured with only a first name rendered as
/// "Amara null" on the summary screen: CLOSEHOUSEHOLD.json interpolated
/// givenName and familyName as two separate templates joined by a space, so a
/// missing familyName printed the literal text "null".
void main() {
  // fullName reads only its args, so an empty state is enough.
  final stateData = CrudStateData(const {}, const []);

  /// Registration needs a BuildContext, so pump a throwaway widget to get one.
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

  dynamic callIt(List<dynamic> args) =>
      FunctionRegistry.call('fullName', args, stateData);

  testWidgets('is registered at all', (tester) async {
    await withRegistry(tester, () {
      expect(FunctionRegistry.get('fullName'), isNotNull);
    });
  });

  testWidgets('joins both parts when they are present', (tester) async {
    await withRegistry(tester, () {
      expect(callIt(['Amara', 'Kamara']), 'Amara Kamara');
    });
  });

  testWidgets('a missing family name does not render as "null"',
      (tester) async {
    await withRegistry(tester, () {
      expect(callIt(['Amara', null]), 'Amara');
      // Template interpolation can hand the value through as text.
      expect(callIt(['Amara', 'null']), 'Amara');
    });
  });

  testWidgets('an empty or whitespace part leaves no dangling space',
      (tester) async {
    await withRegistry(tester, () {
      expect(callIt(['Amara', '']), 'Amara');
      expect(callIt(['Amara', '   ']), 'Amara');
    });
  });

  testWidgets('a missing given name still renders the family name alone',
      (tester) async {
    await withRegistry(tester, () {
      expect(callIt([null, 'Kamara']), 'Kamara');
    });
  });

  testWidgets('an unresolved template is not printed', (tester) async {
    await withRegistry(tester, () {
      expect(callIt(['Amara', '{{some.path}}']), 'Amara');
    });
  });

  testWidgets('no usable parts yields an empty string, not "null null"',
      (tester) async {
    await withRegistry(tester, () {
      expect(callIt([null, null]), '');
    });
  });

  testWidgets('supports more than two parts', (tester) async {
    await withRegistry(tester, () {
      expect(callIt(['Amara', 'B', 'Kamara']), 'Amara B Kamara');
    });
  });
}
