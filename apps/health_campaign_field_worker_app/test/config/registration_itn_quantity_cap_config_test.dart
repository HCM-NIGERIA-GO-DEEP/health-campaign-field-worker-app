import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/registration_flows.dart';

/// Guards the per-household ITN figure everywhere the registration flow displays
/// or forwards it, so what is shown matches the ceiling the field worker is
/// actually allowed to enter (the ResourceCard widget validates against the
/// same configured number - see custom_resource_card.dart).
///
/// The figure comes from the project's resolved dose criteria via
/// fn:itnQuantityFromConfig (see maxDeliveryQuantityFromDoseCriteria in
/// utils.dart). The app applies no ceiling of its own: the per-household
/// maximum is a per-district campaign decision, each district is its own
/// project, and an app-side cap silently overrode it.
///
/// It must also never go back to reading the raw targetCycle dose-criteria
/// path directly - that lookup resolves to null whenever no cycle is
/// currently running, rendering the field blank.
void main() {
  final config = sampleFlows as Map<String, dynamic>;

  const rawQuantityPath =
      'contextData.0.targetCycle.0.deliveries.0.doseCriteria.0.ProductVariants.0.quantity';
  const cappedExpression =
      '{{fn:itnQuantityFromConfig(contextData.0.eligibleProductVariants)}}';

  List<Map<String, dynamic>> flows() =>
      (config['flows'] as List).cast<Map<String, dynamic>>();

  test('registration never displays the raw, uncapped dose-criteria quantity', () {
    final serialized = jsonEncode(config);

    expect(serialized.contains('{{fn:trimTrailingZero($rawQuantityPath)}}'), isFalse);
    expect(serialized.contains('{{$rawQuantityPath}}'), isFalse);
  });

  test('householdOverview\'s NUMBER_OF_ITN_FOR_DELIVERY label uses the configured quantity', () {
    final householdOverview =
        flows().firstWhere((f) => f['name'] == 'householdOverview');
    final serialized = jsonEncode(householdOverview);

    expect(serialized.contains('NUMBER_OF_ITN_FOR_DELIVERY'), isTrue);
    expect(serialized.contains(cappedExpression), isTrue);
  });

  test('previewScreen\'s NUMBER_OF_ITN_FOR_DELIVERY label uses the configured quantity', () {
    final previewScreen =
        flows().firstWhere((f) => f['name'] == 'previewScreen');
    final serialized = jsonEncode(previewScreen);

    expect(serialized.contains('NUMBER_OF_ITN_FOR_DELIVERY'), isTrue);
    expect(serialized.contains(cappedExpression), isTrue);
  });

  test('the "qty" navigation value forwarded to DELIVERY uses the configured quantity', () {
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
