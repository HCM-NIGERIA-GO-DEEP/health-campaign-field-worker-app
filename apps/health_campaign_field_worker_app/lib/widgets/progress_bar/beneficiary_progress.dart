import 'dart:math';

import 'package:collection/collection.dart';
import 'package:digit_data_model/data/repositories/package_repository/local/task.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/theme/spacers.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/utils.dart';
import '../progress_indicator/progress_indicator.dart';

class BeneficiaryProgressBar extends StatefulWidget {
  final String label;
  final String dosePrefixLabel;
  final String itnPrefixLabel;

  const BeneficiaryProgressBar({
    super.key,
    required this.label,
    required this.dosePrefixLabel,
    required this.itnPrefixLabel,
  });

  @override
  State<BeneficiaryProgressBar> createState() => BeneficiaryProgressBarState();
}

class BeneficiaryProgressBarState extends State<BeneficiaryProgressBar> {
  int current = 0;
  int itnCurrent = 0;

  static String? _taskType(TaskModel task) =>
      task.additionalFields?.fields
          .firstWhereOrNull((f) => f.key == 'taskType')
          ?.value;

  static bool _isItnDeliveryTask(TaskModel task) {
    final taskType = _taskType(task);
    return taskType == 'ITN_DELIVERY' || taskType == 'ITN_DELIVERED';
  }

  static int _itnDeliveredQuantity(TaskModel task) {
    var total = 0.0;
    for (final res in task.resources ?? []) {
      if (res.isDelivered != true) continue;
      total += double.tryParse(res.quantity ?? '0') ?? 0.0;
    }
    return total.round();
  }

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

          List<TaskModel> allTasks =
              await taskRepository.search(taskSearchQuery);

          final doseTasks = allTasks.where((t) => !_isItnDeliveryTask(t));
          final groupedEntries = doseTasks.groupListsBy(
            (element) => element.projectBeneficiaryClientReferenceId,
          );

          var itnQuantity = 0;
          for (final task in allTasks) {
            if (!_isItnDeliveryTask(task)) continue;
            itnQuantity += _itnDeliveredQuantity(task);
          }

          if (mounted) {
            setState(() {
              current = groupedEntries.entries.length;
              itnCurrent = itnQuantity;
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
      if (context.isSmcPresent)
        ProgressIndicatorContainer(
          label: '${max(target - current, 0).round()} ${widget.label}',
          prefixLabel: '$current ${widget.dosePrefixLabel}',
          suffixLabel: target.toStringAsFixed(0),
          value: target == 0 ? 0 : min(current / target, 1),
        ),
      ProgressIndicatorContainer(
        label: '${max(target - itnCurrent, 0).round()} ${widget.label}',
        prefixLabel: '$itnCurrent ${widget.itnPrefixLabel}',
        suffixLabel: target.toStringAsFixed(0),
        value: target == 0 ? 0 : min(itnCurrent / target, 1),
      ),
    ]);
  }
}
