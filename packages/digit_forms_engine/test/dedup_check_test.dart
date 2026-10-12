import 'package:digit_forms_engine/models/property_schema/property_schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PropertySchema.dedupCheck', () {
    test('parses a page config carrying a dedupCheck', () {
      final schema = PropertySchema.fromJson({
        'type': 'object',
        'dedupCheck': {
          'model': 'individual',
          'fields': {
            'givenName': 'nameOfIndividual',
            'familyName': 'familyname',
          },
          'filters': [
            {
              'key': 'projectId',
              'root': 'projectBeneficiary',
              'value': '{{singleton.projectId}}',
              'operation': 'equals',
            }
          ],
          'matchThreshold': 0.85,
          'maxResults': 5,
          'minFieldLength': 2,
          'maxCandidates': 5000,
          'skipOnEdit': true,
          'showScore': true,
          'backToSearchPage': 'searchBeneficiary',
        },
      });

      final config = schema.dedupCheck;
      expect(config, isNotNull);
      expect(config!.model, 'individual');
      expect(config.fields, {
        'givenName': 'nameOfIndividual',
        'familyName': 'familyname',
      });
      expect(config.effectiveMatchThreshold, 0.85);
      expect(config.effectiveMaxResults, 5);
      expect(config.effectiveMinFieldLength, 2);
      expect(config.effectiveMaxCandidates, 5000);
      expect(config.skipOnEdit, isTrue);
      expect(config.backToSearchPage, 'searchBeneficiary');

      expect(config.filters, hasLength(1));
      expect(config.filters.first.key, 'projectId');
      expect(config.filters.first.root, 'projectBeneficiary');
      expect(config.filters.first.value, '{{singleton.projectId}}');
      expect(config.filters.first.operation, 'equals');
    });

    test('is null when the page declares no dedupCheck', () {
      final schema = PropertySchema.fromJson({'type': 'object'});
      expect(schema.dedupCheck, isNull);
    });

    test('is null for an empty dedupCheck', () {
      final schema = PropertySchema.fromJson({
        'type': 'object',
        'dedupCheck': <String, dynamic>{},
      });
      expect(schema.dedupCheck, isNull);
    });

    test('coerces numbers sent as strings', () {
      // MDMS configs in this repo send numeric settings as strings
      // (e.g. lengthRange.maxLength: "200").
      final config = DedupCheck.fromJson({
        'fields': {'givenName': 'nameOfIndividual'},
        'matchThreshold': '0.7',
        'maxResults': '3',
        'minFieldLength': '4',
        'maxCandidates': '100',
      });

      expect(config.effectiveMatchThreshold, 0.7);
      expect(config.effectiveMaxResults, 3);
      expect(config.effectiveMinFieldLength, 4);
      expect(config.effectiveMaxCandidates, 100);
    });

    test('falls back to defaults for omitted settings', () {
      final config = DedupCheck.fromJson({
        'fields': {'givenName': 'nameOfIndividual'},
      });

      expect(config.effectiveMatchThreshold, DedupCheck.defaultMatchThreshold);
      expect(config.effectiveMaxResults, DedupCheck.defaultMaxResults);
      expect(config.effectiveMinFieldLength, DedupCheck.defaultMinFieldLength);
      expect(config.effectiveMaxCandidates, DedupCheck.defaultMaxCandidates);
      // Skipping on edit is on unless turned off.
      expect(config.skipOnEdit, isTrue);
      // No dialog block means the built-in dialog with its default copy.
      expect(config.dedupAlertPopUp, isNull);
      expect(config.model, 'individual');
      expect(config.filters, isEmpty);
    });

    test('coerces non-string field mappings and drops null entries', () {
      final config = DedupCheck.fromJson({
        'fields': {'givenName': 'nameOfIndividual', 'familyName': null},
      });
      expect(config.fields, {'givenName': 'nameOfIndividual'});
    });

    test('defaults fields to empty when the mapping is not a map', () {
      final config = DedupCheck.fromJson({'fields': 'nonsense'});
      expect(config.fields, isEmpty);
    });

    test('parses the nested dialog block', () {
      final config = DedupCheck.fromJson({
        'fields': {'givenName': 'nameOfIndividual'},
        'dedupAlertPopUp': {
          'title': 'T',
          'primaryActionLabel': 'P',
          'secondaryActionLabel': 'S',
          'body': [
            {'format': 'listView', 'dataSource': 'dedupMatches'}
          ],
        },
      });

      final alert = config.dedupAlertPopUp;
      expect(alert, isNotNull);
      expect(alert!.title, 'T');
      expect(alert.matchesKey, 'dedupMatches');
      expect(alert.body, hasLength(1));
      // A duplicate warning should be answered, not dismissed by accident.
      expect(alert.barrierDismissible, isFalse);
      expect(alert.showCloseButton, isFalse);
      // Presentation settings moved here from DedupCheck.
      expect(alert.showScore, isTrue);
    });

    test('an empty dialog block is treated as absent', () {
      final config = DedupCheck.fromJson({
        'fields': {'givenName': 'nameOfIndividual'},
        'dedupAlertPopUp': <String, dynamic>{},
      });
      expect(config.dedupAlertPopUp, isNull);
    });

    test('optional fields default to empty and parse when given', () {
      expect(
        DedupCheck.fromJson({'fields': {'givenName': 'nameOfIndividual'}})
            .optionalFields,
        isEmpty,
      );

      final config = DedupCheck.fromJson({
        'fields': {'givenName': 'nameOfIndividual'},
        'optionalFields': {'mobileNumber': 'phone'},
      });
      expect(config.optionalFields, {'mobileNumber': 'phone'});
      // Optional fields must not leak into the required set, or a blank phone
      // would cancel the whole check.
      expect(config.fields, {'givenName': 'nameOfIndividual'});
    });

    test('a filter defaults its operation to equals', () {
      final filter = DedupFilter.fromJson({
        'key': 'projectId',
        'value': '{{singleton.projectId}}',
      });
      expect(filter.operation, 'equals');
      expect(filter.root, isNull);
    });
  });
}
