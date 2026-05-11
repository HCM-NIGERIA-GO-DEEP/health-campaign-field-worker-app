import 'package:collection/collection.dart';
import 'package:digit_data_model/models/entities/facility.dart';
import 'package:digit_data_model/models/entities/project_facility.dart';
import 'package:digit_forms_engine/models/property_schema/property_schema.dart';

import 'constants.dart';

/// Resolved facility `usage` strings for inventory facility dropdowns.
///
/// Call [resolveFacilityUsageForInventory] from widgets, executors, or blocs.
/// Use [filterProjectFacilitiesByFacilityUsage] once [FacilityModel]s are loaded.
class FacilityUsageResolution {
  const FacilityUsageResolution({
    required this.usage,
    this.additionalUsage,
    this.showTeamOption = false,
  });

  /// Primary usage label from MDMS (or `'None'` when the dropdown should not
  /// list facilities by this usage — e.g. distributor destination).
  final String usage;

  /// Optional second usage (e.g. DH rows also tagged as Health Facility).
  final String? additionalUsage;

  /// When true, callers may inject a synthetic "team" row (see inventory UI).
  final bool showTeamOption;
}

/// Resolves primary / secondary facility usage strings from roles, boundary, and
/// stock transaction type — same rules as the inventory facility card reference.
FacilityUsageResolution resolveFacilityUsageForInventory({
  required String stockEntryType,
  required String transactionType,
  required bool isToField,
  required bool isFromField,
  required String? boundaryType,
  required bool isWareHouseMgr,
  required bool isDistributor,
  required bool isCommunityDistributor,
  required bool isHfs,
}) {
  String usage = '';
  var showTeamOption = false;

  if (stockEntryType == 'ISSUED') {
    if (isWareHouseMgr) {
      if (boundaryType == Constants.stateBoundaryLevel) {
        if (isFromField) {
          usage = Constants.stateFacility;
        } else {
          usage = Constants.healthFacility;
        }
      } else if (boundaryType == Constants.lgaBoundaryLevel) {
        if (isFromField) {
          usage = Constants.lgaFacility;
        } else {
          usage = Constants.dhFacility;
        }
      } else if (boundaryType == Constants.distributionHubBoundaryLevel) {
        if (isFromField) {
          usage = Constants.dhFacility;
        } else {
          usage = 'None';
          showTeamOption = true;
        }
      } else {
        if (isHfs) {
          if (isFromField) {
            usage = Constants.healthFacility;
          } else {
            showTeamOption = true;
            usage = 'None';
          }
        } else {
          usage = 'None';
        }
      }
    } else if (isDistributor || isCommunityDistributor) {
      usage = 'None';
    } else {
      if (isToField) {
        showTeamOption = true;
        usage = 'None';
      } else {
        usage = Constants.healthFacility;
      }
    }
  } else {
    if (isWareHouseMgr) {
      if (boundaryType == Constants.stateBoundaryLevel) {
        if (isFromField) {
          usage = Constants.stateFacility;
        } else {
          usage = Constants.centralFacility;
        }
      } else if (boundaryType == Constants.lgaBoundaryLevel) {
        if (isFromField) {
          usage = Constants.lgaFacility;
        } else {
          usage = Constants.stateFacility;
        }
      } else if (boundaryType == Constants.distributionHubBoundaryLevel) {
        if (isFromField) {
          usage = Constants.dhFacility;
        } else {
          usage = Constants.healthFacility;
        }
      } else {
        if (isHfs) {
          if (isFromField) {
            usage = Constants.healthFacility;
          } else {
            usage = Constants.stateFacility;
          }
        } else {
          usage = 'None';
        }
      }
    } else if (isCommunityDistributor || isDistributor) {
      if (isToField) {
        usage = Constants.healthFacility;
      } else {
        usage = 'None';
      }
    } else {
      if (isFromField) {
        if (isHfs) {
          usage = Constants.healthFacility;
        } else {
          usage = 'None';
        }
      } else {
        usage = 'None';
      }
    }
  }

// todo in future if we have to filter the facilities we can do it
  final additionalUsage = (usage == Constants.healthFacility &&
          boundaryType == Constants.stateBoundaryLevel)
      ? Constants.districtFacility
      : (isCommunityDistributor || isDistributor)
          ? Constants.dhFacility
          : null;

  return FacilityUsageResolution(
    usage: usage,
    additionalUsage: additionalUsage,
    showTeamOption: showTeamOption,
  );
}

