import 'package:digit_data_converter/src/transformer_service.dart';
import 'package:digit_data_converter/utils/utils.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/data/digit_data_converter.dart';
import 'package:digit_flow_builder/data/transformer_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Re-registering a closed / consent-declined household was wiping its GPS
/// coordinates, which made it permanently unfindable by proximity search
/// (that filter runs `within` against address latitude/longitude).
///
/// The location is captured once, on first registration. Reopening the
/// household submits a form where `beneficiaryLocation` exists but carries no
/// latLng. `containsPathInFormData` captures a trailing [index] in its regex
/// and never dereferences it, so "beneficiaryLocation.latLng[0]" passed its
/// existence check anyway and the resulting null was written straight over
/// the stored coordinate.
void main() {
  setUpAll(() {
    HouseholdModelMapper.ensureInitialized();
    HouseholdAdditionalFieldsMapper.ensureInitialized();
    AddressModelMapper.ensureInitialized();
    AdditionalFieldMapper.ensureInitialized();
    AuditDetailsMapper.ensureInitialized();
    ClientAuditDetailsMapper.ensureInitialized();
    DataConverterSingleton()
        .setData(dynamicEntityModelListener: EntityModelJsonMapper());
  });

  final householdConfig =
      jsonConfig['beneficiaryRegistration'] as Map<String, dynamic>;
  final householdModelConfig = (householdConfig['models']
      as Map<String, dynamic>)['HouseholdModel'] as Map<String, dynamic>;

  HouseholdModel existingHousehold() => HouseholdModel(
        clientReferenceId: 'hh-closed-1',
        memberCount: 1,
        // The config maps the captured location onto BOTH the top-level
        // household fields and the nested address, so a real registered
        // household carries it in both places.
        latitude: 28.4435016,
        longitude: 77.0997822,
        address: AddressModel(
          relatedClientReferenceId: 'hh-closed-1',
          latitude: 28.4435016,
          longitude: 77.0997822,
          locationAccuracy: 12.0,
        ),
      );

  HouseholdModel update(Map<String, dynamic> formValues) {
    return FormEntityMapper(config: jsonConfig).updateModelFromForm(
      existingModel: existingHousehold(),
      formValues: formValues,
      modelConfig: householdModelConfig,
      context: const {},
    ) as HouseholdModel;
  }

  test(
      'reopening a closed household without re-capturing location keeps its '
      'stored coordinates', () {
    // The exact shape the debug capture showed on re-registration: the key
    // is present, the coordinates are not.
    final updated = update({
      'beneficiaryLocation': <String, dynamic>{'latLng': null},
      'memberCount': 6,
    });

    expect(updated.address?.latitude, 28.4435016);
    expect(updated.address?.longitude, 77.0997822);
    expect(updated.latitude, 28.4435016);
  });

  // latLng is stored as a comma-separated string and indexed by splitting
  // it, so "never captured" surfaces as '' as often as it does as null.
  test('an empty latLng string is also treated as "not captured"', () {
    final updated = update({
      'beneficiaryLocation': <String, dynamic>{'latLng': ''},
      'memberCount': 6,
    });

    expect(updated.address?.latitude, 28.4435016);
    expect(updated.address?.longitude, 77.0997822);
  });

  test('a freshly captured location still overwrites the stored one', () {
    final updated = update({
      'beneficiaryLocation': <String, dynamic>{'latLng': '11.1,22.2,5.0'},
      'memberCount': 6,
    });

    expect(updated.address?.latitude, 11.1);
    expect(updated.address?.longitude, 22.2);
  });
}
