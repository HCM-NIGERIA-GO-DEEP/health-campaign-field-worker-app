import 'dart:math';

import 'package:collection/collection.dart';
import 'package:digit_data_model/data/repositories/package_repository/local/task.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/theme/spacers.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../data/services/server_summary_report_service.dart';
import '../../utils/beneficiary_progress_count.dart';
import '../../utils/daily_delivery_limit.dart';
import '../../utils/summary_report_cutoff.dart';
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

  bool _listening = false;
  int _computeSeq = 0;

  late TaskLocalRepository _taskRepository;
  late ServerSummaryReportService _summaryReportService;
  late String _projectId;
  late String _loggedInUserUuid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Register exactly once — didChangeDependencies can re-run on inherited
    // widget changes and listenToChanges has no cancellation handle, so a
    // re-registration would leak duplicate DB watchers.
    if (_listening) return;
    _listening = true;

    _taskRepository = context.read<LocalRepository<TaskModel, TaskSearchModel>>()
        as TaskLocalRepository;
    _summaryReportService = context.read<ServerSummaryReportService>();
    _projectId = context.projectId;
    _loggedInUserUuid = context.loggedInUserUuid;

    // Recompute when the stored server summary report changes (post-login
    // downsync) — a report write never touches the task table, so the task
    // watch below would otherwise leave the bar stale until the next
    // delivery.
    _summaryReportService.revision.addListener(_onReportRevision);

    final now = DateTime.now();
    _taskRepository.listenToChanges(
      query: TaskSearchModel(
        status: 'ADMINISTRATION_SUCCESS',
        projectId: _projectId,
        createdBy: _loggedInUserUuid,
        plannedEndDate: _endOfDay(now).millisecondsSinceEpoch,
        plannedStartDate: _startOfDay(now).millisecondsSinceEpoch,
      ),
      listener: (taskData) {
        _recompute();
      },
    );
  }

  @override
  void dispose() {
    _summaryReportService.revision.removeListener(_onReportRevision);
    super.dispose();
  }

  void _onReportRevision() {
    _recompute();
  }

  DateTime _startOfDay(DateTime now) => DateTime(now.year, now.month, now.day);

  DateTime _endOfDay(DateTime now) =>
      DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

  Future<void> _recompute() async {
    if (!mounted) return;
    // A slower earlier computation must never overwrite a newer result
    // (each run awaits prefs + two DB queries, so overlap is real).
    final seq = ++_computeSeq;

    final now = DateTime.now();
    final gte = _startOfDay(now);
    final lte = _endOfDay(now);

    // Context is derived per call — the bar must never depend on the
    // one-shot initializeForContext in home.dart having completed, because
    // losing that race made the first computation of a session run with no
    // report cutoff and no server count (the "+8 after every app restart"
    // QA bug, 2026-08-07).
    final cycle = context.selectedCycle;

    int? serverReportCutoff;
    int serverChildrenToday = 0;

    if (cycle != null) {
      final storedTimeStamp =
          await _summaryReportService.readSummaryReportTimestamp(
        userUuid: _loggedInUserUuid,
        projectId: _projectId,
        cycleIndex: cycle.id,
      );
      serverReportCutoff = effectiveReportCutoff(
        storedTimeStamp: storedTimeStamp,
        cycleStartDate: cycle.startDate,
        now: now.millisecondsSinceEpoch,
      );
      final dayData = await _summaryReportService.readSummaryReportDayData(
        userUuid: _loggedInUserUuid,
        projectId: _projectId,
        cycleIndex: cycle.id,
        date: DateFormat('yyyy-MM-dd').format(now),
      );
      serverChildrenToday = parseReportInt(dayData?['childrenTreated']);
    }

    final List<TaskModel> allTasks = await _taskRepository.search(
      TaskSearchModel(
        status: 'ADMINISTRATION_SUCCESS',
        createdBy: _loggedInUserUuid,
        plannedEndDate: lte.millisecondsSinceEpoch,
        plannedStartDate: gte.millisecondsSinceEpoch,
        projectId: _projectId,
      ),
    );

    final todayCount = computeBeneficiaryProgressCount(
      tasks: allTasks
          .map((task) => BeneficiaryProgressTask(
                beneficiaryRef: task.projectBeneficiaryClientReferenceId,
                clientCreatedTime: task.clientAuditDetails?.createdTime,
                auditLastModifiedTime: task.auditDetails?.lastModifiedTime,
                hasAdditionalFields:
                    task.additionalFields?.fields.isNotEmpty ?? false,
              ))
          .toList(),
      windowStart: gte.millisecondsSinceEpoch,
      windowEnd: lte.millisecondsSinceEpoch,
      serverReportCutoff: serverReportCutoff,
      serverReportChildrenTreated: serverChildrenToday,
    );

    if (!mounted || seq != _computeSeq) return;

    // Published for fn:isDailyDeliveryLimitReached (delivery cap gate) —
    // the gate must always agree with what this bar displays.
    DailyDeliveryLimit.count = todayCount;
    setState(() {
      current = todayCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedProject = context.selectedProject;
    final beneficiaryType = context.beneficiaryType;

    final targetModel = selectedProject.targets?.firstWhereOrNull(
      (element) => element.beneficiaryType == beneficiaryType.toValue(),
    );

    const target = DailyDeliveryLimit.defaultTarget;
    //  targetModel?.targetNo ?? 0.0;

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
