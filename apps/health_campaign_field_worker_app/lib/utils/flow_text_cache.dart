/// The config-driven flows (flow builder, forms engine) translate from an
/// in-memory copy of the texts, not from the local database. That copy is
/// refreshed only when a text load finishes, so texts can be in the database
/// while a flow still shows their raw keys.
///
/// Returns true when [stored] (code -> message rows read from the database)
/// holds a text that [translate] does not return yet. A row with a blank
/// message, or whose message equals its code, cannot be told apart from a
/// missing one and is skipped.
bool flowTextsAreStale({
  required Iterable<MapEntry<String, String>> stored,
  required String Function(String code) translate,
}) {
  for (final row in stored) {
    final code = row.key;
    final message = row.value;
    if (message.trim().isEmpty || message == code) continue;
    if (translate(code) == code) return true;
  }
  return false;
}
