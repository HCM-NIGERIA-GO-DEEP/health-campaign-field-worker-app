import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the per-household ITN figure everywhere REGISTRATION.json displays
/// or forwards it, so it never contradicts the quantity the field worker is
/// actually allowed to enter (ResourceCard enforces the same configured
/// maximum - see custom_resource_card.dart).
///
/// The figure is resolved from the project's dose criteria via
/// fn:itnQuantityFromConfig (see maxDeliveryQuantityFromDoseCriteria in
/// utils.dart). It must not go back to either of the superseded sources:
///
///  - the `targetCycle` dose-criteria path, which resolves to null whenever
///    no cycle is currently running and rendered the field blank;
///  - fn:itnsForMemberCount, which derived the figure in the app and capped
///    it at a hardcoded 3, overriding whatever the campaign configured.
void main() {
  late Map<String, dynamic> config;

  const rawQuantityPath =
      'contextData.0.targetCycle.0.deliveries.0.doseCriteria.0.ProductVariants.0.quantity';
  const configExpression =
      '{{fn:itnQuantityFromConfig(contextData.0.eligibleProductVariants)}}';

  setUpAll(() {
    final file = File(
      '${Directory.current.path}/assets/configs/json/REGISTRATION.json',
    );
    config = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  });

  List<Map<String, dynamic>> flows() =>
      (config['flows'] as List).cast<Map<String, dynamic>>();

  test('REGISTRATION.json never reads the quantity off the targetCycle path',
      () {
    final serialized = jsonEncode(config);

    expect(serialized.contains('{{fn:trimTrailingZero($rawQuantityPath)}}'),
        isFalse);
    expect(serialized.contains('{{$rawQuantityPath}}'), isFalse);
  });

  test('no app-side cap is applied to the displayed figure', () {
    // The maximum is campaign configuration; capping it again in the config
    // would reintroduce exactly the bug this replaced.
    final serialized = jsonEncode(config);

    expect(serialized.contains('itnsForMemberCount'), isFalse);
    expect(serialized.contains('capNumber'), isFalse);
  });

  test("householdOverview's NUMBER_OF_ITN_FOR_DELIVERY comes from config", () {
    final householdOverview =
        flows().firstWhere((f) => f['name'] == 'householdOverview');
    final serialized = jsonEncode(householdOverview);

    expect(serialized.contains('NUMBER_OF_ITN_FOR_DELIVERY'), isTrue);
    expect(serialized.contains(configExpression), isTrue);
  });

  test("previewScreen's NUMBER_OF_ITN_FOR_DELIVERY comes from config", () {
    final previewScreen =
        flows().firstWhere((f) => f['name'] == 'previewScreen');
    final serialized = jsonEncode(previewScreen);

    expect(serialized.contains('NUMBER_OF_ITN_FOR_DELIVERY'), isTrue);
    expect(serialized.contains(configExpression), isTrue);
  });

  test('the "qty" navigation value forwarded to DELIVERY uses the same source',
      () {
    // If this drifted from the displayed figure, the household overview would
    // promise one number and the delivery form would pre-fill another.
    final householdOverview =
        flows().firstWhere((f) => f['name'] == 'householdOverview');
    final footerButton = (householdOverview['footer'] as List)
        .cast<Map<String, dynamic>>()
        .first;
    final onAction =
        (footerButton['onAction'] as List).cast<Map<String, dynamic>>();
    final deliveryNav = onAction
        .expand(
            (branch) => (branch['actions'] as List).cast<Map<String, dynamic>>())
        .firstWhere((a) => a['properties']?['name'] == 'DELIVERY');
    final navData =
        (deliveryNav['properties']['data'] as List).cast<Map<String, dynamic>>();
    final qtyEntry = navData.firstWhere((d) => d['key'] == 'qty');

    expect(qtyEntry['value'], configExpression);
  });
}
