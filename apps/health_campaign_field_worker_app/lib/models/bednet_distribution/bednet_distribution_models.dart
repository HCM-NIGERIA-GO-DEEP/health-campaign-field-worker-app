import 'dart:convert';

import 'package:digit_data_model/data_model.dart';

/// Persisted on [IndividualModel.additionalFields] when a class distribution is finished.
const String kBednetClassAdministeredKey = 'bednetClassAdministered';
const String kBednetClassAdministeredAtKey = 'bednetClassAdministeredAt';

/// Identifies a class row created for bednet distribution (links to [HouseholdModel] school).
const String kBednetClassIndexKey = 'bednetClassIndex';
const String kBednetFlowKey = 'bednetClassDistribution';

/// Keys on [TaskModel.additionalFields] when class distribution details are submitted.
const String kBednetTaskTotalPupilKey = 'totalPupilCount';
const String kBednetTaskTotalBoysKey = 'totalBoys';
const String kBednetTaskTotalGirlsKey = 'totalGirls';
const String kBednetTaskPupilsPresentKey = 'pupilsPresent';
const String kBednetTaskBoysPresentKey = 'boysPresent';
const String kBednetTaskGirlsPresentKey = 'girlsPresent';
const String kBednetTaskPupilsAbsentKey = 'pupilsAbsent';
const String kBednetTaskDistributionDateKey = 'distributionDate';
const String kBednetTaskSchoolClientRefKey = 'schoolClientReferenceId';
const String kBednetTaskSchoolNameKey = 'schoolName';
const String kBednetTaskClassNameKey = 'className';
const String kBednetTaskAdministrationStatusKey = 'taskAdministrationStatus';
const String kBednetTaskAdministrationSuccessStatus = 'ADMINISTRATION_SUCCESS';
const String kBednetTaskTotalAbsentKey = 'totalAbsent';

/// Drives one-shot UI navigation after [BednetDistributionEvent.completeClassAdministration].
enum BednetNavIntent { none, openSuccess, continueNextClass }

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

extension BednetIndividualFields on IndividualModel {
  Map<String, Object?> get _bednetFieldMap {
    final fields = additionalFields?.fields ?? const <AdditionalField>[];
    return {
      for (final field in fields)
        field.key.toLowerCase(): field.value as Object?,
    };
  }

  /// True when this class row has completed the bednet distribution workflow.
  bool get bednetClassAdministered {
    final m = _bednetFieldMap;
    final raw = m[kBednetClassAdministeredKey.toLowerCase()] ??
        m['bednetdistributioncompleted'] ??
        m['bednet_distribution_completed'];
    if (raw == null) return false;
    if (raw is bool) return raw;
    final s = raw.toString().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }

  int? get bednetClassIndex {
    final m = _bednetFieldMap;
    final raw = m[kBednetClassIndexKey.toLowerCase()] ??
        m['classindex'] ??
        m['class_index'];
    if (raw == null) return null;
    return int.tryParse(raw.toString());
  }

  String get bednetClassLabel {
    final idx = bednetClassIndex;
    return idx != null ? 'Class $idx' : 'Class';
  }
}

class ClassTeacherInfoModel {
  final String name;
  final String gender;
  final String mobileNumber;

  const ClassTeacherInfoModel({
    required this.name,
    required this.gender,
    required this.mobileNumber,
  });
}

class ClassDetailsModel {
  final DateTime distributionDate;
  final int pupilCount;
  final int numberOfBoys;
  final int numberOfGirls;
  final int pupilsPresent;
  final int boysPresent;
  final int girlsPresent;
  final int pupilsAbsent;

  const ClassDetailsModel({
    required this.distributionDate,
    required this.pupilCount,
    required this.numberOfBoys,
    required this.numberOfGirls,
    required this.pupilsPresent,
    required this.boysPresent,
    required this.girlsPresent,
    required this.pupilsAbsent,
  });
}

class DistributionSummaryModel {
  final String resourceName;
  final int boysReceived;
  final int girlsReceived;
  final int totalDelivered;

  const DistributionSummaryModel({
    required this.resourceName,
    required this.boysReceived,
    required this.girlsReceived,
    required this.totalDelivered,
  });
}
