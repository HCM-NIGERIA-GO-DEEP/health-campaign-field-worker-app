import 'package:digit_data_model/data/repositories/package_repository/local/household.dart';
import 'package:digit_data_model/data/repositories/package_repository/local/household_member.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:collection/collection.dart';
import 'package:digit_ui_components/widgets/atoms/table_cell.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:digit_ui_components/widgets/molecules/digit_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../models/entities/roles_type.dart';
import '../../../router/app_router.dart';
import '../../../utils/i18_key_constants.dart' as i18;
import '../../../utils/stock_calculation_utils.dart';
import '../../../utils/utils.dart';
import '../../../widgets/header/back_navigation_help_header.dart';
import '../../../widgets/localized.dart';

@RoutePage()
class SummaryReportPage extends LocalizedStatefulWidget {
  const SummaryReportPage({super.key});

  @override
  State<SummaryReportPage> createState() => _SummaryReportPageState();
}

class _SummaryReportPageState extends LocalizedState<SummaryReportPage> {
  List<_SummaryReportRow> _reportRows = [];
  List<ProductVariantModel> _productVariants = []; // ignore: prefer_final_fields
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userUuid = context.loggedInUserUuid;
      final projectId = context.projectId;

      // Repositories
      final householdRepo =
          context.read<LocalRepository<HouseholdModel, HouseholdSearchModel>>()
              as HouseholdLocalRepository;
      final taskRepo =
          context.read<LocalRepository<TaskModel, TaskSearchModel>>();
      final householdMemberRepo = context.read<
          LocalRepository<HouseholdMemberModel,
              HouseholdMemberSearchModel>>() as HouseholdMemberLocalRepository;
      final stockRepo =
          context.read<LocalRepository<StockModel, StockSearchModel>>();
      final projectResourceRepo = context.read<
          LocalRepository<ProjectResourceModel, ProjectResourceSearchModel>>();
      final productVariantRepo = context.read<
          LocalRepository<ProductVariantModel, ProductVariantSearchModel>>();
      final projectFacilityRepo = context.read<
          LocalRepository<ProjectFacilityModel, ProjectFacilitySearchModel>>();
      final facilityRepo =
          context.read<LocalRepository<FacilityModel, FacilitySearchModel>>();
      // Determine facility ID (same logic as stock_balance_card)
      final isDistributor = context.loggedInUserRoles
          .any((role) => role.code == RolesType.distributor.toValue());

      final projectFacilities = await projectFacilityRepo
          .search(ProjectFacilitySearchModel(projectId: [projectId]));

      final currentFacilities = projectFacilities.where((pf) {
        final facilityLevel = pf.additionalFields?.fields
            .where((f) => f.key == 'facilityLevel')
            .firstOrNull
            ?.value;
        return facilityLevel == null || facilityLevel == 'current';
      }).toList();

      final facilityIds = currentFacilities.map((pf) => pf.facilityId).toList();
      final facilities =
          await facilityRepo.search(FacilitySearchModel(id: facilityIds));

      // Match stock_balance_card: distributors always use userUuid
      final effectiveFacilityId = isDistributor
          ? userUuid
          : (facilities.isNotEmpty ? facilities.first.id : userUuid);

      // Fetch product variants
      final projectResources = await projectResourceRepo
          .search(ProjectResourceSearchModel(projectId: [projectId]));
      final productVariantIds = projectResources
          .map((pr) => pr.resource.productVariantId)
          .whereType<String>()
          .toSet()
          .toList();
      final productVariants = productVariantIds.isNotEmpty
          ? await productVariantRepo
              .search(ProductVariantSearchModel(id: productVariantIds))
          : <ProductVariantModel>[];

      // Fetch all data
      final households =
          await householdRepo.search(HouseholdSearchModel(), userUuid);
      final tasks = await taskRepo.search(TaskSearchModel(
        createdBy: userUuid,
        projectId: projectId,
      ));
      final householdMembers = await householdMemberRepo.search(
          HouseholdMemberSearchModel(), userUuid);

      // Fetch stock records (received + sent for facility)
      final receivedStocks = await stockRepo
          .search(StockSearchModel(receiverId: effectiveFacilityId));
      final sentStocks = await stockRepo
          .search(StockSearchModel(senderId: effectiveFacilityId));

