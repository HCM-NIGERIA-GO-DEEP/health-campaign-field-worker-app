import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/closed_household.dart';

/// Guards the GPS accuracy reading on the closed-household screens.
///
/// `locationAccuracy` is persisted as a raw double, so binding it directly
/// printed the full precision (`4.7299999999999995`) where capture had shown
/// `4.73`. The `formatAccuracy` function fixes that, but it was only applied
/// in CLOSEHOUSEHOLD.json - `sampleCloseHouseholdFlows`, which home.dart
/// passes as the fallback behind the "Closed Household" card, still bound the
/// raw value, so the summary kept showing the long number.
void main() {
  const expected =
      '{{fn:formatAccuracy(contextData.0.HouseholdModel.address.locationAccuracy)}}';

  List<String> accuracyBindings(dynamic node) {
    final bindings = <String>[];
    if (node is Map) {
      if (node['key'] == 'CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_GPS_ACCURACY_LABEL') {
        bindings.add(node['value'].toString());
      }
      for (final v in node.values) {
        bindings.addAll(accuracyBindings(v));
      }
    } else if (node is List) {
      for (final v in node) {
        bindings.addAll(accuracyBindings(v));
      }
    }
    return bindings;
  }

  test('CLOSEHOUSEHOLD.json formats GPS accuracy to two decimals', () {
    final file = File(
      '${Directory.current.path}/assets/configs/json/CLOSEHOUSEHOLD.json',
    );
    final bindings =
        accuracyBindings(jsonDecode(file.readAsStringSync()));

    expect(bindings, isNotEmpty);
    expect(bindings.every((b) => b == expected), isTrue, reason: '$bindings');
  });

  test('sampleCloseHouseholdFlows formats GPS accuracy to two decimals', () {
    final bindings = accuracyBindings(sampleCloseHouseholdFlows);

    expect(bindings, isNotEmpty);
    expect(bindings.every((b) => b == expected), isTrue, reason: '$bindings');
  });
}
