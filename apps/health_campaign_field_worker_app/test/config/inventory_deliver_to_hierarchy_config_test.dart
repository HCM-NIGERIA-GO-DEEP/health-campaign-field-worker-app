import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/manage_stock.dart';

/// Guards the "Deliver To" (facilityToWhich) dropdown for a warehouse manager
/// at the lowest warehouse level.
///
/// Its options come from two places: project facilities one level down, and
/// the DELIVERY_TEAM entry. A Distribution Point has no child facility - the
/// next step down is the delivery team - so DELIVERY_TEAM is the only option
/// there. That entry is gated by `_allowsDeliveryTeamFromValidation`
/// (custom_facility_widgets.dart), which matches the current boundary level
/// against this `hierarchyMapping`. The mapping was inherited from Gombe and
/// only named State / LGA / Distribution Hub, so nothing matched Sierra
/// Leone's hierarchy (Country > Province/Region > District > Chiefdom > PHU >
/// Distribution Point > Community) and the dropdown rendered empty.
///
/// The widget normalises both sides by upper-casing and stripping spaces,
/// underscores and hyphens, so "Distribution Point" also covers a boundary
/// type spelled DISTRIBUTION_POINT.
void main() {
  List<Map<String, dynamic>> deliverToHierarchies(dynamic node,
      {String? fieldName}) {
    final found = <Map<String, dynamic>>[];
    if (node is Map) {
      final field = node['fieldName']?.toString() ?? fieldName;
      if (node['type'] == 'facilityHierarchy' &&
          field == 'facilityToWhich' &&
          node['value'] is Map) {
        found.add((node['value'] as Map).cast<String, dynamic>());
      }
      for (final v in node.values) {
        found.addAll(deliverToHierarchies(v, fieldName: field));
      }
    } else if (node is List) {
      for (final v in node) {
        found.addAll(deliverToHierarchies(v, fieldName: fieldName));
      }
    }
    return found;
  }

  void expectDistributionPointIssuesToDeliveryTeam(
    dynamic config,
    String source,
  ) {
    final hierarchies = deliverToHierarchies(config);

    // RECORDSTOCK and RECORDLESSEXCESS each carry one.
    expect(hierarchies, hasLength(2), reason: source);

    for (final hierarchy in hierarchies) {
      final mapping = hierarchy['hierarchyMapping'] as Map<String, dynamic>;
      expect(
        mapping.keys,
        contains('Distribution Point'),
        reason: '$source is missing the Sierra Leone leaf warehouse level',
      );
      final level = mapping['Distribution Point'] as Map<String, dynamic>;
      expect(level['forIssue'], contains('DELIVERY_TEAM'), reason: source);
    }
  }

  test('INVENTORY.json offers DELIVERY_TEAM from a Distribution Point', () {
    final file = File(
      '${Directory.current.path}/assets/configs/json/INVENTORY.json',
    );
    expectDistributionPointIssuesToDeliveryTeam(
      jsonDecode(file.readAsStringSync()),
      'INVENTORY.json',
    );
  });

  test('sampleInventoryFlows offers DELIVERY_TEAM from a Distribution Point',
      () {
    expectDistributionPointIssuesToDeliveryTeam(
      sampleInventoryFlows,
      'sampleInventoryFlows',
    );
  });
}