      // Deduplicate stock records by clientReferenceId
      final allStocksMap = <String, StockModel>{};
      for (final stock in receivedStocks) {
        allStocksMap[stock.clientReferenceId] = stock;
      }
      for (final stock in sentStocks) {
        allStocksMap[stock.clientReferenceId] = stock;
      }
      final allStocks = allStocksMap.values.toList();

      // ── Group households by date (filter by logged-in user) ──
      final hhByDate = <String, int>{};
      for (final hh in households) {
        final createdBy =
            hh.clientAuditDetails?.createdBy ?? hh.auditDetails?.createdBy;
        if (createdBy != userUuid) continue;
        final epochMs =
            hh.clientAuditDetails?.createdTime ?? hh.auditDetails?.createdTime;
        if (epochMs == null) continue;
        final date = _epochToDateString(epochMs);
        hhByDate[date] = (hhByDate[date] ?? 0) + 1;
      }

      // ── Group tasks by date for children treated ──
      // (filter by logged-in user AND status == 'ADMINISTRATION_SUCCESS' or 'VISITED')
      final tasksByDate = <String, Set<String>>{};
      for (final task in tasks) {
        if (task.status != 'ADMINISTRATION_SUCCESS' &&
            task.status != 'VISITED') {
          continue;
        }
        final createdBy =
            task.clientAuditDetails?.createdBy ?? task.auditDetails?.createdBy;
        if (createdBy != userUuid) continue;
        final epochMs = task.clientAuditDetails?.createdTime ??
            task.auditDetails?.createdTime;
        if (epochMs == null) continue;
        final beneficiaryRef = task.projectBeneficiaryClientReferenceId;
        if (beneficiaryRef == null || beneficiaryRef.isEmpty) continue;
        final date = _epochToDateString(epochMs);
        tasksByDate.putIfAbsent(date, () => <String>{});
        tasksByDate[date]!.add(beneficiaryRef);
      }

      // ── Group non-head household members by date ──
      final nonHeadMembersByDate = <String, int>{};
      for (final member in householdMembers) {
        if (member.isHeadOfHousehold) continue;
        final createdBy = member.clientAuditDetails?.createdBy ??
            member.auditDetails?.createdBy;
        if (createdBy != userUuid) continue;
        final epochMs = member.clientAuditDetails?.createdTime ??
            member.auditDetails?.createdTime;
        if (epochMs == null) continue;
        final date = _epochToDateString(epochMs);
        nonHeadMembersByDate[date] = (nonHeadMembersByDate[date] ?? 0) + 1;
      }

      // ── Group stock consumed from task resources by date + productVariant ──
      // Only count tasks with status 'ADMINISTRATION_SUCCESS' or 'VISITED'
      // Key: "date|productVariantId" -> sum of quantity
      final consumedByDateProduct = <String, double>{};
      for (final task in tasks) {
        if (task.status != 'ADMINISTRATION_SUCCESS' &&
            task.status != 'VISITED') {
          continue;
        }
        final createdBy =
            task.clientAuditDetails?.createdBy ?? task.auditDetails?.createdBy;
        if (createdBy != userUuid) continue;
        final epochMs = task.clientAuditDetails?.createdTime ??
            task.auditDetails?.createdTime;
        if (epochMs == null) continue;
        final date = _epochToDateString(epochMs);
        final resources = task.resources;
        if (resources == null) continue;
        for (final res in resources) {
          final pvId = res.productVariantId;
          if (pvId == null || pvId.isEmpty) continue;
          final qty = double.tryParse(res.quantity ?? '0') ?? 0.0;
          final key = '$date|$pvId';
          consumedByDateProduct[key] =
              (consumedByDateProduct[key] ?? 0.0) + qty;
        }
      }

      // ── Build rows ─────────────────────────────────────────────────────────
      final allDates = <String>{
        ...hhByDate.keys,
        ...consumedByDateProduct.keys.map((k) => k.split('|')[0]),
      };

      final ageBuckets = <String, _DateBucket>{};

