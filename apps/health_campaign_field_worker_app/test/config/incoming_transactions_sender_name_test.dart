// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';

import 'package:digit_data_converter/src/transformer_service.dart';
import 'package:digit_data_converter/utils/utils.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/data/digit_data_converter.dart';
import 'package:digit_flow_builder/data/transformer_config.dart';
import 'package:digit_flow_builder/utils/function_registry.dart';
import 'package:digit_flow_builder/utils/interpolation.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/manage_stock.dart';
import 'package:health_campaign_field_worker_app/utils/function_registries.dart';

/// QA (SL, 2026-11-18): the Incoming Transactions card showed the sender's
/// user uuid when the sender was a delivery team / distributor.
///
/// The card called `fn:getFacilityName(senderId)`, which can only return the
/// id for a sender that is not a facility. The userName is saved on the stock
/// record (additionalFields `deliveryTeamName`, or the raw team QR in
/// `deliveryTeam`), so the card now passes the record's additionalFields as a
/// second argument and the function reads the name from there.
void main() {
  const uuid = 'f6088ef4-92f3-4286-8d16-40b0df3327ca';
  const facilityId = 'F-2026-11-000123';
  const cardFieldName = 'incomingTransactionsSenderValueText';

  final stateData = CrudStateData(const {}, const []);

  /// Registration needs a BuildContext, so pump a throwaway widget to get one.
  Future<void> withRegistry(WidgetTester tester, VoidCallback body) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            FunctionRegistries(context).registerAll();
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    body();
  }

  dynamic callIt(List<dynamic> args) =>
      FunctionRegistry.call('getFacilityName', args, stateData);

  /// Renders a card template the way the text widget does: resolveTemplate
  /// over the context FlowWidgetState._buildEvalContext builds, with the
  /// list's group ({groupKey, items}) as the item.
  String renderOnCard(String template, Map<String, dynamic> item) =>
      resolveTemplate(
        template,
        <String, dynamic>{
          'itemData': item,
          'parentData': null,
          'contextData': const <String, dynamic>{},
          'formData': const <String, dynamic>{},
          'widgetData': const <String, dynamic>{},
          'navigation': const <String, dynamic>{},
          'item': item,
        },
        stateData: stateData,
      );

  List<Map<String, dynamic>> fields(Map<String, dynamic> values) => [
        for (final e in values.entries) {'key': e.key, 'value': e.value},
      ];

  group('getFacilityName with one argument (configs not yet updated)', () {
    testWidgets('a facility id keeps its FAC_ prefix', (tester) async {
      await withRegistry(tester, () {
        expect(callIt([facilityId]), 'FAC_$facilityId');
      });
    });

    testWidgets('a team uuid is returned as it is', (tester) async {
      await withRegistry(tester, () {
        expect(callIt([uuid]), uuid);
      });
    });

    testWidgets('no id gives an empty text', (tester) async {
      await withRegistry(tester, () {
        expect(callIt([]), '');
        expect(callIt([null]), '');
        expect(callIt(['']), '');
        expect(
            callIt([
              '',
              fields({'deliveryTeamName': 'jdoe'})
            ]),
            '');
      });
    });
  });

  group('getFacilityName with the record additionalFields', () {
    testWidgets('a team sender shows the saved deliveryTeamName',
        (tester) async {
      await withRegistry(tester, () {
        expect(
          callIt([
            uuid,
            fields({'sku': 'BEDNET', 'deliveryTeamName': 'jdoe'}),
          ]),
          'jdoe',
        );
      });
    });

    testWidgets('the name is read from a map of fields too', (tester) async {
      await withRegistry(tester, () {
        expect(
            callIt([
              uuid,
              {'deliveryTeamName': 'jdoe'}
            ]),
            'jdoe');
      });
    });

    testWidgets('the name is read from AdditionalField objects too',
        (tester) async {
      await withRegistry(tester, () {
        expect(
          callIt([
            uuid,
            [const AdditionalField('deliveryTeamName', 'jdoe')],
          ]),
          'jdoe',
        );
      });
    });

    testWidgets('without deliveryTeamName the name comes from the team QR',
        (tester) async {
      await withRegistry(tester, () {
        expect(
          callIt([
            uuid,
            fields({'deliveryTeamName': '', 'deliveryTeam': 'jdoe||$uuid'}),
          ]),
          'jdoe',
        );
      });
    });

    testWidgets('a record with no name falls back to the id', (tester) async {
      await withRegistry(tester, () {
        expect(
            callIt([
              uuid,
              fields({'sku': 'BEDNET'})
            ]),
            uuid);
        expect(
            callIt([
              uuid,
              fields({'deliveryTeamName': '  '})
            ]),
            uuid);
        expect(
            callIt([
              uuid,
              fields({'deliveryTeamName': 'null'})
            ]),
            uuid);
        expect(
            callIt([
              uuid,
              fields({'deliveryTeam': uuid})
            ]),
            uuid);
        expect(callIt([uuid, <dynamic>[]]), uuid);
        expect(callIt([uuid, null]), uuid);
        expect(callIt([uuid, 42]), uuid);
      });
    });

    testWidgets('a facility sender ignores a name on the record',
        (tester) async {
      await withRegistry(tester, () {
        expect(
          callIt([
            facilityId,
            fields({'deliveryTeamName': 'jdoe'})
          ]),
          'FAC_$facilityId',
        );
      });
    });
  });

  group('getFacilityName with the name as text (SMC config shape)', () {
    testWidgets('a name is shown', (tester) async {
      await withRegistry(tester, () {
        expect(callIt([uuid, 'jdoe']), 'jdoe');
        expect(callIt([uuid, ' jdoe ']), 'jdoe');
        expect(callIt([uuid, 'jdoe||$uuid']), 'jdoe');
      });
    });

    testWidgets('an empty or unresolved value falls back to the id',
        (tester) async {
      await withRegistry(tester, () {
        expect(callIt([uuid, '']), uuid);
        expect(callIt([uuid, 'null']), uuid);
        expect(
          callIt([uuid, 'item.items[0].additionalFields.fields']),
          uuid,
        );
        expect(callIt([uuid, '{{ item.items[0].x }}']), uuid);
      });
    });

    testWidgets('an id in second place is not shown as a name', (tester) async {
      // An older config shape called getFacilityName(senderId, receiverId).
      await withRegistry(tester, () {
        expect(callIt([uuid, facilityId]), uuid);
        expect(callIt([uuid, 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee']), uuid);
        expect(callIt([facilityId, uuid]), 'FAC_$facilityId');
      });
    });
  });

  group('Incoming Transactions card, both config sources', () {
    final sources = <String, dynamic>{
      'Dart copy (sampleInventoryFlows)': sampleInventoryFlows,
      'INVENTORY.json': jsonDecode(
        utf8
            .decode(
              File('assets/configs/json/INVENTORY.json').readAsBytesSync(),
            )
            .replaceFirst('﻿', ''),
      ),
    };

    List<String> senderValues(dynamic node) {
      final found = <String>[];
      void walk(dynamic n) {
        if (n is Map) {
          if (n['fieldName'] == cardFieldName) {
            found.add(n['value']?.toString() ?? '');
          }
          n.values.forEach(walk);
        } else if (n is List) {
          n.forEach(walk);
        }
      }

      walk(node);
      return found;
    }

    Map<String, dynamic> cardGroup(
      String senderId,
      Map<String, dynamic> additional,
    ) =>
        {
          'items': [
            {
              'senderId': senderId,
              'senderType': 'STAFF',
              'additionalFields': {
                'schema': 'Stock',
                'version': 1,
                'fields': fields(additional),
              },
            },
          ],
        };

    // The older string-interpolation path must give the same text.
    String render(String template, Map<String, dynamic> item) {
      final viaWidget = renderOnCard(template, item);
      final viaInterpolation = interpolateWithCrudStates(
        template: template,
        stateData: stateData,
        item: item,
      );
      expect(viaInterpolation, viaWidget);
      return viaWidget;
    }

    for (final entry in sources.entries) {
      testWidgets('${entry.key}: the card passes the record fields',
          (tester) async {
        final values = senderValues(entry.value);
        expect(values, hasLength(1));
        expect(
          values.single,
          '{{fn:getFacilityName(item.items[0].senderId, '
          'item.items[0].additionalFields.fields)}}',
        );
      });

      testWidgets('${entry.key}: a team sender renders its userName',
          (tester) async {
        final template = senderValues(entry.value).single;
        await withRegistry(tester, () {
          expect(
            render(
              template,
              cardGroup(uuid, {'sku': 'BEDNET', 'deliveryTeamName': 'jdoe'}),
            ),
            'jdoe',
          );
          expect(
            render(template, cardGroup(uuid, {'deliveryTeam': 'jdoe||$uuid'})),
            'jdoe',
          );
        });
      });

      testWidgets('${entry.key}: a team sender with no name renders the id',
          (tester) async {
        final template = senderValues(entry.value).single;
        await withRegistry(tester, () {
          expect(render(template, cardGroup(uuid, {'sku': 'BEDNET'})), uuid);
          // A record with no additionalFields at all.
          expect(
            render(template, {
              'items': [
                {'senderId': uuid},
              ],
            }),
            uuid,
          );
        });
      });

      testWidgets('${entry.key}: a facility sender renders FAC_<id>',
          (tester) async {
        final template = senderValues(entry.value).single;
        await withRegistry(tester, () {
          expect(
            render(template, cardGroup(facilityId, {'sku': 'BEDNET'})),
            'FAC_$facilityId',
          );
        });
      });
    }

    test('the Dart copy and the JSON hold the same card value', () {
      expect(
        senderValues(sources.values.first),
        senderValues(sources.values.last),
      );
    });
  });

  // A distributor who accepts part of an issue sends the rest back with a
  // shortfallTransaction record. That record is built from the record being
  // accepted, not from a form with a team QR, so it carried no name at all:
  // these were the cards in QA's screenshot.
  group('shortfall records carry the team name', () {
    const expression =
        '{{fn:getShortfallTeamName(navigation.receivedFromName)}}';

    List<List<Map<String, dynamic>>> shortfallCalls(Object? node) {
      final found = <List<Map<String, dynamic>>>[];
      void walk(Object? n) {
        if (n is Map) {
          final props = n['properties'];
          if (n['actionType'] == 'FETCH_TRANSFORMER_CONFIG' &&
              props is Map &&
              props['configName'] == 'shortfallTransaction') {
            found.add((props['data'] as List).cast<Map<String, dynamic>>());
          }
          n.values.forEach(walk);
        } else if (n is List) {
          n.forEach(walk);
        }
      }

      walk(node);
      return found;
    }

    final configs = <String, dynamic>{
      'manage_stock.dart': sampleInventoryFlows,
      'INVENTORY.json': jsonDecode(
        utf8
            .decode(
                File('assets/configs/json/INVENTORY.json').readAsBytesSync())
            .replaceFirst('﻿', ''),
      ),
    };

    for (final entry in configs.entries) {
      test('${entry.key}: every shortfall action passes deliveryTeamName', () {
        final calls = shortfallCalls(entry.value);
        expect(calls, hasLength(4));
        for (final data in calls) {
          final values = data
              .where((e) => e['key'] == 'deliveryTeamName')
              .map((e) => e['value'])
              .toList();
          expect(values, [expression]);
        }
      });
    }

    testWidgets(
        'the config expression resolves to the name on the record being '
        'accepted', (tester) async {
      await withRegistry(tester, () {
        expect(
          resolveValue(expression, {
            'navigation': {'receivedFromName': 'jdoe'},
          }),
          'jdoe',
        );
        // No name on the parent record, or the key not passed at all.
        for (final navigation in [
          {'receivedFromName': ''},
          {'receivedFromName': null},
          <String, dynamic>{},
        ]) {
          expect(
            '${resolveValue(expression, {'navigation': navigation}) ?? ''}',
            '',
            reason: '$navigation',
          );
        }
      });
    });

    group('shortfallTeamName', () {
      test('a distributor sending stock back saves their own userName', () {
        expect(
          shortfallTeamName(
            senderIsTeam: true,
            ownTeamCode: 'jdoe||$uuid',
            parentTeamName: 'name on the issue',
          ),
          'jdoe',
        );
      });

      test('a distributor with no name uses the name on the accepted record',
          () {
        for (final own in [uuid, '||$uuid', ' ||$uuid', '']) {
          expect(
            shortfallTeamName(
              senderIsTeam: true,
              ownTeamCode: own,
              parentTeamName: 'jdoe',
            ),
            'jdoe',
            reason: own,
          );
        }
      });

      test('a warehouse re-issuing to a team saves the team name, not its own',
          () {
        expect(
          shortfallTeamName(
            senderIsTeam: false,
            ownTeamCode: 'storekeeper||$uuid',
            parentTeamName: 'jdoe',
          ),
          'jdoe',
        );
      });

      test('warehouse to warehouse has no team name', () {
        for (final parent in [null, '', '  ', 'null']) {
          expect(
            shortfallTeamName(
              senderIsTeam: false,
              ownTeamCode: '',
              parentTeamName: parent,
            ),
            '',
            reason: '$parent',
          );
        }
      });

      test('an unresolved config value is not saved as a name', () {
        for (final parent in [
          'navigation.receivedFromName',
          '{{navigation.receivedFromName}}',
        ]) {
          expect(
            shortfallTeamName(
              senderIsTeam: false,
              ownTeamCode: '',
              parentTeamName: parent,
            ),
            '',
            reason: parent,
          );
        }
      });
    });

    group('the saved record', () {
      setUpAll(() {
        StockModelMapper.ensureInitialized();
        StockAdditionalFieldsMapper.ensureInitialized();
        AdditionalFieldMapper.ensureInitialized();
        AuditDetailsMapper.ensureInitialized();
        ClientAuditDetailsMapper.ensureInitialized();
        DataConverterSingleton()
            .setData(dynamicEntityModelListener: EntityModelJsonMapper());
      });

      StockModel build({String? teamName}) {
        final config = jsonConfig['shortfallTransaction']!;
        return FormEntityMapper(config: jsonConfig)
            .mapFormToEntities(
              formValues: const {},
              modelsConfig: config['models'] as Map<String, dynamic>,
              context: {
                'stockEntryType': 'RETURNED',
                'quantity': '25',
                'senderFacilityId': uuid,
                'senderPartyType': 'STAFF',
                'receiverFacilityId': facilityId,
                'receiverPartyType': 'WAREHOUSE',
                'productVariantId': 'bednet',
                'projectId': 'campaign',
                'tenantId': 'si',
                'userUUID': 'user',
                'mrnNumber': 'mrn-1',
                'originalIssueClientReferenceId': 'dispatch-1',
                'discrepancyReason': 'IN_TRANSIT',
                if (teamName != null) 'deliveryTeamName': teamName,
              },
            )
            .whereType<StockModel>()
            .single;
      }

      const cardTemplate = '{{fn:getFacilityName(item.items[0].senderId, '
          'item.items[0].additionalFields.fields)}}';

      testWidgets('carries deliveryTeamName, and the card shows it',
          (tester) async {
        final row = build(teamName: 'jdoe');
        expect(
          row.additionalFields?.fields
              .where((f) => f.key == 'deliveryTeamName')
              .map((f) => f.value),
          ['jdoe'],
        );
        expect(row.senderId, uuid);
        expect(row.quantity, '25');
        await withRegistry(tester, () {
          // The list hands the card a group of StockModel entities, and the
          // text widget resolves the template through resolveValue.
          expect(
            renderOnCard(cardTemplate, {
              'groupKey': 'mrn-1',
              'items': [row]
            }),
            'jdoe',
          );
        });
      });

      testWidgets('without a name the key is left out, the rest is unchanged',
          (tester) async {
        for (final name in [null, '']) {
          final row = build(teamName: name);
          expect(
            row.additionalFields?.fields.map((f) => f.key),
            isNot(contains('deliveryTeamName')),
            reason: '$name',
          );
          expect(row.senderId, uuid);
          expect(row.quantity, '25');
          await withRegistry(tester, () {
            expect(
              renderOnCard(cardTemplate, {
                'groupKey': 'mrn-1',
                'items': [row]
              }),
              uuid,
            );
          });
        }
      });
    });
  });
}
