import 'dart:async';

import 'package:digit_data_model/data/repositories/package_repository/local/household.dart';
import 'package:digit_data_model/data/repositories/package_repository/local/household_member.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../models/entities/roles_type.dart';
import '../../utils/stock_calculation_utils.dart';
import '../../utils/utils.dart';
import 'summary_report_backup_service.dart';

/// Computes the summary report's per-date rows by merging the shared-storage
/// backup (records up to its snapshot time — including data lost locally
/// when the user cleared the app's storage) with post-snapshot local
/// records, then rolls the backup forward.
///
/// Runs from the home screen on every visit so the backup stays current
/// without requiring the report page to be opened; the report page calls it
/// too and displays the returned rows.
class SummaryReportData {
  SummaryReportData._();

  static Future<SummaryReportResult> loadMergedRows(
    BuildContext context,
  ) async {
    final userUuid = context.loggedInUserUuid;
    final projectId = context.projectId;
    final currentCycle = context.selectedCycle;
    final currentCycleStartDate = currentCycle?.startDate;
    final currentCycleEndDate = currentCycle?.endDate;

    // Captured before any DB reads so records created while this method
    // runs are not skipped by the next run's post-snapshot filter.
    final snapshotTime = DateTime.now().millisecondsSinceEpoch;

    bool isWithinCurrentCycle(int? epochMs) {
      if (currentCycleStartDate == null || currentCycleEndDate == null) {
        return true;
      }
      if (epochMs == null) return false;
      return epochMs >= currentCycleStartDate && epochMs <= currentCycleEndDate;
    }

    // Repositories
    final householdRepo =
        context.read<LocalRepository<HouseholdModel, HouseholdSearchModel>>()
            as HouseholdLocalRepository;
    final taskRepo =
        context.read<LocalRepository<TaskModel, TaskSearchModel>>();
    final householdMemberRepo = context.read<
            LocalRepository<HouseholdMemberModel, HouseholdMemberSearchModel>>()
        as HouseholdMemberLocalRepository;
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

    // Backed-up rows hold everything recorded up to their snapshot time —
    // including data lost locally when the user cleared the app's storage.
    // Local records are only counted below when created after that
    // snapshot, and their contribution is added on top.
    final cycleIndex = (currentCycle?.id ?? 0).toString();
    final backupService = SummaryReportBackupService.instance;
    final backupEntry = await backupService.readEntry(
      projectId: projectId,
      userUuid: userUuid,
      facilityId: effectiveFacilityId,
      cycleIndex: cycleIndex,
    );
    final backupTime = backupEntry.timeStamp;
    final backedUpRows = <String, SummaryReportRow>{};
    for (final entry in backupEntry.rows.entries) {
      final parsed = rowFromJson(entry.key, entry.value);
      if (parsed != null) backedUpRows[entry.key] = parsed;
    }

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
    final householdMembers =
        await householdMemberRepo.search(HouseholdMemberSearchModel(), userUuid);

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
      if (!isWithinCurrentCycle(epochMs)) continue;
      if (epochMs == null) continue;
      if (epochMs <= backupTime || epochMs > snapshotTime) continue;
      final date = epochToDateString(epochMs);
      hhByDate[date] = (hhByDate[date] ?? 0) + 1;
    }

    // ── Group tasks by date for children treated ──
    // (filter by logged-in user AND status == 'ADMINISTRATION_SUCCESS' or 'VISITED')
    final tasksByDate = <String, Set<String>>{};
    for (final task in tasks) {
      if (task.status != 'ADMINISTRATION_SUCCESS' && task.status != 'VISITED') {
        continue;
      }
      final createdBy =
          task.clientAuditDetails?.createdBy ?? task.auditDetails?.createdBy;
      if (createdBy != userUuid) continue;
      final epochMs = task.clientAuditDetails?.createdTime ??
          task.auditDetails?.createdTime;
      if (!isWithinCurrentCycle(epochMs)) continue;
      if (epochMs == null) continue;
      if (epochMs <= backupTime || epochMs > snapshotTime) continue;
      final beneficiaryRef = task.projectBeneficiaryClientReferenceId;
      if (beneficiaryRef == null || beneficiaryRef.isEmpty) continue;
      final date = epochToDateString(epochMs);
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
      if (!isWithinCurrentCycle(epochMs)) continue;
      if (epochMs == null) continue;
      if (epochMs <= backupTime || epochMs > snapshotTime) continue;
      final date = epochToDateString(epochMs);
      nonHeadMembersByDate[date] = (nonHeadMembersByDate[date] ?? 0) + 1;
    }

