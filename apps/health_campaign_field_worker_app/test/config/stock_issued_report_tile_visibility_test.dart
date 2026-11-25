import 'dart:convert';
import 'dart:io';

import 'package:digit_flow_builder/utils/conditional_evaluator.dart';
import 'package:digit_flow_builder/utils/function_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/inventory_reports.dart';

/// QA (Liberia, 2026-11-25): "stock issue should be removed for dpdis user".
/// Amit's decision: hide the "Stock Issued" tile in View Reports for every
/// user holding DISTRIBUTOR - the CDD and the dual-role Distribution Point
/// user (WAREHOUSE_MANAGER + DISTRIBUTOR). Neither can issue stock.
///
/// The tile already carried a hide rule, but as a forms-engine
/// `visibilityCondition`, which a TEMPLATE screen never reads (it reads
/// `visible`), on a key that does not exist (`singleton.userRole`). So the
/// tile showed for every role.
void main() {
  Map<String, dynamic> tileIn(Map<String, dynamic> config, String fieldName) {
    final flows = (config['flows'] as List).cast<Map<String, dynamic>>();
    for (final flow in flows) {
      for (final widget in (flow['body'] as List? ?? const [])) {
        if (widget is Map && widget['fieldName'] == fieldName) {
          return Map<String, dynamic>.from(widget);
        }
      }
    }
    throw StateError('no tile "$fieldName"');
  }

  final copies = <String, Map<String, dynamic> Function()>{
    'Dart copy': () => inventoryReportFlows,
    'JSON copy': () => jsonDecode(
          File('assets/configs/json/STOCKREPORTS.json')
              .readAsStringSync()
              .replaceFirst('﻿', ''),
        ) as Map<String, dynamic>,
  };

  /// What ResolvedFlowWidget does with `visible`: hidden only on `false`.
  bool shown(Map<String, dynamic> tile, Set<String> roles) {
    FunctionRegistry.register('hasRole', (args, _) => args.any(roles.contains));
    final rule = tile['visible'];
    if (rule == null) return true;
    return ConditionalEvaluator.evaluate(rule, const <String, dynamic>{}) !=
        false;
  }

  for (final copy in copies.entries) {
    group(copy.key, () {
      late Map<String, dynamic> issued;

      setUpAll(() => issued = tileIn(copy.value(), 'stockIssued'));

      test('Stock Issued is hidden for a CDD (DISTRIBUTOR)', () {
        expect(shown(issued, {'DISTRIBUTOR'}), isFalse);
        expect(shown(issued, {'REGISTRAR', 'DISTRIBUTOR'}), isFalse);
      });

      test('Stock Issued is hidden for the dual-role Distribution Point user',
          () {
        expect(shown(issued, {'WAREHOUSE_MANAGER', 'DISTRIBUTOR'}), isFalse);
      });

      test('Stock Issued stays for a warehouse manager and other roles', () {
        expect(shown(issued, {'WAREHOUSE_MANAGER'}), isTrue);
        expect(shown(issued, {'DISTRICT_SUPERVISOR'}), isTrue);
        expect(shown(issued, <String>{}), isTrue);
      });

      test('the rule is one the screen engine reads', () {
        expect(issued['visible'], "{{fn:hasRole('DISTRIBUTOR')}} == false");
        expect(issued.containsKey('visibilityCondition'), isFalse,
            reason: 'a TEMPLATE screen ignores visibilityCondition');
      });

      test('the other report tiles are shown to a distributor as before', () {
        for (final name in [
          'stockRecieved',
          'stockReturned',
          'stockDamaged',
          'stockLoss',
          'stockExcess',
          'stockLess',
          'stockReconciliation',
        ]) {
          expect(shown(tileIn(copy.value(), name), {'DISTRIBUTOR'}), isTrue,
              reason: name);
        }
      });
    });
  }
}
