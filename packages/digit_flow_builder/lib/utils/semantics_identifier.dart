/// Derives a stable semantics identifier for a config-driven widget.
///
/// The identifier is exposed to the Android accessibility tree as a
/// `resource-id` (via `Semantics(identifier:)`), giving UI tests a selector
/// that survives campaign label/localization changes because it is derived
/// from the config's own keys rather than displayed text.
///
/// Kept import-free so its unit tests compile independently of the rest of
/// the package.
///
/// Returns null when the widget has no stable key — pure layout nodes are
/// intentionally left without an identifier.
String? semanticsIdentifierFor(Map<String, dynamic> json, String? stateKey) {
  String? fieldKey;

  final dynamic rawKey = json['key'] ?? json['fieldName'];
  if (rawKey is String && rawKey.isNotEmpty) {
    fieldKey = rawKey;
  }

  // Buttons usually carry no key; their label localization CODE (not the
  // displayed text) is a stable fallback. Template labels ({{...}}) resolve
  // per item and are not stable, so they are rejected.
  if (fieldKey == null && json['format'] == 'button') {
    final dynamic label = json['label'];
    if (label is String && label.isNotEmpty && !label.contains('{{')) {
      fieldKey = label;
    }
  }

  if (fieldKey == null) {
    return null;
  }

  if (stateKey == null || stateKey.isEmpty) {
    return fieldKey;
  }

  return '${stateKey}_$fieldKey';
}
