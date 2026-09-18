import 'package:digit_ui_components/constants/AppView.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/TextTheme/digit_text_theme.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:flutter/material.dart';

/// Definition for a single [CustomDataTable] column.
class CustomTableColumn {
  final String header;

  const CustomTableColumn({
    required this.header,
  });
}

/// A single row of cell values, in the same order as [CustomDataTable.columns].
class CustomTableRow {
  final List<String> values;

  const CustomTableRow(this.values);
}

/// Lightweight bordered data table used in place of `DigitTable` where its
/// fixed-height header clips long column titles instead of wrapping them.
/// Column widths mirror `DigitTable`'s default text-column sizing so the UI
/// is unchanged; headers wrap onto multiple lines instead of overflowing,
/// and the table scrolls independently both horizontally and vertically.
class CustomDataTable extends StatelessWidget {
  final List<CustomTableColumn> columns;
  final List<CustomTableRow> rows;
  final bool enableBorder;
  final double maxBodyHeight;

  const CustomDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.enableBorder = true,
    this.maxBodyHeight = 420,
  });

  double _columnWidth(Size screenSize) {
    if (AppView.isMobileView(screenSize)) return 140;
    if (AppView.isTabletView(screenSize)) return 170;
    return 202;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);
    final dividerColor = theme.colorTheme.generic.divider;
    final columnWidth = _columnWidth(MediaQuery.of(context).size);
    final tableWidth = columnWidth * columns.length;
    // Container reserves the border thickness as implicit padding, shrinking
    // the space available to the Row inside it — pad the outer width to
    // compensate, otherwise the Row overflows by the border's total width.
    final outerBorderWidth = enableBorder ? 2.0 : 0.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        width: tableWidth + outerBorderWidth,
        decoration: BoxDecoration(
          border: enableBorder ? Border.all(color: dividerColor) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderRow(context, textTheme, dividerColor, columnWidth),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxBodyHeight),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var i = 0; i < rows.length; i++)
                      _buildDataRow(
                        context,
                        textTheme,
                        dividerColor,
                        columnWidth,
                        rows[i],
                        showBottomBorder: i != rows.length - 1,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow(
    BuildContext context,
    DigitTextTheme textTheme,
    Color dividerColor,
    double columnWidth,
  ) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: const DigitColors().light.genericBackground,
        border: Border(bottom: BorderSide(color: dividerColor)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: columns
              .map((column) => Container(
                    width: columnWidth,
                    padding: const EdgeInsets.symmetric(
                      horizontal: spacer3,
                      vertical: spacer3,
                    ),
                    child: Text(
                      column.header,
                      softWrap: true,
                      style: textTheme.headingS.copyWith(
                        color: theme.colorTheme.primary.primary2,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildDataRow(
    BuildContext context,
    DigitTextTheme textTheme,
    Color dividerColor,
    double columnWidth,
    CustomTableRow row, {
    required bool showBottomBorder,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorTheme.paper.primary,
        border: showBottomBorder
            ? Border(bottom: BorderSide(color: dividerColor))
            : null,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < columns.length; i++)
              Container(
                width: columnWidth,
                padding: const EdgeInsets.symmetric(
                  horizontal: spacer3,
                  vertical: spacer3,
                ),
                child: Text(
                  i < row.values.length ? row.values[i] : '',
                  softWrap: true,
                  style: textTheme.bodyS.copyWith(
                    color: theme.colorTheme.text.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
