// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';

import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/manage_stock.dart';
import 'package:health_campaign_field_worker_app/utils/function_registries.dart';

/// Sierra Leone ITN, QA 2026-11-18: a partially accepted dispatch (111 sent,
/// 98 received) kept balesQuantity 2.22 - the dispatched bales, like quantity
/// 111 - and nothing held the 1.96 bales received. Amit's call: keep
/// balesQuantity as dispatched and save actualBalesReceived next to every
/// actualQuantityReceived, worked out from the same value.
void main() {
  const fieldPrefix = 'StockModel.additionalFields.fields.';
  // QA's record.
  final contextData = {
    'navigation': {'quantity': '111'},
    'formData': {'actualQuantityReceived': '98'},
  };

  final configs = {
    'manage_stock.dart': sampleInventoryFlows,
    'INVENTORY.json': jsonDecode(
        File('assets/configs/json/INVENTORY.json').readAsStringSync()),
  };

  /// Every UPDATE_EVENT modify list in a flow config.
  List<List<Map<String, dynamic>>> modifyLists(Object? node) {
    final found = <List<Map<String, dynamic>>>[];
    void walk(Object? n) {
      if (n is Map) {
        final props = n['properties'];
        if (n['actionType'] == 'UPDATE_EVENT' &&
            props is Map &&
            props['modify'] is List) {
          found.add((props['modify'] as List).cast<Map<String, dynamic>>());
        }
        n.values.forEach(walk);
      } else if (n is List) {
        n.forEach(walk);
      }
    }

    walk(node);
    return found;
  }

  Set<num> divideByValues(Object? node) {
    final found = <num>{};
    void walk(Object? n) {
      if (n is Map) {
        final computed = n['computedValue'];
        if (computed is Map && computed['divideBy'] is num) {
          found.add(computed['divideBy'] as num);
        }
        n.values.forEach(walk);
      } else if (n is List) {
        n.forEach(walk);
      }
    }

    walk(node);
    return found;
  }

  Future<void> registerFunctions(WidgetTester tester) =>
      tester.pumpWidget(Builder(builder: (context) {
        FunctionRegistries(context).registerAll();
        return const SizedBox();
      }));

  testWidgets(
      'every record that gets actualQuantityReceived gets the same amount '
      'in bales', (tester) async {
    await registerFunctions(tester);

    for (final entry in configs.entries) {
      final perBale = divideByValues(entry.value).single;
      final withQuantity = modifyLists(entry.value)
          .where((m) => m.any(
              (e) => e['key'] == '${fieldPrefix}actualQuantityReceived'))
          .toList();
      // Accept, the damaged and lost return accepts, two partial accepts.
      expect(withQuantity, hasLength(5), reason: entry.key);

      for (final modify in withQuantity) {
        String resolved(String field) => '${resolveValue(
              modify.singleWhere((e) => e['key'] == '$fieldPrefix$field')[
                  'value'],
              contextData,
            )}';
        final pieces = num.parse(resolved('actualQuantityReceived'));
        expect(resolved('actualBalesReceived'),
            (pieces / perBale).toStringAsFixed(2),
            reason: '${entry.key}: $pieces pieces');
        expect(modify.where((e) => e['key'] == '${fieldPrefix}balesQuantity'),
            isEmpty,
            reason: 'balesQuantity stays the dispatched bales');
      }
    }
  });

  testWidgets("QA's case: 98 of 111 received is 1.96 bales", (tester) async {
    await registerFunctions(tester);
    final partial = modifyLists(sampleInventoryFlows).firstWhere((m) => m.any(
        (e) =>
            e['key'] == '${fieldPrefix}actualQuantityReceived' &&
            '${e['value']}'.contains('formData')));
    final bales = partial.singleWhere(
        (e) => e['key'] == '${fieldPrefix}actualBalesReceived')['value'];
    expect(resolveValue(bales, contextData), '1.96');
  });
}
