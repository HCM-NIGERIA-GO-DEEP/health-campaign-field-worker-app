import 'dart:async';

import 'package:digit_data_model/data/repositories/package_repository/local/household.dart';
import 'package:digit_data_model/data/repositories/package_repository/local/household_member.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../models/entities/roles_type.dart';
import '../../utils/environment_config.dart';
import '../../utils/stock_calculation_utils.dart';
import '../../utils/utils.dart';
import '../local_store/secure_store/secure_store.dart';
import '../remote_client.dart';
import '../repositories/remote/summary_report.dart';
import 'summary_report_backup_service.dart';

/// Computes the summary report's per-date rows by merging the shared-storage
/// backup (records up to its snapshot time — including data lost locally
/// when the user cleared the app's storage) with post-snapshot local
/// records, then rolls the backup forward.
///
/// On the first computation after login, the server summary API is queried
/// and its per-date data (counts + stock consumed) is written to the backup
/// as the baseline, so a fresh device or a cleared/reinstalled app recovers
/// the user's synced history even without a surviving backup file.
class SummaryReportData {
  SummaryReportData._();

  /// Access token the server baseline has been attempted for. The token
  /// changes on every login, so this yields exactly one attempt per login;
  /// failures fall back to the existing file baseline.
  static String? _baselineAttemptedForToken;
  static Future<void>? _baselineInFlight;

  static Future<SummaryReportResult> loadMergedRows(
    BuildContext context,
  ) async {
    await _ensureServerBaseline(context);

    // Captured before any DB reads so records created while this method
    // runs are not skipped by the next run's post-snapshot filter.
    final snapshotTime = DateTime.now().millisecondsSinceEpoch;

    final key = await _resolveKey(context);
    final backupService = SummaryReportBackupService.instance;

    // Backed-up rows hold everything recorded up to their snapshot time —
    // including data lost locally when the user cleared the app's storage.
    // Local records are only counted below when created after that
    // snapshot, and their contribution is added on top.
    final backupEntry = await backupService.readEntry(
      projectId: key.projectId,
      userUuid: key.userUuid,
      facilityId: key.effectiveFacilityId,
      cycleIndex: key.cycleIndex,
    );
    final backedUpRows = <String, SummaryReportRow>{};
    for (final entry in backupEntry.rows.entries) {
      final parsed = rowFromJson(entry.key, entry.value);
      if (parsed != null) backedUpRows[entry.key] = parsed;
    }

    final computation = await _computeRows(
      context,
      key: key,
      backupTime: backupEntry.timeStamp,
      backedUpRows: backedUpRows,
      snapshotTime: snapshotTime,
    );

    final rows = computation.rows;

    // Snapshot the merged rows so the backup rolls forward and survives
    // the user clearing the app's storage.
    if (rows.isNotEmpty) {
      unawaited(backupService.writeRows(
        projectId: key.projectId,
        userUuid: key.userUuid,
        facilityId: key.effectiveFacilityId,
        cycleIndex: key.cycleIndex,
        timeStamp: snapshotTime,
        rows: {for (final row in rows) row.date: rowToJson(row)},
      ));
    }

    // Sort descending by date for display
    final displayRows = [...rows]..sort((a, b) => b.date.compareTo(a.date));

    return SummaryReportResult(
      rows: displayRows,
      productVariants: computation.productVariants,
    );
  }

  /// Fetches the server summary once per login and writes it to the backup
  /// as the baseline.
  static Future<void> _ensureServerBaseline(BuildContext context) async {
    final token = await LocalSecureStore.instance.accessToken;
    if (token == null || token.isEmpty) return;
    if (_baselineAttemptedForToken == token) return;

    final inFlight = _baselineInFlight;
    if (inFlight != null) return inFlight;

    if (!context.mounted) return;
    final future =
        _fetchAndApplyServerBaseline(context, token).whenComplete(() {
      _baselineInFlight = null;
    });
    _baselineInFlight = future;
    return future;
  }

