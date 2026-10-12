/// Filter keys the proximity switch (ProximitySearchWidget) removes when it is
/// turned on.
///
/// SearchStateManager.getAllFilters merges every search group on a screen, so
/// a filter another search left behind (the name search's boundary and team
/// filters, the scanner's tag) joins every later proximity search until its
/// key is cleared. Turning proximity on already empties the name and ID search
/// boxes; this clears their filters too, plus any key the proximity action
/// lists in its config `filterKeys` (the same list its OFF branch clears).
///
/// Deliberately import-free so its unit tests compile standalone.
library;

/// The name / ID search keys proximity ON has always cleared.
const List<String> kProximityLinkedSearchFilterKeys = [
  'givenName,familyName',
  'identifierId',
];

/// [kProximityLinkedSearchFilterKeys] followed by every `filterKeys` entry on
/// the proximity [onActions], without duplicates. Malformed actions and blank
/// keys are skipped; never throws.
List<String> proximityEnableClearKeys(dynamic onActions) {
  final keys = <String>{...kProximityLinkedSearchFilterKeys};
  if (onActions is! List) return keys.toList();

  for (final action in onActions) {
    if (action is! Map) continue;
    final properties = action['properties'];
    if (properties is! Map) continue;
    final configured = properties['filterKeys'];
    if (configured is! List) continue;
    for (final item in configured) {
      final key = item?.toString();
      if (key != null && key.isNotEmpty) keys.add(key);
    }
  }
  return keys.toList();
}