/// Keeps only project facilities whose `facilityLevel` is unset or `current`
/// (aligned with stock balance / inventory behaviour).
List<ProjectFacilityModel> filterProjectFacilitiesToCurrentLevel(
  List<ProjectFacilityModel> projectFacilities,
) {
  return projectFacilities.where((pf) {
    final facilityLevel = pf.additionalFields?.fields
        .where((f) => f.key == 'facilityLevel')
        .firstOrNull
        ?.value;
    return facilityLevel == null || facilityLevel == 'current';
  }).toList();
}

/// Filters [projectFacilities] by matching [FacilityModel.usage] from
/// [facilitiesFromDb]. When [usage] is null or blank, returns [projectFacilities]
/// unchanged (no usage-based narrowing).
///
/// When [usage] is non-empty, scopes to [filterProjectFacilitiesToCurrentLevel]
/// first, then restricts to facility IDs whose usage matches [usage] or
/// [additionalUsage]. When [facilitiesFromDb] is empty, this returns an empty
/// list so callers can wait for DB-backed usage filtering instead of showing an
/// unfiltered current-level fallback.
List<ProjectFacilityModel> filterProjectFacilitiesByFacilityUsage({
  required List<ProjectFacilityModel> projectFacilities,
  required List<FacilityModel> facilitiesFromDb,
  required bool isLoadingFacilitiesFromDb,
  required String? usage,
  String? additionalUsage,
}) {
  if (usage == null || usage.trim().isEmpty) {
    return projectFacilities;
  }

  final currentLevelProjectFacilities =
      filterProjectFacilitiesToCurrentLevel(projectFacilities);

  final currentLevelFacilityIds =
      currentLevelProjectFacilities.map((pf) => pf.facilityId).toSet();

  if (currentLevelFacilityIds.isEmpty) {
    return currentLevelProjectFacilities;
  }

  if (facilitiesFromDb.isEmpty) {
    return <ProjectFacilityModel>[];
  }

  final primaryUsage = usage.trim();
  final secondaryUsage = additionalUsage?.trim();

  final allowedFacilityIds = facilitiesFromDb
      .where((f) {
        final currentUsage = (f.usage ?? '').trim();
        final matchesPrimary = currentUsage == primaryUsage;
        final matchesSecondary =
            secondaryUsage != null && secondaryUsage.isNotEmpty
                ? currentUsage == secondaryUsage
                : false;
        return matchesPrimary || matchesSecondary;
      })
      .map((f) => f.id)
      .toSet();

  return currentLevelProjectFacilities
      .where((pf) => allowedFacilityIds.contains(pf.facilityId))
      .toList();
}

/// Optional: reads facility hierarchy config for a `'DELIVERY*'` target used as
/// dropdown code for the delivery team row.
String? getDeliveryTeamCodeFromFacilityHierarchy(
  PropertySchema fieldSchema,
  String transactionType,
) {
  final hierarchyValidation = fieldSchema.validations?.firstWhere(
    (v) => v.type == 'facilityHierarchy',
    orElse: () => const ValidationRule(type: ''),
  );

  if (hierarchyValidation == null || hierarchyValidation.type.isEmpty) {
    return null;
  }

  final value = hierarchyValidation.value;
  if (value is! Map) return null;

  final hierarchyMapping = value['hierarchyMapping'];
  if (hierarchyMapping is! Map) return null;

  final isReceipt = transactionType == 'RECEIVED' ||
      transactionType == 'RECEIPT' ||
      transactionType == 'RETURNED';
  final directionKey = isReceipt ? 'forReceipt' : 'forIssue';

  for (final entry in hierarchyMapping.entries) {
    final directions = entry.value;
    if (directions is Map && directions.containsKey(directionKey)) {
      final targets = directions[directionKey];
      if (targets is List) {
        for (final target in targets) {
          if (target is String && target.startsWith('DELIVERY')) {
            return target;
          }
        }
      }
    }
  }

  return null;
}
