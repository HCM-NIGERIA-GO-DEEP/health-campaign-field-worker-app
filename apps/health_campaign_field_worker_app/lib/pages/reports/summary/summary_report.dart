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
      final projectFacilityRepo = context.read<
          LocalRepository<ProjectFacilityModel, ProjectFacilitySearchModel>>();
      final facilityRepo =
          context.read<LocalRepository<FacilityModel, FacilitySearchModel>>();
      final projectBeneficiaryRepo = context.read<
          LocalRepository<ProjectBeneficiaryModel,
              ProjectBeneficiarySearchModel>>();
      final householdMemberRepo = context.read<
          LocalRepository<HouseholdMemberModel,
              HouseholdMemberSearchModel>>();
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

      // Fetch all data
      final households =
          await householdRepo.search(HouseholdSearchModel(), userUuid);
      final tasks = await taskRepo.search(TaskSearchModel(
        createdBy: userUuid,
        projectId: projectId,
      ));

      // A household marked closed (Mark Closed Household or a declined
      // consent) isn't a real registration yet - just a placeholder with
      // nothing captured. It should only start counting once reopened and
      // completed, which moves its task off CLOSED_HOUSEHOLD status (see
      // the HOUSEHOLD flow's isEdit && isClosedHousehold branch). Resolve
      // each household's own task chain (household -> projectBeneficiary ->
      // task) to check its current status.
      //
      // A ProjectBeneficiary can point at the head INDIVIDUAL rather than
      // the household (the beneficiaryType switch in every registration
      // transformer), so the members are needed to trace it back. Without
      // this the chain broke, isHouseholdStillClosed silently returned false
      // and every closed household was counted as a real registration - the
      // Summary Report reading 11 for 10 real households.
      final householdRefs =
          households.map((hh) => hh.clientReferenceId).toList();
      final members = householdRefs.isEmpty
          ? <HouseholdMemberModel>[]
          : await householdMemberRepo.search(HouseholdMemberSearchModel(
              householdClientReferenceId: householdRefs,
            ));
      final householdRefByIndividualRef =
          householdClientRefByIndividualClientRef(members);

      final projectBeneficiaries = householdRefs.isEmpty
          ? <ProjectBeneficiaryModel>[]
          : await projectBeneficiaryRepo.search(ProjectBeneficiarySearchModel(
              beneficiaryClientReferenceId: [
                ...householdRefs,
                ...householdRefByIndividualRef.keys,
              ],
            ));
      final projectBeneficiaryClientRefsByHousehold =
          groupProjectBeneficiaryClientRefsByHousehold(
        projectBeneficiaries,
        householdClientRefByIndividualClientRef: householdRefByIndividualRef,
      );
      final tasksByProjectBeneficiaryClientRef =
          groupTasksByProjectBeneficiaryClientRef(tasks);

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

      // Local household registrations by date, reconciled against the server
      // snapshot rather than summed on top of it.
      //
      // home.dart's completedSync handler calls
      // _refreshSummaryReportAfterSync() after EVERY sync, so the snapshot is
      // re-pulled and then DOES include households this device already
      // pushed. Adding the local table on top counted each of them twice -
      // three registrations read as six.
      //
      // Split local households by whether the server already knows about
      // them. HouseholdModel.id stays null until a sync-up round trip writes
      // the server-generated id back onto the local row (sync_service_mapper,
      // DataModelType.household case), so `id != null` means "the server
      // aggregate below already counts this one". Dedupe by
      // clientReferenceId as well, so a household is one unit regardless of
      // how many rows reference it.
      //
      // Neither addend alone is correct. Summing both double-counts every
      // synced household (3 local + 3 in the aggregate read as 6). Excluding
      // the synced ones outright makes the count jump backwards during the
      // window where the id has been written locally but the server's
      // aggregate has not caught up yet. The row build below therefore takes
      // max(serverAggregate, localAlreadySynced) + localNotYetSynced, which
      // is both duplicate-free and monotonic.
      final localHouseholdsRegisteredByDate = <String, int>{};
      final localPeopleInHouseholdsByDate = <String, int>{};
      final localSyncedHouseholdsByDate = <String, int>{};
      final localSyncedPeopleByDate = <String, int>{};
      final countedHouseholdClientRefs = <String>{};
      for (final hh in households) {
        final createdBy =
            hh.clientAuditDetails?.createdBy ?? hh.auditDetails?.createdBy;
        if (createdBy != userUuid) continue;
        // Distinctness by clientReferenceId keeps a household that has
        // several rows referencing it counted as one unit.
        if (!countedHouseholdClientRefs.add(hh.clientReferenceId)) {
          continue;
        }
        final epochMs =
            hh.clientAuditDetails?.createdTime ?? hh.auditDetails?.createdTime;
        if (!isWithinCurrentCycle(epochMs)) {
          continue;
        }
        if (epochMs == null) continue;
        if (isHouseholdStillClosed(
          householdClientReferenceId: hh.clientReferenceId,
          projectBeneficiaryClientRefsByHousehold:
              projectBeneficiaryClientRefsByHousehold,
          tasksByProjectBeneficiaryClientRef:
              tasksByProjectBeneficiaryClientRef,
        )) {
          continue;
        }

        final date = _epochToDateString(epochMs);
        if (hh.id != null) {
          localSyncedHouseholdsByDate[date] =
              (localSyncedHouseholdsByDate[date] ?? 0) + 1;
          localSyncedPeopleByDate[date] =
              (localSyncedPeopleByDate[date] ?? 0) + (hh.memberCount ?? 0);
        } else {
          localHouseholdsRegisteredByDate[date] =
              (localHouseholdsRegisteredByDate[date] ?? 0) + 1;
          localPeopleInHouseholdsByDate[date] =
              (localPeopleInHouseholdsByDate[date] ?? 0) + (hh.memberCount ?? 0);
        }
      }

      // Local ITN distributed by date (same reasoning as households above).
      final localITNByDate = <String, int>{};
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
        // Baselines, not live totals: the live count grows to include this
        // device's own synced households, so adding local rows to it
        // double-counts. The local count is passed in because a baseline may
        // only be recorded for a date this device has no rows for - see
        // baselineFor.
        final localForDate = (localSyncedHouseholdsByDate[date] ?? 0) +
            (localHouseholdsRegisteredByDate[date] ?? 0);
        final baseline = await summaryReportService.baselineFor(
          date: date,
          localHouseholdCount: localForDate,
        );
        final int serverReportHouseholdRegistration = baseline.households;
        final int serverReportPeopleInHouseholds = baseline.people;
        int serverReportITNDistributed =
            await summaryReportService.itnsDistributed(date: date);

        // The server side is an opaque aggregate, not a list of
        // clientReferenceIds, so the de-duplication above cannot reach into
        // it. max() is what keeps an already-synced household from being
        // counted once by each side while still never reading lower than
        // what the device itself knows it has registered.
        // Every local household for the date counts, synced or not: the
        // baseline above deliberately excludes them all.
        final syncedHouseholds = localSyncedHouseholdsByDate[date] ?? 0;
        final syncedPeople = localSyncedPeopleByDate[date] ?? 0;

        final hhCount = serverReportHouseholdRegistration +
            syncedHouseholds +
            (localHouseholdsRegisteredByDate[date] ?? 0);
        final dailyPeopleCount = serverReportPeopleInHouseholds +
            syncedPeople +
            (localPeopleInHouseholdsByDate[date] ?? 0);
        final dailyITNCount =
            serverReportITNDistributed + (localITNByDate[date] ?? 0);

        rows.add(_SummaryReportRow(
          date: date,
          householdsRegistered: hhCount,
          numberOfPeopleInHouseholds: dailyPeopleCount,
          numberOfITNDistributed: dailyITNCount,
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

    // Distributor summary is limited to the ITNs distributed. Stock loss,
    // excess, and less are available through their transaction reports.
    // Registrar sees household and people counts.
    final isDistributor = context.loggedInUserRoles
        .any((role) => role.code == RolesType.distributor.toValue());

    final columns = isDistributor
        ? <CustomTableColumn>[
            CustomTableColumn(
              header: localizations.translate(i18.summaryReport.dateColumn),
            ),
            CustomTableColumn(
              header: localizations
                  .translate(i18.summaryReport.numberOfITNDistributed),
            ),
            // Households Registered / Number of People in Households dropped
            // for Distributor - those figures belong to the Registrar's
            // registration flow, not distribution.
          ]
        : <CustomTableColumn>[
            CustomTableColumn(
              header: localizations.translate(i18.summaryReport.dateColumn),
            ),
            CustomTableColumn(
              header: localizations
                  .translate(i18.summaryReport.householdsRegistered),
            ),
            CustomTableColumn(
              header: localizations
                  .translate(i18.summaryReport.numberOfPeopleInHouseholds),
            ),
          ];

    // Build rows
    final rows = _reportRows.map((row) {
      return CustomTableRow(
        isDistributor
            ? [
                _formatDisplayDate(row.date),
                row.numberOfITNDistributed.toString(),
              ]
            : [
                _formatDisplayDate(row.date),
                row.householdsRegistered.toString(),
                row.numberOfPeopleInHouseholds.toString(),
              ],
      );
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

  _SummaryReportRow({
    required this.date,
    required this.householdsRegistered,
    required this.numberOfPeopleInHouseholds,
    required this.numberOfITNDistributed,
  });
}
