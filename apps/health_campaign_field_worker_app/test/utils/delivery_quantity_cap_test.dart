import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/utils.dart';

/// Covers capDeliveryQuantity, which enforces the per-household ITN cap at
/// the one place a project's dose-criteria-configured quantity actually
/// reaches the field worker: ResourceCard's max-quantity bound and its
/// pre-filled initial value (widgets/resource_card/custom_resource_card.dart).
/// Without this, a project configured to scale quantity with household size
/// could offer more than the agreed maximum per household.
void main() {
  test('leaves a quantity at or below the cap untouched', () {
    expect(capDeliveryQuantity(1), 1);
    expect(capDeliveryQuantity(3), 3);
  });

  test('clamps a quantity above the cap down to the cap', () {
    expect(capDeliveryQuantity(4), 3);
    expect(capDeliveryQuantity(10), 3);
  });

  test('passes through null (no quantity configured) unchanged', () {
    expect(capDeliveryQuantity(null), null);
  });

  test('supports a custom cap override', () {
    expect(capDeliveryQuantity(5, maxQuantity: 2), 2);
    expect(capDeliveryQuantity(1, maxQuantity: 2), 1);
  });

  test('default cap matches maxDeliveryQuantityPerHousehold', () {
    expect(maxDeliveryQuantityPerHousehold, 3);
  });
}
