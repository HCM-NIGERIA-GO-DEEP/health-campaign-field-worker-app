import 'package:digit_data_converter/src/transformer_service.dart';
import 'package:digit_data_converter/utils/utils.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/identifier.dart';
import 'package:digit_data_model/models/entities/individual.dart';
import 'package:digit_flow_builder/data/digit_data_converter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards updateModelFromForm's handling of "list:ModelName" string mappings
/// (e.g. IndividualModel's "identifiers": "list:IdentifierModel", used by
/// beneficiaryRegistration/individualRegistration in transformer_config.dart).
///
/// applyUpdate's dispatcher only recognized two mapping shapes: a nested Map
/// (object/matched-list updates) and a plain form-data path string. A
/// "list:IdentifierModel" marker is neither - it isn't a real path
/// containsPathInFormData could ever find in form data - so this field was
/// silently skipped on every edit, no matter what the form actually
/// submitted. In practice: a household created with a placeholder DEFAULT
/// identifier (Mark Closed Household / a declined consent) could never pick
/// up a real Beneficiary ID or a newly-captured National ID when reopened
/// and resubmitted - the stale placeholder just persisted forever.
void main() {
  setUpAll(() {
    IdentifierModelMapper.ensureInitialized();
    IndividualModelMapper.ensureInitialized();
    DataConverterSingleton()
        .setData(dynamicEntityModelListener: EntityModelJsonMapper());
  });

  const modelsConfig = {
    'IndividualModel': {
      'mappings': {
        'clientReferenceId': '__generate:uuid',
        'identifiers': 'list:IdentifierModel',
      },
      'listMappings': {
        'IdentifierModel': {
          'listSource': '__context:identifierEntries',
          'mappings': {
            'identifierType': 'identifierType',
            'identifierId': 'identifierId',
            'individualClientReferenceId':
                '__ref:IndividualModel.clientReferenceId',
            'clientReferenceId': '__generate:uuid',
          },
        },
      },
    },
  };

  test(
      'a placeholder DEFAULT identifier is replaced by a real Beneficiary ID '
      'and a National ID on edit-and-resubmit', () {
    final existingIndividual = IndividualModel(
      clientReferenceId: 'ind-1',
      identifiers: [
        IdentifierModel(
          individualClientReferenceId: 'ind-1',
          clientReferenceId: 'id-old',
          identifierType: 'DEFAULT',
          identifierId: 'c0ffee00-random-uuid',
        ),
      ],
    );

    final mapper = FormEntityMapper(config: const {});

    final updated = mapper.updateEntitiesFromForm(
      existingModels: [existingIndividual],
      formValues: const {},
      modelsConfig: modelsConfig,
      context: const {
        'identifierEntries': [
          {'identifierType': 'UNIQUE_BENEFICIARY_ID', 'identifierId': '1234567890'},
          {'identifierType': 'NATIONAL_ID', 'identifierId': 'NAT999'},
        ],
      },
    );

    expect(updated, hasLength(1));
    final updatedIndividual = updated.single as IndividualModel;

    expect(updatedIndividual.identifiers, hasLength(2));
    final types =
        updatedIndividual.identifiers!.map((i) => i.identifierType).toSet();
    expect(types, {'UNIQUE_BENEFICIARY_ID', 'NATIONAL_ID'});
    expect(types.contains('DEFAULT'), isFalse);

    final beneficiaryId = updatedIndividual.identifiers!
        .firstWhere((i) => i.identifierType == 'UNIQUE_BENEFICIARY_ID');
    expect(beneficiaryId.identifierId, '1234567890');

    final nationalId = updatedIndividual.identifiers!
        .firstWhere((i) => i.identifierType == 'NATIONAL_ID');
    expect(nationalId.identifierId, 'NAT999');

    // The identifier's clientReferenceId should NOT be the individual's own
    // - a prior bug in this test's construction could pass vacuously if
    // __ref: resolution silently fell through to something else.
    for (final id in updatedIndividual.identifiers!) {
      expect(id.individualClientReferenceId, 'ind-1');
    }
  });

  test(
      'a missing identifierEntries context (never happens in practice - '
      'TransformerExecutor.buildIdentifierEntries always supplies at least '
      'one, possibly-null, entry) falls back to a single item rather than '
      'throwing', () {
    final existingIndividual = IndividualModel(
      clientReferenceId: 'ind-2',
      identifiers: [
        IdentifierModel(
          individualClientReferenceId: 'ind-2',
          clientReferenceId: 'id-old',
          identifierType: 'DEFAULT',
          identifierId: 'c0ffee00-random-uuid',
        ),
      ],
    );

    final mapper = FormEntityMapper(config: const {});

    final updated = mapper.updateEntitiesFromForm(
      existingModels: [existingIndividual],
      formValues: const {},
      modelsConfig: modelsConfig,
      context: const {},
    );

    final updatedIndividual = updated.single as IndividualModel;
    expect(updatedIndividual.identifiers, hasLength(1));
    expect(updatedIndividual.identifiers!.single.identifierType, isNull);
  });
}
