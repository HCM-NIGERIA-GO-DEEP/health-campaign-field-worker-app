import 'dart:convert';

import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data_model.init.dart' as model_init;
import 'package:digit_flow_builder/data/digit_crud_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(model_init.initializeMappers);
  final mapper = EntityModelMapMapper();
  final additionalFields = {
    'schema': 'Task',
    'version': 1,
    'fields': [
      {'key': 'isDelivered', 'value': 'true'},
    ],
  };

  for (final encoded in [true, false]) {
    test('completed task hydrates with encoded additionalFields=$encoded', () {
      final task = mapper.dynamicEntityModelFromMap('task', {
        'clientReferenceId': 'delivery-task',
        'projectBeneficiaryClientReferenceId': 'beneficiary',
        'status': 'ADMINISTRATION_SUCCESS',
        'additionalFields':
            encoded ? jsonEncode(additionalFields) : additionalFields,
        'resources': [
          {
            'clientReferenceId': 'resource',
            'isDelivered': true,
            'quantity': '2',
            'additionalFields': jsonEncode({
              'schema': 'TaskResource',
              'version': 1,
              'fields': [
                {'key': 'batch', 'value': 'batch-1'},
              ],
            }),
          },
        ],
      }) as TaskModel;
      expect(task.status, 'ADMINISTRATION_SUCCESS');
      expect(task.projectBeneficiaryClientReferenceId, 'beneficiary');
      expect(task.additionalFields!.fields.single.value, 'true');
      expect(task.resources!.single.isDelivered, isTrue);
      expect(task.resources!.single.additionalFields, isNotNull);
    });
  }

  test('null and malformed values retain existing normalization behavior', () {
    for (final value in [null, '', 'invalid JSON', '[1,2]', '42']) {
      final normalized = mapper.normalizeKnownFlatFieldsRecursively({
        'additionalFields': value,
      });
      expect(normalized['additionalFields'],
          value == '[1,2]' ? ['1', '2'] : value);
    }
  });

  test('ordinary text containing JSON is not decoded', () {
    final text = jsonEncode({'message': 'household note'});
    expect(
      mapper.normalizeKnownFlatFieldsRecursively({'description': text}),
      {'description': text},
    );
  });
}
