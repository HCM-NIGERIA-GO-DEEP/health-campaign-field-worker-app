import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A household marked closed (via Mark Closed Household, or a declined
/// consent) used to show the same generic "Delivery Pending" status in
/// search as any normal not-yet-delivered household - a Registrar couldn't
/// tell the two apart. This adds a distinct "Closed Household" status,
/// shown only while the task's last status is literally CLOSED_HOUSEHOLD.
/// Once the household is reopened and completed, its task status moves off
/// CLOSED_HOUSEHOLD (see the HOUSEHOLD flow's isEdit && isClosedHousehold
/// branch), so it naturally falls back to "Delivery Pending" like any other
/// household - no separate "revert" logic needed.
void main() {
  late List<dynamic> cardChildren;

  setUpAll(() {
    final file = File(
      '${Directory.current.path}/assets/configs/json/REGISTRATION.json',
    );
    final config = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final flows = (config['flows'] as List).cast<Map<String, dynamic>>();
    final search = flows.firstWhere((f) => f['name'] == 'searchBeneficiary');
    final listView = (search['body'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((w) => w['fieldName'] == 'listView');
    cardChildren = listView['child']['children'] as List<dynamic>;
  });

  Map<String, dynamic> childNamed(String fieldName) {
    return cardChildren.cast<Map<String, dynamic>>().firstWhere(
          (w) => w['fieldName'] == fieldName,
          orElse: () => throw StateError('No card child with fieldName "$fieldName" found'),
        );
  }

  test('statusClosedHousehold shows only while the household is marked closed', () {
    final widget = childNamed('statusClosedHousehold');

    expect(widget['value'], 'SEARCH_HOUSEHOLD_STATUS_CLOSED_HOUSEHOLD');
    expect(widget['visible'], "{{fn:isHouseholdMarkedClosed(item.tasks)}} == true");
  });

  test('statusNotVisited (Delivery Pending) excludes closed households, so the two never both show', () {
    final widget = childNamed('statusNotVisited');

    expect(
      widget['visible'],
      "{{fn:isClosedHousehold(item.tasks)}} == false && {{fn:isHouseholdMarkedClosed(item.tasks)}} == false",
    );
  });

  test('delivered status is unaffected', () {
    final widget = childNamed('statusDelivered');

    expect(widget['value'], 'SEARCH_HOUSEHOLD_STATUS_ITN_DELIVERED');
    expect(widget['visible'], "{{fn:isClosedHousehold(item.tasks)}} == true");
  });
}
