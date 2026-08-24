import 'package:digit_flow_builder/utils/semantics_identifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('semanticsIdentifierFor', () {
    test('uses key when present', () {
      expect(
        semanticsIdentifierFor({'key': 'houseType'}, 'householdDetails'),
        'householdDetails_houseType',
      );
    });

    test('falls back to fieldName when key is absent', () {
      expect(
        semanticsIdentifierFor({'fieldName': 'searchBar'}, 'searchBeneficiary'),
        'searchBeneficiary_searchBar',
      );
    });

    test('key wins over fieldName when both present', () {
      expect(
        semanticsIdentifierFor(
          {'key': 'primary', 'fieldName': 'secondary'},
          's',
        ),
        's_primary',
      );
    });

    test('button falls back to plain label code', () {
      expect(
        semanticsIdentifierFor(
          {'format': 'button', 'label': 'APPONE_SUBMIT_LABEL'},
          'deliveryDetails',
        ),
        'deliveryDetails_APPONE_SUBMIT_LABEL',
      );
    });

    test('button with template label gets no identifier', () {
      expect(
        semanticsIdentifierFor(
          {'format': 'button', 'label': '{{fn:someLabel()}}'},
          's',
        ),
        isNull,
      );
    });

    test('non-button widget never uses label fallback', () {
      expect(
        semanticsIdentifierFor({'format': 'text', 'label': 'SOME_CODE'}, 's'),
        isNull,
      );
    });

    test('returns null for layout nodes without key/fieldName', () {
      expect(semanticsIdentifierFor({'format': 'card'}, 'screen'), isNull);
    });

    test('empty-string key is treated as missing', () {
      expect(semanticsIdentifierFor({'key': ''}, 's'), isNull);
    });

    test('non-string key is treated as missing', () {
      expect(semanticsIdentifierFor({'key': 42}, 's'), isNull);
    });

    test('null stateKey returns bare field key', () {
      expect(semanticsIdentifierFor({'key': 'houseType'}, null), 'houseType');
    });

    test('empty stateKey returns bare field key', () {
      expect(semanticsIdentifierFor({'key': 'houseType'}, ''), 'houseType');
    });
  });
}
