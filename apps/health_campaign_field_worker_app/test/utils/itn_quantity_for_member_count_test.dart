import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the REGISTRATION.json wiring of the ITN entitlement shown as
/// NUMBER_OF_ITN_FOR_DELIVERY.
///
/// Two superseded approaches this must not drift back to:
///
///  1. Reading the dose-criteria quantity through the `targetCycle` lookup.
///     That lookup resolves to null whenever no cycle is currently running,
///     which rendered the field blank.
///  2. Deriving the figure in the app as "1 net per 2 household members,
///     capped at 3" (fn:itnsForMemberCount). That was app-side guesswork; it
///     ignored the maximum the campaign actually configured, so a campaign
///     created with a maximum of 4 still showed and distributed 3.
///
/// The figure now comes from `eligibleProductVariants` - the dose criteria
/// the flow builder has already resolved into context - so each district's
/// own configured maximum is what the field worker sees.
void main() {
  late String raw;
  late Map<String, dynamic> config;

  const expression =
      '{{fn:itnQuantityFromConfig(contextData.0.eligibleProductVariants)}}';

  setUpAll(() {
    raw = File('assets/configs/json/REGISTRATION.json').readAsStringSync();
    config = jsonDecode(raw) as Map<String, dynamic>;
  });

  List<String> valuesForKey(String key) {
    final values = <String>[];
    void walk(dynamic node) {
      if (node is Map) {
        if (node['key'] == key && node['value'] != null) {
          values.add(node['value'].toString());
        }
        node.values.forEach(walk);
      } else if (node is List) {
        node.forEach(walk);
      }
    }

    walk(config);
    return values;
  }

  test('NUMBER_OF_ITN_FOR_DELIVERY is read from the backend dose criteria',
      () {
    final values = valuesForKey('NUMBER_OF_ITN_FOR_DELIVERY');

    expect(values, isNotEmpty);
    for (final value in values) {
      expect(value, expression);
    }
  });

  test('every screen agrees on the same source - none is left behind', () {
    // householdOverview and previewScreen both display this figure; a
    // partial migration would show two different numbers for one household.
    expect(
      valuesForKey('NUMBER_OF_ITN_FOR_DELIVERY').toSet(),
      {expression},
    );
  });

  test('the app-side member-count rule is gone from the config', () {
    expect(raw, isNot(contains('itnsForMemberCount')));
  });

  test('no reader is left on the stale targetCycle doseCriteria path', () {
    expect(raw, isNot(contains('doseCriteria.0.ProductVariants.0.quantity')));
  });
}
