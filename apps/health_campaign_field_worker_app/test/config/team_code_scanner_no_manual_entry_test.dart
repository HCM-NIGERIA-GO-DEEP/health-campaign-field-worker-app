import 'dart:convert';
import 'dart:io';

import 'package:digit_scanner/models/scanner_validation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/manage_stock.dart';

/// SL 2026-11-18: the Team Code scanner must only accept a scanned QR, so its
/// "Enter Code Manually" link is switched off. Every other inventory scanner
/// keeps manual entry.
void main() {
  /// fieldName -> allowManualEntry, for every scanner field in the config.
  Map<String, List<bool>> scannerManualEntry(dynamic config) {
    final result = <String, List<bool>>{};
    void walk(dynamic node) {
      if (node is Map) {
        if (node['format'] == 'scanner' && node['fieldName'] is String) {
          final rules = ((node['validations'] as List?) ?? [])
              .map((v) =>
                  ScannerValidation.fromJson(Map<String, dynamic>.from(v)))
              .toList();
          result
              .putIfAbsent(node['fieldName'] as String, () => [])
              .add(rules.allowManualEntry);
        }
        node.values.forEach(walk);
      } else if (node is List) {
        node.forEach(walk);
      }
    }

    walk(config);
    return result;
  }

  final configs = <String, dynamic>{
    'INVENTORY.json': jsonDecode(
        File('${Directory.current.path}/assets/configs/json/INVENTORY.json')
            .readAsStringSync()),
    'manage_stock.dart': sampleInventoryFlows,
  };

  for (final entry in configs.entries) {
    test('${entry.key}: only teamCode scanners have manual entry off', () {
      final scanners = scannerManualEntry(entry.value);
      expect(scanners['teamCode'], [false, false]);
      scanners.remove('teamCode');
      expect(scanners, isNotEmpty);
      for (final other in scanners.entries) {
        expect(other.value, everyElement(isTrue), reason: other.key);
      }
    });
  }
}
