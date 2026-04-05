import 'dart:convert';

import 'package:digit_data_model/data_model.dart';

/// Parsed [HouseholdModel.additionalFields] for school households (see assets/sample_data/household.csv).
extension BednetHouseholdFields on HouseholdModel {
  String get bednetSchoolId => id ?? clientReferenceId;

  Map<String, Object?> get _bednetFieldMap {
    final fields = additionalFields?.fields ?? const <AdditionalField>[];
    return {
      for (final field in fields)
        field.key.toLowerCase(): field.value as Object?,
    };
  }

  int _readInt(List<String> keys, int fallback) {
    final fieldMap = _bednetFieldMap;
    for (final key in keys) {
      final raw = fieldMap[key.toLowerCase()];
      if (raw == null) continue;
      final value = int.tryParse(raw.toString());
      if (value != null) return value;
    }
    return fallback;
  }

  String _readString(List<String> keys, String fallback) {
    final fieldMap = _bednetFieldMap;
    for (final key in keys) {
      final raw = fieldMap[key.toLowerCase()];
      if (raw == null) continue;
      final value = raw.toString().trim();
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  /// Server sample uses [schoolName]; also supports nested map / JSON string with `name`.
  String get bednetDisplayName {
    final fromFlat = _readString(
      const ['schoolname', 'name', 'school_name', 'nameofphu'],
      '',
    );
    if (fromFlat.isNotEmpty) return fromFlat;

    final fields = additionalFields?.fields ?? const <AdditionalField>[];
    for (final field in fields) {
      final v = field.value;
      if (v is Map) {
        final n = v['name'] ?? v['Name'];
        if (n != null && n.toString().trim().isNotEmpty) {
          return n.toString().trim();
        }
      }
      if (v is String) {
        final trimmed = v.trim();
        if (trimmed.startsWith('{')) {
          try {
            final decoded = jsonDecode(trimmed);
            if (decoded is Map) {
              final n = decoded['name'] ?? decoded['Name'];
              if (n != null && n.toString().trim().isNotEmpty) {
                return n.toString().trim();
              }
            }
          } catch (_) {}
        }
      }
    }

    return clientReferenceId;
  }

  String get bednetSchoolHead => _readString(
        const ['schoolhead', 'school_head', 'headteacher'],
        'N/A',
      );

  String get bednetCommunity => _readString(
        const [
          'community',
          'localityname',
          'locality_name',
          'boundaryname',
          'boundary_name',
          'village',
        ],
        '—',
      );

  /// CSV uses [numberOfClasses]; keys like class1_className define per-class rows.
  int get bednetNumberOfClasses => _readInt(
        const ['numberofclasses', 'number_of_classes', 'classcount'],
        1,
      );

  int get bednetPupilCount {
    final boysInSchool = _readInt(
      const ['numberofboysinschool', 'number_of_boys_in_school'],
      0,
    );
    final girlsInSchool = _readInt(
      const ['numberofgirlsinschool', 'number_of_girls_in_school'],
      0,
    );
    if (boysInSchool > 0 || girlsInSchool > 0) {
      return boysInSchool + girlsInSchool;
    }
    final pupilCount = _readInt(
      const ['pupilcount', 'pupil_count', 'totalpupilcount'],
      0,
    );
    final numberOfBoys = bednetNumberOfBoys;
    final numberOfGirls = bednetNumberOfGirls;
    final derivedTotal = numberOfBoys + numberOfGirls;
    return pupilCount > 0 ? pupilCount : derivedTotal;
  }

  int get bednetNumberOfBoys => _readInt(
        const [
          'numberofboysinschool',
          'number_of_boys_in_school',
          'numberofboys',
          'number_of_boys',
          'boyscount',
        ],
        0,
      );

  int get bednetNumberOfGirls => _readInt(
        const [
          'numberofgirlsinschool',
          'number_of_girls_in_school',
          'numberofgirls',
          'number_of_girls',
          'girlscount',
        ],
        0,
      );

  /// Location for addresses/tasks — sourced from [additionalFields] (`latitude` / `longitude`, `lat` / `lng`).
  ({double? latitude, double? longitude}) get bednetLatLngFromAdditionalFields {
    final fieldMap = _bednetFieldMap;
    double? parseCoord(String key) {
      final raw = fieldMap[key.toLowerCase()];
      if (raw == null) return null;
      return double.tryParse(raw.toString());
    }

    final lat = parseCoord('latitude') ??
        parseCoord('lat') ??
        parseCoord('schoollatitude');
    final lng = parseCoord('longitude') ??
        parseCoord('lng') ??
        parseCoord('long') ??
        parseCoord('schoollongitude');
    return (latitude: lat, longitude: lng);
  }
}

/// Registered head name if present; otherwise school head from [HouseholdModel.additionalFields].
String bednetHouseholdHeadDisplayName({
  HouseholdModel? household,
  IndividualModel? headOfHousehold,
}) {
  final given = headOfHousehold?.name?.givenName?.trim();
  if (given != null && given.isNotEmpty) return given;
  if (household != null) {
    final schoolHead = household.bednetSchoolHead.trim();
    if (schoolHead.isNotEmpty && schoolHead != 'N/A') return schoolHead;
  }
  return '';
}

/// Placeholder schools when the local DB has no school households yet (replace
/// with API-backed list when available).
List<HouseholdModel> bednetDummySchoolHouseholds() {
  HouseholdModel dummySchool({
    required String clientReferenceId,
    required String schoolName,
    required String schoolHead,
    required int studentCount,
    required String community,
    int numberOfClasses = 2,
    int numberOfBoys = 0,
    int numberOfGirls = 0,
  }) {
    final fields = <AdditionalField>[
      const AdditionalField('type', 'school'),
      AdditionalField('schoolName', schoolName),
      AdditionalField('schoolHead', schoolHead),
      AdditionalField('community', community),
      AdditionalField('numberOfClasses', numberOfClasses),
    ];
    if (numberOfBoys > 0 || numberOfGirls > 0) {
      fields.add(AdditionalField('numberOfBoysInSchool', numberOfBoys));
      fields.add(AdditionalField('numberOfGirlsInSchool', numberOfGirls));
    } else {
      fields.add(AdditionalField('pupilCount', studentCount));
    }
    return HouseholdModel(
      clientReferenceId: clientReferenceId,
      rowVersion: 1,
      additionalFields: HouseholdAdditionalFields(
        version: 1,
        fields: fields,
      ),
    );
  }

  return [
    dummySchool(
      clientReferenceId: 'bednet-dummy-school-001',
      schoolName: 'School ABC',
      schoolHead: 'Joseph Sergio',
      studentCount: 115,
      community: 'Bagwaro gabas',
      numberOfClasses: 3,
      numberOfBoys: 60,
      numberOfGirls: 55,
    ),
    dummySchool(
      clientReferenceId: 'bednet-dummy-school-002',
      schoolName: 'LGA Primary School',
      schoolHead: 'Amina Bello',
      studentCount: 240,
      community: 'Bagwaro gabas',
      numberOfClasses: 4,
      numberOfBoys: 120,
      numberOfGirls: 120,
    ),
    dummySchool(
      clientReferenceId: 'bednet-dummy-school-003',
      schoolName: 'Community Junior Secondary',
      schoolHead: 'Emeka Okafor',
      studentCount: 88,
      community: 'Rijiyar Lemu',
      numberOfClasses: 2,
      numberOfBoys: 0,
      numberOfGirls: 0,
    ),
  ];
}
