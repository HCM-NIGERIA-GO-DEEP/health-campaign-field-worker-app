// T15 - QA (Kebbi AZM): members downloaded from last year's AZM data carry
// identifierType `uniqueBeneficiaryID` (old app enum name) instead of
// `UNIQUE_BENEFICIARY_ID`. hasBeneficiaryId gates the overview's ID tag and
// the Edit branch that hands the form a fresh pool ID, so a legacy member
// showed NO_BENEFICIARY_ID and editing it would replace its ID.
//
// Decision (Amit, 2026-11-03): a legacy-typed identifier counts as a
// beneficiary ID; its stored type is not changed.
import 'package:digit_flow_builder/utils/function_registry.dart';
import 'package:digit_flow_builder/utils/interpolation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/unique_id_test_support.dart';

void main() {
  setUpAll(setUpUniqueIdFlow);

  dynamic call(List<dynamic> args) =>
      FunctionRegistry.call('hasBeneficiaryId', args, CrudStateData({}, []));

  Map<String, dynamic> identifier(String? type) => {
        'identifierType': type,
        'identifierId': 'AB12CD',
      };

  test('UNIQUE_BENEFICIARY_ID -> true', () {
    expect(call([identifier('UNIQUE_BENEFICIARY_ID')]), isTrue);
  });

  test('legacy uniqueBeneficiaryID -> true', () {
    expect(call([identifier('uniqueBeneficiaryID')]), isTrue);
  });

  test('legacy spelling uniqueBeneficiaryId -> true', () {
    expect(call([identifier('uniqueBeneficiaryId')]), isTrue);
  });

  test('DEFAULT -> false', () {
    expect(call([identifier('DEFAULT')]), isFalse);
  });

  test('OTHER -> false', () {
    expect(call([identifier('OTHER')]), isFalse);
  });

  test('missing type -> false', () {
    expect(call([identifier(null)]), isFalse);
  });

  test('no identifier -> false', () {
    expect(call([null]), isFalse);
    expect(call([]), isFalse);
  });
}
