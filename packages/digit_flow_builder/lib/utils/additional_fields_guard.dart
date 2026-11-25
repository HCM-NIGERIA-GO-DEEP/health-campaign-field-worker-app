/// No additional field is saved with a null or empty value.
///
/// The server rejects an additional field whose value is null (400 "must not
/// be null") and one rejected record stops the whole sync. CREATE_EVENT and
/// UPDATE_EVENT run every record through [dropEmptyAdditionalFields] before
/// it reaches a repository, so the rule does not depend on what built the
/// record. It covers `additionalFields: {fields: [{key, value}]}` on the
/// record and on records nested in it, for every model that has a factory.
library;

/// True for null and for text that is empty or only white space.
/// `0` and `false` are values.
bool isEmptyAdditionalValue(dynamic value) =>
    value == null || (value is String && value.trim().isEmpty);

final RegExp _wholeTemplate = RegExp(r'^\{\{[^{}]*\}\}$');

/// True when [value] is still a whole `{{...}}` template, i.e. a config value
/// that resolved to nothing. It is config text, not data to save.
bool isUnresolvedTemplate(dynamic value) =>
    value is String && _wholeTemplate.hasMatch(value.trim());

/// A copy of [entity] (an entity's `toMap()`) without the additional fields
/// whose value is null, empty, or still a whole `{{...}}` template (records
/// saved before 2026-11-26 can hold `{{navigation.firstName}}` as a value),
/// on the entity and on any record nested in it. Returns null when there is
/// nothing to drop, so callers can keep the entity they already have.
/// [entity] itself is never changed.
Map<String, dynamic>? dropEmptyAdditionalFields(Map<String, dynamic> entity) {
  var changed = false;

  dynamic clean(dynamic node) {
    if (node is List) return node.map(clean).toList();
    if (node is! Map) return node;

    final result = <String, dynamic>{};
    node.forEach((key, value) {
      final fields = key == 'additionalFields' && value is Map
          ? value['fields']
          : null;
      if (fields is List) {
        final kept = fields
            .where((f) => !(f is Map &&
                (isEmptyAdditionalValue(f['value']) ||
                    isUnresolvedTemplate(f['value']))))
            .toList();
        if (kept.length != fields.length) changed = true;
        result[key.toString()] = <String, dynamic>{
          for (final entry in (value as Map).entries)
            entry.key.toString(): entry.key == 'fields' ? kept : entry.value,
        };
      } else {
        result[key.toString()] = clean(value);
      }
    });
    return result;
  }

  final cleaned = clean(entity) as Map<String, dynamic>;
  return changed ? cleaned : null;
}
