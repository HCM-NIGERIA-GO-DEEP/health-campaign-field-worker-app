import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the per-household ITN figure everywhere REGISTRATION.json displays
/// or forwards it, so it never contradicts the capped quantity the field
/// worker is actually allowed to enter (the ResourceCard widget separately
/// enforces the same cap - see custom_resource_card.dart /
/// capDeliveryQuantity in utils.dart).
///
/// The figure is derived from the household's member count via
/// fn:itnsForMemberCount (see itnQuantityForMemberCount in utils.dart), which
/// applies the cap internally. It must never go back to reading the project's
/// dose-criteria quantity directly: that value is a flat per-unit "1" that
/// ignores household size, and the targetCycle lookup it hangs off resolves
/// to null whenever no cycle is currently running - rendering the field
/// blank.
void main() {
  late Map<String, dynamic> config;

  const rawQuantityPath =
      'contextData.0.targetCycle.0.deliveries.0.doseCriteria.0.ProductVariants.0.quantity';
  const cappedExpression =
      '{{fn:itnsForMemberCount(contextData.0.household.HouseholdModel.memberCount)}}';

  setUpAll(() {
    final file = File(
      '${Directory.current.path}/assets/configs/json/REGISTRATION.json',
    );
    config = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  });

  List<Map<String, dynamic>> flows() =>
      (config['flows'] as List).cast<Map<String, dynamic>>();

  test('REGISTRATION.json never displays the raw, uncapped dose-criteria quantity', () {
    final serialized = jsonEncode(config);

    expect(serialized.contains('{{fn:trimTrailingZero($rawQuantityPath)}}'), isFalse);
    expect(serialized.contains('{{$rawQuantityPath}}'), isFalse);
  });

  test('householdOverview\'s NUMBER_OF_ITN_FOR_DELIVERY label is capped at 3', () {
    final householdOverview =
        flows().firstWhere((f) => f['name'] == 'householdOverview');
    final serialized = jsonEncode(householdOverview);

    expect(serialized.contains('NUMBER_OF_ITN_FOR_DELIVERY'), isTrue);
    expect(serialized.contains(cappedExpression), isTrue);
  });

  test('previewScreen\'s NUMBER_OF_ITN_FOR_DELIVERY label is capped at 3', () {
    final previewScreen =
        flows().firstWhere((f) => f['name'] == 'previewScreen');
    final serialized = jsonEncode(previewScreen);

    expect(serialized.contains('NUMBER_OF_ITN_FOR_DELIVERY'), isTrue);
    expect(serialized.contains(cappedExpression), isTrue);
  });

  test('the "qty" navigation value forwarded to DELIVERY is also capped at 3', () {
    final householdOverview =
        flows().firstWhere((f) => f['name'] == 'householdOverview');
    final footerButton =
        (householdOverview['footer'] as List).cast<Map<String, dynamic>>().first;
    final onAction = (footerButton['onAction'] as List).cast<Map<String, dynamic>>();
    final deliveryNav = onAction
        .expand((branch) => (branch['actions'] as List).cast<Map<String, dynamic>>())
        .firstWhere((a) => a['properties']?['name'] == 'DELIVERY');
    final navData =
        (deliveryNav['properties']['data'] as List).cast<Map<String, dynamic>>();
    final qtyEntry = navData.firstWhere((d) => d['key'] == 'qty');

    expect(qtyEntry['value'], cappedExpression);
  });
}
