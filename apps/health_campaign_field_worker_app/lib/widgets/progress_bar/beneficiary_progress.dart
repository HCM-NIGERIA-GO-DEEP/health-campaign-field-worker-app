import 'dart:math';

import 'package:collection/collection.dart';
import 'package:digit_data_model/data/repositories/package_repository/local/household.dart';
import 'package:digit_data_model/data/repositories/package_repository/local/project_beneficiary.dart';
import 'package:digit_data_model/data/repositories/package_repository/local/task.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/theme/spacers.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../data/services/server_summary_report_service.dart';
import '../../utils/utils.dart';
import '../progress_indicator/progress_indicator.dart';

class BeneficiaryProgressBar extends StatefulWidget {
  final String label;
  final String prefixLabel;

  const BeneficiaryProgressBar({
    super.key,
    required this.label,
    required this.prefixLabel,
  });

  @override
  State<BeneficiaryProgressBar> createState() => BeneficiaryProgressBarState();
}

class BeneficiaryProgressBarState extends State<BeneficiaryProgressBar> {
  int current = 0;

  // didChangeDependencies can fire more than once for the same State, and
  // listenToChanges hands back no subscription to cancel - without this
  // guard every re-entry stacks another live watch() on the same table.
  bool _listenersAttached = false;

  @override
  void didChangeDependencies() {
    if (_listenersAttached) {
      super.didChangeDependencies();
      return;
    }
    _listenersAttached = true;

    final isRegistrar = context.isRegistrarRole;
    final isDistributor = context.isDistributorRole;
    final taskRepository =
        context.read<LocalRepository<TaskModel, TaskSearchModel>>()
            as TaskLocalRepository;

    final projectId = context.projectId;
    final loggedInUserUuid = context.loggedInUserUuid;

    final now = DateTime.now();
    final gte = DateTime(
      now.year,
      now.month,
      now.day,
    );
    final lte = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
      59,
      999,
    );

