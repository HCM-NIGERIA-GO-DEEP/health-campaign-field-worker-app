import 'package:digit_flow_builder/utils/function_registry.dart';
import 'package:digit_flow_builder/utils/interpolation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/function_registries.dart';

/// The configs branch on hasBeneficiaryId in four places - the member card
/// shows the identifier when true and a "NO_BENEFICIARY_ID" tag when false,
/// and the search card now hides a placeholder id the same way.
///
/// Nothing registered it, and FunctionRegistry.call returns null for an unknown
/// name (rendered as ''), so BOTH `==true` and `==false` compared false and
/// neither branch ever applied. A closed household - which only ever carries a
/// DEFAULT identifier - therefore displayed its raw 36-char uuid.
void main() {
  // hasBeneficiaryId reads only its args, so an empty state is enough.
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

  dynamic call(dynamic identifier) =>
      FunctionRegistry.call('hasBeneficiaryId', [identifier], stateData);

  testWidgets('is registered at all', (tester) async {
    await withRegistry(tester, () {
      expect(FunctionRegistry.get('hasBeneficiaryId'), isNotNull,
          reason: 'an unregistered name breaks both ==true and ==false');
    });
  });

  testWidgets('a pool Beneficiary ID is shown', (tester) async {
    await withRegistry(tester, () {
      expect(
        call({
          'identifierType': 'UNIQUE_BENEFICIARY_ID',
          'identifierId': 'X-1',
        }),
        true,
      );
    });
  });

  testWidgets('a DEFAULT placeholder is hidden', (tester) async {
    await withRegistry(tester, () {
      expect(
        call({
          'identifierType': 'DEFAULT',
          'identifierId': '123e4567-e89b-12d3-a456-426614174000',
        }),
        false,
      );
    });
  });

  testWidgets('matches the type case-insensitively and ignores padding',
      (tester) async {
    await withRegistry(tester, () {
      expect(call({'identifierType': ' unique_beneficiary_id '}), true);
    });
  });

  testWidgets('a missing identifier is hidden rather than crashing the card',
      (tester) async {
    await withRegistry(tester, () {
      expect(call(null), false);
      expect(call(<String, dynamic>{}), false);
      expect(call({'identifierType': null}), false);
    });
  });

  testWidgets('any other identifier type is hidden', (tester) async {
    await withRegistry(tester, () {
      expect(call({'identifierType': 'NATIONAL_ID'}), false);
    });
  });
}
