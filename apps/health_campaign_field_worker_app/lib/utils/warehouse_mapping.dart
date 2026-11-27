// Facility options from the MDMS HCM.WAREHOUSE_MAPPING master.
//
// A regional warehouse serves a group of district warehouses that is not a
// boundary level, so the parent/child tags derived from the boundary tree
// cannot describe it. The master lists, per warehouse facility id, the
// facility ids it issues to.
//
// Import-free on purpose (like parent_facility_resolver.dart) so it can be
// unit tested without Isar or a BuildContext. Nothing here throws.

/// Which side of the mapping a facility dropdown shows.
enum WarehouseMappingSide {
  /// The warehouses the user issues to.
  children,

  /// The warehouse the user receives from and returns to.
  parent,
}

/// The side a stock-form facility field shows, or null when the field shows
/// the user's own facility (or a delivery team) and the mapping has no say.
///
/// Mirrors the branch order of the facilityLevel filter in
/// custom_facility_widgets.dart: return and loss/excess flows first, then the
/// transaction type.
WarehouseMappingSide? warehouseMappingSide({
  required bool isToField,
  required bool isFromField,
  required bool isReturnOrLessExcessFlow,
  required String transactionType,
  required String upwardLevel,
}) {
  // A distributor without the warehouse role answers to a warehouse on its
  // own boundary ('current'), which the mapping does not describe.
  final upward = upwardLevel == 'parent' ? WarehouseMappingSide.parent : null;

  if (isReturnOrLessExcessFlow) return isToField ? upward : null;
  if (transactionType == 'DISPATCHED' || transactionType == 'ISSUED') {
    return isToField ? WarehouseMappingSide.children : null;
  }
  if (transactionType == 'RECEIVED' || transactionType == 'RECEIPT') {
    return isFromField ? upward : null;
  }
  return null;
}

/// Facility ids to offer for [side], or null when no mapping entry names any
/// of [currentFacilityIds] - the caller then keeps its existing list.
///
/// [mapping] is warehouse facility id -> the facility ids it issues to.
List<String>? mappedFacilityIds({
  required Map<String, List<String>> mapping,
  required Iterable<String> currentFacilityIds,
  required WarehouseMappingSide side,
}) {
  final current = currentFacilityIds.toSet();
  final result = <String>{};

  for (final entry in mapping.entries) {
    if (side == WarehouseMappingSide.children) {
      if (current.contains(entry.key)) result.addAll(entry.value);
    } else if (entry.value.any(current.contains)) {
      result.add(entry.key);
    }
  }

  result.removeWhere((id) => id.trim().isEmpty);
  // An entry with an empty list counts as no entry: an empty "Deliver to"
  // would otherwise read as "lowest level" and offer the delivery team.
  return result.isEmpty ? null : result.toList();
}
