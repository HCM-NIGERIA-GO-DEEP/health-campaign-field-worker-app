import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:flutter/material.dart';

class CustomSummaryTable extends StatelessWidget {
  const CustomSummaryTable({
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
    const cellPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 14);

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

    final normalizedRows = rows.map((cells) {
      if (cells.length == headers.length) return cells;
      if (cells.length > headers.length) {
        return cells.take(headers.length).toList();
      }
      return <String>[
        ...cells,
        ...List<String>.filled(headers.length - cells.length, '--'),
      ];
    }).toList();

    final table = Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      border: TableBorder.all(color: borderColor),
      children: [
        TableRow(
          decoration: BoxDecoration(color: headerBg),
          children: headers.map((h) => cellText(h)).toList(),
        ),
        ...normalizedRows.map(
          (cells) => TableRow(
            children: cells.map(cellText).toList(),
          ),
        ),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 360,
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            primary: false,
            physics: const ClampingScrollPhysics(),
            child: SingleChildScrollView(
              primary: false,
              physics: const ClampingScrollPhysics(),
              child: table,
            ),
          ),
        ),
      ),
    );
  }
}