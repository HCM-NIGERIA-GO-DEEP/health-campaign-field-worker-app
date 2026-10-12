/// Team-ownership helpers shared by TeamRecordVisibility (the disable gate
/// behind `disableEdit` and `fn:isOwnedByMyTeam`, on in both modes), the app's
/// HIDE-mode filter functions (`myTeamFilterValue` / `isVisibleToMyTeam` /
/// `individualsVisibleToMyTeam`) and its auth / team-selection code.
///
/// Deliberately free of project imports so the unit tests compile standalone,
/// and written so nothing here can throw into a flow-builder `fn:` (an
/// uncaught throw there blanks the whole TEMPLATE screen body).
library;

import 'dart:convert';

/// `Individual.additionalFields` key holding the logged-in user's team code.
const String kTeamCodeKey = 'team_code';

/// `ProjectBeneficiary.additionalFields` key holding the registering team.
const String kRegisteredByTeamKey = 'registered_by_team';

/// Reads one value out of an `additionalFields` structure.
///
/// [source] may be an `AdditionalFields` model (anything with a `fields`
/// getter), a `{fields: [...]}` map, a bare list of `{key, value}` entries /
/// `AdditionalField` objects, or the JSON string the Drift column stores.
/// Returns the trimmed value, or null when absent, blank or unreadable.
String? readAdditionalField(dynamic source, String key) {
  final fields = _fieldsOf(source);
  if (fields == null) return null;
  for (final field in fields) {
    final entry = _keyValueOf(field);
    if (entry == null || entry.key != key) continue;
    final value = entry.value?.toString().trim();
    return (value == null || value.isEmpty) ? null : value;
  }
  return null;
}

/// Whether the logged-in team may act on [projectBeneficiaries].
///
/// True when the record carries no `registered_by_team` (legacy / untagged),
/// when [myTeamCode] is null or blank (today's behaviour), or when the codes
/// match after trimming. False only when both are present and differ.
/// With several beneficiaries the one whose `projectId` equals [projectId]
/// is used, falling back to the first. Malformed input is allowed (fail-open).
bool isOwnedByMyTeam(
  dynamic projectBeneficiaries,
  String? myTeamCode, {
  String? projectId,
}) {
  try {
    final mine = myTeamCode?.trim();
    if (mine == null || mine.isEmpty) return true;

    final beneficiary = _selectBeneficiary(projectBeneficiaries, projectId);
    if (beneficiary == null) return true;

    final owner = readAdditionalField(
      _additionalFieldsOf(beneficiary),
      kRegisteredByTeamKey,
    );
    if (owner == null) return true;

    return owner == mine;
  } catch (_) {
    return true;
  }
}

/// The `matches` (SQL `LIKE '%value%'`) search-filter value that selects
/// beneficiaries registered by [myTeamCode].
///
/// It is the `{"key":..,"value":..}` fragment exactly as
/// `ProjectBeneficiaryAdditionalFields.toJson()` writes it into the
/// `additional_fields` column; the closing quote keeps `T1` from matching
/// `T10`. Null when there is no team code, so the search executor and the
/// dedup check drop the filter and the user sees everything.
String? teamFilterValue(String? myTeamCode) {
  final code = myTeamCode?.trim();
  if (code == null || code.isEmpty) return null;
  return '"key":${jsonEncode(kRegisteredByTeamKey)},"value":${jsonEncode(code)}';
}

/// Whether a household member with [projectBeneficiaries] is shown to the
/// logged-in team.
///
/// True for everyone when [myTeamCode] is null or blank. Otherwise true only
/// when ANY of the beneficiary records carries `registered_by_team` equal to
/// the code after trimming, the same rule the search filter applies in SQL;
/// untagged records, other teams' records and members without a record are
/// hidden. [projectBeneficiaries] may be one record or a list of models /
/// maps.
bool isVisibleToMyTeam(dynamic projectBeneficiaries, String? myTeamCode) {
  final mine = myTeamCode?.trim();
  if (mine == null || mine.isEmpty) return true;
  return _asList(projectBeneficiaries).any(
    (beneficiary) =>
        readAdditionalField(
          _additionalFieldsOf(beneficiary),
          kRegisteredByTeamKey,
        ) ==
        mine,
  );
}

/// The [individuals] shown to the logged-in team: those whose beneficiary
/// records (matched on `beneficiaryClientReferenceId`) pass
/// [isVisibleToMyTeam]. Everyone when [myTeamCode] is null or blank.
///
/// A single individual is treated as a one-item list and null as empty,
/// mirroring how the table widget reads its rows.
List<dynamic> individualsVisibleToMyTeam(
  dynamic individuals,
  dynamic projectBeneficiaries,
  String? myTeamCode,
) {
  final people = _asList(individuals);
  final mine = myTeamCode?.trim();
  if (mine == null || mine.isEmpty) return people;

  final beneficiaries = _asList(projectBeneficiaries);
  return people.where((individual) {
    final ref = _clientReferenceIdOf(individual);
    if (ref == null) return false;
    final own = beneficiaries.where((b) => _beneficiaryReferenceOf(b) == ref);
    return isVisibleToMyTeam(own.toList(), mine);
  }).toList();
}

List<dynamic>? _fieldsOf(dynamic source) {
  if (source == null) return null;
  if (source is String) {
    final decoded = _tryDecode(source);
    return (decoded is Map || decoded is List) ? _fieldsOf(decoded) : null;
  }
  if (source is List) return source;
  if (source is Map) {
    final fields = source['fields'];
    return fields is List ? fields : null;
  }
  try {
    final fields = (source as dynamic).fields;
    return fields is List ? fields : null;
  } catch (_) {
    return null;
  }
}

({String key, dynamic value})? _keyValueOf(dynamic field) {
  if (field is Map) {
    final key = field['key']?.toString();
    return key == null ? null : (key: key, value: field['value']);
  }
  try {
    final key = (field as dynamic).key?.toString();
    return key == null ? null : (key: key, value: field.value);
  } catch (_) {
    return null;
  }
}

List<dynamic> _asList(dynamic source) {
  if (source == null) return const [];
  if (source is List) return source;
  return [source];
}

dynamic _selectBeneficiary(dynamic source, String? projectId) {
  if (source == null || source is String || source is num) return null;
  if (source is! List) return source;
  if (source.isEmpty) return null;
  if (projectId != null) {
    for (final candidate in source) {
      if (_projectIdOf(candidate) == projectId) return candidate;
    }
  }
  return source.first;
}

dynamic _additionalFieldsOf(dynamic beneficiary) {
  if (beneficiary is Map) return beneficiary['additionalFields'];
  try {
    return (beneficiary as dynamic).additionalFields;
  } catch (_) {
    return null;
  }
}

String? _clientReferenceIdOf(dynamic individual) {
  if (individual is Map) return individual['clientReferenceId']?.toString();
  try {
    return (individual as dynamic).clientReferenceId?.toString();
  } catch (_) {
    return null;
  }
}

String? _beneficiaryReferenceOf(dynamic beneficiary) {
  if (beneficiary is Map) {
    return beneficiary['beneficiaryClientReferenceId']?.toString();
  }
  try {
    return (beneficiary as dynamic).beneficiaryClientReferenceId?.toString();
  } catch (_) {
    return null;
  }
}

String? _projectIdOf(dynamic beneficiary) {
  if (beneficiary is Map) return beneficiary['projectId']?.toString();
  try {
    return (beneficiary as dynamic).projectId?.toString();
  } catch (_) {
    return null;
  }
}

dynamic _tryDecode(String raw) {
  try {
    return jsonDecode(raw);
  } catch (_) {
    return null;
  }
}
