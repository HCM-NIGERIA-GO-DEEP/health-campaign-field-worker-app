// Rows arrive as maps or as models, read by field name; a missing field is
// caught.
// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';

/// Household details the delivery task carries for the distribution report.
///
/// Liberia delivers one ITN task per HOUSEHOLD, so the task has no individual
/// of its own: the head and the registered members are copied onto it when
/// householdOverview opens the DELIVERY form. The registration report reads
/// the same people from Household Members.
///
/// Both functions run inside flow `fn:` rules, where a throw blanks the whole
/// screen, so neither throws. Each returns null when it has nothing to say: a
/// null navigation value is dropped and the task is saved without that key.

/// Gender code of [individual] ("MALE", "FEMALE", ...), or null.
///
/// Usage: `{{fn:individualGender(contextData.0.headIndividual.IndividualModel)}}`
String? individualGender(dynamic individual) {
  try {
    return _gender(_asMap(individual));
  } catch (_) {
    return null;
  }
}

/// The registered members of a household that are not its head, as a JSON
/// array text, or null when there are none.
///
/// [members] is the `members` relation of the household wrapper: a list of
/// rows, each holding its HouseholdMember under `member` and its Individual
/// under `individual`. One object per member, with only the keys that have a
/// value:
/// `individualClientReferenceId`, `name`, `gender`, `dateOfBirth`,
/// `beneficiaryId`.
///
/// It is text because a task additional field holds one string value.
///
/// Usage: `{{fn:householdMembersForTask(contextData.0.members)}}`
String? householdMembersForTask(dynamic members) {
  try {
    final List<dynamic> rows;
    if (members is List) {
      rows = members;
    } else if (members is Map) {
      rows = [members];
    } else {
      return null;
    }

    final result = <Map<String, String>>[];
    for (final row in rows) {
      if (row == null) continue;
      try {
        final member = _asMap(_field(row, 'member'));
        if (_isTrue(member?['isHeadOfHousehold'])) continue;

        final individual = _asMap(_field(row, 'individual'));
        final entry = <String, String>{};
        void put(String key, dynamic value) {
          final text = value?.toString().trim() ?? '';
          if (text.isNotEmpty && text != 'null') entry[key] = text;
        }

        put(
          'individualClientReferenceId',
          individual?['clientReferenceId'] ??
              member?['individualClientReferenceId'],
        );
        final name = _asMap(individual?['name']);
        put(
          'name',
          [name?['givenName'], name?['familyName']]
              .map((part) => part?.toString().trim() ?? '')
              .where((part) => part.isNotEmpty && part != 'null')
              .join(' '),
        );
        put('gender', _gender(individual));
        put('dateOfBirth', individual?['dateOfBirth']);
        put('beneficiaryId', _beneficiaryId(individual?['identifiers']));

        if (entry.isNotEmpty) result.add(entry);
      } catch (_) {
        // One unreadable row must not lose the others.
      }
    }
    return result.isEmpty ? null : jsonEncode(result);
  } catch (_) {
    return null;
  }
}

dynamic _field(dynamic row, String name) {
  if (row is Map) return row[name];
  try {
    return (row.toMap() as Map)[name];
  } catch (_) {
    return null;
  }
}

/// A map view of a map, a model with `toMap()`, or the first usable entry of
/// a list of either.
Map<dynamic, dynamic>? _asMap(dynamic value) {
  if (value == null) return null;
  if (value is Map) return value;
  if (value is List) {
    for (final entry in value) {
      final map = _asMap(entry);
      if (map != null) return map;
    }
    return null;
  }
  try {
    final map = value.toMap();
    return map is Map ? map : null;
  } catch (_) {
    return null;
  }
}

String? _gender(Map<dynamic, dynamic>? individual) {
  final raw = individual?['gender'];
  if (raw == null) return null;
  // "MALE", or an enum printed as "Gender.male".
  final text = raw.toString().split('.').last.trim().toUpperCase();
  return text.isEmpty || text == 'NULL' ? null : text;
}

String? _beneficiaryId(dynamic identifiers) {
  if (identifiers is! List) return null;
  for (final identifier in identifiers) {
    final map = _asMap(identifier);
    final type = map?['identifierType']?.toString().trim().toUpperCase();
    final id = map?['identifierId']?.toString().trim() ?? '';
    if (type == 'UNIQUE_BENEFICIARY_ID' && id.isNotEmpty) return id;
  }
  return null;
}

bool _isTrue(dynamic value) =>
    value == true || value == 1 || value?.toString().toLowerCase() == 'true';