    // ── Group stock consumed from task resources by date + productVariant ──
    // Only count tasks with status 'ADMINISTRATION_SUCCESS' or 'VISITED'
    // Key: "date|productVariantId" -> sum of quantity
    final consumedByDateProduct = <String, double>{};
    for (final task in tasks) {
      if (task.status != 'ADMINISTRATION_SUCCESS' && task.status != 'VISITED') {
        continue;
      }
      final createdBy =
          task.clientAuditDetails?.createdBy ?? task.auditDetails?.createdBy;
      if (createdBy != userUuid) continue;
      final epochMs = task.clientAuditDetails?.createdTime ??
          task.auditDetails?.createdTime;
      if (!isWithinCurrentCycle(epochMs)) continue;
      if (epochMs == null) continue;
      if (epochMs <= backupTime || epochMs > snapshotTime) continue;
      final date = epochToDateString(epochMs);
      final resources = task.resources;
      if (resources == null) continue;
      for (final res in resources) {
        final pvId = res.productVariantId;
        if (pvId == null || pvId.isEmpty) continue;
        final qty = double.tryParse(res.quantity ?? '0') ?? 0.0;
        final key = '$date|$pvId';
        consumedByDateProduct[key] = (consumedByDateProduct[key] ?? 0.0) + qty;
      }
    }

    // ── Collect stock dates (for date rows) ──
    final stockDates = <String>{};
    for (final stock in allStocks) {
      final epochMs = stock.clientAuditDetails?.createdTime ??
          stock.auditDetails?.createdTime;
      if (!isWithinCurrentCycle(epochMs)) continue;
      if (epochMs == null) continue;
      if (epochMs <= backupTime || epochMs > snapshotTime) continue;
      stockDates.add(epochToDateString(epochMs));
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
      ...backedUpRows.keys,
    };

    // ── Build rows ──
    // Sort dates ascending for cumulative consumed calculation
    final sortedDates = allDates.toList()..sort();

    // Track cumulative post-snapshot consumed per product variant
    final cumulativeConsumed = <String, double>{};

    // Latest backed-up cumulative stock values seen so far; carried
    // forward to dates the backup does not cover.
    final carryStock = <String, ProductStockData>{};

