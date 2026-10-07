import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the input restrictions on the Beneficiary ID / National ID /
/// Phone Number search bars in REGISTRATION.json.
///
/// Sierra Leone captures four ID types (National ID, Voter ID, Passport,
/// Driver's License) through one shared search bar, so that bar has to
/// accept any of their formats while still rejecting junk. The search bar
/// widget already strips non-ASCII (emoji); `allowedCharacters` is what
/// additionally keeps ASCII punctuation out of an ID or phone lookup.
/// Name search deliberately has no such restriction - names legitimately
/// contain spaces, hyphens and apostrophes.
void main() {
  late Map<String, dynamic> registration;

  setUpAll(() {
    final file = File('assets/configs/json/REGISTRATION.json');
    registration = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  });

  /// Walks the whole config looking for a widget with the given fieldName.
  Map<String, dynamic>? findByFieldName(dynamic node, String fieldName) {
    if (node is Map<String, dynamic>) {
      if (node['fieldName'] == fieldName) return node;
      for (final value in node.values) {
        final found = findByFieldName(value, fieldName);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final item in node) {
        final found = findByFieldName(item, fieldName);
        if (found != null) return found;
      }
    }
    return null;
  }

  test('the National ID search bar accepts only alphanumeric characters', () {
    final field = findByFieldName(registration, 'nationalIdSearchBar');

    expect(field, isNotNull);
    expect(field!['allowedCharacters'], 'a-zA-Z0-9');
  });

  test('the Beneficiary ID search bar accepts only alphanumeric characters',
      () {
    final field = findByFieldName(registration, 'idSearchBar');

    expect(field, isNotNull);
    expect(field!['allowedCharacters'], 'a-zA-Z0-9');
  });

  test('the Phone Number search bar accepts only digits', () {
    final field = findByFieldName(registration, 'phoneNumberSearchBar');

    expect(field, isNotNull);
    expect(field!['allowedCharacters'], '0-9');
  });

  test(
      'the name search bar stays unrestricted - names contain spaces, '
      'hyphens and apostrophes', () {
    final field = findByFieldName(registration, 'searchBar');

    expect(field, isNotNull);
    expect(field!.containsKey('allowedCharacters'), isFalse);
  });

  test(
      'every ID search bar still requires a minimum number of characters '
      'before firing a search', () {
    for (final fieldName in ['nationalIdSearchBar', 'idSearchBar']) {
      final field = findByFieldName(registration, fieldName);
      expect(field, isNotNull, reason: '$fieldName should exist');

      final minSearchChars = field!['minSearchChars'];
      expect(minSearchChars, isA<int>(), reason: '$fieldName minSearchChars');
      expect(minSearchChars as int, greaterThanOrEqualTo(2),
          reason: '$fieldName should not search on a single character');
    }
  });

  test(
      'the National ID search covers all four captured ID types, not just '
      'NATIONAL_ID', () {
    final field = findByFieldName(registration, 'nationalIdSearchBar');
    final actions = field!['onAction'] as List<dynamic>;

    final data = (((actions.first as Map<String, dynamic>)['actions']
            as List<dynamic>)
        .first as Map<String, dynamic>)['properties']['data'] as List<dynamic>;

    final identifierTypeFilter = data.firstWhere(
      (e) => (e as Map<String, dynamic>)['key'] == 'identifierType',
    ) as Map<String, dynamic>;

    expect(
      (identifierTypeFilter['value'] as List<dynamic>).toSet(),
      {'NATIONAL_ID', 'VOTER_ID', 'PASSPORT', 'DRIVERS_LICENSE'},
    );
  });

  test(
      'the search result card labels the ID by its actual type rather than '
      'hardcoding NATIONAL_ID', () {
    final field = findByFieldName(registration, 'nationalIdDisplay');
    final data = (field!['data'] as List<dynamic>).first
        as Map<String, dynamic>;

    // A Passport or Voter ID must not be displayed under a "NATIONAL_ID"
    // label - the key has to come from the identifier's own type.
    expect(data['key'], contains('identifierType'));
    expect(data['value'], contains('identifierId'));
  });

  test(
      'the identification type dropdown offers exactly the four ID types '
      'the search filters on', () {
    final field = findByFieldName(registration, 'identificationType');
    final enums = field!['enums'] as List<dynamic>;

    final codes =
        enums.map((e) => (e as Map<String, dynamic>)['code']).toSet();

    expect(codes, {'NATIONAL_ID', 'DRIVERS_LICENSE', 'PASSPORT', 'VOTER_ID'});
  });

  test(
      'the captured identification number rejects special characters and '
      'emoji via an anchored alphanumeric pattern', () {
    final field = findByFieldName(registration, 'identificationNumber');
    final validations = field!['validations'] as List<dynamic>;

    final pattern = validations.firstWhere(
      (v) => (v as Map<String, dynamic>)['type'] == 'pattern',
    ) as Map<String, dynamic>;

    final regex = RegExp(pattern['value'] as String);

    expect(regex.hasMatch('AB1234567'), isTrue);
    expect(regex.hasMatch('12345'), isTrue);
    expect(regex.hasMatch('AB-123'), isFalse);
    expect(regex.hasMatch('AB 123'), isFalse);
    expect(regex.hasMatch('AB@123'), isFalse);
    expect(regex.hasMatch('AB😀123'), isFalse);
    expect(regex.hasMatch(''), isFalse);
  });
}
