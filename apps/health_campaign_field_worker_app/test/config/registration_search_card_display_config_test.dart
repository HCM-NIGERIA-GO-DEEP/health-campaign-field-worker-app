import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards what the search results card displays for each household
/// (searchBeneficiary's listView), beyond name and Beneficiary ID:
/// - the head individual's National ID (any of National ID/Voter ID/
///   Passport/Driver's License, consistent with the already-merged
///   National ID search toggle)
/// - a precise "delivery pending" status, instead of overloading the
///   pre-existing "not visited" wording with a different meaning
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

  test('nationalIdDisplay shows the second identifier entry (the captured ID, not the Beneficiary ID)', () {
    final widget = childNamed('nationalIdDisplay');
    final data = (widget['data'] as List).cast<Map<String, dynamic>>().first;

    expect(widget['format'], 'labelPairList');
    // The label is driven by the identifier's own type rather than
    // hardcoded: Sierra Leone captures National ID, Voter ID, Passport and
    // Driver's License through this same slot, so a Passport must not be
    // displayed under a "NATIONAL_ID" label.
    expect(data['key'],
        '{{ item.headIndividual.0.identifiers.1.identifierType }}');
    expect(data['value'], '{{ item.headIndividual.0.identifiers.1.identifierId }}');
  });

  test('nationalIdDisplay hides itself for households with no second identifier (pre-dating this feature)', () {
    final widget = childNamed('nationalIdDisplay');
    final data = (widget['data'] as List).cast<Map<String, dynamic>>().first;

    expect(data['hideIfNull'], true);
  });

  test('nationalIdDisplay sits between the household name and the delivery status', () {
    final nameIndex = cardChildren.indexWhere(
        (c) => c is Map && c['fieldName'] == 'householdName');
    final nationalIdIndex = cardChildren
        .indexWhere((c) => c is Map && c['fieldName'] == 'nationalIdDisplay');
    final statusIndex = cardChildren.indexWhere(
        (c) => c is Map && c['fieldName'] == 'statusNotVisited');

    expect(nameIndex, lessThan(nationalIdIndex));
    expect(nationalIdIndex, lessThan(statusIndex));
  });

  test('not-yet-delivered status uses a precise "delivery pending" key, not the unrelated "not visited" wording', () {
    final widget = childNamed('statusNotVisited');

    expect(widget['value'], 'SEARCH_HOUSEHOLD_STATUS_DELIVERY_PENDING');
  });

  test('delivered status label is unchanged', () {
    final widget = childNamed('statusDelivered');

    expect(widget['value'], 'SEARCH_HOUSEHOLD_STATUS_ITN_DELIVERED');
  });
}
