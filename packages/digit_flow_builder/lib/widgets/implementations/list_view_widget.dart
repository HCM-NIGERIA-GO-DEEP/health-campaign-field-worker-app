import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/theme/spacers.dart';
import 'package:flutter/material.dart';

import '../../action_handler/action_config.dart';
import '../../layout_renderer.dart';
import '../../utils/interpolation.dart';
import '../../widget_registry.dart';
import '../resolved_flow_widget.dart';

class ListViewWidget extends ResolvedFlowWidget {
  @override
  String get format => 'listView';

  @override
  Widget buildResolved(
    Map<String, dynamic> json,
    BuildContext context,
    void Function(ActionConfig) onAction,
    ResolvedWidgetContext resolved,
  ) {
    final stateData = resolved.stateData;
    final items = resolveItems(
      json,
      resolved.state.contextData,
      resolved.state.itemData,
    );

    if (items == null || (items is List && items.isEmpty)) {
      return const SizedBox.shrink();
    }

    // Read spacing property (e.g., "spacer4")
    final properties = json['properties'] as Map<String, dynamic>?;
    final spacingKey = properties?['spacing']?.toString();
    final double spacing = mapSpacingValue(context, spacingKey);

    final itemCount = (items as List).length;
    final widgets = <Widget>[];

    for (int index = 0; index < itemCount; index++) {
      final child = buildListItem(
        json: json,
        items: items,
        index: index,
        itemCount: itemCount,
        stateData: stateData,
        context: context,
        onAction: onAction,
        screenKey: resolved.screenKey,
        compositeKey: resolved.compositeKey,
        spacing: spacing,
      );
      if (child == null) continue;
      widgets.add(child);
    }

    if (widgets.isEmpty) return const SizedBox.shrink();

    return Column(children: widgets);
  }

  /// Resolves the list of items a `listView` node should render, honoring
  /// the same `dataSource` semantics used by [buildResolved]:
  /// - null/absent: use [rawState] itself (one row per search result)
  /// - `item.<path>`: a nested field on the current (ambient) list item
  /// - `<key>`: a field on `rawState[0]` (grouped-wrapper shapes, e.g.
  ///   `groupByType: true`, where `rawState[0]` is `{<entityType>: [...]}`)
  ///
  /// Shared by the eager (non-paginated, in-memory) rendering path in
  /// [buildResolved] and the lazy sliver path built directly by
  /// `LayoutRendererPageState` for paginated, top-level search-result lists.
  static dynamic resolveItems(
    Map<String, dynamic> json,
    List<dynamic>? rawState,
    Map<String, dynamic>? itemData,
  ) {
    final dataSourceKey = json['dataSource'] as String?;
    final safeRawState = rawState ?? [];
    dynamic items = safeRawState;

    if (dataSourceKey != null && safeRawState.isNotEmpty) {
      if (dataSourceKey.startsWith('item.')) {
        final fieldPath = dataSourceKey.substring(5);
        items = itemData != null
            ? _resolveNestedFieldStatic(itemData, fieldPath)
            : [];
      } else {
        items = safeRawState[0]?[dataSourceKey];
      }
    }

    return items;
  }

  /// Builds one row of a `listView`: the mapped item widget plus the
  /// inter-item spacer, wrapped in the [CrudItemContext] the row needs to
  /// resolve `{{item.*}}` templates and actions. Returns null for rows that
  /// resolve to nothing visible (mirrors the eager path's `continue`).
  static Widget? buildListItem({
    required Map<String, dynamic> json,
    required dynamic items,
    required int index,
    required int itemCount,
    required CrudStateData? stateData,
    required BuildContext context,
    required void Function(ActionConfig) onAction,
    required String? screenKey,
    required String? compositeKey,
    required double spacing,
  }) {
    final item = items[index];
    Map<String, dynamic> safeItem;

    if (item is Map) {
      safeItem = Map<String, dynamic>.from(
        item.map((k, v) => MapEntry(k.toString(), v)),
      );
    } else if (item is EntityModel) {
      safeItem = item.toMap();
    } else {
      safeItem = <String, dynamic>{};
    }

    final childJson = Map<String, dynamic>.from(json['child'] as Map);
    final processedChild = preprocessConfigWithState(
      childJson,
      stateData!,
      listIndex: index,
      item: safeItem,
    );

    final mappedChild = LayoutMapper.map(
      processedChild,
      stateData,
      context,
      onAction,
      item: safeItem,
      listIndex: index,
      screenKey: screenKey,
      compositeKey: compositeKey,
    );

    if (mappedChild is SizedBox &&
        mappedChild.width == 0.0 &&
        mappedChild.height == 0.0) {
      return null;
    }

    // Add spacing below each item except the last
    return CrudItemContext(
      stateData: stateData,
      listIndex: index,
      item: safeItem,
      screenKey: screenKey,
      compositeKey: compositeKey,
      child: Column(
        children: [
          mappedChild,
          if (index < itemCount - 1 && spacing > 0) SizedBox(height: spacing),
        ],
      ),
    );
  }

  // Map your "spacer" keywords to actual pixel values
  static double mapSpacingValue(BuildContext context, String? key) {
    switch (key) {
      case 'spacer1':
        return spacer1;
      case 'spacer2':
        return spacer2;
      case 'spacer3':
        return spacer3;
      case 'spacer4':
        return spacer4;
      case 'spacer5':
        return spacer5;
      case 'spacer6':
        return spacer6;
      case 'spacer7':
        return spacer7;
      case 'spacer8':
        return spacer8;
      default:
        return 0.0;
    }
  }

  static dynamic _resolveNestedFieldStatic(
      Map<String, dynamic> item, String fieldPath) {
    final parts = fieldPath.split('.');
    dynamic current = item;

    for (final part in parts) {
      if (current == null) return null;
      if (current is Map) {
        current = current[part];
      } else if (current is EntityModel) {
        try {
          current = current.toMap()[part];
        } catch (_) {
          return null;
        }
      } else {
        return null;
      }
    }
    return current;
  }
}
