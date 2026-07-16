import 'dart:convert';

import 'package:digit_ui_components/widgets/atoms/table_cell.dart';
import 'package:digit_ui_components/widgets/molecules/digit_table.dart';
import 'package:flutter/material.dart';

import '../../action_handler/action_config.dart';
import '../../blocs/flow_crud_bloc.dart';
import '../../utils/conditional_evaluator.dart';
import '../../utils/utils.dart';
import '../../widget_registry.dart';
import '../localization_context.dart';
import '../resolved_flow_widget.dart';

class TableWidget extends ResolvedFlowWidget {
  @override
  String get format => 'table';

  @override
  Widget buildResolved(
    Map<String, dynamic> json,
    BuildContext context,
    void Function(ActionConfig) onAction,
    ResolvedWidgetContext resolved,
  ) {
    final stateData = resolved.stateData;
    final localization = resolved.localization;

    // Use compositeKey for registry operations (includes instanceId for proper isolation)
    final compositeKey = resolved.compositeKey ?? resolved.screenKey;

    // Get navigation params for visibility evaluation
    final navigationParams = compositeKey != null
        ? FlowCrudStateRegistry().getNavigationParams(compositeKey) ?? {}
        : <String, dynamic>{};

    // Build evaluation context with navigation params
    final evalContext = {
      ...resolved.evalContext,
      'navigation': navigationParams,
      // Legacy support for existing templates
      'currentItem': resolved.state.itemData,
    };

    // Check visibility condition
    final visible = ConditionalEvaluator.evaluate(
      json['visible'] ?? true,
      evalContext,
      screenKey: resolved.screenKey,
    );

    if (visible == false) {
      return const SizedBox.shrink();
    }

    final data = Map<String, dynamic>.from(json['data'] ?? {});

    // Store raw column configuration for later evaluation
    final rawColumns = (data['columns'] as List<dynamic>?) ?? [];

    // Create column headers with resolved templates
    final columns =
        rawColumns.where((col) => col['isActive'] != false).map((col) {
      final cellValue = col['cellValue'];
      final headerTemplate = col['header']?.toString() ?? '';

      // Resolve header template using evalContext (supports {{formData.x}}, {{itemData.x}}, etc.)
      final resolvedHeader = resolveTemplate(headerTemplate, evalContext,
          screenKey: resolved.screenKey);

      return DigitTableColumn(
        header: localization?.translate(resolvedHeader) ?? resolvedHeader,
        cellValue: cellValue is String ? cellValue : jsonEncode(cellValue),
      );
    }).toList();

    // Step 1: Resolve data source from either 'rows' or 'source' (both should point to same data)
    List<dynamic> sourceList = [];

    // Prefer 'rows' if specified, fallback to 'source'
    final dataSourceKey = data['rows'] ?? data['source'];

    if (dataSourceKey != null) {
      final rowsKey = dataSourceKey.toString();

      // Strip {{ }} if present
      String cleanKey = rowsKey;
      if (rowsKey.startsWith('{{') && rowsKey.endsWith('}}')) {
        cleanKey = rowsKey.substring(2, rowsKey.length - 2).trim();
      }

      // Case 1: Singleton path
      if (cleanKey.startsWith("singleton")) {
        final resolvedSource = resolveValueRaw("{{ $cleanKey }}", null,
            screenKey: resolved.screenKey);
        if (resolvedSource is List) {
          sourceList = resolvedSource;
        } else if (resolvedSource != null) {
          sourceList = [resolvedSource];
        }
      }
      // Case 2: If the current item already has this source (table inside listView)
      else if (resolved.state.itemData != null &&
          (resolved.state.itemData?[cleanKey] != null)) {
        final localSource = resolveValueRaw(
            "{{ $cleanKey }}", resolved.state.itemData,
            screenKey: resolved.screenKey);
        if (localSource is List) {
          sourceList = localSource;
        } else if (localSource != null) {
          sourceList = [localSource];
        }
      }
      // Case 3: Try modelMap first for named entities like 'stock', 'productVariant'
      else if (stateData?.modelMap != null &&
          stateData!.modelMap.containsKey(cleanKey)) {
        final localSource = stateData.modelMap[cleanKey];
        if (localSource is List) {
          sourceList = List<dynamic>.from(localSource as List);
        }
      }
      // Case 4: Fallback to resolving from rawState
      else if (stateData != null) {
        final localSource = resolveValueRaw(rowsKey, evalContext,
            screenKey: resolved.screenKey);
        if (localSource is List) {
          sourceList = localSource;
        } else if (localSource != null) {
          sourceList = [localSource];
        }
      }
    }

    if (sourceList.isEmpty) return const SizedBox.shrink();

    final rows = sourceList.asMap().entries.map((entry) {
      final rowItem = entry.value;

      // Build evaluation context for cell values
      // Uses evalContext as base, with row-specific 'item' and 'itemData' override
      final cellEvalContext = {
        ...evalContext,
        'item': rowItem,
        'itemData':
            rowItem is Map<String, dynamic> ? rowItem : null // Legacy support
      };

      return DigitTableRow(
        tableRow: rawColumns.asMap().entries.map((entry) {
          final colIndex = entry.key;
          final colConfig = entry.value;

          // Get the raw cellValue configuration
          // Resolve static localization keys from cellValue (text without {{}})
          final rawCellValue = colConfig['cellValue'] is String
              ? resolveStaticString(colConfig['cellValue'], localization)
              : colConfig['cellValue'];

          final cellValue = ConditionalEvaluator.evaluate(
              rawCellValue, cellEvalContext,
              screenKey: resolved.screenKey, stateData: stateData);

          // cellValue should already be resolved by ConditionalEvaluator
          // Just convert to string
          final finalText = cellValue?.toString() ?? '';

          final displayText = finalText != "null"
              ? (localization?.translate(finalText) ?? finalText)
              : "--";

          return DigitTableData(
            displayText,
            cellKey: rawCellValue is Map
                ? 'conditional_$colIndex'
                : rawCellValue?.toString() ?? '',
            widget: Text(
              displayText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
      );
    }).toList();

    // Optional JSON props:
    //   "maxVisibleRows": int  — cap the table at this many rows; extras
    //                            scroll inside the card. When set, uses a
    //                            taller per-row height so maxLines:2 cells
    //                            don't silently overflow and steal gestures.
    //   "rowHeight": double    — override the per-row height (default 52 in
    //                            legacy mode, 80 in capped mode).
    final maxVisibleRows = (json['maxVisibleRows'] as num?)?.toInt();
    const double headerHeight = 64.0;

    if (maxVisibleRows != null && maxVisibleRows > 0) {
      final double rowHeight = (json['rowHeight'] as num?)?.toDouble() ?? 80.0;
      final int visibleRowCount =
          rows.length < maxVisibleRows ? rows.length : maxVisibleRows;
      final double tableHeight = visibleRowCount * rowHeight + headerHeight;

      return SizedBox(
        height: tableHeight,
        child: SingleChildScrollView(
          child: DigitTable(
            enableBorder: true,
            withRowDividers: false,
            withColumnDividers: false,
            showSelectedState: false,
            showPagination: false,
            columns: columns,
            rows: rows,
          ),
        ),
      );
    }

    final double rowHeight = (json['rowHeight'] as num?)?.toDouble() ?? 52.0;
    final double fixedHeight = rows.length * rowHeight + headerHeight;

    // Opt-in (per-config) path: when "fitToContent" is true on the table JSON,
    // make DigitTable actually FILL the fixed-height box with all its rows and
    // let the surrounding page own the scrolling — instead of the default
    // behaviour below, where DigitTable (tableHeight == null) caps its own body
    // at `MediaQuery.height - ~168` and scrolls the overflow in its own
    // ListView. That internal cap is what left the box taller than the drawn
    // table, producing the empty region the page could scroll into (the "blank
    // screen past the table end"). Passing tableHeight lifts the cap so all
    // rows render, and NeverScrollableScrollPhysics stops the inner ListView
    // from intercepting the page's scroll gesture.
    //
    // Gated behind a flag so existing flows keep the default behaviour exactly;
    // only configs that set "fitToContent": true (e.g. STOCKREPORTS) opt in.
    final fitToContent = json['fitToContent'] == true;
    if (fitToContent) {
      return SizedBox(
        height: fixedHeight,
        child: DigitTable(
          enableBorder: true,
          withRowDividers: false,
          withColumnDividers: false,
          showSelectedState: false,
          showPagination: false,
          tableHeight: fixedHeight,
          scrollPhysicsForPagination: const NeverScrollableScrollPhysics(),
          columns: columns,
          rows: rows,
        ),
      );
    }

    return SizedBox(
      height: fixedHeight,
      child: SingleChildScrollView(
        child: DigitTable(
          enableBorder: true,
          withRowDividers: false,
          withColumnDividers: false,
          showSelectedState: false,
          showPagination: false,
          columns: columns,
          rows: rows,
        ),
      ),
    );
  }
}
