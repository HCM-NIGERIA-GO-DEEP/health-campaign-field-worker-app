import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:flutter/material.dart';

import '../../action_handler/action_config.dart';
import '../../blocs/flow_crud_bloc.dart';
import '../../utils/conditional_evaluator.dart';
import '../../utils/utils.dart';
import '../localization_context.dart';
import '../resolved_flow_widget.dart';

/// Flow-config table: avoids [DigitTable]'s nested vertical scroll views
/// (vertical [SingleChildScrollView] + [ListView]), which conflict with the
/// template page [CustomScrollView] and produce blank/white gaps when scrolling.
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

    final compositeKey = resolved.compositeKey ?? resolved.screenKey;

    final navigationParams = compositeKey != null
        ? FlowCrudStateRegistry().getNavigationParams(compositeKey) ?? {}
        : <String, dynamic>{};

    final evalContext = {
      ...resolved.evalContext,
      'navigation': navigationParams,
      'currentItem': resolved.state.itemData,
    };

    final visible = ConditionalEvaluator.evaluate(
      json['visible'] ?? true,
      evalContext,
      screenKey: resolved.screenKey,
    );

    if (visible == false) {
      return const SizedBox.shrink();
    }

    final data = Map<String, dynamic>.from(json['data'] ?? {});
    final rawColumns = (data['columns'] as List<dynamic>?) ?? [];

    final List<String> headerLabels = rawColumns
        .where((col) => col['isActive'] != false)
        .map<String>((col) {
      final headerTemplate = col['header']?.toString() ?? '';
      final resolvedHeader = resolveTemplate(headerTemplate, evalContext,
          screenKey: resolved.screenKey);
      final label = localization?.translate(resolvedHeader) ?? resolvedHeader;
      return label.toString();
    }).toList();

    List<dynamic> sourceList = [];
    final dataSourceKey = data['rows'] ?? data['source'];

    if (dataSourceKey != null) {
      final rowsKey = dataSourceKey.toString();
      String cleanKey = rowsKey;
      if (rowsKey.startsWith('{{') && rowsKey.endsWith('}}')) {
        cleanKey = rowsKey.substring(2, rowsKey.length - 2).trim();
      }

      if (cleanKey.startsWith('singleton')) {
        final resolvedSource = resolveValueRaw('{{ $cleanKey }}', null,
            screenKey: resolved.screenKey);
        if (resolvedSource is List) {
          sourceList = resolvedSource;
        } else if (resolvedSource != null) {
          sourceList = [resolvedSource];
        }
      } else if (resolved.state.itemData != null &&
          (resolved.state.itemData?[cleanKey] != null)) {
        final localSource = resolveValueRaw(
            '{{ $cleanKey }}', resolved.state.itemData,
            screenKey: resolved.screenKey);
        if (localSource is List) {
          sourceList = localSource;
        } else if (localSource != null) {
          sourceList = [localSource];
        }
      } else if (stateData?.modelMap != null &&
          stateData!.modelMap.containsKey(cleanKey)) {
        final localSource = stateData.modelMap[cleanKey];
        if (localSource is List) {
          sourceList = List<dynamic>.from(localSource as List);
        }
      } else if (stateData != null) {
        final localSource =
            resolveValueRaw(rowsKey, evalContext, screenKey: resolved.screenKey);
        if (localSource is List) {
          sourceList = localSource;
        } else if (localSource != null) {
          sourceList = [localSource];
        }
      }
    }

    if (sourceList.isEmpty) return const SizedBox.shrink();

    final activeColumns =
        rawColumns.where((col) => col['isActive'] != false).toList();

    final List<List<String>> rowTexts = sourceList.map<List<String>>((rowItem) {
      final cellEvalContext = {
        ...evalContext,
        'item': rowItem,
        'itemData': rowItem is Map<String, dynamic> ? rowItem : null,
      };

      return activeColumns.map<String>((colConfig) {
        final rawCellValue = colConfig['cellValue'] is String
            ? resolveStaticString(colConfig['cellValue'], localization)
            : colConfig['cellValue'];

        final cellValue = ConditionalEvaluator.evaluate(
          rawCellValue,
          cellEvalContext,
          screenKey: resolved.screenKey,
          stateData: stateData,
        );

        final finalText = cellValue?.toString() ?? '';
        final displayText = finalText != 'null'
            ? (localization?.translate(finalText) ?? finalText).toString()
            : '--';
        return displayText;
      }).toList();
    }).toList();

    return _FlowTemplateTable(
      headers: headerLabels,
      rows: rowTexts,
    );
  }
}

class _FlowTemplateTable extends StatelessWidget {
  const _FlowTemplateTable({
    required this.headers,
    required this.rows,
  });

  final List<String> headers;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorTheme.generic.divider;
    final headerBg = theme.colorTheme.paper.secondary;
    final cellPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 14);

    Widget cellText(String text) {
      return Padding(
        padding: cellPadding,
        child: Text(
          text,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            primary: false,
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                border: TableBorder.all(color: borderColor),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: headerBg),
                    children:
                        headers.map((h) => cellText(h)).toList(),
                  ),
                  ...rows.map(
                    (cells) => TableRow(
                      children: cells.map(cellText).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
