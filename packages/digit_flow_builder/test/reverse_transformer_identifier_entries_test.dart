import 'package:digit_data_converter/src/reverse_transformer_service.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/identifier.dart';
import 'package:digit_data_model/models/entities/individual.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the reversal of IdentifierModel's "listSource:
/// __context:identifierEntries" mapping (used by beneficiaryRegistration and
/// individualRegistration in transformer_config.dart). Its forward mapping
/// values ("identifierType", "identifierId") are keys into a pre-built
/// {identifierType, identifierId} map, not form field paths - reusing them
/// naively for reverse mapping used to write into meaningless top-level
/// "identifierType"/"identifierId" form keys instead of the real
/// householdDetails.identificationType/identificationNumber fields, so an
/// existing National ID silently vanished on edit-and-resubmit (it reads
/// those fields at submit time, found them blank, and dropped the entry).
void main() {
  setUpAll(() {
    IdentifierModelMapper.ensureInitialized();
    IndividualModelMapper.ensureInitialized();
  });

  const formConfig = {
    'models': {
      'IndividualModel': {
        'mappings': {},
        'listMappings': {
          'IdentifierModel': {
            'listSource': '__context:identifierEntries',
            'mappings': {
              'id': 'id',
              'identifierType': 'identifierType',
              'identifierId': 'identifierId',
            },
          },
        },
      },
    },
  };

  test(
      'a real captured National ID reverses into identificationType/identificationNumber',
      () {
    final individual = IndividualModel(
      clientReferenceId: 'ind-1',
      identifiers: [
        IdentifierModel(
          individualClientReferenceId: 'ind-1',
          clientReferenceId: 'id-1',
          identifierType: 'NATIONAL_ID',
          identifierId: 'NAT12345',
        ),
      ],
    );

    final formData = ReverseFormMapper(
      formConfig: formConfig,
      modelInstances: [individual],
    ).buildFormData();

    expect(formData['identificationType'], 'NATIONAL_ID');
    expect(formData['identificationNumber'], 'NAT12345');
    expect(formData.containsKey('identifierType'), isFalse);
    expect(formData.containsKey('identifierId'), isFalse);
  });

  test(
      'the hidden Beneficiary ID reverses into the combined "identifiers" field, not identificationType/Number',
      () {
    final individual = IndividualModel(
      clientReferenceId: 'ind-1',
      identifiers: [
        IdentifierModel(
          individualClientReferenceId: 'ind-1',
          clientReferenceId: 'id-1',
          identifierType: 'UNIQUE_BENEFICIARY_ID',
          identifierId: '00000-1700afd1',
        ),
      ],
    );

    final formData = ReverseFormMapper(
      formConfig: formConfig,
      modelInstances: [individual],
    ).buildFormData();

    expect(formData['identifiers'], 'UNIQUE_BENEFICIARY_ID,00000-1700afd1');
    expect(formData.containsKey('identificationType'), isFalse);
    expect(formData.containsKey('identificationNumber'), isFalse);
  });

  test('both a hidden Beneficiary ID and a real National ID reverse independently', () {
    final individual = IndividualModel(
      clientReferenceId: 'ind-1',
      identifiers: [
        IdentifierModel(
          individualClientReferenceId: 'ind-1',
          clientReferenceId: 'id-1',
          identifierType: 'UNIQUE_BENEFICIARY_ID',
          identifierId: '00000-1700afd1',
        ),
        IdentifierModel(
          individualClientReferenceId: 'ind-1',
          clientReferenceId: 'id-2',
          identifierType: 'VOTER_ID',
          identifierId: 'VOT999',
        ),
      ],
    );

    final formData = ReverseFormMapper(
      formConfig: formConfig,
      modelInstances: [individual],
    ).buildFormData();

    expect(formData['identifiers'], 'UNIQUE_BENEFICIARY_ID,00000-1700afd1');
    expect(formData['identificationType'], 'VOTER_ID');
    expect(formData['identificationNumber'], 'VOT999');
  });

  test('a DEFAULT placeholder identifier (consent-declined household) reverses like a hidden ID', () {
    final individual = IndividualModel(
      clientReferenceId: 'ind-1',
      identifiers: [
        IdentifierModel(
          individualClientReferenceId: 'ind-1',
          clientReferenceId: 'id-1',
          identifierType: 'DEFAULT',
          identifierId: 'c0ffee00-random-uuid',
        ),
      ],
    );

    final formData = ReverseFormMapper(
      formConfig: formConfig,
      modelInstances: [individual],
    ).buildFormData();

    expect(formData['identifiers'], 'DEFAULT,c0ffee00-random-uuid');
    expect(formData.containsKey('identificationType'), isFalse);
  });
}