      for (final task in tasks) {
        if (task.status != 'ADMINISTRATION_SUCCESS' &&
            task.status != 'VISITED') {
          continue;
        }
        final createdBy =
            task.clientAuditDetails?.createdBy ?? task.auditDetails?.createdBy;
        if (createdBy != userUuid) continue;
        final epochMs = task.clientAuditDetails?.createdTime ??
            task.auditDetails?.createdTime;
        if (epochMs == null) continue;

        final fields = task.additionalFields?.fields ?? [];
        final ageMonths = int.tryParse(
                fields.firstWhereOrNull((f) => f.key == 'ageInMonths')
                        ?.value
                        ?.toString() ??
                    '') ??
            -1;
        if (ageMonths < 3 || ageMonths > 59) continue;

        final gender = fields
            .firstWhereOrNull((f) => f.key == 'gender')
            ?.value
            ?.toString();

        final date = _epochToDateString(epochMs);
        allDates.add(date);
        ageBuckets.putIfAbsent(date, () => _DateBucket()).add(ageMonths, gender);
      }

      final sortedDates = allDates.toList()..sort();

      // Track cumulative consumed per product variant (for balance)
      final cumulativeConsumed = <String, double>{};

      final rows = <_SummaryReportRow>[];
      for (final date in sortedDates) {
        final hhCount = hhByDate[date] ?? 0;
        final childrenCount = tasksByDate[date]?.length ?? 0;
        final nonHeadCount = nonHeadMembersByDate[date] ?? 0;
        final percentage =
            nonHeadCount > 0 ? (childrenCount / nonHeadCount) * 100 : 0.0;
        final bucket = ageBuckets[date] ?? _DateBucket();

        // End-of-day timestamp for cumulative stock filtering
        final endOfDay = DateTime.parse(date)
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1))
            .millisecondsSinceEpoch;

        // Filter all stocks up to and including this day
        // Stocks without timestamps are included (assumed historical)
        final cumulativeStocks = allStocks.where((stock) {
          final epochMs = stock.clientAuditDetails?.createdTime ??
              stock.auditDetails?.createdTime;
          if (epochMs == null) return true;
          return epochMs <= endOfDay;
        }).toList();

        // Per-product stock data
        final stockData = <String, _ProductStockData>{};
        for (final pv in productVariants) {
          // Cumulative received & returned using same logic as stock_balance_card
          final metrics = cumulativeStocks.isNotEmpty
              ? StockCalculationUtils.calculateStockMetrics(
                  stockList: cumulativeStocks,
                  facilityId: effectiveFacilityId,
                  productId: pv.id,
                  loggedInUserUuid: userUuid,
                  isDistributor: isDistributor,
                )
              : StockCalculationUtils.emptyMetrics;

          final totalReceived = metrics['stockReceived'] ?? 0.0;
          final totalReturned = metrics['stockReturned'] ?? 0.0;
          final totalWastage = metrics['stockWastage'] ?? 0.0;

          // Daily consumed (for this day only)
          final key = '$date|${pv.id}';
          final dailyConsumed = consumedByDateProduct[key] ?? 0.0;

          // Accumulate consumed for balance calculation
          cumulativeConsumed[pv.id] =
              (cumulativeConsumed[pv.id] ?? 0.0) + dailyConsumed;
          final totalConsumed = cumulativeConsumed[pv.id]!;

          final balance =
              totalReceived - totalConsumed - totalReturned - totalWastage;

          stockData[pv.id] = _ProductStockData(
            received: totalReceived,
            consumed: dailyConsumed,
            returned: totalReturned,
            balance: balance,
          );
        }

        rows.add(_SummaryReportRow(
          date: date,
          // Age/gender breakdown
          totalAll: bucket.totalAll,
          total3to11: bucket.total3to11,
          total12to59: bucket.total12to59,
          boysAll: bucket.boysAll,
          boys3to11: bucket.boys3to11,
          boys12to59: bucket.boys12to59,
          girlsAll: bucket.girlsAll,
          girls3to11: bucket.girls3to11,
          girls12to59: bucket.girls12to59,
          householdsRegistered: hhCount,
          childrenTreated: childrenCount,
          childrenTreatedPercent: percentage,
          stockData: stockData,
        ));
      }

      // Sort descending by date for display
      rows.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _reportRows = rows;
          // _productVariants = productVariants; // uncomment when re-enabling stock columns
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

  String _epochToDateString(int epochMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  String _formatDisplayDate(String dateStr) {
    final dt = DateTime.parse(dateStr);
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

    // Active columns — age/gender breakdown
    // To re-enable stock columns: uncomment the stock section below and add
    // per-product columns for received/consumed/returned/balance using _productVariants
    final columns = <DigitTableColumn>[
      DigitTableColumn(
        header: localizations.translate(i18.summaryReport.dateColumn),
        cellValue: 'date',
      ),
      DigitTableColumn(
        header: localizations.translate(i18.summaryReport.childrenAll),
        cellValue: 'totalAll',
        width: 500,
      ),
      DigitTableColumn(
        header: localizations.translate(i18.summaryReport.children3to11),
        cellValue: 'total3to11',
        width: 500,
      ),
      DigitTableColumn(
        header: localizations.translate(i18.summaryReport.children12to59),
        cellValue: 'total12to59',
        width: 500,
      ),
      DigitTableColumn(
        header: localizations.translate(i18.summaryReport.boysAll),
        cellValue: 'boysAll',
        width: 500,
      ),
      DigitTableColumn(
        header: localizations.translate(i18.summaryReport.boys3to11),
        cellValue: 'boys3to11',
        width: 500,
      ),
      DigitTableColumn(
        header: localizations.translate(i18.summaryReport.boys12to59),
        cellValue: 'boys12to59',
        width: 500,
      ),
      DigitTableColumn(
        header: localizations.translate(i18.summaryReport.girlsAll),
        cellValue: 'girlsAll',
        width: 500,
      ),
      DigitTableColumn(
        header: localizations.translate(i18.summaryReport.girls3to11),
        cellValue: 'girls3to11',
        width: 500,
      ),
      DigitTableColumn(
        header: localizations.translate(i18.summaryReport.girls12to59),
        cellValue: 'girls12to59',
        width: 500,
      ),
      // Stock columns — re-enable by uncommenting _productVariants = productVariants in setState:
      for (final pv in _productVariants) ...[
        DigitTableColumn(
          header:
              '${localizations.translate(i18.summaryReport.stockReceived)} (${localizations.translate(pv.sku ?? pv.id)})',
          cellValue: 'received_${pv.id}',
        ),
        DigitTableColumn(
          header:
              '${localizations.translate(i18.summaryReport.stockConsumed)} (${localizations.translate(pv.sku ?? pv.id)})',
          cellValue: 'consumed_${pv.id}',
        ),
        DigitTableColumn(
          header:
              '${localizations.translate(i18.summaryReport.stockReturned)} (${localizations.translate(pv.sku ?? pv.id)})',
          cellValue: 'returned_${pv.id}',
        ),
        DigitTableColumn(
          header:
              '${localizations.translate(i18.summaryReport.stockBalance)} (${localizations.translate(pv.sku ?? pv.id)})',
          cellValue: 'balance_${pv.id}',
        ),
      ],
    ];

    // Totals row
    final totals = _SummaryReportRow(
      date: localizations.translate(i18.summaryReport.totalRow),
      totalAll: _reportRows.fold(0, (s, r) => s + r.totalAll),
      total3to11: _reportRows.fold(0, (s, r) => s + r.total3to11),
      total12to59: _reportRows.fold(0, (s, r) => s + r.total12to59),
      boysAll: _reportRows.fold(0, (s, r) => s + r.boysAll),
      boys3to11: _reportRows.fold(0, (s, r) => s + r.boys3to11),
      boys12to59: _reportRows.fold(0, (s, r) => s + r.boys12to59),
      girlsAll: _reportRows.fold(0, (s, r) => s + r.girlsAll),
      girls3to11: _reportRows.fold(0, (s, r) => s + r.girls3to11),
      girls12to59: _reportRows.fold(0, (s, r) => s + r.girls12to59),
      householdsRegistered:
          _reportRows.fold(0, (s, r) => s + r.householdsRegistered),
    );

    final displayRows = [..._reportRows, if (_reportRows.isNotEmpty) totals];

    final rows = displayRows.map((row) {
      final isTotal = row == totals && _reportRows.isNotEmpty;
      final cells = <DigitTableData>[
        DigitTableData(
          isTotal ? row.date : _formatDisplayDate(row.date),
          cellKey: 'date',
        ),
        DigitTableData(
          row.totalAll.toString(), 
          cellKey: 'totalAll', 
          widget: Center(
            child: Text(
              row.totalAll.toString(),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        DigitTableData(
          row.total3to11.toString(), 
          cellKey: 'total3to11',
          widget: Center(
            child: Text(
              row.totalAll.toString(),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        DigitTableData(
          row.total12to59.toString(), 
          cellKey: 'total12to59',
          widget: Center(
            child: Text(
              row.totalAll.toString(),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        DigitTableData(
          row.boysAll.toString(), 
          cellKey: 'boysAll',
          widget: Center(
            child: Text(
              row.totalAll.toString(),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        DigitTableData(
          row.boys3to11.toString(), 
          cellKey: 'boys3to11',
          widget: Center(
            child: Text(
              row.totalAll.toString(),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        DigitTableData(
          row.boys12to59.toString(), 
          cellKey: 'boys12to59',
          widget: Center(
            child: Text(
              row.totalAll.toString(),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        DigitTableData(
          row.girlsAll.toString(), 
          cellKey: 'girlsAll',
          widget: Center(
            child: Text(
              row.totalAll.toString(),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        DigitTableData(
          row.girls3to11.toString(), 
          cellKey: 'girls3to11',
          widget: Center(
            child: Text(
              row.totalAll.toString(),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        DigitTableData(
          row.girls12to59.toString(), 
          cellKey: 'girls12to59',
          widget: Center(
            child: Text(
              row.totalAll.toString(),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        // Stock cells — active when _productVariants is populated:
        for (final pv in _productVariants) ...[
          DigitTableData(
              (row.stockData[pv.id]?.received ?? 0).toStringAsFixed(0),
              cellKey: 'received_${pv.id}'),
          DigitTableData(
              (row.stockData[pv.id]?.consumed ?? 0).toStringAsFixed(0),
              cellKey: 'consumed_${pv.id}'),
          DigitTableData(
              (row.stockData[pv.id]?.returned ?? 0).toStringAsFixed(0),
              cellKey: 'returned_${pv.id}'),
          DigitTableData(
              (row.stockData[pv.id]?.balance ?? 0).toStringAsFixed(0),
              cellKey: 'balance_${pv.id}'),
        ],
      ];
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

class _DateBucket {
  int totalAll = 0, total3to11 = 0, total12to59 = 0;
  int boysAll = 0, boys3to11 = 0, boys12to59 = 0;
  int girlsAll = 0, girls3to11 = 0, girls12to59 = 0;

  void add(int ageMonths, String? gender) {
    totalAll++;
    if (ageMonths <= 11) total3to11++;
    if (ageMonths >= 12) total12to59++;

    final g = gender?.toUpperCase();
    if (g == 'MALE') {
      boysAll++;
      if (ageMonths <= 11) boys3to11++;
      if (ageMonths >= 12) boys12to59++;
    } else if (g == 'FEMALE') {
      girlsAll++;
      if (ageMonths <= 11) girls3to11++;
      if (ageMonths >= 12) girls12to59++;
    }
  }
}

class _SummaryReportRow {
  final String date;
  // Age/gender columns (active)
  final int totalAll;
  final int total3to11;
  final int total12to59;
  final int boysAll;
  final int boys3to11;
  final int boys12to59;
  final int girlsAll;
  final int girls3to11;
  final int girls12to59;
  // Retained for future columns
  final int householdsRegistered;
  final int childrenTreated;
  final double childrenTreatedPercent;
  final Map<String, _ProductStockData> stockData;

  _SummaryReportRow({
    required this.date,
    required this.totalAll,
    required this.total3to11,
    required this.total12to59,
    required this.boysAll,
    required this.boys3to11,
    required this.boys12to59,
    required this.girlsAll,
    required this.girls3to11,
    required this.girls12to59,
    this.householdsRegistered = 0,
    this.childrenTreated = 0,
    this.childrenTreatedPercent = 0.0,
    this.stockData = const {},
  });
}

class _ProductStockData {
  final double received;
  final double consumed;
  final double returned;
  final double balance;

  _ProductStockData({
    required this.received,
    required this.consumed,
    required this.returned,
    required this.balance,
  });
}