    // Registering a household creates no ADMINISTRATION_SUCCESS task, so a
    // Registrar's bar - whose value is computed inside this body - never
    // recomputed after the first build: the task watch simply never fired.
    // That is why a completed normal registration left the bar frozen.
    // Extracted so both the Task watch (deliveries) and the
    // ProjectBeneficiary watch (registrations, created at registration
    // time) can drive it.
    Future<void> recompute() async {
        if (mounted) {
          final now = DateTime.now();
          final gte = DateTime(
            now.year,
            now.month,
            now.day,
          );
          final lte = DateTime(
            now.year,
            now.month,
            now.day,
            23,
            59,
            59,
            999,
          );
          TaskSearchModel taskSearchQuery = TaskSearchModel(
            status: 'ADMINISTRATION_SUCCESS',
            createdBy: loggedInUserUuid,
            plannedEndDate: lte.millisecondsSinceEpoch,
            plannedStartDate: gte.millisecondsSinceEpoch,
            projectId: projectId,
          );

          final summaryReportService =
              context.read<ServerSummaryReportService>();
          int? serverReportTimestamp = await summaryReportService.timestamp();
          final todayKey = DateFormat('yyyy-MM-dd').format(now);

          // The server-side snapshot above is a point-in-time baseline that
          // doesn't get refreshed same-day once any local registration
          // exists (see _loadSummaryReportData's hasHouseholdDataForCycle
          // check), so a household registered - or a closed/declined one
          // completed - today never shows up in it. Count today's local
          // households directly instead, the same way the Summary Report
          // page does, excluding ones still marked closed (a placeholder,
          // not a real registration yet).
          final householdRepository = context
              .read<LocalRepository<HouseholdModel, HouseholdSearchModel>>();
          final projectBeneficiaryRepository = context.read<
              LocalRepository<ProjectBeneficiaryModel,
                  ProjectBeneficiarySearchModel>>();

          final todaysHouseholds =
              await householdRepository.search(HouseholdSearchModel());
          final localHouseholdsToday = todaysHouseholds.where((hh) {
            final createdBy =
                hh.clientAuditDetails?.createdBy ?? hh.auditDetails?.createdBy;
            if (createdBy != loggedInUserUuid) return false;
            final epochMs = hh.clientAuditDetails?.createdTime ??
                hh.auditDetails?.createdTime;
            if (epochMs == null) return false;
            return epochMs >= gte.millisecondsSinceEpoch &&
                epochMs <= lte.millisecondsSinceEpoch;
          }).toList();

          // A ProjectBeneficiary can point at the head INDIVIDUAL rather
          // than the household (the beneficiaryType switch in every
          // registration transformer), so the members are needed to trace
          // it back. Without this the household -> projectBeneficiary ->
          // task chain broke, isHouseholdStillClosed silently returned
          // false, and a Mark Closed Household placeholder counted as a
          // real registration.
          final memberRepository = context.read<
              LocalRepository<HouseholdMemberModel,
                  HouseholdMemberSearchModel>>();
          final todaysHouseholdRefs =
              localHouseholdsToday.map((hh) => hh.clientReferenceId).toList();
          final todaysMembers = todaysHouseholdRefs.isEmpty
              ? <HouseholdMemberModel>[]
              : await memberRepository.search(HouseholdMemberSearchModel(
                  householdClientReferenceId: todaysHouseholdRefs,
                ));
          final householdRefByIndividualRef =
              householdClientRefByIndividualClientRef(todaysMembers);

          // Search by household refs AND the member individual refs, so the
          // lookup finds the ProjectBeneficiary whichever of the two it
          // points at.
          final todaysProjectBeneficiaries = todaysHouseholdRefs.isEmpty
              ? <ProjectBeneficiaryModel>[]
              : await projectBeneficiaryRepository.search(
                  ProjectBeneficiarySearchModel(
                    beneficiaryClientReferenceId: [
                      ...todaysHouseholdRefs,
                      ...householdRefByIndividualRef.keys,
                    ],
                  ),
                );
          final projectBeneficiaryClientRefsByHousehold =
              groupProjectBeneficiaryClientRefsByHousehold(
            todaysProjectBeneficiaries,
            householdClientRefByIndividualClientRef:
                householdRefByIndividualRef,
          );
          final tasksByProjectBeneficiaryClientRefForToday =
              groupTasksByProjectBeneficiaryClientRef(
                  await taskRepository.search(TaskSearchModel(
            projectId: projectId,
          )));

          var closedHouseholdsAlreadyInServerCount = 0;
          final openHouseholdsToday = localHouseholdsToday.where((hh) {
            final createdTime = hh.clientAuditDetails?.createdTime ??
                hh.auditDetails?.createdTime;
            final isClosedPlaceholder = isHouseholdConsentDeclined(hh) ||
                isHouseholdStillClosed(
                  householdClientReferenceId: hh.clientReferenceId,
                  projectBeneficiaryClientRefsByHousehold:
                      projectBeneficiaryClientRefsByHousehold,
                  tasksByProjectBeneficiaryClientRef:
                      tasksByProjectBeneficiaryClientRefForToday,
                );
            final isInServerSnapshot = serverReportTimestamp != null &&
                createdTime != null &&
                createdTime <= serverReportTimestamp;
            if (isClosedPlaceholder) {
              if (isInServerSnapshot) {
                closedHouseholdsAlreadyInServerCount++;
              }
              return false;
            }
            // Every other household registered today is counted locally.
            // Do NOT try to infer "already in the server snapshot" from
            // createdTime <= serverReportTimestamp: a reopened household
            // keeps the createdTime of the placeholder it started as, so
            // that test silently dropped real registrations and the bar
            // under-counted.
            return true;
          }).toList();

          // Split on whether the server aggregate already counts them.
          // HouseholdModel.id stays null until a sync-up round trip writes
          // the server-generated id back onto the local row, so `id != null`
          // means "already inside houseHoldRegistered".
          //
          // Summing both sides double-counts every synced household (a
          // capture showed serverHouseholds=6/adjustedServer=5 plus
          // localHouseholds=6 giving 11 where the answer was 6), while
          // excluding the synced ones makes the bar run backwards whenever
          // the server aggregate lags the local rows. max() is both
          // duplicate-free and monotonic. This rule must stay identical to
          // the Summary Report's so the two surfaces cannot disagree.
          // Baseline, not the live total: the live count grows to include
          // this device's own synced households, so adding local rows to it
          // double-counts (capture: adjustedServer=11 + 1 unsynced = 12 for
          // 11 real households), while reconciling with max() drops rows
          // whenever the backend aggregate lags the push. The local count is
          // passed in because a baseline may only be recorded for a date
          // this device holds no rows for - the one moment the server total
          // cannot already include something of ours.
          final baseline = await summaryReportService.baselineFor(
            date: todayKey,
            localHouseholdCount: localHouseholdsToday.length,
          );
          final houseHoldRegistered = baseline.households;

          final syncedHouseholdsToday = openHouseholdsToday
              .where((hh) => hh.id != null)
              .map((hh) => hh.clientReferenceId)
              .toSet()
              .length;
          final unsyncedHouseholdsToday = openHouseholdsToday
              .where((hh) => hh.id == null)
              .map((hh) => hh.clientReferenceId)
              .toSet()
              .length;

          List<TaskModel> allTasks =
              await taskRepository.search(taskSearchQuery);

          // Scope to today's own deliveries by creation window (same approach
          // as localHouseholdsRegisteredToday/Summary Report), instead of
          // comparing auditDetails.lastModifiedTime against a server
          // snapshot timestamp. That comparison excluded any task still
          // missing synced server auditDetails (every freshly-created local
          // delivery, until it syncs) and any task older than a timestamp
          // that shifts as new snapshots land (e.g. right after Mark Closed
          // Household triggers a snapshot refresh) - which is why the bar
          // would advance once and then stop, or drop back to 0.
          List<TaskModel> filteredTasks = allTasks.where((task) {
            final createdBy = task.clientAuditDetails?.createdBy ??
                task.auditDetails?.createdBy;
            if (createdBy != loggedInUserUuid) return false;
            final epochMs = task.clientAuditDetails?.createdTime ??
                task.auditDetails?.createdTime;
            if (epochMs == null) return false;
            return epochMs >= gte.millisecondsSinceEpoch &&
                epochMs <= lte.millisecondsSinceEpoch;
          }).toList();
          List<TaskModel> results = filteredTasks.where((task) {
            final additionalFields = task.additionalFields?.fields;
            if (additionalFields == null || additionalFields.isEmpty) {
              return false;
            } else
              return true;
          }).toList();
          // Count every delivered task, not distinct beneficiary groups - a
          // beneficiary visited more than once in a day (e.g. re-delivery)
          // must add to the bar each time, and tasks missing a beneficiary
          // reference must each count individually instead of collapsing
          // into one shared `null` bucket.
          final deliveredCount = results.length;
          if (mounted) {
            setState(() {
              if (mounted) {
                // Registrar-only progress measures completed household
                // registrations. Any user who distributes (distributor-only
                // or combined) progresses only after a successful delivery.
                // Non-nullable now that this comes from baselineFor().
                final serverHouseholdCount = houseHoldRegistered;
                final adjustedServerCount =
                    serverHouseholdCount > closedHouseholdsAlreadyInServerCount
                        ? serverHouseholdCount -
                            closedHouseholdsAlreadyInServerCount
                        : 0;
                // Every open household registered today counts on top of
                // the baseline, synced or not - the baseline deliberately
                // excludes them all. Must stay identical to the Summary
                // Report's rule so the two surfaces cannot disagree.
                final registeredToday = adjustedServerCount +
                    syncedHouseholdsToday +
                    unsyncedHouseholdsToday;
                current = isRegistrar && !isDistributor
                    ? registeredToday
                    : deliveredCount;
              }
            });
          }
        }
    }

