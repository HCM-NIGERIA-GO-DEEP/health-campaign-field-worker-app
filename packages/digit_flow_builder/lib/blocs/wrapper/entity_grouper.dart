import 'package:digit_data_model/data_model.dart';
import 'package:flutter/cupertino.dart';

import 'value_resolver.dart';

/// Groups entities by their runtime type or by custom field values.
class EntityGrouper {
  final IValueResolver _resolver;

  EntityGrouper(this._resolver);

  /// Groups a list of entities by their runtime type name.
  Map<String, List<dynamic>> groupEntitiesByType(List<EntityModel> entities) {
    final map = <String, List<dynamic>>{};
    for (final entity in entities) {
      final typeName = entity.runtimeType.toString();
      map.putIfAbsent(typeName, () => []).add(entity);
    }
    return map;
  }

  /// Groups a list of entities by a custom field path
  /// (e.g., "additionalFields.fields.mrnNumber").
  /// Returns a list of group objects:
  /// [{"groupKey": "value1", "items": [entity1, entity2]}, ...]
  ///
  /// [fallbackFieldPath] is resolved only for entities where [fieldPath] is
  /// null, and gives those entities a real, stable group key instead of a
  /// synthetic 'null_N'. Stock created from the web (Commodity Management)
  /// carries no mrnNumber, so grouping incoming transactions on MRN alone put
  /// every such row in its own 'null_0', 'null_1', ... group - a key that
  /// exists nowhere in the data, so the drilldown's
  /// "additionalFields contains <groupKey>" search could never match it and
  /// the details screen came up empty. Falling back to clientReferenceId
  /// keeps the key groupable AND searchable.
  List<Map<String, dynamic>> groupEntitiesByCustomField(
    List<dynamic> entities,
    String fieldPath, {
    String? fallbackFieldPath,
  }) {
    final Map<String, List<dynamic>> groupedByField = {};
    int nullCounter = 0;
    // Probe only - counts how many entities had no value at fieldPath. For
    // "additionalFields.fields.mrnNumber" a non-zero unresolved count is a
    // web/Commodity-Management created transaction that carries no MRN: each
    // one lands in its own 'null_N' group and the card renders "MRN null_0".
    int unresolved = 0;
    int usedFallback = 0;
    int threw = 0;

    for (final entity in entities) {
      try {
        // Resolve the field value for this entity
        var fieldValue = _resolver.resolveValue(fieldPath, entity, {});

        if (fieldValue == null) {
          unresolved++;
          if (fallbackFieldPath != null) {
            fieldValue = _resolver.resolveValue(fallbackFieldPath, entity, {});
            if (fieldValue != null) usedFallback++;
          }
        }

        // Create unique keys for null values instead of grouping them together
        final groupKey = fieldValue?.toString() ?? 'null_${nullCounter++}';

        groupedByField.putIfAbsent(groupKey, () => []).add(entity);
      } catch (e) {
        debugPrint('Error grouping entity by field $fieldPath: $e');
        threw++;
        // Put ungroupable entities in unique 'null' groups
        groupedByField
            .putIfAbsent('null_${nullCounter++}', () => [])
            .add(entity);
      }
    }

    debugPrint('SLDBG|groupBy|path=$fieldPath'
        '|fallback=${fallbackFieldPath ?? "none"}'
        '|entities=${entities.length}'
        '|groups=${groupedByField.length}'
        '|unresolved=$unresolved'
        '|usedFallback=$usedFallback'
        '|threw=$threw'
        '|keys=${groupedByField.keys.take(12).toList()}');

    // Convert to list of group objects with groupKey and items
    final result = <Map<String, dynamic>>[];
    for (final entry in groupedByField.entries) {
      result.add({
        'groupKey': entry.key,
        'items': entry.value,
      });
    }

    return result;
  }
}
