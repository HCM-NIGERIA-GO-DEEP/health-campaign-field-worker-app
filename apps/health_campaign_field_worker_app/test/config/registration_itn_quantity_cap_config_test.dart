import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the per-household ITN delivery cap (3) everywhere REGISTRATION.json
/// displays or forwards a quantity read directly from the project's dose
/// criteria (bypassing the ResourceCard widget, which separately enforces
/// the same cap on the quantity actually entered for delivery -
/// see custom_resource_card.dart / capDeliveryQuantity in utils.dart).
///
/// Without this, the "NUMBER_OF_ITN_FOR_DELIVERY" label on householdOverview
/// and previewScreen would show a raw, unbounded MDMS-configured number that
/// contradicts the capped quantity the field worker is actually allowed to
/// enter.
void main() {
  late Map<String, dynamic> config;

  const rawQuantityPath =
      'contextData.0.targetCycle.0.deliveries.0.doseCriteria.0.ProductVariants.0.quantity';
  const cappedExpression = '{{fn:capNumber($rawQuantityPath, 3)}}';

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
