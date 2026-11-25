// Resolves the "parent" facility for a user who has no boundary above them.
//
// Import-free on purpose, like boundary_relationship_matcher.dart: these are
// pure functions over plain config maps so they can be unit tested without
// SharedPreferences, Isar or a BuildContext.
//
// Why this exists
// ---------------
// "Receive from" (and Return/Loss/Damaged "Deliver to") only ever list project
// facilities tagged facilityLevel == 'parent'. That tag can only be produced
// from the FacilityMap in the ProjectFacility search response, keyed by a
// boundary type above the user's own. The national warehouse sits on Country,
// the root of the LIBERIA hierarchy, so no such boundary exists and the server
// cannot return one - the four upward-facing stock operations had no source to
// offer at all.
//
// For that case the source facility is identified by its `usage` instead of by
// a boundary level, declared in INVENTORY.json as
// hierarchyMapping.<boundaryType>.forReceipt.

/// True when [assignedBoundaryType] has nothing above it, i.e. the boundary
/// derivation found no parent level.
///
/// [boundaryTypes] is the positional `[parent, current, child]` list built for
/// the project-facility search. A parent was found only when its first entry
/// differs from the assigned type, so equality (or an absent/empty list) means
/// the user sits at the top of the hierarchy.
bool isTopLevelAssignment({
  required String? assignedBoundaryType,
  required List<String>? boundaryTypes,
}) {
  if (assignedBoundaryType == null || assignedBoundaryType.isEmpty) {
    return false;
  }
  if (boundaryTypes == null || boundaryTypes.isEmpty) return true;
  return boundaryTypes.first == assignedBoundaryType;
}

/// Facility `usage` values that count as the parent source for
/// [boundaryType], read from an INVENTORY flow config.
///
/// Walks every `facilityHierarchy` validation and collects
/// `hierarchyMapping[boundaryType].forReceipt`. Returns an empty list when the
/// config names nothing for that level, which is the normal case for every
/// level that does have a real boundary above it — those entries name a
/// boundary type, which matches no facility usage, so the caller resolves
/// nothing and behaviour is unchanged.
///
/// Deliberately tolerant: config shape drifts between environments and a
/// malformed entry must never block project selection.
List<String> parentFacilityUsages({
  required dynamic inventoryConfig,
  required String? boundaryType,
}) {
  if (boundaryType == null || boundaryType.isEmpty) return const [];

  final usages = <String>[];

  void visit(dynamic node) {
    if (node is Map) {
      if (node['type'] == 'facilityHierarchy') {
        final value = node['value'];
        if (value is Map) {
          final mapping = value['hierarchyMapping'];
          if (mapping is Map) {
            final level = mapping[boundaryType];
            if (level is Map) {
              final forReceipt = level['forReceipt'];
              if (forReceipt is List) {
                for (final entry in forReceipt) {
                  final name = entry?.toString().trim();
                  if (name != null && name.isNotEmpty && !usages.contains(name)) {
                    usages.add(name);
                  }
                }
              }
            }
          }
        }
      }
      for (final child in node.values) {
        visit(child);
      }
    } else if (node is List) {
      for (final child in node) {
        visit(child);
      }
    }
  }

  visit(inventoryConfig);
  return usages;
}