  static Future<void> _fetchAndApplyServerBaseline(
    BuildContext context,
    String token,
  ) async {
    final userUuid = context.loggedInUserUuid;
    try {
      final currentCycle = context.selectedCycle;

      final reports = await SummaryReportRemoteRepository(
        DioClient().dio,
        searchPath: envConfig.variables.summaryReportApiPath,
      ).search(
        tenantId: envConfig.variables.tenantId,
        startDate: currentCycle?.startDate ?? 0,
        endDate: DateTime.now().millisecondsSinceEpoch,
      );

      // One attempt per login; a later retry would risk overwriting newer
      // local snapshots with stale server aggregates.
      _baselineAttemptedForToken = token;

      final mine = <String, ServerSummaryReport>{};
      for (final report in reports) {
        if (report.createdBy == userUuid) mine[report.date] = report;
      }
      if (mine.isEmpty) return;

      if (!context.mounted) return;

      final snapshotTime = DateTime.now().millisecondsSinceEpoch;
      final key = await _resolveKey(context);
      final backupService = SummaryReportBackupService.instance;

      // Recompute everything locally from scratch (no backup baseline) so
      // stock received/returned/balance reflect the downsynced records —
      // the summary API does not carry those; only counts and consumption.
      final computation = await _computeRows(
        context,
        key: key,
        backupTime: 0,
        backedUpRows: const {},
        snapshotTime: snapshotTime,
      );

      var rows = _overrideWithServer(
        localRowsAsc: computation.rows,
        productVariants: computation.productVariants,
        serverByDate: mine,
      );

      // Never let the login overwrite lose what the existing file snapshot
      // knows: records that were never synced before a storage clear exist
      // only there. Per date and field, the larger value wins.
      final existingEntry = await backupService.readEntry(
        projectId: key.projectId,
        userUuid: key.userUuid,
        facilityId: key.effectiveFacilityId,
        cycleIndex: key.cycleIndex,
      );
      final existingRows = <String, SummaryReportRow>{};
      for (final entry in existingEntry.rows.entries) {
        final parsed = rowFromJson(entry.key, entry.value);
        if (parsed != null) existingRows[entry.key] = parsed;
      }
      if (existingRows.isNotEmpty) {
        rows = _maxMergeWithExisting(rows: rows, existingRows: existingRows);
      }

      if (rows.isEmpty) return;

      await SummaryReportBackupService.instance.writeRows(
        projectId: key.projectId,
        userUuid: key.userUuid,
        facilityId: key.effectiveFacilityId,
        cycleIndex: key.cycleIndex,
        timeStamp: snapshotTime,
        rows: {for (final row in rows) row.date: rowToJson(row)},
      );
    } catch (error) {
      // Offline logins keep working from the file baseline.
      _baselineAttemptedForToken = token;
      AppLogger.instance.error(
        title: 'SummaryReportData',
        message: 'Server summary baseline failed: $error',
      );
    }
  }

