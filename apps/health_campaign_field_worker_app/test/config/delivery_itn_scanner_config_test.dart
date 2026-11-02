import 'dart:convert';
import 'dart:io';

import 'package:digit_flow_builder/data/transformer_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the ITN serial capture on the delivery flow.
///
/// The scanner field already existed on the DeliveryDetails page but was
/// `hidden: true`, which meant it was neither rendered
/// (json_form_builder.dart skips hidden properties) nor counted by the
/// under-capture gate in forms_render.dart - so no serials were captured and
/// nothing blocked submission.
///
/// For GS1 codes the required scan count is derived from the resource-card
/// quantity (scanner_builder.dart `_effectiveRequiredScanCount`), which in
/// turn now comes from the project's dose criteria. So the distributor
/// captures exactly as many serials as ITNs being handed over, and a district
/// configured for 2 nets and one configured for 4 each get the right count
/// with no app-side number involved.
///
/// `scanLimit` here is only the fallback for when that quantity cannot be
/// read. A template expression would NOT work in a validations value: it is
/// consumed as a raw JSON literal (scanner_builder.dart `scanLimit`) and an
/// unparseable string silently degrades to 1 - so this stays a plain number.
void main() {
  group('DeliveryDetails scanner field', () {
    late Map<String, dynamic> scanner;

    setUpAll(() {
      final config = jsonDecode(
        File('assets/configs/json/REGISTRATION.json').readAsStringSync(),
      ) as Map<String, dynamic>;

      final delivery = (config['flows'] as List)
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

    test('is rendered - a hidden scanner captures nothing and gates nothing',
        () {
      expect(scanner['hidden'], isFalse);
      expect(scanner['format'], 'scanner');
    });

    test('is explicitly marked GS1', () {
      // isGS1code defaults to true when unset, but the delivery flow depends
      // on the GS1 branch for both serial extraction and the resource-card
      // derived scan count, so it is stated outright rather than inherited.
      expect(validationsByType()['isGS1Code'], isTrue);
    });

    test('its fallback scan limit covers the largest configured district', () {
      // 4 is the highest per-household maximum any Liberia district is
      // configured for. A lower fallback (it was 3) would, on the rare path
      // where the resource-card quantity cannot be read, stop a rural
      // distributor from scanning the 4th net they are handing over.
      expect(validationsByType()['scanLimit'], 4);
    });

    test('the fallback is a literal number, not a template expression', () {
      // Validations values skip template resolution entirely, so a
      // "{{fn:...}}" string here would fail int.tryParse and silently
      // collapse the limit to 1.
      expect(validationsByType()['scanLimit'], isA<int>());
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
