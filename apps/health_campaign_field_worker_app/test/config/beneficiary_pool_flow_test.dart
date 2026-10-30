import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/registration_flows.dart';

void main() {
  for (final entry in <String, Map<String, dynamic>>{
    'Dart fallback': Map<String, dynamic>.from(sampleFlows as Map),
    'bundled JSON': jsonDecode(
            File('assets/configs/json/REGISTRATION.json').readAsStringSync())
        as Map<String, dynamic>,
  }.entries) {
    group(entry.key, () {
      final flows = (entry.value['flows'] as List).cast<Map<String, dynamic>>();
      final search = flows.firstWhere((f) => f['name'] == 'searchBeneficiary');
      test(
          'only registrars see downloads and new registration, with no skip bypass',
          () {
        final footer = (search['footer'] as List).cast<Map<String, dynamic>>();
        final download =
            footer.firstWhere((f) => f['fieldName'] == 'beneficiaryIdMinCheck');
        final register = footer
            .firstWhere((f) => f['fieldName'] == 'registerNewBeneficiary');
        expect(download['visible'], "{{fn:hasRole('REGISTRAR')}} == true");
        expect(register['visible'], download['visible']);
        expect(download['format'], 'button');
        expect(download['hidden'], isNot(true));
        expect(download['properties']['popupConfig'], isNull);
        expect(register['disabled'],
            '{{fn:hasMinimumBeneficiaryId(1, uniqueIdPoolCount)}} == false');
        expect(register['onAction'][0]['properties']['requireAvailable'], true);
        expect(search['initActions'][0]['actionType'], 'LOAD_UNIQUE_ID_POOL');
      });
      test('all allocating branches persist before marking raw IDs assigned',
          () {
        final household = flows.firstWhere((f) => f['name'] == 'HOUSEHOLD');
        var allocating = 0;
        for (final branch in household['onAction'] as List) {
          final actions =
              (branch['actions'] as List).cast<Map<String, dynamic>>();
          expect(
              actions.any(
                  (a) => a['actionType'] == 'GENERATE_LOCAL_BENEFICIARY_ID'),
              false);
          if (!actions.any((a) => a['actionType'] == 'LOAD_UNIQUE_ID_POOL'))
            continue;
          allocating++;
          final pool = actions
              .firstWhere((a) => a['actionType'] == 'LOAD_UNIQUE_ID_POOL');
          expect(pool['properties']['allocate'], true);
          final assigned = actions
              .indexWhere((a) => a['actionType'] == 'UPDATE_IDENTIFIER_STATUS');
          final writes = actions.where((a) =>
              ['CREATE_EVENT', 'UPDATE_EVENT'].contains(a['actionType']));
          expect(writes, isNotEmpty);
          for (final write in writes) {
            expect(actions.indexOf(write), lessThan(assigned));
            expect(write['properties']['stopOnError'], true);
            if (write['actionType'] == 'CREATE_EVENT')
              expect(write['properties']['awaitPersistence'], true);
          }
          expect(
              assigned,
              lessThan(
                  actions.indexWhere((a) => a['actionType'] == 'NAVIGATION')));
        }
        expect(allocating, 3);
      });
    });
  }
}