  /// Merges server per-date data over locally computed rows. Server values
  /// win for counts and daily consumption on the dates they cover; balance
  /// is adjusted by the consumption difference so it stays consistent with
  /// the locally computed received/returned.
  static List<SummaryReportRow> _overrideWithServer({
    required List<SummaryReportRow> localRowsAsc,
    required List<ProductVariantModel> productVariants,
    required Map<String, ServerSummaryReport> serverByDate,
  }) {
    final localByDate = {for (final row in localRowsAsc) row.date: row};
    final allDates = <String>{...localByDate.keys, ...serverByDate.keys}
        .toList()
      ..sort();

    final localCum = <String, double>{};
    final finalCum = <String, double>{};
    final lastLocalStock = <String, ProductStockData>{};

    final rows = <SummaryReportRow>[];
    for (final date in allDates) {
      final local = localByDate[date];
      final server = serverByDate[date];

      final householdsRegistered =
          server?.householdsRegistered ?? local?.householdsRegistered ?? 0;
      final childrenTreated =
          server?.childrenTreated ?? local?.childrenTreated ?? 0;
      // The report's childrenRegistered counts non-head household members;
      // server-side each household contributes one head individual, so
      // children = individuals - households. This holds regardless of the
      // campaign's beneficiary enrollment configuration.
      final serverChildren = server == null
          ? 0
          : server.individualRegistered - server.householdsRegistered;
      final childrenRegistered = server != null
          ? (serverChildren < 0 ? 0 : serverChildren)
          : (local?.childrenRegistered ?? 0);
      final percentage = childrenRegistered > 0
          ? (childrenTreated / childrenRegistered) * 100
          : 0.0;

      final stockData = <String, ProductStockData>{};
      for (final pv in productVariants) {
        final localStock = local?.stockData[pv.id];
        if (localStock != null) lastLocalStock[pv.id] = localStock;
        final base = lastLocalStock[pv.id];

        final localDaily = localStock?.consumed ?? 0.0;
        final finalDaily = server != null
            ? (server.stockConsumedMap[pv.id] ?? 0.0)
            : localDaily;

        localCum[pv.id] = (localCum[pv.id] ?? 0.0) + localDaily;
        finalCum[pv.id] = (finalCum[pv.id] ?? 0.0) + finalDaily;

        // The local balance embeds the local cumulative consumption; swap
        // it for the merged cumulative consumption.
        final localBalance = localStock?.balance ?? base?.balance ?? 0.0;
        final balance =
            localBalance + (localCum[pv.id] ?? 0.0) - (finalCum[pv.id] ?? 0.0);

        stockData[pv.id] = ProductStockData(
          received: base?.received ?? 0.0,
          consumed: finalDaily,
          returned: base?.returned ?? 0.0,
          balance: balance,
        );
      }

      rows.add(SummaryReportRow(
        date: date,
        householdsRegistered: householdsRegistered,
        childrenTreated: childrenTreated,
        childrenRegistered: childrenRegistered,
        childrenTreatedPercent: percentage,
        stockData: stockData,
      ));
    }

    return rows;
  }

  /// Combines the login baseline with the pre-existing file snapshot so the
  /// overwrite can only add information, never lose it. Per date and field
  /// the larger value wins (for balance the smaller, since knowing more
  /// consumption lowers it).
  static List<SummaryReportRow> _maxMergeWithExisting({
    required List<SummaryReportRow> rows,
    required Map<String, SummaryReportRow> existingRows,
  }) {
    final byDate = {for (final row in rows) row.date: row};
    final allDates = <String>{...byDate.keys, ...existingRows.keys}.toList()
      ..sort();

    final merged = <SummaryReportRow>[];
    for (final date in allDates) {
      final candidate = byDate[date];
      final existing = existingRows[date];
      if (candidate == null || existing == null) {
        merged.add(candidate ?? existing!);
        continue;
      }

      final householdsRegistered = candidate.householdsRegistered >
              existing.householdsRegistered
          ? candidate.householdsRegistered
          : existing.householdsRegistered;
      final childrenTreated =
          candidate.childrenTreated > existing.childrenTreated
              ? candidate.childrenTreated
              : existing.childrenTreated;
      final childrenRegistered =
          candidate.childrenRegistered > existing.childrenRegistered
              ? candidate.childrenRegistered
              : existing.childrenRegistered;
      final percentage = childrenRegistered > 0
          ? (childrenTreated / childrenRegistered) * 100
          : 0.0;

      final pvIds = <String>{
        ...candidate.stockData.keys,
        ...existing.stockData.keys,
      };
      final stockData = <String, ProductStockData>{};
      for (final pvId in pvIds) {
        final a = candidate.stockData[pvId];
        final b = existing.stockData[pvId];
        if (a == null || b == null) {
          stockData[pvId] = a ?? b!;
          continue;
        }
        stockData[pvId] = ProductStockData(
          received: a.received > b.received ? a.received : b.received,
          consumed: a.consumed > b.consumed ? a.consumed : b.consumed,
          returned: a.returned > b.returned ? a.returned : b.returned,
          balance: a.balance < b.balance ? a.balance : b.balance,
        );
      }

      merged.add(SummaryReportRow(
        date: date,
        householdsRegistered: householdsRegistered,
        childrenTreated: childrenTreated,
        childrenRegistered: childrenRegistered,
        childrenTreatedPercent: percentage,
        stockData: stockData,
      ));
    }

    return merged;
  }

