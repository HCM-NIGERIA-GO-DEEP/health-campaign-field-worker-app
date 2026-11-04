import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/models/boundary_beneficiary_id.dart';

/// The beneficiary-ID prefix is a zero-padded fixed-width code ("0255").
///
/// It was held as an int, and int.tryParse("0255") is 255 - so the padding was
/// dropped and IDs were composed and persisted as "255_xx" instead of
/// "0255_xx". The prefix width then varied with the code's magnitude and no
/// longer matched what the backend issued.
///
/// Nothing arithmetic is ever done with this value; it is pure prefix text, so
/// it is now carried as a String end to end.
///
/// NOTE the value only survives if ALL THREE layers keep it textual:
///   1. this model (int.tryParse)
///   2. AppSharedPreferences get/setBoundaryNumericId (getInt/setInt)
///   3. BeneficiaryIdService.compose (numeric.toString())
/// Fixing one and missing another silently restores the bug - layer 2 in
/// particular would re-normalise a correctly parsed "0255" back to 255 on the
/// next read.
void main() {
  group('BoundaryBeneficiaryIdMap.fromJson', () {
    test('preserves leading zeros', () {
      final map = BoundaryBeneficiaryIdMap.fromJson({'BC-1': '0255'});

      expect(map.boundaryToNumericId['BC-1'], '0255',
          reason: 'the padding was dropped - an int round-trip is back');
    });

    test('keeps the issued width for several codes', () {
      final map = BoundaryBeneficiaryIdMap.fromJson({
        'BC-1': '0001',
        'BC-2': '0255',
        'BC-3': '1234',
      });

      expect(map.boundaryToNumericId.values.map((v) => v.length).toSet(), {4},
          reason: 'all four-wide on the wire, so all four-wide in the app');
    });

    test('accepts a value sent as a JSON number', () {
      // If the service ever sends 255 rather than "255" there is no padding to
      // preserve, but it must still parse rather than throw.
      final map = BoundaryBeneficiaryIdMap.fromJson({'BC-1': 255});

      expect(map.boundaryToNumericId['BC-1'], '255');
    });

    test('still rejects malformed mappings as loudly as before', () {
      // The int round-trip was doing double duty as validation. Dropping it
      // must not quietly let non-numeric text through into the ID prefix.
      expect(() => BoundaryBeneficiaryIdMap.fromJson({'BC-1': 'abc'}),
          throwsA(isA<FormatException>()));
      expect(() => BoundaryBeneficiaryIdMap.fromJson({'BC-1': '12a'}),
          throwsA(isA<FormatException>()));
      expect(() => BoundaryBeneficiaryIdMap.fromJson({'BC-1': ''}),
          throwsA(isA<FormatException>()));
      expect(() => BoundaryBeneficiaryIdMap.fromJson({'BC-1': null}),
          throwsA(isA<FormatException>()));
      expect(() => BoundaryBeneficiaryIdMap.fromJson({'': '0255'}),
          throwsA(isA<FormatException>()));
      expect(() => BoundaryBeneficiaryIdMap.fromJson({'BC-1': '-5'}),
          throwsA(isA<FormatException>()),
          reason: 'a negative prefix is not a valid fixed-width code');
    });

    test('the composed identifier keeps the padding', () {
      // What the user actually sees. Mirrors BeneficiaryIdService.compose:
      //   '${cached ?? dp.name}_$rawId'
      final map = BoundaryBeneficiaryIdMap.fromJson({'BC-1': '0255'});
      final prefix = map.boundaryToNumericId['BC-1'];

      expect('${prefix}_99', '0255_99');
      expect('${prefix}_99', isNot('255_99'));
    });
  });
}
