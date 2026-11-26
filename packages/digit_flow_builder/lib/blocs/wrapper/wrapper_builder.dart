import 'package:digit_data_model/data_model.dart';
import 'package:flutter/cupertino.dart';

import 'computed_field_processor.dart';
import 'computed_list_processor.dart';
import 'entity_field_accessor.dart';
import 'entity_filter.dart';
import 'entity_grouper.dart';
import 'field_evaluator.dart';
import 'value_resolver.dart';

/// Orchestrates the wrapper building process by delegating to
/// specialized single-responsibility classes.
class WrapperBuilder {
  final List<EntityModel> entities;
  final Map<String, dynamic> config;
  final String? screenKey;

  WrapperBuilder(this.entities, this.config, {this.screenKey});

  List<dynamic> build() {
    final List<dynamic> wrappers = [];
    // Clear entity toMap() cache at start of build
    EnhancedEntityFieldAccessor.clearCache();

    // Create specialized delegates
    final resolver = ValueResolver();
    final grouper = EntityGrouper(resolver);
    final filter = EntityFilter(resolver, screenKey: screenKey);
    final fieldEvaluator = FieldEvaluator(resolver);

    try {
      final entityMap = grouper.groupEntitiesByType(entities);
      final rootEntityType = config['rootEntity'];
      final groupByType = config['groupByType'] == true;
      final groupByField = config['groupBy'] as String?;

      if (groupByType) {
        // Return all entities grouped by type
        final Map<String, List<dynamic>> groupedEntities = {};
        for (final type in entityMap.keys) {
          final typeEntities = entityMap[type]!;

          // If groupBy field is specified, further group entities by that field
          if (groupByField != null) {
            groupedEntities[type] =
                grouper.groupEntitiesByCustomField(typeEntities, groupByField);
          } else {
            groupedEntities[type] = typeEntities;
          }
        }
        return groupedEntities.entries.map((e) => {e.key: e.value}).toList();
      }

      // Fallback: old behavior, return flat list for rootEntity
      final roots = entityMap[rootEntityType] ?? [];

      for (final root in roots) {
        if (!filter.passesFilters(root, entityMap, config)) continue;

        final wrapperData = <String, dynamic>{rootEntityType: root};

        // Steps 1 and 2 were the only unguarded work in this loop, so one
        // bad row took the whole list with it: the throw escaped to the
        // outer catch, which logs and returns `wrappers` as it stands -
        // silently dropping every item AFTER the bad one, not just that one.
        //
        // That is how a single consent-declined household stopped the search
        // list loading. Its card dereferences item.headIndividual.0.name.*,
        // and headIndividual is resolved household -> HouseholdMember ->
        // Individual; a placeholder missing that member link resolves empty,
        // and indexing .0 on it throws inside _buildRelations.
        //
        // Skip only the offending item. Keeping the half-built wrapper was
        // the alternative - it would leave the household visible in search -
        // but its card would then render unresolved {{...}} paths or throw
        // again in the widget layer, putting the same failure one level up.
        try {
          // 1. Build relations
          _buildRelations(root, wrapperData, entityMap, filter, resolver);

          // 2. Apply normal fields
          _applyFields(root, wrapperData, resolver);
        } catch (e, st) {
          debugPrint(
            'WrapperBuilder: skipped one $rootEntityType - relations/fields '
            'failed to build; the rest of the list is unaffected. $e\n$st',
          );
          continue;
        }

        // 3. Computed fields
        try {
          final computed = ComputedFieldProcessor.applyComputed(
            wrapperData,
            config,
            fieldEvaluator,
            resolver,
          );
          wrapperData.addAll(computed);
        } catch (e) {
          print(e.toString());
        }

        // 4. Computed list fields
        try {
          final computedList = ComputedListProcessor.applyComputedList(
            wrapperData,
            config,
          );
          wrapperData.addAll(computedList);
        } catch (e) {
          print(e.toString());
        }

        wrappers.add(wrapperData);
      }
    } catch (e, st) {
      debugPrint('WrapperBuilder.build error: $e\n$st');
    } finally {
      // Clear cache after build to free memory
      EnhancedEntityFieldAccessor.clearCache();
    }

    debugPrint(wrappers.toString());

    return wrappers;
  }

  /// Builds entity relations (including nested) for a root entity.
  void _buildRelations(
    dynamic root,
    Map<String, dynamic> wrapperData,
    Map<String, List<dynamic>> entityMap,
    EntityFilter filter,
    IValueResolver resolver,
  ) {
    for (final relation in config['relations'] ?? []) {
      final relatedEntities = filter.findRelatedEntities(
        root,
        relation,
        wrapperData,
        entityMap,
      );
      wrapperData[relation['name']] = relatedEntities;

      // Handle nested relations
      if (relation['relations'] != null) {
        for (int i = 0; i < relatedEntities.length; i++) {
          final entity = relatedEntities[i];
          final nestedData = <String, dynamic>{};

          for (final nestedRelation in relation['relations']) {
            final nestedEntities = filter.findRelatedEntities(
              entity,
              nestedRelation,
              {...wrapperData, ...nestedData},
              entityMap,
            );
            nestedData[nestedRelation['name']] = nestedEntities;
          }

          final relationItem = entity is Map
              ? <String, dynamic>{...entity, ...nestedData}
              : <String, dynamic>{'entity': entity, ...nestedData};

          final mappedFields =
              relation['mappedFields'] as Map<String, dynamic>?;
          if (mappedFields != null && mappedFields.isNotEmpty) {
            for (final entry in mappedFields.entries) {
              final source = entry.value;
              if (source is String) {
                relationItem[entry.key] = resolver.resolveValue(
                  source,
                  relationItem,
                  {...wrapperData, ...relationItem},
                );
              } else {
                relationItem[entry.key] = source;
              }
            }
          }

          relatedEntities[i] = relationItem;
        }
      }
    }
  }

  /// Applies normal field configurations to wrapperData.
  void _applyFields(
    dynamic root,
    Map<String, dynamic> wrapperData,
    IValueResolver resolver,
  ) {
    final fields = config['fields'] as Map<String, dynamic>? ?? {};
    for (final entry in fields.entries) {
      final valueConfig = entry.value;
      if (valueConfig is String) {
        wrapperData[entry.key] =
            resolver.resolveValue(valueConfig, root, wrapperData);
      } else if (valueConfig is Map<String, dynamic>) {
        final fieldEvaluator = FieldEvaluator(resolver);
        wrapperData[entry.key] =
            fieldEvaluator.evaluateFieldMap(valueConfig, root, wrapperData);
      } else {
        wrapperData[entry.key] = valueConfig;
      }
    }
  }
}
