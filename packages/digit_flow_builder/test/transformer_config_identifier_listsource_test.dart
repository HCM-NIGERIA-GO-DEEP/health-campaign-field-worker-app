import 'package:digit_flow_builder/data/transformer_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Structural lint on transformer_config.dart's IdentifierModel listMappings
/// for both registration configs: guards against silently reverting to the
/// old single-item "householdDetails.identifiers[0]/[1]" mapping (which would
/// only ever capture the Beneficiary ID again, dropping the new
/// Identification Type/Number) or losing the listSource wiring.
void main() {
  for (final configName in ['beneficiaryRegistration', 'individualRegistration']) {
    group(configName, () {
      late Map<String, dynamic> identifierMapping;

      setUpAll(() {
        final config = jsonConfig[configName] as Map<String, dynamic>;
        final individualModel =
            config['models']['IndividualModel'] as Map<String, dynamic>;
        identifierMapping = individualModel['listMappings']['IdentifierModel']
            as Map<String, dynamic>;
      });

      test('is wired to read from the identifierEntries context, not a single form field', () {
        expect(identifierMapping['listSource'], '__context:identifierEntries');
      });

      test('reads identifierType/identifierId as plain per-item keys, not a bracket-indexed combined string', () {
        final mappings = identifierMapping['mappings'] as Map<String, dynamic>;

        expect(mappings['identifierType'], 'identifierType');
        expect(mappings['identifierId'], 'identifierId');
      });

      test('still generates a fresh clientReferenceId per identifier record', () {
        final mappings = identifierMapping['mappings'] as Map<String, dynamic>;

        expect(mappings['clientReferenceId'], '__generate:uuid');
      });
    });
  }
}
