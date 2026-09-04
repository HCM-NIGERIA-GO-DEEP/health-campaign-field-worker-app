import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data_model.init.dart' as mappers;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('entityTypeName', () {
    test('resolves the canonical model name once mappers are initialized', () {
      mappers.initializeMappers();

      expect(entityTypeName(HouseholdModel(clientReferenceId: 'h1')),
          'HouseholdModel');
      expect(entityTypeName(IndividualModel(clientReferenceId: 'i1')),
          'IndividualModel');
      expect(entityTypeName(TaskModel(clientReferenceId: 't1')), 'TaskModel');
    });

    test('resolves the name for a model with no registered mapper', () {
      // The model factory registries are keyed by these names, so resolution
      // must not depend on initializeMappers() having run first.
      expect(entityTypeName(AddressModel()), 'AddressModel');
    });
  });
}
