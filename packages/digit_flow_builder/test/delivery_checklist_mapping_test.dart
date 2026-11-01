import 'dart:convert';
import 'package:digit_data_converter/src/transformer_service.dart';
import 'package:digit_data_converter/utils/utils.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data_model.init.dart' as models;
import 'package:digit_flow_builder/data/digit_data_converter.dart';
import 'package:digit_flow_builder/data/transformer_config.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../apps/health_campaign_field_worker_app/lib/sampleJsonConfigs/registration_flows.dart';

void main() {
  setUpAll(() {
    models.initializeMappers();
    DataConverterSingleton()
        .setData(dynamicEntityModelListener: EntityModelJsonMapper());
  });
  const capturedSerials = '(01)00000000000000(21)ABCD1234(10)MANUAL';
  final config = jsonConfig['delivery'] as Map<String, dynamic>;

  Map<String, dynamic> mapAnswers(
      {bool lastAnswer = true, bool legacy = false}) {
    final models =
        jsonDecode(jsonEncode(config['models'])) as Map<String, dynamic>;
    if (legacy) {
      for (var i = 9; i <= 11; i++) {
        models['TaskModel']['mappings']['additionalFields']['ACTION$i'] =
            'DeliveryChecklist.ACTION$i';
      }
    }
    final entities = FormEntityMapper(config: jsonConfig).mapFormToEntities(
      formValues: {
        'DeliveryChecklist': {
          for (var i = 1; i <= 8; i++) 'ACTION$i': i == 8 ? lastAnswer : true
        },
        'DeliveryDetails': {
          'scanner': capturedSerials,
          'resourceCard': {
            'quantityDistributed': 2,
            'resourceDelivered': {'productId': 'bednet'},
          }
        },
      },
      modelsConfig: models,
      context: {
        'tenantId': 'si',
        'selectedBoundaryCode': 'community-1',
        'boundary': {'name': 'Community'},
        'projectId': 'campaign',
        'userId': 'distributor',
        'userUUID': 'distributor-uuid',
        'ProjectBeneficiaryClientReferenceId': 'beneficiary',
        'isDelivered': true
      },
    );
    final task = entities.whereType<TaskModel>().single;
    final payload = jsonDecode(jsonEncode(task.toMap()));
    expect(payload['additionalFields'], isNotNull);
    final rows = payload['additionalFields']['fields'] as List;
    return {for (final row in rows) row['key'] as String: row['value']};
  }

  test('eight delivery answers survive task serialization without null entries',
      () {
    final fields = mapAnswers();
    for (var i = 1; i <= 8; i++) {
      expect(fields['ACTION$i'], true);
    }
    expect(fields.keys.where((key) => key.startsWith('ACTION')), hasLength(8));
    expect(fields.values, everyElement(isNotNull));
    expect(fields['quantity'], 2);
    expect(fields['isDelivered'], true);
  });
  test('delivery scan payload survives task mapping and JSON serialization', () {
    expect(mapAnswers()['scanResource'], capturedSerials);
  });
  test('false answer is preserved rather than null', () {
    expect(mapAnswers(lastAnswer: false)['ACTION8'], false);
  });
  test('legacy eleven-question mappings omit removed answers without nulls',
      () {
    final fields = mapAnswers(legacy: true);
    expect(fields.keys.where((key) => key.startsWith('ACTION')), hasLength(8));
    expect(fields.values, everyElement(isNotNull));
  });
  test(
      'delivery UI and mappings agree on eight required questions',
      () {
    final pages = (sampleFlows['flows'] as List)
        .expand((flow) => (flow['pages'] as List?) ?? []);
    final page =
        pages.singleWhere((page) => page['page'] == 'DeliveryChecklist');
    final actions = (page['properties'] as List)
        .where((field) =>
            (field['fieldName'] as String? ?? '').startsWith('ACTION'))
        .toList();
    expect(actions, hasLength(8));
    final mappings =
        config['models']['TaskModel']['mappings']['additionalFields'] as Map;
    expect(page['description'], 'APPONE_DISTRIBUTOR_DELIVERY_CHECKLIST_DESCRIPTION');
    for (var i = 1; i <= 8; i++) {
      final field = actions[i - 1];
      expect(field['fieldName'], 'ACTION$i');
      expect(field['mandatory'], true);
      expect(mappings['ACTION$i'], 'DeliveryChecklist.ACTION$i');
      expect(field['label'], 'APPONE_DISTRIBUTOR_DELIVERY_CHECKLIST_ACTION$i');
    }
    expect(
        mappings.keys.where((key) => key.startsWith('ACTION')), hasLength(8));
    final registrarPages = pages
        .where((page) => page['page'] == 'registrationHealthTalkChecklist');
    for (final registrar in registrarPages) {
      expect(
          (registrar['properties'] as List).where((field) =>
              (field['fieldName'] as String? ?? '').startsWith('ACTION')),
          hasLength(11));
    }
  });
}
