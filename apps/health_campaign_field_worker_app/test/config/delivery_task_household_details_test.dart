import 'dart:convert';
import 'dart:io';

import 'package:digit_data_converter/src/transformer_service.dart';
import 'package:digit_data_converter/utils/utils.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data_model.init.dart';
import 'package:digit_flow_builder/data/digit_data_converter.dart';
import 'package:digit_flow_builder/data/transformer_config.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/registration_flows.dart';
import 'package:health_campaign_field_worker_app/utils/function_registries.dart';

/// Liberia delivers one ITN task per household. The distribution report reads
/// the task, so the task must carry the household head and - when any are
/// registered - the members (QA: "child info to pass in household and task").
///
/// Three links must all hold for a key to be saved: householdOverview passes
/// it to the DELIVERY form, the executor hands every navigation key to the
/// delivery mapping, and the mapping lists the key.
void main() {
  const newKeys = [
    'headIndividualClientReferenceId',
    'headGender',
    'householdMembers',
  ];

  setUpAll(() {
    initializeMappers();
    DataConverterSingleton()
        .setData(dynamicEntityModelListener: EntityModelJsonMapper());
  });

  Map<String, dynamic> dartCopy() =>
      jsonDecode(jsonEncode(sampleFlows)) as Map<String, dynamic>;
  Map<String, dynamic> jsonCopy() => jsonDecode(
        File('assets/configs/json/REGISTRATION.json')
            .readAsStringSync()
            .replaceFirst('﻿', ''),
      ) as Map<String, dynamic>;

  /// The `data` of every NAVIGATION to the DELIVERY form.
  List<List<Map<String, dynamic>>> deliveryNavigations(
      Map<String, dynamic> config) {
    final found = <List<Map<String, dynamic>>>[];
    void walk(dynamic node) {
      if (node is Map) {
        final properties = node['properties'];
        if (node['actionType'] == 'NAVIGATION' &&
            properties is Map &&
            properties['name'] == 'DELIVERY') {
          found.add((properties['data'] as List).cast<Map<String, dynamic>>());
        }
        node.values.forEach(walk);
      } else if (node is List) {
        node.forEach(walk);
      }
    }

    walk(config['flows']);
    return found;
  }

  final head = {
    'clientReferenceId': 'head-ind',
    'mobileNumber': '0770000000',
    'gender': 'MALE',
    'name': {'givenName': 'Head', 'familyName': 'Family'},
    'identifiers': [
      {'identifierType': 'UNIQUE_BENEFICIARY_ID', 'identifierId': 'B-0'},
    ],
  };
  Map<String, dynamic> wrapper({bool withChild = true}) => {
        'household': {
          'HouseholdModel': {'clientReferenceId': 'hh', 'memberCount': 3},
        },
        'headIndividual': {'IndividualModel': head},
        'members': [
          {
            'member': [
              {'isHeadOfHousehold': true},
            ],
            'individual': [head],
          },
          if (withChild)
            {
              'member': [
                {'isHeadOfHousehold': false},
              ],
              'individual': [
                {
                  'clientReferenceId': 'child-ind',
                  'gender': 'FEMALE',
                  'dateOfBirth': '10/05/2023',
                  'name': {'givenName': 'Ama', 'familyName': 'Family'},
                  'identifiers': [
                    {
                      'identifierType': 'UNIQUE_BENEFICIARY_ID',
                      'identifierId': 'B-1',
                    },
                  ],
                },
              ],
            },
        ],
      };

  Future<void> registerFunctions(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              FunctionRegistries(context).registerAll();
              return const SizedBox.shrink();
            },
          ),
        ),
      );

  /// What the DELIVERY form receives: every navigation value resolved the way
  /// NavigationExecutor does on the householdOverview TEMPLATE screen.
  Map<String, dynamic> resolveNavigation(
    List<Map<String, dynamic>> data,
    Map<String, dynamic> wrapperRow,
  ) {
    final contextData = <String, dynamic>{
      'contextData': [wrapperRow],
      'navigation': {'HouseholdClientReferenceId': 'hh'},
    };
    return {
      for (final entry in data)
        entry['key'] as String: resolveNavigationDataValue(
          rawValue: entry['value'],
          stateWrapperFirst: wrapperRow,
          contextData: contextData,
        ),
    };
  }

  /// The delivery task the mapping builds from those navigation values (the
  /// executor adds all of them to the mapping context for `delivery`).
  Map<String, dynamic> taskFields(
    String configName,
    Map<String, dynamic> navigation,
  ) {
    final config = jsonConfig[configName]!;
    final tasks = FormEntityMapper(config: jsonConfig).mapFormToEntities(
      formValues: const {
        'DeliveryDetails': {
          'latLng': [6.3, -10.8, 12.0],
        },
      },
      modelsConfig: config['models'] as Map<String, dynamic>,
      fallbackFormDataString: config['fallbackModel'] as String?,
      context: {
        ...navigation,
        'tenantId': 't',
        'projectId': 'p',
        'userId': 'worker',
        'userUUID': 'worker',
        'selectedBoundaryCode': 'community',
      },
    ).whereType<TaskModel>().toList();
    expect(tasks, hasLength(1), reason: '$configName must still build a task');

    // Through the sync JSON and back, as the oplog does.
    final restored = TaskModelMapper.fromJson(tasks.single.toJson());
    return {
      for (final field
          in restored.additionalFields?.fields ?? const <AdditionalField>[])
        field.key: field.value,
    };
  }

  for (final copy in {'Dart copy': dartCopy, 'REGISTRATION.json': jsonCopy}
      .entries) {
    group(copy.key, () {
      test('householdOverview passes the head and the members to DELIVERY',
          () {
        final navigations = deliveryNavigations(copy.value());
        expect(navigations, hasLength(1));
        final values = {
          for (final entry in navigations.single) entry['key']: entry['value'],
        };

        expect(
          values['headIndividualClientReferenceId'],
          '{{contextData.0.headIndividual.IndividualModel.clientReferenceId}}',
        );
        expect(
          values['headGender'],
          '{{fn:individualGender(contextData.0.headIndividual.IndividualModel)}}',
        );
        expect(
          values['householdMembers'],
          '{{fn:householdMembersForTask(contextData.0.members)}}',
        );
      });

      testWidgets('the delivery task carries the head and the members',
          (tester) async {
        await registerFunctions(tester);
        final navigation = resolveNavigation(
          deliveryNavigations(copy.value()).single,
          wrapper(),
        );

        expect(navigation['headIndividualClientReferenceId'], 'head-ind');
        expect(navigation['headGender'], 'MALE');
        expect(navigation['householdMembers'], isA<String>());

        final fields = taskFields('delivery', navigation);
        expect(fields['headIndividualClientReferenceId'], 'head-ind');
        expect(fields['headGender'], 'MALE');
        expect(fields['headMobileNumber'], '0770000000');
        expect(fields['beneficiaryId'], 'B-0');
        expect(fields['householdMembers'], isA<String>());
        expect(jsonDecode(fields['householdMembers'] as String), [
          {
            'individualClientReferenceId': 'child-ind',
            'name': 'Ama Family',
            'gender': 'FEMALE',
            'dateOfBirth': '10/05/2023',
            'beneficiaryId': 'B-1',
          },
        ]);
      });

      testWidgets('a household with only its head saves no members key',
          (tester) async {
        await registerFunctions(tester);
        final navigation = resolveNavigation(
          deliveryNavigations(copy.value()).single,
          wrapper(withChild: false),
        );

        expect(navigation['householdMembers'], isNull);

        final fields = taskFields('delivery', navigation);
        expect(fields.keys, isNot(contains('householdMembers')));
        expect(fields['headGender'], 'MALE');
      });
    });
  }

  test('both delivery mappings list the new keys', () {
    for (final configName in ['delivery', 'indirectBulkDelivery']) {
      final mappings = ((jsonConfig[configName]!['models'] as Map)['TaskModel']
          as Map)['mappings'] as Map;
      final additionalFields = mappings['additionalFields'] as Map;
      for (final key in newKeys) {
        expect(additionalFields[key], '__context:$key',
            reason: '$configName.$key');
      }
    }
  });

  test('an older APK without the functions drops the keys, nothing else', () {
    // Unregistered fn -> null navigation value -> the key is not saved.
    final fields = taskFields('delivery', const {
      'headName': 'Head Family',
      'headGender': null,
      'householdMembers': null,
    });

    expect(fields['headName'], 'Head Family');
    expect(fields.keys, isNot(contains('headGender')));
    expect(fields.keys, isNot(contains('householdMembers')));
  });
}
