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

  @override
  void didChangeDependencies() {
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

    taskRepository.listenToChanges(
      query: TaskSearchModel(
        status: 'ADMINISTRATION_SUCCESS',
        projectId: projectId,
        createdBy: loggedInUserUuid,
        plannedEndDate: lte.millisecondsSinceEpoch,
        plannedStartDate: gte.millisecondsSinceEpoch,
      ),
      listener: (taskData) async {
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
          int? houseHoldRegistered =
              await summaryReportService.householdRegistration(
            date: DateFormat('yyyy-MM-dd').format(now),
          );

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

          List<TaskModel> allTasks =
              await taskRepository.search(taskSearchQuery);

          List<TaskModel> filteredTasks = allTasks;
          if (serverReportTimestamp != null) {
            filteredTasks = filteredTasks
                .where((e) =>
                    e.auditDetails != null &&
                    e.auditDetails!.lastModifiedTime >= serverReportTimestamp)
                .toList();
          }
          List<TaskModel> results = filteredTasks.where((task) {
            final additionalFields = task?.additionalFields?.fields;
            if (additionalFields == null || additionalFields.isEmpty) {
              return false;
            } else
              return true;
          }).toList();
          final groupedEntries = results.groupListsBy(
            (element) => element.projectBeneficiaryClientReferenceId,
          );
          if (mounted) {
            setState(() {
              if (mounted) {
                current = houseHoldRegistered +
                    localHouseholdsRegisteredToday +
                    groupedEntries.entries.length;
              }
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
