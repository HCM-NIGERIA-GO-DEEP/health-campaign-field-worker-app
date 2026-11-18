import 'dart:convert';
import 'dart:io';

import 'package:digit_flow_builder/data/transformer_config.dart';
import 'package:digit_scanner/models/scanner_validation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/registration_flows.dart';

/// Guards the ITN serial capture on the delivery flow.
///
/// The scanner field already existed on the DeliveryDetails page but was
/// `hidden: true`, which meant it was neither rendered
/// (json_form_builder.dart skips hidden properties) nor counted by the
/// under-capture gate in forms_render.dart - so no serials were captured and
/// nothing blocked submission. It also carried a hardcoded `scanLimit: 4`,
/// above the per-household cap of 3.
///
/// For GS1 codes the required scan count is derived from the resource-card
/// quantity (scanner_builder.dart `_effectiveRequiredScanCount`), so the
/// distributor must capture exactly as many serials as ITNs being handed
/// over; `scanLimit` only applies as a fallback when that quantity cannot be
/// read.
void main() {
  group('DeliveryDetails scanner field', () {
    late Map<String, dynamic> scanner;

    setUpAll(() {
      final delivery = (sampleFlows['flows'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((f) => f['name'] == 'DELIVERY');
      final page = (delivery['pages'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((p) => p['page'] == 'DeliveryDetails');
      scanner = (page['properties'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((p) => p['fieldName'] == 'scanner');
    });

    Map<String, dynamic> validationsByType() => {
          for (final v in (scanner['validations'] as List))
            (v as Map)['type'] as String: v['value'],
        };

    // Reversed on request 2026-11-18 (SL): no ITN scan on delivery. Hidden
    // means not rendered (so no Scan QR Code button and no red "Ensure that
    // N ITNs..." banner, both drawn by the scanner field) and not counted by
    // the Next gate in forms_render.dart. Set back to false to bring the
    // scan back; the rest of the field config is kept for that.
    test('is hidden - no scan button, no banner, Next is not gated', () {
      expect(scanner['hidden'], isTrue);
      expect(scanner['format'], 'scanner');
    });

    test('the bundled JSON hides it too', () {
      final delivery = ((jsonDecode(
                  File('assets/configs/json/REGISTRATION.json')
                      .readAsStringSync()
                      .replaceFirst('﻿', ''))
              as Map<String, dynamic>)['flows'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((f) => f['name'] == 'DELIVERY');
      final page = (delivery['pages'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((p) => p['page'] == 'DeliveryDetails');
      final jsonScanner = (page['properties'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((p) => p['fieldName'] == 'scanner');
      expect(jsonScanner['hidden'], isTrue);
    });

    test('is explicitly marked GS1', () {
      // isGS1code defaults to true when unset, but the delivery flow depends
      // on the GS1 branch for both serial extraction and the resource-card
      // derived scan count, so it is stated outright rather than inherited.
      expect(validationsByType()['isGS1Code'], isTrue);
    });

    test('manual serial entry is enabled without pattern validation', () {
      final rules = (scanner['validations'] as List)
          .cast<Map<String, dynamic>>()
          .map(ScannerValidation.fromJson)
          .toList();
      expect(rules.allowManualEntry, isTrue);
      expect(rules.scanLimitMessage,
          'APPONE_REGISTRATION_DELIVERYDETAILS_SCANNER_LIMIT_MESSAGE');
      expect(validationsByType().keys,
          isNot(anyElement(contains(RegExp('pattern', caseSensitive: false)))));
    });

    test('its fallback scan limit covers the largest configured district', () {
      // Only a fallback: the live scan count comes from dynamicScanLimit,
      // driven by the dose criteria. There is no app-side per-household cap
      // to align with any more, so this just has to be >= the largest
      // per-household maximum any district is configured for. Raise it if a
      // district is ever configured above this.
      expect(validationsByType()['scanLimit'], 3);
    });
  });

  group('delivery transformer config', () {
    test('persists captured serials into TaskModel.additionalFields', () {
      final delivery = jsonConfig['delivery'] as Map<String, dynamic>;
      final task = (delivery['models'] as Map)['TaskModel'] as Map;
      final additionalFields =
          (task['mappings'] as Map)['additionalFields'] as Map;

      expect(additionalFields['scanResource'], 'DeliveryDetails.scanner');
    });

    test('TaskResourceModel still has no per-unit serial field', () {
      // Documents why the serials go on the task: the resource row carries
      // only an aggregate quantity. If a real per-unit column is added later
      // this test should fail and the mapping should move there.
      final delivery = jsonConfig['delivery'] as Map<String, dynamic>;
      final listMappings = ((delivery['models'] as Map)['TaskModel']
          as Map)['listMappings'] as Map;
      final resource =
          (listMappings['TaskResourceModel'] as Map)['mappings'] as Map;

      expect(resource.keys, contains('quantity'));
      expect(resource.keys, isNot(contains('scanResource')));
      expect(resource.keys, isNot(contains('serialNumber')));
    });

    test('the stock flow precedent it mirrors is still in place', () {
      // The same additionalFields trick is already used for stock; if that
      // changes, this approach should be revisited too.
      final stock = jsonConfig['stock'] as Map<String, dynamic>;
      final stockFields = ((stock['models'] as Map)['StockModel']
          as Map)['mappings'] as Map;

      expect(
        (stockFields['additionalFields'] as Map)['scanResource'],
        isNotNull,
      );
    });
  });
}
