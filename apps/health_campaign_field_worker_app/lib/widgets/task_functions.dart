import 'package:digit_flow_builder/flow_builder.dart';
import 'package:digit_flow_builder/utils/function_registry.dart';

import '../utils/constants.dart';

/// Registers task-related functions to the FunctionRegistry.
/// Call this during app initialization.
void registerTaskFunctions() {
  bool _hasRole(String code) {
    final roles = FlowBuilderSingleton().userRoles;
    if (roles == null) return false;
    return roles.any((r) => r is Map && r['code']?.toString() == code);
  }

  String? _resolveUsageForCurrentUser() {
    final isWarehouseManager = _hasRole('WAREHOUSE_MANAGER');
    final isDistributor = _hasRole('DISTRIBUTOR');
    final isHealthFacilitySupervisor = _hasRole('HEALTH_FACILITY_SUPERVISOR');

    final boundaryLevel =
        FlowBuilderSingleton().selectedProject?.address?.boundaryType;

    String? usage;
    if (isWarehouseManager) {
      if (boundaryLevel == Constants.stateBoundaryLevel) {
        usage = Constants.stateFacility;
      } else if (boundaryLevel == Constants.lgaBoundaryLevel) {
        usage = Constants.districtFacility;
      } else {
        usage = Constants.dhFacility;
      }
    } else if (isDistributor) {
      usage = 'None';
    } else {
      usage = Constants.healthFacility;
    }

    if (isHealthFacilitySupervisor) {
      usage = Constants.healthFacility;
    }

    return usage;
  }

  String? _additionalFieldValue(Map<String, dynamic> entity, String key) {
    final additionalFields = entity['additionalFields'];
    dynamic fields;
    if (additionalFields is Map<String, dynamic>) {
      fields = additionalFields['fields'];
    } else if (additionalFields is Map) {
      fields = additionalFields['fields'];
    }

    if (fields is List) {
      for (final f in fields) {
        if (f is Map && f['key']?.toString() == key) {
          return f['value']?.toString();
        }
      }
    }
    return null;
  }

  /// Filters `ProjectFacilityModel` list to the current level and only those
  /// whose corresponding `FacilityModel.usage` matches the current user's usage.
  ///
  /// Usage in configs:
  /// `{{fn:filterProjectFacilitiesByUsage(ProjectFacilityModel, FacilityModel)}}`
  FunctionRegistry.register('filterProjectFacilitiesByUsage', (args, stateData) {
    if (args.length < 2) return <dynamic>[];

    final projectFacilities = args[0];
    final facilities = args[1];

    if (projectFacilities is! List || facilities is! List) return <dynamic>[];

    final usage = _resolveUsageForCurrentUser();
    final usageTrimmed = (usage ?? '').trim();

    // Keep only "current" level project facilities (matches StockBalanceCard)
    final currentLevelPfs = projectFacilities.where((pf) {
      if (pf is! Map) return false;
      final level = _additionalFieldValue(Map<String, dynamic>.from(pf), 'facilityLevel');
      return level == null || level == 'current';
    }).toList();

    if (usageTrimmed.isEmpty) return currentLevelPfs;

    // Build allowed facility IDs by usage from FacilityModel list
    final allowedFacilityIds = <String>{};
    for (final f in facilities) {
      if (f is! Map) continue;
      final id = f['id']?.toString();
      final currentUsage = (f['usage'] ?? '').toString().trim();
      if (id != null && id.isNotEmpty && currentUsage == usageTrimmed) {
        allowedFacilityIds.add(id);
      }
    }

    if (allowedFacilityIds.isEmpty) return <dynamic>[];

    return currentLevelPfs.where((pf) {
      if (pf is! Map) return false;
      final facilityId = pf['facilityId']?.toString();
      return facilityId != null && allowedFacilityIds.contains(facilityId);
    }).toList();
  });

  /// Gets the task completion date for a specific dose and cycle index.
  ///
  /// - **Arguments**:
  ///   - First argument: The dose index to find (e.g., 0, 1, 2)
  ///   - Second argument: The cycle index to find (e.g., 1, 2)
  ///   - Third argument (optional): Date format (default: 'dd MMM yyyy')
  /// - **Returns**: Formatted completion date if task exists, empty string otherwise.
  ///
  /// Example usage: {{fn:getTaskCompletionDate(currentItem.id, contextData.0.cycle)}}
  // FunctionRegistry.register('getTaskCompletionDate', (args, stateData) {
  //   if (args.isEmpty) return '';
  //
  //   final doseIndex = int.tryParse(args[0]?.toString() ?? '') ?? -1;
  //   if (doseIndex < 0) return '';
  //
  //   // Get cycleIndex from second argument (optional for backward compatibility)
  //   final cycleIndex =
  //       args.length > 1 ? int.tryParse(args[1]?.toString() ?? '') ?? -1 : -1;
  //
  //   final dateFormat =
  //       args.length > 2 ? args[2]?.toString() ?? 'dd MMM yyyy' : 'dd MMM yyyy';
  //
  //   // Get tasks from modelMap
  //   final tasks = stateData.modelMap['tasks'] as List? ?? [];
  //
  //   // Find task with matching doseIndex and cycleIndex in additionalFields
  //   for (final task in tasks) {
  //     if (task is! Map) continue;
  //
  //     // Get additionalFields.fields
  //     final additionalFields = task['additionalFields'];
  //     if (additionalFields == null) continue;
  //
  //     List? fields;
  //     if (additionalFields is Map) {
  //       fields = additionalFields['fields'] as List?;
  //     } else if (additionalFields is List) {
  //       fields = additionalFields;
  //     }
  //
  //     if (fields == null) continue;
  //
  //     // Find doseIndex and cycleIndex in fields
  //     int? taskDoseIndex;
  //     int? taskCycleIndex;
  //
  //     for (final field in fields) {
  //       if (field is Map) {
  //         if (field['key'] == 'doseIndex') {
  //           taskDoseIndex = int.tryParse(field['value']?.toString() ?? '');
  //         }
  //         if (field['key'] == 'cycleIndex') {
  //           taskCycleIndex = int.tryParse(field['value']?.toString() ?? '');
  //         }
  //       }
  //     }
  //
  //     // Check if dose matches, and cycle matches (if provided)
  //     final doseMatches = taskDoseIndex == doseIndex;
  //     final cycleMatches = cycleIndex < 0 || taskCycleIndex == cycleIndex;
  //
  //     if (doseMatches && cycleMatches) {
  //       // Found matching task, get createdTime
  //       final clientAuditDetails = task['clientAuditDetails'];
  //       if (clientAuditDetails is Map) {
  //         final createdTime = clientAuditDetails['createdTime'];
  //         if (createdTime != null) {
  //           try {
  //             final timestamp = createdTime is int
  //                 ? createdTime
  //                 : int.tryParse(createdTime.toString()) ?? 0;
  //             if (timestamp > 0) {
  //               final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  //               return DateFormat(dateFormat).format(date);
  //             }
  //           } catch (_) {
  //             return '';
  //           }
  //         }
  //       }
  //     }
  //   }
  //
  //   return '';
  // });
}
