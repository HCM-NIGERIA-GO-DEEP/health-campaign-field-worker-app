import 'package:digit_data_model/data/repositories/package_repository/local/household.dart';
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
import '../../../utils/utils.dart';
import '../../../widgets/custom_table/custom_data_table.dart';
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

      final pendingHouseholdClientRefs =
          (await householdRepo.getItemsToBeSyncedUp(userUuid))
              .where((e) =>
                  e.operation == DataOperation.create ||
                  e.operation == DataOperation.singleCreate)
              .map((e) => e.clientReferenceId)
              .whereType<String>()
              .where((id) => id.isNotEmpty)
              .toSet();

      final pendingTaskClientRefs = (await taskRepo.getItemsToBeSyncedUp(
        userUuid,
      ))
          .where((e) =>
              e.operation == DataOperation.create ||
              e.operation == DataOperation.singleCreate)
          .map((e) => e.clientReferenceId)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();

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

      // Unsynced local household registrations by date.
      final localHouseholdsRegisteredByDate = <String, int>{};
      final localPeopleInHouseholdsByDate = <String, int>{};
      for (final hh in households) {
        if (!pendingHouseholdClientRefs.contains(hh.clientReferenceId)) {
          continue;
        }

        final createdBy =
            hh.clientAuditDetails?.createdBy ?? hh.auditDetails?.createdBy;
        if (createdBy != userUuid) continue;
        final epochMs =
            hh.clientAuditDetails?.createdTime ?? hh.auditDetails?.createdTime;
        if (!isWithinCurrentCycle(epochMs)) continue;
        if (epochMs == null) continue;

        final date = _epochToDateString(epochMs);
        localHouseholdsRegisteredByDate[date] =
            (localHouseholdsRegisteredByDate[date] ?? 0) + 1;
        localPeopleInHouseholdsByDate[date] =
            (localPeopleInHouseholdsByDate[date] ?? 0) + (hh.memberCount ?? 0);
      }

      // Unsynced local ITN distributed by date.
      final localITNByDate = <String, int>{};
      for (final task in tasks) {
        if (!pendingTaskClientRefs.contains(task.clientReferenceId)) {
          continue;
        }

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
          final qty = (double.tryParse(res.quantity ?? '0') ?? 0).toInt();
          localITNByDate[date] = (localITNByDate[date] ?? 0) + qty;
        }
      }

      // ── Group stock consumed from task resources by date + productVariant ──
      // Only count tasks with status 'ADMINISTRATION_SUCCESS' or 'VISITED'
      // Key: "date|productVariantId" -> sum of quantity
      final consumedByDateProduct = <String, double>{};
      for (final task in tasks) {
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
        ...localHouseholdsRegisteredByDate.keys,
        ...localPeopleInHouseholdsByDate.keys,
        ...localITNByDate.keys,
        ...stockDates,
        ...consumedDates,
        ...serverReportAllDates,
      };

      // ── Build rows ──
      // Sort dates ascending for cumulative consumed calculation
      final sortedDates = allDates.toList()..sort();

      final rows = <_SummaryReportRow>[];
      for (final date in sortedDates) {
        int serverReportHouseholdRegistration =
            await summaryReportService.householdRegistration(date: date);
        int serverReportPeopleInHouseholds =
            await summaryReportService.peopleInHouseholds(date: date);
        int serverReportITNDistributed =
            await summaryReportService.itnsDistributed(date: date);

        final hhCount = serverReportHouseholdRegistration +
            (localHouseholdsRegisteredByDate[date] ?? 0);
        final dailyPeopleCount = serverReportPeopleInHouseholds +
            (localPeopleInHouseholdsByDate[date] ?? 0);
        final dailyITNCount =
            serverReportITNDistributed + (localITNByDate[date] ?? 0);

        // Filter stock entries for this day only to compute total less/excess.
        final dateStocks = allStocks.where((stock) {
          final epochMs = stock.clientAuditDetails?.createdTime ??
              stock.auditDetails?.createdTime;
          if (!isWithinCurrentCycle(epochMs)) return false;
          if (epochMs == null) return false;
          return _epochToDateString(epochMs) == date;
        }).toList();

        double totalLess = 0;
        double totalExcess = 0;

        for (final pv in productVariants) {
          final metrics = dateStocks.isNotEmpty
              ? StockCalculationUtils.calculateStockMetrics(
                  stockList: dateStocks,
                  facilityId: effectiveFacilityId,
                  productId: pv.id,
                  loggedInUserUuid: userUuid,
                  isDistributor: isDistributor,
                )
              : StockCalculationUtils.emptyMetrics;

          totalLess += metrics['stockLess'] ?? 0.0;
          totalExcess += metrics['stockExcess'] ?? 0.0;
        }

        rows.add(_SummaryReportRow(
          date: date,
          householdsRegistered: hhCount,
          numberOfPeopleInHouseholds: dailyPeopleCount,
          numberOfITNDistributed: dailyITNCount,
          totalLess: totalLess,
          totalExcess: totalExcess,
        ));
      }

      // Sort descending by date for display
      rows.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _reportRows = rows;
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

    // Build columns: base columns + per-product stock columns
    final columns = <CustomTableColumn>[
      CustomTableColumn(
        header: localizations.translate(i18.summaryReport.dateColumn),
      ),
      CustomTableColumn(
        header: localizations.translate(i18.summaryReport.householdsRegistered),
      ),
      CustomTableColumn(
        header: localizations
            .translate(i18.summaryReport.numberOfPeopleInHouseholds),
      ),
      CustomTableColumn(
        header:
            localizations.translate(i18.summaryReport.numberOfITNDistributed),
      ),
      CustomTableColumn(
        header: localizations.translate(i18.common.loss),
      ),
      CustomTableColumn(
        header: localizations.translate(i18.common.excess),
      ),
    ];

    // Build rows
    final rows = _reportRows.map((row) {
      return CustomTableRow([
        _formatDisplayDate(row.date),
        row.householdsRegistered.toString(),
        row.numberOfPeopleInHouseholds.toString(),
        row.numberOfITNDistributed.toString(),
        row.totalLess.toStringAsFixed(0),
        row.totalExcess.toStringAsFixed(0),
      ]);
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
              child: CustomDataTable(
                enableBorder: true,
                columns: columns,
                rows: rows,
              ),
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
  final int numberOfPeopleInHouseholds;
  final int numberOfITNDistributed;
  final double totalLess;
  final double totalExcess;

  _SummaryReportRow({
    required this.date,
    required this.householdsRegistered,
    required this.numberOfPeopleInHouseholds,
    required this.numberOfITNDistributed,
    required this.totalLess,
    required this.totalExcess,
  });
}
