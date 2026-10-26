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
      final isDistributor = context.loggedInUserRoles
          .any((role) => role.code == RolesType.distributor.toValue());
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
      final projectBeneficiaryRepo = context.read<
          LocalRepository<ProjectBeneficiaryModel,
              ProjectBeneficiarySearchModel>>();
      final householdMemberRepo = context.read<
          LocalRepository<HouseholdMemberModel,
              HouseholdMemberSearchModel>>();
      final summaryReportService = context.read<ServerSummaryReportService>();
      List<String> serverReportAllDates = await summaryReportService.allDates();
      final serverReportTimestamp = await summaryReportService.timestamp();

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
      // this the chain broke, isHouseholdStillClosed silently returned
      // false, and a Mark Closed Household placeholder counted as a real
      // registration. Mirrors the Beneficiary Progress bar exactly so the
      // two surfaces cannot disagree.
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

      // Local household registrations by date. The server summary is a
      // cached point-in-time baseline: add eligible local registrations made
      // after it, and remove any closed placeholders already included in it.
      final localHouseholdsRegisteredByDate = <String, int>{};
      final localPeopleInHouseholdsByDate = <String, int>{};
      final localChildrenUnder5ByDate = <String, int>{};
      final closedHouseholdsInServerReportByDate = <String, int>{};
      final closedHouseholdMembersInServerReportByDate = <String, int>{};
      final closedHouseholdChildrenUnder5InServerReportByDate = <String, int>{};
      for (final hh in households) {
        final createdBy =
            hh.clientAuditDetails?.createdBy ?? hh.auditDetails?.createdBy;
        if (createdBy != userUuid) continue;
        final epochMs =
            hh.clientAuditDetails?.createdTime ?? hh.auditDetails?.createdTime;
        if (!isWithinCurrentCycle(epochMs)) continue;
        if (epochMs == null) continue;
        final isClosedPlaceholder = isHouseholdConsentDeclined(hh) ||
            isHouseholdStillClosed(
          householdClientReferenceId: hh.clientReferenceId,
          projectBeneficiaryClientRefsByHousehold:
              projectBeneficiaryClientRefsByHousehold,
          tasksByProjectBeneficiaryClientRef:
              tasksByProjectBeneficiaryClientRef,
        );
        final isInServerSnapshot =
            serverReportTimestamp != null && epochMs <= serverReportTimestamp;
        if (isClosedPlaceholder) {
          // The server summary is a cached baseline. If this placeholder
          // predates that snapshot, its counts are already included there and
          // must be removed from the displayed totals as well.
          if (isInServerSnapshot) {
            final date = _epochToDateString(epochMs);
            closedHouseholdsInServerReportByDate[date] =
                (closedHouseholdsInServerReportByDate[date] ?? 0) + 1;
            closedHouseholdMembersInServerReportByDate[date] =
                (closedHouseholdMembersInServerReportByDate[date] ?? 0) +
                    (hh.memberCount ?? 0);
            closedHouseholdChildrenUnder5InServerReportByDate[date] =
                (closedHouseholdChildrenUnder5InServerReportByDate[date] ??
                        0) +
                    householdChildrenUnder5Count(hh);
          }
          continue;
        }

        // Every other household in the cycle is counted locally. Do NOT skip
        // on epochMs <= serverReportTimestamp: a reopened household keeps the
        // createdTime of the closed placeholder it started as, so that test
        // dropped real registrations - the row for the current date could
        // disappear entirely.
        final date = _epochToDateString(epochMs);
        localChildrenUnder5ByDate[date] =
            (localChildrenUnder5ByDate[date] ?? 0) +
                householdChildrenUnder5Count(hh);
        localHouseholdsRegisteredByDate[date] =
            (localHouseholdsRegisteredByDate[date] ?? 0) + 1;
        localPeopleInHouseholdsByDate[date] =
            (localPeopleInHouseholdsByDate[date] ?? 0) + (hh.memberCount ?? 0);
      }

      // Local ITN distributed by date (same reasoning as households above).
      final localITNByDate = <String, int>{};
      for (final task in tasks) {
        if (task.status != 'ADMINISTRATION_SUCCESS' &&
            task.status != 'VISITED') {
          continue;
        }
        final createdBy =
            task.clientAuditDetails?.createdBy ?? task.auditDetails?.createdBy;
        if (createdBy != userUuid) {
          continue;
        }
        final epochMs = task.clientAuditDetails?.createdTime ??
            task.auditDetails?.createdTime;
        if (!isWithinCurrentCycle(epochMs)) {
          continue;
        }
        if (epochMs == null) {
          continue;
        }
        final date = _epochToDateString(epochMs);

        final resources = task.resources;
        if (resources == null) {
          continue;
        }
        for (final res in resources) {
          final pvId = res.productVariantId;
          if (pvId == null || pvId.isEmpty) {
            continue;
          }
          final qty = (double.tryParse(res.quantity ?? '0') ?? 0).toInt();
          localITNByDate[date] = (localITNByDate[date] ?? 0) + qty;
        }
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
        if (createdBy != userUuid) {
          continue;
        }
        final epochMs = task.clientAuditDetails?.createdTime ??
            task.auditDetails?.createdTime;
        if (!isWithinCurrentCycle(epochMs)) {
          continue;
        }
        if (epochMs == null) {
          continue;
        }
        final date = _epochToDateString(epochMs);
        final resources = task.resources;
        if (resources == null) {
          continue;
        }
        for (final res in resources) {
          final pvId = res.productVariantId;
          if (pvId == null || pvId.isEmpty) {
            continue;
          }
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
        ...localChildrenUnder5ByDate.keys,
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
        int serverReportChildrenUnder5 =
            await summaryReportService.childrenRegistered(date: date);

        final adjustedServerHouseholdCount =
            serverReportHouseholdRegistration -
                (closedHouseholdsInServerReportByDate[date] ?? 0);
        final adjustedServerPeopleCount = serverReportPeopleInHouseholds -
            (closedHouseholdMembersInServerReportByDate[date] ?? 0);
        final adjustedServerChildrenUnder5Count = serverReportChildrenUnder5 -
            (closedHouseholdChildrenUnder5InServerReportByDate[date] ?? 0);
        final hhCount =
            (adjustedServerHouseholdCount < 0 ? 0 : adjustedServerHouseholdCount) +
            (localHouseholdsRegisteredByDate[date] ?? 0);
        final dailyPeopleCount =
            (adjustedServerPeopleCount < 0 ? 0 : adjustedServerPeopleCount) +
            (localPeopleInHouseholdsByDate[date] ?? 0);
        final dailyChildrenUnder5Count = (adjustedServerChildrenUnder5Count < 0
                ? 0
                : adjustedServerChildrenUnder5Count) +
            (localChildrenUnder5ByDate[date] ?? 0);
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
          numberOfChildrenUnder5: dailyChildrenUnder5Count,
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

    // Distributors see ITNs distributed. Household/people counts are shown
    // only when the user also has the Registrar role. Loss/Excess columns are
    // dropped for both roles - commented out below (not deleted) so they
    // can be restored without rebuilding the totalLess/totalExcess
    // computation in _loadData().
    final isDistributor = context.loggedInUserRoles
        .any((role) => role.code == RolesType.distributor.toValue());
    final isRegistrar = context.loggedInUserRoles
        .any((role) => role.code == RolesType.registrar.toValue());

    final columns = isDistributor
        ? <CustomTableColumn>[
            CustomTableColumn(
              header: localizations.translate(i18.summaryReport.dateColumn),
            ),
            CustomTableColumn(
              header: localizations
                  .translate(i18.summaryReport.numberOfITNDistributed),
            ),
            if (isRegistrar) ...[
              CustomTableColumn(
                header: localizations
                    .translate(i18.summaryReport.householdsRegistered),
              ),
              CustomTableColumn(
                header: localizations
                    .translate(i18.summaryReport.numberOfPeopleInHouseholds),
              ),
              CustomTableColumn(
                header: localizations
                    .translate(i18.summaryReport.numberOfChildrenUnder5),
              ),
            ],
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
            // Children under 5 is a registration metric, so it is shown only
            // to Registrars - matching the isRegistrar gate on the
            // distributor branch above.
            if (isRegistrar)
              CustomTableColumn(
                header: localizations
                    .translate(i18.summaryReport.numberOfChildrenUnder5),
              ),
          ];
    // CustomTableColumn(header: localizations.translate(i18.common.loss)),
    // CustomTableColumn(header: localizations.translate(i18.common.excess)),

    // Build rows
    final rows = _reportRows.map((row) {
      return CustomTableRow(
        isDistributor
            ? [
                _formatDisplayDate(row.date),
                row.numberOfITNDistributed.toString(),
                if (isRegistrar) ...[
                  row.householdsRegistered.toString(),
                  row.numberOfPeopleInHouseholds.toString(),
                  row.numberOfChildrenUnder5.toString(),
                ],
              ]
            : [
                _formatDisplayDate(row.date),
                row.householdsRegistered.toString(),
                row.numberOfPeopleInHouseholds.toString(),
                // Must mirror the isRegistrar gate on the columns above, or
                // the cells shift out of alignment with their headers.
                if (isRegistrar) row.numberOfChildrenUnder5.toString(),
              ],
        // row.totalLess.toStringAsFixed(0),
        // row.totalExcess.toStringAsFixed(0),
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
  final int numberOfChildrenUnder5;
  final int numberOfITNDistributed;
  // Kept (not removed) so the Loss/Excess columns, commented out below in
  // build(), can be restored later without rebuilding the computation.
  final double totalLess;
  final double totalExcess;

  _SummaryReportRow({
    required this.date,
    required this.householdsRegistered,
    required this.numberOfPeopleInHouseholds,
    required this.numberOfChildrenUnder5,
    required this.numberOfITNDistributed,
    required this.totalLess,
    required this.totalExcess,
  });
}