  /// Resolves the backup key parts (project, user, facility, cycle) the
  /// same way the stock balance card does.
  static Future<_BackupKey> _resolveKey(BuildContext context) async {
    final userUuid = context.loggedInUserUuid;
    final projectId = context.projectId;
    final currentCycle = context.selectedCycle;

    final projectFacilityRepo = context.read<
        LocalRepository<ProjectFacilityModel, ProjectFacilitySearchModel>>();
    final facilityRepo =
        context.read<LocalRepository<FacilityModel, FacilitySearchModel>>();

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

    return _BackupKey(
      userUuid: userUuid,
      projectId: projectId,
      effectiveFacilityId: effectiveFacilityId,
      cycleIndex: (currentCycle?.id ?? 0).toString(),
      isDistributor: isDistributor,
      cycleStartDate: currentCycle?.startDate,
      cycleEndDate: currentCycle?.endDate,
    );
  }

  static Future<_Computation> _computeRows(
    BuildContext context, {
    required _BackupKey key,
    required int backupTime,
    required Map<String, SummaryReportRow> backedUpRows,
    required int snapshotTime,
  }) async {
    final userUuid = key.userUuid;
    final projectId = key.projectId;
    final effectiveFacilityId = key.effectiveFacilityId;
    final isDistributor = key.isDistributor;

    bool isWithinCurrentCycle(int? epochMs) {
      if (key.cycleStartDate == null || key.cycleEndDate == null) {
        return true;
      }
      if (epochMs == null) return false;
      return epochMs >= key.cycleStartDate! && epochMs <= key.cycleEndDate!;
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
      if (task.status != 'ADMINISTRATION_SUCCESS' &&
          task.status != 'VISITED') {
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
      if (task.status != 'ADMINISTRATION_SUCCESS' &&
          task.status != 'VISITED') {
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
        final consumedKey = '$date|$pvId';
        consumedByDateProduct[consumedKey] =
            (consumedByDateProduct[consumedKey] ?? 0.0) + qty;
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
    for (final consumedKey in consumedByDateProduct.keys) {
      consumedDates.add(consumedKey.split('|')[0]);
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
        final consumedKey = '$date|${pv.id}';
        final dailyConsumedDelta = consumedByDateProduct[consumedKey] ?? 0.0;

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

    return _Computation(rows: rows, productVariants: productVariants);
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
      householdsRegistered:
          (json['householdsRegistered'] as num?)?.toInt() ?? 0,
      childrenTreated: (json['childrenTreated'] as num?)?.toInt() ?? 0,
      childrenRegistered: (json['childrenRegistered'] as num?)?.toInt() ?? 0,
      childrenTreatedPercent:
          (json['childrenTreatedPercent'] as num?)?.toDouble() ?? 0.0,
      stockData: stockData,
    );
  }
}

class _BackupKey {
  final String userUuid;
  final String projectId;
  final String effectiveFacilityId;
  final String cycleIndex;
  final bool isDistributor;
  final int? cycleStartDate;
  final int? cycleEndDate;

  const _BackupKey({
    required this.userUuid,
    required this.projectId,
    required this.effectiveFacilityId,
    required this.cycleIndex,
    required this.isDistributor,
    required this.cycleStartDate,
    required this.cycleEndDate,
  });
}

class _Computation {
  final List<SummaryReportRow> rows;
  final List<ProductVariantModel> productVariants;

  const _Computation({required this.rows, required this.productVariants});
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
