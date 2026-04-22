import 'dart:math';

import 'package:collection/collection.dart';
import '../../data/registration_deliver_repo/local/task.dart';
import 'package:digit_data_model/data_model.dart';
import '../../models/registration_deliver_model/entities/status.dart';
import 'package:digit_ui_components/theme/spacers.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    // final repository = context.read<
    //         LocalRepository<ProjectBeneficiaryModel,
    //             ProjectBeneficiarySearchModel>>()
    //     as ProjectBeneficiaryLocalRepository;
    final repository =
        context.read<LocalRepository<TaskModel, TaskSearchModel>>()
            as TaskLocalRepository;

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

    repository.listenToChanges(
      query: TaskSearchModel(
        projectId: context.projectId.toString(),
      ),
      listener: (data) {
        if (mounted) {
          setState(() {
            current = data
                .where((element) =>
                    (element.clientAuditDetails?.createdTime != null &&
                        DateTime.fromMillisecondsSinceEpoch(
                          element.clientAuditDetails!.createdTime,
                        ).isAfter(gte) &&
                        DateTime.fromMillisecondsSinceEpoch(
                          element.clientAuditDetails!.createdTime,
                        ).isBefore(lte)) &&
                    (element.isDeleted == false || element.isDeleted == null) &&
                    element.status == Status.administeredSuccess.toValue() &&
                    element.createdBy ==
                        RegistrationDeliverySingleton().loggedInUserUuid)
                .length;
          });
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
