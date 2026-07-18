import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/atoms/table_cell.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:digit_ui_components/widgets/molecules/digit_table.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/backup/summary_report_data.dart';
import '../../../router/app_router.dart';
import '../../../utils/i18_key_constants.dart' as i18;
import '../../../widgets/header/back_navigation_help_header.dart';
import '../../../widgets/localized.dart';

@RoutePage()
class SummaryReportPage extends LocalizedStatefulWidget {
  const SummaryReportPage({super.key});

  @override
  State<SummaryReportPage> createState() => _SummaryReportPageState();
}

class _SummaryReportPageState extends LocalizedState<SummaryReportPage> {
  List<SummaryReportRow> _reportRows = [];
  List<ProductVariantModel> _productVariants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final result = await SummaryReportData.loadMergedRows(context);

      if (mounted) {
        setState(() {
          _reportRows = result.rows;
          _productVariants = result.productVariants;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDisplayDate(String dateStr) {
    final dt = DateTime.parse(dateStr);
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

    // Build columns: base columns + per-product stock columns
    final columns = <DigitTableColumn>[
      DigitTableColumn(
        header: localizations.translate(i18.summaryReport.dateColumn),
        cellValue: 'date',
      ),
      DigitTableColumn(
        header: localizations.translate(i18.summaryReport.householdsRegistered),
        cellValue: 'hhRegistered',
      ),
      DigitTableColumn(
        header: localizations.translate(i18.summaryReport.childrenTreated),
        cellValue: 'childrenTreated',
      ),
      DigitTableColumn(
        header:
            localizations.translate(i18.summaryReport.childrenTreatedPercent),
        cellValue: 'childrenTreatedPercent',
      ),
    ];

    // Add stock columns per product variant
    for (final pv in _productVariants) {
      final name = localizations.translate(pv.sku ?? pv.id);
      columns.addAll([
        DigitTableColumn(
          header:
              '${localizations.translate(i18.summaryReport.stockReceived)} ($name)',
          cellValue: 'received_${pv.id}',
        ),
        DigitTableColumn(
          header:
              '${localizations.translate(i18.summaryReport.stockConsumed)} ($name)',
          cellValue: 'consumed_${pv.id}',
        ),
        DigitTableColumn(
          header:
              '${localizations.translate(i18.summaryReport.stockReturned)} ($name)',
          cellValue: 'returned_${pv.id}',
        ),
        DigitTableColumn(
          header:
              '${localizations.translate(i18.summaryReport.stockBalance)} ($name)',
          cellValue: 'balance_${pv.id}',
        ),
      ]);
    }

    // Build rows
    final rows = _reportRows.map((row) {
      final cells = <DigitTableData>[
        DigitTableData(
          _formatDisplayDate(row.date),
          cellKey: 'date',
        ),
        DigitTableData(
          row.householdsRegistered.toString(),
          cellKey: 'hhRegistered',
        ),
        DigitTableData(
          row.childrenTreated.toString(),
          cellKey: 'childrenTreated',
        ),
        DigitTableData(
          '${row.childrenTreatedPercent.toStringAsFixed(1)}%',
          cellKey: 'childrenTreatedPercent',
        ),
      ];

      // Add stock cells per product variant
      for (final pv in _productVariants) {
        final data = row.stockData[pv.id];
        cells.addAll([
          DigitTableData(
            (data?.received ?? 0).toStringAsFixed(0),
            cellKey: 'received_${pv.id}',
          ),
          DigitTableData(
            (data?.consumed ?? 0).toStringAsFixed(0),
            cellKey: 'consumed_${pv.id}',
          ),
          DigitTableData(
            (data?.returned ?? 0).toStringAsFixed(0),
            cellKey: 'returned_${pv.id}',
          ),
          DigitTableData(
            (data?.balance ?? 0).toStringAsFixed(0),
            cellKey: 'balance_${pv.id}',
          ),
        ]);
      }

      return DigitTableRow(tableRow: cells);
    }).toList();

    return Scaffold(
      body: ScrollableContent(
        enableFixedDigitButton: true,
        header: BackNavigationHelpHeaderWidget(
          handleback: () {
            context.router.replaceAll([HomeRoute()]);
          },
        ),
        footer: DigitCard(
          margin: const EdgeInsets.only(top: spacer2),
          children: [
            DigitButton(
              mainAxisSize: MainAxisSize.max,
              label: localizations.translate(i18.summaryReport.backToHome),
              type: DigitButtonType.primary,
              size: DigitButtonSize.large,
              onPressed: () {
                context.router.replaceAll([HomeRoute()]);
              },
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(spacer2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                localizations.translate(i18.summaryReport.heading),
                style: textTheme.headingXl.copyWith(
                  color: theme.colorTheme.primary.primary2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: spacer2),
            child: Text(
              localizations.translate(i18.summaryReport.description),
              style: textTheme.bodyL,
            ),
          ),
          const SizedBox(height: spacer2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: spacer2),
            child: InfoCard(
              title: localizations.translate(i18.summaryReport.infoCardTitle),
              description: localizations
                  .translate(i18.summaryReport.infoCardDescription),
              type: InfoType.info,
            ),
          ),
          const SizedBox(height: spacer2),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_reportRows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(spacer4),
              child: Center(
                child: Text(
                  localizations.translate(i18.common.noResultsFound),
                  style: textTheme.bodyL,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: spacer2),
              child: DigitTable(
                enableBorder: true,
                showPagination: false,
                showSelectedState: false,
                columns: columns,
                rows: rows,
                tableHeight: 1000,
              ),
            ),
          const SizedBox(height: spacer2),
        ],
      ),
    );
  }
}
