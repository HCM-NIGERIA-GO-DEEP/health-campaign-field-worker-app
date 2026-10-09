import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<Map<String, dynamic>> flows;

  setUpAll(() {
    final file = File(
      '${Directory.current.path}/assets/configs/json/REGISTRATION.json',
    );
    final config = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    flows = (config['flows'] as List).cast<Map<String, dynamic>>();
  });

  test(
      'household overview loads delivery tasks through its household beneficiary',
      () {
    final overview =
        flows.firstWhere((flow) => flow['name'] == 'householdOverview');
    final relations = (overview['wrapperConfig']['relations'] as List)
        .cast<Map<String, dynamic>>();
    final beneficiaries = relations
        .firstWhere((relation) => relation['name'] == 'projectBeneficiaries');
    final tasks =
        relations.firstWhere((relation) => relation['name'] == 'tasks');

    expect(beneficiaries['match']['field'], 'beneficiaryClientReferenceId');
    expect(beneficiaries['match']['equalsFrom'], 'clientReferenceId');
    expect(tasks['match']['field'], 'projectBeneficiaryClientReferenceId');
    expect(tasks['match']['inFrom'], 'projectBeneficiaries.clientReferenceId');
  });

  test(
      'Distributor delivery button is disabled after successful administration',
      () {
    final overview =
        flows.firstWhere((flow) => flow['name'] == 'householdOverview');
    final button = (overview['footer'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((widget) => widget['fieldName'] == 'registerBeneficiary');

    expect(
      button['disabled'],
      '{{fn:isClosedHousehold(contextData.0.tasks)}} == true',
    );
  });

  test('delivered search result shows delivered status and disables Open', () {
    final search =
        flows.firstWhere((flow) => flow['name'] == 'searchBeneficiary');
    final listView = (search['body'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((widget) => widget['fieldName'] == 'listView');
    final children =
        (listView['child']['children'] as List).cast<Map<String, dynamic>>();
    final status = children
        .firstWhere((widget) => widget['fieldName'] == 'statusDelivered');

    Map<String, dynamic>? findOpenButton(dynamic node) {
      if (node is Map<String, dynamic>) {
        if (node['label'] == 'OPEN' && node['format'] == 'button') return node;
        for (final value in node.values) {
          final found = findOpenButton(value);
          if (found != null) return found;
        }
      } else if (node is List) {
        for (final value in node) {
          final found = findOpenButton(value);
          if (found != null) return found;
        }
      }
      return null;
    }

    expect(status['value'], 'SEARCH_HOUSEHOLD_STATUS_ITN_DELIVERED');
    expect(status['visible'], '{{fn:isClosedHousehold(item.tasks)}} == true');
    expect(
      findOpenButton(listView)?['disabled'],
      '{{fn:isClosedHousehold(item.tasks)}} == true',
    );
  });

  test(
      'Delivery Checklist fetches config with the canonical beneficiary reference key',
      () {
    final delivery = flows.firstWhere((flow) => flow['name'] == 'DELIVERY');
    final page = (delivery['pages'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((item) => item['page'] == 'DeliveryChecklist');
    final fetch = (page['onAction'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere(
            (action) => action['actionType'] == 'FETCH_TRANSFORMER_CONFIG');
    final data =
        (fetch['properties']['data'] as List).cast<Map<String, dynamic>>();
    final beneficiaryReference = data.firstWhere(
      (entry) => entry['key'] == 'ProjectBeneficiaryClientReferenceId',
    );

    expect(
      beneficiaryReference['value'],
      '{{navigation.ProjectBeneficiaryClientReferenceId}}',
    );
  });

  test('delivery success refreshes the retained search before returning to it',
      () {
    final success =
        flows.firstWhere((flow) => flow['name'] == 'deliverySuccess');
    final exits = <List<Map<String, dynamic>>>[
      (success['body'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((widget) => widget['fieldName'] == 'successCard')
          .letActions('secondaryAction'),
      (success['onSystemBack'] as List).cast<Map<String, dynamic>>(),
      ((success['header'] as List).cast<Map<String, dynamic>>().firstWhere(
                  (widget) => widget['fieldName'] == 'deliveryBack')['onAction']
              as List)
          .cast<Map<String, dynamic>>(),
    ];

    for (final actions in exits) {
      expect(actions.first['actionType'], 'REFRESH_SEARCH');
      expect(actions.first['properties']['screenName'], 'searchBeneficiary');
      expect(actions.last['actionType'], 'NAVIGATION');
      expect(actions.last['properties']['name'], 'searchBeneficiary');
      expect(actions.last['properties']['navigationMode'], 'popUntil');
    }
  });
}

extension on Map<String, dynamic> {
  List<Map<String, dynamic>> letActions(String actionName) =>
      ((this[actionName] as Map<String, dynamic>)['onAction'] as List)
          .cast<Map<String, dynamic>>();
}
