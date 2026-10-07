import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/utils.dart';

/// Guards the ITN entitlement shown as NUMBER_OF_ITN_FOR_DELIVERY.
///
/// The Bednet/LLIN project type configures a flat `quantity: 1` per
/// ProductVariant - a per-unit figure, not a per-household total - so reading
/// it directly showed "1" for every household no matter how many members it
/// had. The real rule lives in the project type's own taskProcedure: "1
/// bednet is to be distributed per 2 household members", with the worked
/// examples 4 members -> 2 nets and 5 members -> 3 nets.
void main() {
  group('itnQuantityForMemberCount', () {
    test('matches the worked examples in the project type taskProcedure', () {
      // "If there are 4 household members, 2 bednets should be distributed."
      expect(itnQuantityForMemberCount(4), 2);
      // "If there are 5 household members, 3 bednets should be distributed."
      expect(itnQuantityForMemberCount(5), 3);
    });

    test('rounds up - an odd member still needs a net', () {
      expect(itnQuantityForMemberCount(1), 1);
      expect(itnQuantityForMemberCount(3), 2);
    });

    test('a household of exactly 2 gets a single net', () {
      expect(itnQuantityForMemberCount(2), 1);
    });

    test('never exceeds the per-household cap', () {
      expect(itnQuantityForMemberCount(6), maxDeliveryQuantityPerHousehold);
      expect(itnQuantityForMemberCount(20), maxDeliveryQuantityPerHousehold);
      expect(maxDeliveryQuantityPerHousehold, 3);
    });

    test('an unknown or nonsensical member count yields null, not zero', () {
      // A blank is honest; "0 nets" would be a misleading instruction.
      expect(itnQuantityForMemberCount(null), isNull);
      expect(itnQuantityForMemberCount(0), isNull);
      expect(itnQuantityForMemberCount(-1), isNull);
    });

    test('scales with a different members-per-unit rule', () {
      expect(itnQuantityForMemberCount(6, membersPerUnit: 3, maxQuantity: 10),
          2);
      expect(itnQuantityForMemberCount(7, membersPerUnit: 3, maxQuantity: 10),
          3);
    });
  });

  group('REGISTRATION.json wiring', () {
    late String raw;

    setUpAll(() {
      raw = File('assets/configs/json/REGISTRATION.json').readAsStringSync();
    });

    test(
        'NUMBER_OF_ITN_FOR_DELIVERY is derived from member count, not from '
        'the dose criteria quantity', () {
      final config = jsonDecode(raw);

      final values = <String>[];
      void walk(dynamic node) {
        if (node is Map) {
          if (node['key'] == 'NUMBER_OF_ITN_FOR_DELIVERY') {
            values.add(node['value'].toString());
          }
          node.values.forEach(walk);
        } else if (node is List) {
          node.forEach(walk);
        }
      }

      walk(config);

      expect(values, isNotEmpty);
      for (final value in values) {
        expect(value, contains('itnsForMemberCount'));
        expect(value, contains('memberCount'));
        // The old wiring collapsed to an empty string whenever no project
        // cycle was currently running, because the whole targetCycle lookup
        // resolved to null.
        expect(value, isNot(contains('targetCycle')));
      }
    });

    test(
        'no NUMBER_OF_ITN_FOR_DELIVERY reader is left on the stale '
        'doseCriteria quantity path anywhere in the config', () {
      expect(
        raw,
        isNot(contains(
            'doseCriteria.0.ProductVariants.0.quantity')),
      );
    });
  });
}
