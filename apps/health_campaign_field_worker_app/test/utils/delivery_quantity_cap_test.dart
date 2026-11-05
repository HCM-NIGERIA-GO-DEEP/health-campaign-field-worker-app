import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the ABSENCE of an app-side per-household ITN cap.
///
/// This file used to cover capDeliveryQuantity / maxDeliveryQuantityPerHousehold,
/// a hardcoded ceiling of 3. The per-household maximum is a per-district
/// campaign decision carried on the project type, and each district is its own
/// project, so the constant silently overrode the backend config and made every
/// district behave identically - a district configured for 4 nets still issued
/// 3. The value now comes from the resolved dose criteria
/// (maxDeliveryQuantityFromDoseCriteria, covered in
/// itn_quantity_for_member_count_test.dart).
///
/// Reintroducing a constant here would re-break it silently, with no failing
/// assertion anywhere else, so the ban is asserted directly against the source.
void main() {
  String read(String path) =>
      File('${Directory.current.path}/$path').readAsStringSync();

  test('no app-side per-household quantity cap survives in utils', () {
    final utils = read('lib/utils/utils.dart');
    expect(utils, isNot(contains('maxDeliveryQuantityPerHousehold')));
    expect(utils, isNot(contains('capDeliveryQuantity')));
    expect(utils, contains('maxDeliveryQuantityFromDoseCriteria'));
  });

  test('the resource card validates against the configured max, not a constant',
      () {
    final card = read('lib/widgets/resource_card/custom_resource_card.dart');
    expect(card, isNot(contains('maxDeliveryQuantityPerHousehold')));
    expect(card, isNot(contains('capDeliveryQuantity')));
    // The ceiling is applied only when the config actually carries one.
    expect(card, contains('if (configuredMax != null) Validators.max('));
  });

  test('the stock sufficiency checks no longer clamp the required quantity',
      () {
    // Clamping here under-stated what a delivery needs for a district
    // configured above the old cap, so the insufficient-stock check passed on
    // a balance that could not cover it.
    expect(
      read('lib/utils/function_registries.dart'),
      isNot(contains('maxDeliveryQuantityPerHousehold ?')),
    );
  });
}
