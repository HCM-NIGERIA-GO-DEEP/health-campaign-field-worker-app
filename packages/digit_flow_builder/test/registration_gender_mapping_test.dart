import 'package:digit_data_converter/src/transformer_service.dart';
import 'package:digit_data_converter/utils/utils.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/data/digit_data_converter.dart';
import 'package:digit_flow_builder/data/transformer_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {
    GenderMapper.ensureInitialized();
    IndividualModelMapper.ensureInitialized();
    DataConverterSingleton().setData(
      dynamicEntityModelListener: EntityModelJsonMapper(),
    );
  });

  test('household registration maps gender to the individual and member record',
      () {
    final config =
        jsonConfig['beneficiaryRegistration'] as Map<String, dynamic>;
    final models = config['models'] as Map<String, dynamic>;
    final individualMappings = (models['IndividualModel']
        as Map<String, dynamic>)['mappings'] as Map<String, dynamic>;
    final memberMappings = (models['HouseholdMemberModel']
        as Map<String, dynamic>)['mappings'] as Map<String, dynamic>;
    final memberAdditionalFields =
        memberMappings['additionalFields'] as Map<String, dynamic>;

    expect(individualMappings['gender'], 'householdDetails.gender');
    expect(memberAdditionalFields['gender'], 'householdDetails.gender');
  });

  test('Add Member maps gender from its beneficiary details page', () {
    final config = jsonConfig['individualRegistration'] as Map<String, dynamic>;
    final individualMappings = (config['models']['IndividualModel']
        as Map<String, dynamic>)['mappings'] as Map<String, dynamic>;

    expect(individualMappings['gender'], 'beneficiaryDetails.gender');
  });

  test('household form value becomes the IndividualModel gender enum', () {
    final entities = FormEntityMapper(config: jsonConfig).mapFormToEntities(
      formValues: {
        'householdDetails': {'gender': 'FEMALE'},
      },
      modelsConfig: {
        'IndividualModel': {
          'mappings': {
            'clientReferenceId': '__generate:uuid',
            'gender': 'householdDetails.gender',
          },
        },
      },
      context: {'tenantId': 'liberia'},
    );

    expect(entities.single, isA<IndividualModel>());
    expect((entities.single as IndividualModel).gender, Gender.female);
  });
}
