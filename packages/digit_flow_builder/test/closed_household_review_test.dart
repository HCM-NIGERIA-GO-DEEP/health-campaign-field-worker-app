import 'package:digit_data_converter/src/transformer_service.dart';
import 'package:digit_data_converter/utils/utils.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data_model.init.dart';
import 'package:digit_data_model/models/entities/name.dart';
import 'package:digit_flow_builder/data/digit_data_converter.dart';
import 'package:digit_flow_builder/data/transformer_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repeated corrections keep entity references and saved names', () {
    initializeMappers();
    DataConverterSingleton()
        .setData(dynamicEntityModelListener: EntityModelJsonMapper());
    var entities = <EntityModel>[
      HouseholdModel(clientReferenceId: 'household', memberCount: 1),
      IndividualModel(clientReferenceId: 'head',
        name: NameModel(givenName: 'Original', individualClientReferenceId: 'head')),
      TaskModel(clientReferenceId: 'task', status: 'CLOSED_HOUSEHOLD'),
      ProjectBeneficiaryModel(clientReferenceId: 'beneficiary', dateOfRegistration: 1234),
    ];
    for (final name in ['First correction', 'Second correction', 'Final name']) {
      entities = FormEntityMapper(config: jsonConfig).updateEntitiesFromForm(
        existingModels: entities,
        formValues: {'closeHouseholdDetails': {'headName': name}},
        modelsConfig: jsonConfig['closeHouseholdEdit']!['models']
            as Map<String, dynamic>,
        context: const {},
      );
      expect(entities.length, 4);
      final head = entities.whereType<IndividualModel>().single;
      expect(head.clientReferenceId, 'head');
      expect(head.name?.givenName, name);
      final household = entities.whereType<HouseholdModel>().single;
      expect(household.clientReferenceId, 'household');
      expect(household.additionalFields!.fields
          .singleWhere((field) => field.key == 'householdName').value, name);
      final task = entities.whereType<TaskModel>().single;
      expect(task.clientReferenceId, 'task');
      expect(task.status, 'CLOSED_HOUSEHOLD');
      expect(task.additionalFields!.fields
          .singleWhere((field) => field.key == 'headName').value, name);
      expect(entities.whereType<ProjectBeneficiaryModel>().single
          .clientReferenceId, 'beneficiary');
    }
  });
}
