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

  @override
  void didChangeDependencies() {
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

      final now = DateTime.now();
      final gte = DateTime(now.year, now.month, now.day);
      final lte = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

      taskRepository.listenToChanges(
        query: TaskSearchModel(
          status: 'ADMINISTRATION_SUCCESS',
          projectId: projectId,
          createdBy: loggedInUserUuid,
          plannedEndDate: lte.millisecondsSinceEpoch,
          plannedStartDate: gte.millisecondsSinceEpoch,
        ),
        listener: (taskData) async {
          if (!mounted) return;
          final results = taskData.where((task) {
            final additionalFields = task.additionalFields?.fields;
            return additionalFields != null && additionalFields.isNotEmpty;
          }).toList();
          final groupedEntries = results.groupListsBy(
            (element) => element.projectBeneficiaryClientReferenceId,
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

    projectBeneficiaryRepository.listenToChanges(
      query: ProjectBeneficiarySearchModel(
        projectId: [projectId],
      ),
      listener: (_) async {
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

          final summaryReportService =
              context.read<ServerSummaryReportService>();
          int? houseHoldRegistered =
              await summaryReportService.householdRegistration(
            date: DateFormat('yyyy-MM-dd').format(now),
          );

          // The server-side snapshot above aggregates every device
          // registering against this project (not just this one), and
          // doesn't get refreshed same-day once any local registration
          // exists (see _loadSummaryReportData's hasHouseholdDataForCycle
          // check), so a household registered - or a closed/declined one
          // completed - today on THIS device never shows up in it yet.
          // Count today's local households on this device on top of that
          // snapshot, the same way the Summary Report page does, excluding
          // ones still marked closed (a placeholder, not a real
          // registration yet).
          final householdRepository = context
              .read<LocalRepository<HouseholdModel, HouseholdSearchModel>>();
          final taskRepository =
              context.read<LocalRepository<TaskModel, TaskSearchModel>>();

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

          final todaysProjectBeneficiaries = localHouseholdsToday.isEmpty
              ? <ProjectBeneficiaryModel>[]
              : await projectBeneficiaryRepository.search(
                  ProjectBeneficiarySearchModel(
                    beneficiaryClientReferenceId: localHouseholdsToday
                        .map((hh) => hh.clientReferenceId)
                        .toList(),
                  ),
                );
          final projectBeneficiaryClientRefsByHousehold =
              groupProjectBeneficiaryClientRefsByHousehold(
                  todaysProjectBeneficiaries);
          final tasksByProjectBeneficiaryClientRefForToday =
              groupTasksByProjectBeneficiaryClientRef(
                  await taskRepository.search(TaskSearchModel(
            createdBy: loggedInUserUuid,
            projectId: projectId,
          )));

          final localHouseholdsRegisteredToday = localHouseholdsToday
              .where((hh) => !isHouseholdStillClosed(
                    householdClientReferenceId: hh.clientReferenceId,
                    projectBeneficiaryClientRefsByHousehold:
                        projectBeneficiaryClientRefsByHousehold,
                    tasksByProjectBeneficiaryClientRef:
                        tasksByProjectBeneficiaryClientRefForToday,
                  ))
              .length;

          if (mounted) {
            setState(() {
              current = houseHoldRegistered + localHouseholdsRegisteredToday;
            });
          }
        }
      },
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
