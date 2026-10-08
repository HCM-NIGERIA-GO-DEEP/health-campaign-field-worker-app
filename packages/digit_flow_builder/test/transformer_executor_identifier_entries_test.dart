import 'package:digit_data_converter/src/transformer_service.dart';
import 'package:digit_flow_builder/action_handler/executors/transformer_executor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers TransformerExecutor.buildIdentifierEntries, which lets an
/// individual carry both an auto-generated Beneficiary ID (captured by the
/// existing, unchanged hidden "identifiers" idPopulator field) and a
/// separately-captured Identification Type/Number (the new
/// identificationType/identificationNumber fields), as two distinct
/// IdentifierModel records, without altering how the hidden field itself is
/// resolved.
void main() {
  final mapper = FormEntityMapper(config: const {});

  Map<String, dynamic> formValues({
    String? identifiers,
    String? identificationType,
    String? identificationNumber,
  }) {
    return {
      'householdDetails': {
        if (identifiers != null) 'identifiers': identifiers,
        if (identificationType != null) 'identificationType': identificationType,
        if (identificationNumber != null)
          'identificationNumber': identificationNumber,
      },
    };
  }

  test('produces 2 entries when both the auto Beneficiary ID and the new Identification pair are present', () {
    final entries = TransformerExecutor.buildIdentifierEntries(
      formValues(
        identifiers: 'DEFAULT, 123e4567-e89b-12d3-a456-426614174000',
        identificationType: 'NATIONAL_ID',
        identificationNumber: '98765432101',
      ),
      mapper,
    );

    expect(entries, hasLength(2));
    expect(entries[0], {
      'identifierType': 'DEFAULT',
      'identifierId': '123e4567-e89b-12d3-a456-426614174000',
    });
    expect(entries[1], {
      'identifierType': 'NATIONAL_ID',
      'identifierId': '98765432101',
    });
  });

  test('preserves a UNIQUE_BENEFICIARY_ID value on the existing hidden field unchanged', () {
    final entries = TransformerExecutor.buildIdentifierEntries(
      formValues(identifiers: 'UNIQUE_BENEFICIARY_ID, 998877665'),
      mapper,
    );

    expect(entries, hasLength(1));
    expect(entries.single['identifierType'], 'UNIQUE_BENEFICIARY_ID');
    expect(entries.single['identifierId'], '998877665');
  });

  test('skips the second entry when identificationType is set but identificationNumber is empty', () {
    final entries = TransformerExecutor.buildIdentifierEntries(
      formValues(
        identifiers: 'DEFAULT, uuid-1',
        identificationType: 'VOTER_ID',
        identificationNumber: '',
      ),
      mapper,
    );

    expect(entries, hasLength(1));
    expect(entries.single['identifierType'], 'DEFAULT');
  });

  test('skips the second entry entirely when neither identification field is present', () {
    final entries = TransformerExecutor.buildIdentifierEntries(
      formValues(identifiers: 'DEFAULT, uuid-1'),
      mapper,
    );

    expect(entries, hasLength(1));
  });

  test('falls back to a single all-null entry when nothing resolves, matching prior single-item behavior', () {
    final entries = TransformerExecutor.buildIdentifierEntries({}, mapper);

    expect(entries, hasLength(1));
    expect(entries.single, {'identifierType': null, 'identifierId': null});
  });

  test('handles an identifierId value that itself contains a comma (e.g. a name with a comma) by keeping the remainder joined', () {
    final entries = TransformerExecutor.buildIdentifierEntries(
      formValues(identifiers: 'DEFAULT, part-a,part-b'),
      mapper,
    );

    expect(entries.single['identifierId'], 'part-a,part-b');
  });

  /// Form data is keyed by page name. These fields were read from a hard-coded
  /// `householdDetails.` prefix, so the ADD_MEMBER flow - which captures them
  /// on its `beneficiaryDetails` page - resolved nothing and every added member
  /// synced with an identifier carrying no type and no Beneficiary ID.
  group('resolves the identifier fields off whichever page carries them', () {
    test('reads the Beneficiary ID from ADD_MEMBER\'s beneficiaryDetails page', () {
      final entries = TransformerExecutor.buildIdentifierEntries(
        {
          'beneficiaryDetails': {
            'identifiers': 'UNIQUE_BENEFICIARY_ID, 00000-1700afd1',
          },
        },
        mapper,
      );

      expect(entries, hasLength(1));
      expect(entries.single['identifierType'], 'UNIQUE_BENEFICIARY_ID');
      expect(entries.single['identifierId'], '00000-1700afd1');
    });

    test('reads the Identification Type/Number pair off a non-household page too', () {
      final entries = TransformerExecutor.buildIdentifierEntries(
        {
          'beneficiaryDetails': {
            'identifiers': 'UNIQUE_BENEFICIARY_ID, 998877665',
            'identificationType': 'NATIONAL_ID',
            'identificationNumber': '98765432101',
          },
        },
        mapper,
      );

      expect(entries, hasLength(2));
      expect(entries[0]['identifierId'], '998877665');
      expect(entries[1], {
        'identifierType': 'NATIONAL_ID',
        'identifierId': '98765432101',
      });
    });

    test('still prefers householdDetails when both pages are present, so existing flows are untouched', () {
      final entries = TransformerExecutor.buildIdentifierEntries(
        {
          'householdDetails': {'identifiers': 'UNIQUE_BENEFICIARY_ID, from-household'},
          'beneficiaryDetails': {'identifiers': 'UNIQUE_BENEFICIARY_ID, from-member'},
        },
        mapper,
      );

      expect(entries.single['identifierId'], 'from-household');
    });

    test('ignores the navigation params that execute() merges into form values', () {
      final entries = TransformerExecutor.buildIdentifierEntries(
        {
          'navigation': {'identifiers': 'UNIQUE_BENEFICIARY_ID, from-navigation'},
        },
        mapper,
      );

      expect(entries.single, {'identifierType': null, 'identifierId': null});
    });

    test('scans past pages that do not carry the field', () {
      final entries = TransformerExecutor.buildIdentifierEntries(
        {
          'beneficiaryLocation': {'addressLine1': 'somewhere'},
          'caregiverConsent': {'consent': true},
          'beneficiaryDetails': {'identifiers': 'DEFAULT, uuid-9'},
        },
        mapper,
      );

      expect(entries.single['identifierId'], 'uuid-9');
    });
  });
}
