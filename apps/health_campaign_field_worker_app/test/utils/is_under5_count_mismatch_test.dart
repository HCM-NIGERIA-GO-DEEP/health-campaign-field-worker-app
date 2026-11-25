import 'package:digit_flow_builder/utils/function_registry.dart';
import 'package:digit_flow_builder/utils/interpolation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/function_registries.dart';

/// fn:isUnder5CountMismatch keeps householdOverview's Back/Close disabled
/// while the registered members other than the head differ from the
/// household's children count. Its member counting moved into
/// `registeredChildCount` (shared with the children-count floor on household
/// edit); these cases hold the rule's verdicts where they were.
void main() {
  final stateData = CrudStateData(const {}, const []);

  Future<void> withRegistry(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        FunctionRegistries(context).registerAll();
        return const SizedBox.shrink();
      }),
    ));
  }

  Map<String, dynamic> row({required Object? head}) => {
        'member': [
          {'isHeadOfHousehold': head},
        ],
        'individual': const [{}],
      };

  /// `contextData.0.household`: the wrapper's household relation.
  Map<String, dynamic> household(Object? childrenCount) => {
        'HouseholdModel': {
          'memberCount': 3,
          'additionalFields': {
            'schema': 'Household',
            'version': 1,
            'fields': [
              {'key': 'memberCount', 'value': '3'},
              {'key': 'childrenCount', 'value': childrenCount},
            ],
          },
        },
      };

  dynamic mismatch(List<dynamic> members, Object? childrenCount) =>
      FunctionRegistry.call(
        'isUnder5CountMismatch',
        [members, household(childrenCount)],
        stateData,
      );

  testWidgets('no mismatch when every declared child is registered',
      (tester) async {
    await withRegistry(tester);
    final members = [row(head: true), row(head: false), row(head: false)];

    expect(mismatch(members, '2'), false);
    expect(mismatch(members, 2), false);
  });

  testWidgets('mismatch while children are still to be registered',
      (tester) async {
    await withRegistry(tester);

    expect(mismatch([row(head: true), row(head: false)], '2'), true);
    expect(mismatch([row(head: true)], '2'), true);
  });

  testWidgets('mismatch when more children are registered than declared',
      (tester) async {
    await withRegistry(tester);
    final members = [row(head: true), row(head: false), row(head: false)];

    // QA's case: 2 children registered, count edited down to 0.
    expect(mismatch(members, '0'), true);
  });

  testWidgets('a head-only household with no children declared matches',
      (tester) async {
    await withRegistry(tester);

    expect(mismatch([row(head: true)], '0'), false);
    expect(mismatch([row(head: 'true')], '0'), false);
    expect(mismatch([row(head: 1)], '0'), false);
  });

  testWidgets('a null member row is not counted', (tester) async {
    await withRegistry(tester);

    expect(mismatch([null, row(head: true), row(head: false)], '1'), false);
  });

  testWidgets('no arguments means no mismatch', (tester) async {
    await withRegistry(tester);

    expect(
      FunctionRegistry.call('isUnder5CountMismatch', const [], stateData),
      false,
    );
  });

  testWidgets('members that are not a list count as none', (tester) async {
    await withRegistry(tester);

    expect(
      FunctionRegistry.call(
          'isUnder5CountMismatch', [null, household('0')], stateData),
      false,
    );
    expect(
      FunctionRegistry.call(
          'isUnder5CountMismatch', [null, household('1')], stateData),
      true,
    );
  });
}