    final rows = <SummaryReportRow>[];
    for (final date in sortedDates) {
      final backupRow = backedUpRows[date];

      // Counts are additive: backed-up value (records up to the snapshot)
      // plus the post-snapshot records grouped above.
      final hhCount =
          (backupRow?.householdsRegistered ?? 0) + (hhByDate[date] ?? 0);
      final childrenCount =
          (backupRow?.childrenTreated ?? 0) + (tasksByDate[date]?.length ?? 0);
      final nonHeadCount = (backupRow?.childrenRegistered ?? 0) +
          (nonHeadMembersByDate[date] ?? 0);
      final percentage =
          nonHeadCount > 0 ? (childrenCount / nonHeadCount) * 100 : 0.0;

      // End-of-day timestamp for cumulative stock filtering
      final endOfDay = DateTime.parse(date)
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1))
          .millisecondsSinceEpoch;

      // Post-snapshot stocks up to and including this day; older records
      // are already baked into the backed-up rows.
      final cumulativeStocks = allStocks.where((stock) {
        final epochMs = stock.clientAuditDetails?.createdTime ??
            stock.auditDetails?.createdTime;
        if (!isWithinCurrentCycle(epochMs)) return false;
        if (epochMs == null) return false;
        if (epochMs <= backupTime || epochMs > snapshotTime) return false;
        return epochMs <= endOfDay;
      }).toList();

      // Per-product stock data
      final stockData = <String, ProductStockData>{};
      for (final pv in productVariants) {
        // Post-snapshot received & returned using same logic as stock_balance_card
        final metrics = cumulativeStocks.isNotEmpty
            ? StockCalculationUtils.calculateStockMetrics(
                stockList: cumulativeStocks,
                facilityId: effectiveFacilityId,
                productId: pv.id,
                loggedInUserUuid: userUuid,
                isDistributor: isDistributor,
              )
            : StockCalculationUtils.emptyMetrics;

        final deltaReceived = metrics['stockReceived'] ?? 0.0;
        final deltaReturned = metrics['stockReturned'] ?? 0.0;
        final deltaWastage = metrics['stockWastage'] ?? 0.0;

        // Daily consumed from post-snapshot records (for this day only)
        final key = '$date|${pv.id}';
        final dailyConsumedDelta = consumedByDateProduct[key] ?? 0.0;

        // Accumulate consumed for balance calculation
        cumulativeConsumed[pv.id] =
            (cumulativeConsumed[pv.id] ?? 0.0) + dailyConsumedDelta;
        final deltaConsumed = cumulativeConsumed[pv.id]!;

        // A backed-up row for this date refreshes the carried-forward
        // cumulative baseline (its values predate the snapshot, so the
        // post-snapshot deltas added below are never double counted).
        final backupStock = backupRow?.stockData[pv.id];
        if (backupStock != null) {
          carryStock[pv.id] = backupStock;
        }
        final base = carryStock[pv.id];

        final totalReceived = (base?.received ?? 0.0) + deltaReceived;
        final totalReturned = (base?.returned ?? 0.0) + deltaReturned;
        final dailyConsumed =
            (backupStock?.consumed ?? 0.0) + dailyConsumedDelta;
        final balance = (base?.balance ?? 0.0) +
            deltaReceived -
            deltaConsumed -
            deltaReturned -
            deltaWastage;

        stockData[pv.id] = ProductStockData(
          received: totalReceived,
          consumed: dailyConsumed,
          returned: totalReturned,
          balance: balance,
        );
      }

      rows.add(SummaryReportRow(
        date: date,
        householdsRegistered: hhCount,
        childrenTreated: childrenCount,
        childrenRegistered: nonHeadCount,
        childrenTreatedPercent: percentage,
        stockData: stockData,
      ));
    }

    // Snapshot the merged rows so the backup rolls forward and survives
    // the user clearing the app's storage.
    if (rows.isNotEmpty) {
      unawaited(backupService.writeRows(
        projectId: projectId,
        userUuid: userUuid,
        facilityId: effectiveFacilityId,
        cycleIndex: cycleIndex,
        timeStamp: snapshotTime,
        rows: {for (final row in rows) row.date: rowToJson(row)},
      ));
    }

    // Sort descending by date for display
    rows.sort((a, b) => b.date.compareTo(a.date));

    return SummaryReportResult(rows: rows, productVariants: productVariants);
  }

  static String epochToDateString(int epochMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  static Map<String, dynamic> rowToJson(SummaryReportRow row) => {
        'householdsRegistered': row.householdsRegistered,
        'childrenTreated': row.childrenTreated,
        'childrenRegistered': row.childrenRegistered,
        'childrenTreatedPercent': row.childrenTreatedPercent,
        'stockData': row.stockData.map(
          (pvId, data) => MapEntry(pvId, {
            'received': data.received,
            'consumed': data.consumed,
            'returned': data.returned,
            'balance': data.balance,
          }),
        ),
      };

  static SummaryReportRow? rowFromJson(String date, dynamic json) {
    if (json is! Map) return null;

    final stockData = <String, ProductStockData>{};
    final rawStock = json['stockData'];
    if (rawStock is Map) {
      for (final entry in rawStock.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        stockData[entry.key.toString()] = ProductStockData(
          received: (value['received'] as num?)?.toDouble() ?? 0.0,
          consumed: (value['consumed'] as num?)?.toDouble() ?? 0.0,
          returned: (value['returned'] as num?)?.toDouble() ?? 0.0,
          balance: (value['balance'] as num?)?.toDouble() ?? 0.0,
        );
      }
    }

    return SummaryReportRow(
      date: date,
      householdsRegistered: (json['householdsRegistered'] as num?)?.toInt() ?? 0,
      childrenTreated: (json['childrenTreated'] as num?)?.toInt() ?? 0,
      childrenRegistered: (json['childrenRegistered'] as num?)?.toInt() ?? 0,
      childrenTreatedPercent:
          (json['childrenTreatedPercent'] as num?)?.toDouble() ?? 0.0,
      stockData: stockData,
    );
  }
}

class SummaryReportResult {
  final List<SummaryReportRow> rows;
  final List<ProductVariantModel> productVariants;

  const SummaryReportResult({
    required this.rows,
    required this.productVariants,
  });
}

class SummaryReportRow {
  final String date;
  final int householdsRegistered;
  final int childrenTreated;
  final int childrenRegistered;
  final double childrenTreatedPercent;
  final Map<String, ProductStockData> stockData;

  SummaryReportRow({
    required this.date,
    required this.householdsRegistered,
    required this.childrenTreated,
    this.childrenRegistered = 0,
    required this.childrenTreatedPercent,
    this.stockData = const {},
  });
}

class ProductStockData {
  final double received;
  final double consumed;
  final double returned;
  final double balance;

  ProductStockData({
    required this.received,
    required this.consumed,
    required this.returned,
    required this.balance,
  });
}