    taskRepository.listenToChanges(
      query: TaskSearchModel(
        status: 'ADMINISTRATION_SUCCESS',
        projectId: projectId,
        createdBy: loggedInUserUuid,
        plannedEndDate: lte.millisecondsSinceEpoch,
        plannedStartDate: gte.millisecondsSinceEpoch,
      ),
      listener: (_) => recompute(),
    );

    (context.read<
                LocalRepository<ProjectBeneficiaryModel,
                    ProjectBeneficiarySearchModel>>()
            as ProjectBeneficiaryLocalRepository)
        .listenToChanges(
      query: ProjectBeneficiarySearchModel(projectId: [projectId]),
      listener: (_) => recompute(),
    );

    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final selectedProject = context.selectedProject;
    final beneficiaryType = context.beneficiaryType;

    final targetModel = selectedProject.targets?.firstWhereOrNull(
      (element) => element.beneficiaryType == beneficiaryType.toValue(),
    );

    final target = targetModel?.targetNo ?? 0.0;

    return DigitCard(margin: const EdgeInsets.all(spacer2), children: [
      ProgressIndicatorContainer(
        label: '${max(target - current, 0).round()} ${widget.label}',
        prefixLabel: '$current ${widget.prefixLabel}',
        suffixLabel: target.toStringAsFixed(0),
        value: target == 0 ? 0 : min(current / target, 1),
      ),
    ]);
  }
}
