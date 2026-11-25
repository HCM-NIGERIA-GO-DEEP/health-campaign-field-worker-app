// Import-free on purpose, so its tests compile on their own.

/// Whether a project address `boundaryType` is the Distribution Point level
/// (trimmed, case-insensitive, as boundary_selection.dart compares it).
bool isDistributionPointBoundaryType(String? boundaryType) =>
    boundaryType?.trim().toLowerCase() == 'distribution point';

/// Reads a project search response made with `includeDescendants=true`
/// (`{Project: [{..., descendants: [...]}]}`) and returns
/// {boundary code -> project id} for every Distribution Point descendant.
///
/// Descendants may be flat or nested under each other's `descendants`; both
/// are walked. Deleted entries and entries without an id or boundary are
/// skipped. A malformed response yields whatever could be read, never a throw.
Map<String, String> boundaryProjectIdsFromSearchResponse(dynamic responseData) {
  final result = <String, String>{};

  void walk(dynamic descendants) {
    if (descendants is! List) return;
    for (final descendant in descendants) {
      if (descendant is! Map) continue;
      final address = descendant['address'];
      final id = descendant['id'];
      if (descendant['isDeleted'] != true && address is Map && id is String) {
        final boundary = address['boundary'];
        final boundaryType = address['boundaryType'];
        if (boundary is String &&
            boundary.isNotEmpty &&
            id.isNotEmpty &&
            boundaryType is String &&
            isDistributionPointBoundaryType(boundaryType)) {
          result[boundary] = id;
        }
      }
      walk(descendant['descendants']);
    }
  }

  if (responseData is Map) {
    final projects = responseData['Project'];
    if (projects is List) {
      for (final project in projects) {
        if (project is Map) walk(project['descendants']);
      }
    }
  }
  return result;
}

/// The project a new ProjectBeneficiary belongs to: the project of the
/// nearest Distribution Point at or above the boundary being saved.
///
/// Candidates are [boundaryCode] first, then the codes of [materializedPath]
/// from the leaf upwards. Returns null when none of them is in
/// [boundaryProjectIds].
String? beneficiaryProjectIdFor({
  String? materializedPath,
  String? boundaryCode,
  required Map<String, String> boundaryProjectIds,
}) {
  if (boundaryProjectIds.isEmpty) return null;
  final candidates = [
    if (boundaryCode != null) boundaryCode,
    ...?materializedPath?.split('.').reversed,
  ];
  for (final code in candidates) {
    final projectId = boundaryProjectIds[code.trim()];
    if (projectId != null) return projectId;
  }
  return null;
}
