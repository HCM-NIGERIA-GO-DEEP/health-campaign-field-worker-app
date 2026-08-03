import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:digit_data_model/data/repositories/package_repository/local/household.dart';
import 'package:digit_data_model/data/repositories/package_repository/local/household_member.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../data/services/server_summary_report_service.dart';
import '../../../models/entities/roles_type.dart';
import '../../../router/app_router.dart';
import '../../../utils/i18_key_constants.dart' as i18;
import '../../../utils/stock_calculation_utils.dart';
import '../../../utils/summary_report_utils.dart';
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
  List<ProductVariantModel> _productVariants = [];
  bool _isLoading = true;
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final userUuid = context.loggedInUserUuid;
      final projectId = context.projectId;
      final currentCycle = context.selectedCycle;
      final currentCycleStartDate = currentCycle?.startDate;
      final currentCycleEndDate = currentCycle?.endDate;

      bool isWithinCurrentCycle(int? epochMs) {
        if (currentCycleStartDate == null || currentCycleEndDate == null) {
          return true;
        }
        if (epochMs == null) return false;
        return epochMs >= currentCycleStartDate &&
            epochMs <= currentCycleEndDate;
      }

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
      final summaryReportService = context.read<ServerSummaryReportService>();

      int? serverReportTimestamp = await summaryReportService.timestamp();
      List<String> serverReportAllDates = await summaryReportService.allDates();

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

      // Filter households by server report timestamp (if available)
      List<HouseholdModel> filteredHouseholds = households;
      if (serverReportTimestamp != null) {
        filteredHouseholds = filteredHouseholds
            .where((e) =>
                e.auditDetails != null &&
                e.auditDetails!.lastModifiedTime >= serverReportTimestamp)
            .toList();
      }

      // ── Group households by date (filter by logged-in user) ──
      final hhByDate = <String, int>{};
      for (final hh in filteredHouseholds) {
        final createdBy =
            hh.clientAuditDetails?.createdBy ?? hh.auditDetails?.createdBy;
        if (createdBy != userUuid) continue;
        final epochMs =
            hh.clientAuditDetails?.createdTime ?? hh.auditDetails?.createdTime;
        if (!isWithinCurrentCycle(epochMs)) continue;
        if (epochMs == null) continue;
        final date = _epochToDateString(epochMs);
        hhByDate[date] = (hhByDate[date] ?? 0) + 1;
      }

      // Filter tasks by server report timestamp (if available)
      List<TaskModel> filteredTasks = tasks;
      if (serverReportTimestamp != null) {
        filteredTasks = filteredTasks
            .where((e) =>
                e.auditDetails != null &&
                e.auditDetails!.lastModifiedTime >= serverReportTimestamp)
            .toList();
      }

      // ── Group tasks by date for children treated ──
      // (filter by logged-in user AND status == 'ADMINISTRATION_SUCCESS' or 'VISITED')
      final tasksByDate = <String, Set<String>>{};
      for (final task in filteredTasks) {
        if (task.status != 'ADMINISTRATION_SUCCESS' && task.status != 'VISITED')
          continue;
        final createdBy =
            task.clientAuditDetails?.createdBy ?? task.auditDetails?.createdBy;
        if (createdBy != userUuid) continue;
        final epochMs = task.clientAuditDetails?.createdTime ??
            task.auditDetails?.createdTime;
        if (!isWithinCurrentCycle(epochMs)) continue;
        if (epochMs == null) continue;
        final beneficiaryRef = task.projectBeneficiaryClientReferenceId;
        if (beneficiaryRef == null || beneficiaryRef.isEmpty) continue;
        final date = _epochToDateString(epochMs);
        tasksByDate.putIfAbsent(date, () => <String>{});
        tasksByDate[date]!.add(beneficiaryRef);
      }

      // Filter household members by server report timestamp (if available)
      List<HouseholdMemberModel> filteredHouseholdMembers = householdMembers;
      if (serverReportTimestamp != null) {
        filteredHouseholdMembers = filteredHouseholdMembers
            .where((e) =>
                e.auditDetails != null &&
                e.auditDetails!.lastModifiedTime >= serverReportTimestamp)
            .toList();
      }

      // ── Group non-head household members by date ──
      final nonHeadMembersByDate = <String, int>{};
      for (final member in filteredHouseholdMembers) {
        if (member.isHeadOfHousehold) continue;
        final createdBy = member.clientAuditDetails?.createdBy ??
            member.auditDetails?.createdBy;
        if (createdBy != userUuid) continue;
        final epochMs = member.clientAuditDetails?.createdTime ??
            member.auditDetails?.createdTime;
        if (!isWithinCurrentCycle(epochMs)) continue;
        if (epochMs == null) continue;
        final date = _epochToDateString(epochMs);
        nonHeadMembersByDate[date] = (nonHeadMembersByDate[date] ?? 0) + 1;
      }

      // ── Group stock consumed from task resources by date + productVariant ──
      // Only count tasks with status 'ADMINISTRATION_SUCCESS' or 'VISITED'
      // Key: "date|productVariantId" -> sum of quantity
      final consumedByDateProduct = <String, double>{};
      for (final task in filteredTasks) {
        if (task.status != 'ADMINISTRATION_SUCCESS' && task.status != 'VISITED')
          continue;
        final createdBy =
            task.clientAuditDetails?.createdBy ?? task.auditDetails?.createdBy;
        if (createdBy != userUuid) continue;
        final epochMs = task.clientAuditDetails?.createdTime ??
            task.auditDetails?.createdTime;
        if (!isWithinCurrentCycle(epochMs)) continue;
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

      // ── Collect stock dates (for date rows) ──
      final stockDates = <String>{};
      for (final stock in allStocks) {
        final epochMs = stock.clientAuditDetails?.createdTime ??
            stock.auditDetails?.createdTime;
        if (!isWithinCurrentCycle(epochMs)) continue;
        if (epochMs == null) continue;
        stockDates.add(_epochToDateString(epochMs));
      }

      // ── Collect consumed dates ──
      final consumedDates = <String>{};
      for (final key in consumedByDateProduct.keys) {
        consumedDates.add(key.split('|')[0]);
      }

      final allDates = <String>{
        ...hhByDate.keys,
        ...tasksByDate.keys,
        ...stockDates,
        ...consumedDates,
        ...serverReportAllDates,
      };

      // ── Build rows ──
      // Sort dates ascending for cumulative consumed calculation
      final sortedDates = allDates.toList()..sort();

      // Track cumulative consumed per product variant (for balance)
      final cumulativeConsumed = <String, double>{};

      final rows = <_SummaryReportRow>[];
      for (final date in sortedDates) {
        int? serverReportHouseholdRegistration =
            await summaryReportService.householdRegistration(date: date);
        int? serverReportChildrenRegistered =
            await summaryReportService.childrenRegistered(date: date);
        int? serverReportChildrenTreated =
            await summaryReportService.childrenTreated(date: date);
        final serverReportStockConsumedMap =
            await summaryReportService.stockConsumedMap(date: date);

        final hhCount =
            serverReportHouseholdRegistration + (hhByDate[date] ?? 0);
        final childrenCount =
            serverReportChildrenTreated + (tasksByDate[date]?.length ?? 0);
        final nonHeadCount =
            serverReportChildrenRegistered + (nonHeadMembersByDate[date] ?? 0);
        final percentage =
            nonHeadCount > 0 ? (childrenCount / nonHeadCount) * 100 : 0.0;

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
          if (!isWithinCurrentCycle(epochMs)) return false;
          if (epochMs == null) return false;
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
          final dailyConsumed = (serverReportStockConsumedMap[pv.id] ?? 0.0) +
              (consumedByDateProduct[key] ?? 0.0);

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
          _productVariants = productVariants;
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

  /// KPI label -> one formatted cell per date, dates in `_reportRows` order
  /// (already sorted newest first in `_loadData`).
  List<MapEntry<String, List<String>>> _transposedRows() {
    final rows = <MapEntry<String, List<String>>>[
      MapEntry(
        localizations.translate(i18.summaryReport.householdsRegistered),
        _reportRows.map((r) => r.householdsRegistered.toString()).toList(),
      ),
      MapEntry(
        localizations.translate(i18.summaryReport.childrenTreated),
        _reportRows.map((r) => r.childrenTreated.toString()).toList(),
      ),
      MapEntry(
        localizations.translate(i18.summaryReport.childrenTreatedPercent),
        _reportRows
            .map((r) => formatSummaryPercent(r.childrenTreatedPercent))
            .toList(),
      ),
    ];

    for (final pv in _productVariants) {
      final name = localizations.translate(pv.sku ?? pv.id);
      rows.addAll([
        MapEntry(
          '${localizations.translate(i18.summaryReport.stockReceived)} ($name)',
          _reportRows
              .map((r) => formatSummaryStock(r.stockData[pv.id]?.received))
              .toList(),
        ),
        MapEntry(
          '${localizations.translate(i18.summaryReport.stockConsumed)} ($name)',
          _reportRows
              .map((r) => formatSummaryStock(r.stockData[pv.id]?.consumed))
              .toList(),
        ),
        MapEntry(
          '${localizations.translate(i18.summaryReport.stockReturned)} ($name)',
          _reportRows
              .map((r) => formatSummaryStock(r.stockData[pv.id]?.returned))
              .toList(),
        ),
        MapEntry(
          '${localizations.translate(i18.summaryReport.stockBalance)} ($name)',
          _reportRows
              .map((r) => formatSummaryStock(r.stockData[pv.id]?.balance))
              .toList(),
        ),
      ]);
    }

    return rows;
  }

  /// Renders the transposed table: pinned KPI column on the left (bold,
  /// wrapped labels), date columns scrolling horizontally on the right.
  /// Per-row heights are measured from the KPI labels with TextPainter so
  /// the pinned column and the scrolling grid stay pixel-aligned.
  Widget _buildTransposedTable(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);
    final dividerColor = theme.colorTheme.generic.divider;
    final headerBackground = theme.colorTheme.generic.background;
    final bodyBackground = theme.colorTheme.paper.primary;

    const pinnedWidth = 140.0;
    const dataColumnWidth = 110.0;
    const cellPadding = 16.0;
    const minRowHeight = 52.0;
    const innerWidth = pinnedWidth - 2 * cellPadding;

    final headerStyle = textTheme.headingS.copyWith(
      color: theme.colorTheme.primary.primary2,
    );
    final labelStyle = textTheme.bodyS.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorTheme.text.primary,
    );
    final cellStyle = textTheme.bodyS.copyWith(
      color: theme.colorTheme.text.primary,
    );

    final textScaler = MediaQuery.textScalerOf(context);

    // Must use the same style/width/scaler as the rendered pinned cells,
    // otherwise the two sides of the table drift out of alignment.
    double measuredCellHeight(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: ui.TextDirection.ltr,
        textScaler: textScaler,
      )..layout(maxWidth: innerWidth);
      final height = painter.height;
      painter.dispose();
      return math.max(minRowHeight, height.ceilToDouble() + 2 * cellPadding);
    }

    final kpiHeader = localizations.translate(i18.summaryReport.kpiColumn);
    final kpiRows = _transposedRows();
    final dateHeaders =
        _reportRows.map((r) => formatSummaryDisplayDate(r.date)).toList();

    final headerHeight = measuredCellHeight(kpiHeader, headerStyle);
    final rowHeights = [
      for (final row in kpiRows) measuredCellHeight(row.key, labelStyle),
    ];

    Widget cell(
      Widget child, {
      required double width,
      required double height,
      required Color background,
      bool rightDivider = false,
    }) {
      return Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(cellPadding),
        alignment: Alignment.topLeft,
        decoration: BoxDecoration(
          color: background,
          border: Border(
            bottom: BorderSide(color: dividerColor),
            right: rightDivider
                ? BorderSide(color: dividerColor)
                : BorderSide.none,
          ),
        ),
        child: child,
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pinned KPI column
          SizedBox(
            width: pinnedWidth,
            child: Column(
              children: [
                cell(
                  Text(kpiHeader, style: headerStyle),
                  width: pinnedWidth,
                  height: headerHeight,
                  background: headerBackground,
                  rightDivider: true,
                ),
                for (var i = 0; i < kpiRows.length; i++)
                  cell(
                    Text(kpiRows[i].key, style: labelStyle, softWrap: true),
                    width: pinnedWidth,
                    height: rowHeights[i],
                    background: bodyBackground,
                    rightDivider: true,
                  ),
              ],
            ),
          ),
          // Horizontally scrolling date columns
          Expanded(
            child: Scrollbar(
              controller: _horizontalScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        for (final date in dateHeaders)
                          cell(
                            Text(
                              date,
                              style: headerStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            width: dataColumnWidth,
                            height: headerHeight,
                            background: headerBackground,
                          ),
                      ],
                    ),
                    for (var i = 0; i < kpiRows.length; i++)
                      Row(
                        children: [
                          for (final value in kpiRows[i].value)
                            cell(
                              Text(
                                value,
                                style: cellStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              width: dataColumnWidth,
                              height: rowHeights[i],
                              background: bodyBackground,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

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
              child: _buildTransposedTable(context),
            ),
          const SizedBox(height: spacer2),
        ],
      ),
    );
  }
}

class _SummaryReportRow {
  final String date;
  final int householdsRegistered;
  final int childrenTreated;
  final double childrenTreatedPercent;
  final Map<String, _ProductStockData> stockData;

  _SummaryReportRow({
    required this.date,
    required this.householdsRegistered,
    required this.childrenTreated,
    required this.childrenTreatedPercent,
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
