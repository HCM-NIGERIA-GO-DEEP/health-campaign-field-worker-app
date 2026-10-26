import 'dart:math';

import 'package:collection/collection.dart';
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
  // listenToChanges hands back no subscription to cancel - without this guard
  // every re-entry stacks another live watch() on the same table.
  bool _listenersAttached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_listenersAttached) return;
    _listenersAttached = true;

    final projectId = context.projectId;
    final loggedInUserUuid = context.loggedInUserUuid;
    final isDistributor = context.isDistributorRole;

    // Registrar's count (households registered) never touches the task
    // table - registering a household doesn't create a TaskModel row - so
    // listening only to TaskLocalRepository (as this used to, unconditionally)
    // meant a Registrar's bar only ever reflected whatever was true at the
    // very first build and never recomputed afterwards. ProjectBeneficiary is
    // created at registration time instead, and its own listenToChanges is a
    // live Drift watch() stream, same as Task's - this fires on every new
    // registration. Distributor keeps listening to Task, since delivering to
    // a household does create one, and that path already updated live.
    if (isDistributor) {
      final taskRepository =
          context.read<LocalRepository<TaskModel, TaskSearchModel>>()
              as TaskLocalRepository;

      taskRepository.listenToChanges(
        query: TaskSearchModel(
          projectId: projectId,
        ),
        listener: (taskData) async {
          if (!mounted) return;
          final now = DateTime.now();
          final startOfToday = DateTime(now.year, now.month, now.day)
              .millisecondsSinceEpoch;
          final startOfTomorrow =
              DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
          final results = taskData.where((task) {
            final createdBy = task.clientAuditDetails?.createdBy ??
                task.auditDetails?.createdBy;
            final createdTime = task.clientAuditDetails?.createdTime ??
                task.auditDetails?.createdTime;

            return task.status == 'ADMINISTRATION_SUCCESS' &&
                createdBy == loggedInUserUuid &&
                createdTime != null &&
                createdTime >= startOfToday &&
                createdTime < startOfTomorrow;
          }).toList();
          final groupedEntries = results.groupListsBy(
            (element) => element.projectBeneficiaryClientReferenceId ??
                element.clientReferenceId,
          );
          if (mounted) {
            setState(() {
              // Distinct households delivered to today, NOT total ITN units
              // distributed - a household receiving 2 nets still counts once.
              current = groupedEntries.entries.length;
            });
          }
        },
      );
      return;
    }

    final projectBeneficiaryRepository = context.read<
            LocalRepository<ProjectBeneficiaryModel,
                ProjectBeneficiarySearchModel>>()
        as ProjectBeneficiaryLocalRepository;

    // Reopening a closed household (the HOUSEHOLD flow's
    // isEdit && isClosedHousehold branch) is a pure UPDATE_EVENT on
    // Household/Individual/Task - it writes no project_beneficiary row, so
    // the ProjectBeneficiary watch alone never fired and the bar stayed
    // stale until the *next* registration created a PB row, at which point
    // it jumped by two. That reopen does move the task off CLOSED_HOUSEHOLD,
    // so watching the task table too closes the gap. Both listeners run the
    // same recompute; whichever fires first wins and the other is a no-op.
    void recompute() => _recomputeRegistrarCount(
          projectId: projectId,
          loggedInUserUuid: loggedInUserUuid,
          projectBeneficiaryRepository: projectBeneficiaryRepository,
        );

    projectBeneficiaryRepository.listenToChanges(
      query: ProjectBeneficiarySearchModel(
        projectId: [projectId],
      ),
      listener: (_) => recompute(),
    );

    (context.read<LocalRepository<TaskModel, TaskSearchModel>>()
            as TaskLocalRepository)
        .listenToChanges(
      query: TaskSearchModel(projectId: projectId),
      listener: (_) => recompute(),
    );
  }

  Future<void> _recomputeRegistrarCount({
    required String projectId,
    required String loggedInUserUuid,
    required ProjectBeneficiaryLocalRepository projectBeneficiaryRepository,
  }) async {
    if (!mounted) return;

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

    // Resolve everything off the BuildContext up front, before the first
    // await, so nothing reads it across an async gap.
    final summaryReportService = context.read<ServerSummaryReportService>();
    final householdRepository =
        context.read<LocalRepository<HouseholdModel, HouseholdSearchModel>>();
    final taskRepository =
        context.read<LocalRepository<TaskModel, TaskSearchModel>>();
    final memberRepository = context.read<
        LocalRepository<HouseholdMemberModel, HouseholdMemberSearchModel>>();

    int houseHoldRegistered = await summaryReportService.householdRegistration(
      date: DateFormat('yyyy-MM-dd').format(now),
    );

    // The server-side snapshot above aggregates every device registering
    // against this project, so today's local households are added on top of
    // it.
    //
    // The previous `hh.id != null` guard here (meant to avoid double-counting
    // a household once it synced) is gone: it opened a window where a
    // just-synced household was dropped locally while the server's aggregate
    // had not caught up yet, so the bar visibly went BACKWARDS (10 -> 9).
    // Double-counting is now handled by counting distinct clientReferenceIds
    // only, which is also what the Summary Report does, so the two agree.
    final todaysHouseholds =
        await householdRepository.search(HouseholdSearchModel());
    final localHouseholdsToday = todaysHouseholds.where((hh) {
      final createdBy =
          hh.clientAuditDetails?.createdBy ?? hh.auditDetails?.createdBy;
      if (createdBy != loggedInUserUuid) return false;
      final epochMs =
          hh.clientAuditDetails?.createdTime ?? hh.auditDetails?.createdTime;
      if (epochMs == null) return false;
      return epochMs >= gte.millisecondsSinceEpoch &&
          epochMs <= lte.millisecondsSinceEpoch;
    }).toList();

    // A ProjectBeneficiary can point at the head INDIVIDUAL rather than the
    // household (the beneficiaryType switch in every registration
    // transformer), so the members are needed to trace it back. Without this
    // the household -> projectBeneficiary -> task chain broke,
    // isHouseholdStillClosed silently returned false, and every closed /
    // consent-declined household was counted as a real registration.
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
    // lookup finds the ProjectBeneficiary whichever of the two it points at.
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
      householdClientRefByIndividualClientRef: householdRefByIndividualRef,
    );
    final tasksByProjectBeneficiaryClientRefForToday =
        groupTasksByProjectBeneficiaryClientRef(
            await taskRepository.search(TaskSearchModel(
      createdBy: loggedInUserUuid,
      projectId: projectId,
    )));

    // Distinct households, not rows - a household with several
    // ProjectBeneficiary/Task rows must still count once.
    final localHouseholdsRegisteredToday = localHouseholdsToday
        .where((hh) => !isHouseholdStillClosed(
              householdClientReferenceId: hh.clientReferenceId,
              projectBeneficiaryClientRefsByHousehold:
                  projectBeneficiaryClientRefsByHousehold,
              tasksByProjectBeneficiaryClientRef:
                  tasksByProjectBeneficiaryClientRefForToday,
            ))
        .map((hh) => hh.clientReferenceId)
        .toSet()
        .length;

    if (mounted) {
      setState(() {
        current = houseHoldRegistered + localHouseholdsRegisteredToday;
      });
    }
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
