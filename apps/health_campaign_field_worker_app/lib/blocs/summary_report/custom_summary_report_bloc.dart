import 'package:collection/collection.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/utils/date_utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../models/bednet_distribution/bednet_distribution_models.dart';
import '../../models/registration_deliver_model/entities/additional_fields_type.dart';
import '../../models/registration_deliver_model/entities/status.dart';
import '../../utils/utils.dart';

part 'custom_summary_report_bloc.freezed.dart';

typedef SummaryReportEmitter = Emitter<SummaryReportState>;

/// Reads task rows from the local SQLite store via the same
/// [LocalRepository] registered in [NetworkManagerProviderWrapper].
class SummaryReportBloc extends Bloc<SummaryReportEvent, SummaryReportState> {
  final LocalRepository<TaskModel, TaskSearchModel> taskLocalRepository;

  SummaryReportBloc({
    required this.taskLocalRepository,
  }) : super(const SummaryReportEmptyState()) {
    on<SummaryReportLoadDataEvent>(_handleLoadDataEvent);
    on<SummaryReportLoadingEvent>(_handleLoadingEvent);
  }

  /// Uses client modified time when present, else client created time (epoch ms).
  static String? _dateKeyFromClientAudit(ClientAuditDetails? audit) {
    if (audit == null) return null;
    final ms = audit.lastModifiedTime ?? audit.createdTime;
    return DigitDateUtils.getDateFromTimestamp(ms);
  }

  static int _readIntFromTaskFields(
    TaskAdditionalFields? additionalFields,
    List<String> keys,
  ) {
    final fields = additionalFields?.fields ?? const <AdditionalField>[];
    final map = {
      for (final f in fields) f.key.toLowerCase(): f.value,
    };
    for (final key in keys) {
      final raw = map[key.toLowerCase()];
      if (raw == null) continue;
      final v = int.tryParse(raw.toString());
      if (v != null) return v;
    }
    return 0;
  }

  /// Distinct schools per day for summary: prefer [kBednetTaskSchoolNameKey], else school client ref.
  static String? _schoolVisitedIdentityFromTask(TaskModel task) {
    final fields = task.additionalFields?.fields ?? const <AdditionalField>[];
    final map = {
      for (final f in fields) f.key.toLowerCase(): f.value,
    };
    for (final key in const [
      'schoolname',
      'schoolName',
      'schoolid',
      'schoolId',
      'school_name',
      'nameofphu',
    ]) {
      final raw = map[key.toLowerCase()];
      if (raw == null) continue;
      final s = raw.toString().trim();
      if (s.isNotEmpty) return s;
    }
    for (final key in const [
      kBednetTaskSchoolClientRefKey,
      'schoolclientreferenceid',
      'householdclientreferenceid', // Preferred grouping when schoolId is missing
    ]) {
      final raw = map[key.toLowerCase()];
      if (raw == null) continue;
      final s = raw.toString().trim();
      if (s.isNotEmpty) return s;
    }

    return null;
  }

  Future<void> _handleLoadDataEvent(
    SummaryReportLoadDataEvent event,
    SummaryReportEmitter emit,
  ) async {
    emit(const SummaryReportLoadingState());

    final allTasks = await taskLocalRepository.search(
      TaskSearchModel(
        projectId: RegistrationDeliverySingleton().projectId,
        createdBy: event.userId,
      ),
    );

    final schoolsVisitedByDate = <String, Set<String>>{};
    final schoolBednetDeliveredByDate = <String, int>{};

    final householdsVisitedByDate = <String, Set<String>>{};
    final householdBednetDeliveredByDate = <String, int>{};

    const presentPupilKeys = [
      kBednetTaskPupilsPresentKey,
      'pupilspresent',
      'totalpupilpreset',
      'totalPupilPresent',
      'bednetcount',
      'bednetCount',
    ];

    for (final task in allTasks) {
      final dateKey = _dateKeyFromClientAudit(task.clientAuditDetails);
      if (dateKey == null) continue;

      final fields = task.additionalFields?.fields ?? [];
      final isSchool = fields.any(
        (f) =>
            f.key == AdditionalFieldsType.isSchool.toValue() &&
            (f.value == true || f.value == 'true'),
      );

      // Extract delivery count
      var delivered = _readIntFromTaskFields(
        task.additionalFields,
        presentPupilKeys,
      );

      // Fallback 1: Resource quantity
      if (delivered == 0 && task.resources != null) {
        for (final r in task.resources!) {
          final q = int.tryParse(r.quantity.toString()) ?? 0;
          delivered += q;
        }
      }

      if (isSchool) {
        final schoolId = _schoolVisitedIdentityFromTask(task);
        if (schoolId != null) {
          schoolsVisitedByDate
              .putIfAbsent(dateKey, () => <String>{})
              .add(schoolId);
        }

        schoolBednetDeliveredByDate.update(
          dateKey,
          (v) => v + delivered,
          ifAbsent: () => delivered,
        );
      } else {
        // Household flow: only count SUCCESS
        if (task.status == Status.administeredSuccess.toValue()) {
          final hhId = fields
                  .firstWhereOrNull(
                      (f) => f.key == 'householdClientReferenceId')
                  ?.value
                  ?.toString() ??
              task.projectBeneficiaryClientReferenceId;

          if (hhId != null) {
            householdsVisitedByDate
                .putIfAbsent(dateKey, () => <String>{})
                .add(hhId);
          }

          householdBednetDeliveredByDate.update(
            dateKey,
            (v) => v + delivered,
            ifAbsent: () => delivered,
          );
        }
      }
    }

    final allDates = <String>{
      ...schoolsVisitedByDate.keys,
      ...schoolBednetDeliveredByDate.keys,
      ...householdsVisitedByDate.keys,
      ...householdBednetDeliveredByDate.keys,
    };

    // Keys for Schools
    const schoolVisitedKey = 'schoolVisitedKey';
    const schoolBednetDeliveredKey = 'schoolBednetDeliveredKey';
    // Keys for Households
    const householdVisitedKey = 'householdVisitedKey';
    const householdBednetDeliveredKey = 'householdBednetDeliveredKey';

    final data = <String, Map<String, int>>{
      for (final d in allDates)
        d: {
          schoolVisitedKey: schoolsVisitedByDate[d]?.length ?? 0,
          schoolBednetDeliveredKey: schoolBednetDeliveredByDate[d] ?? 0,
          householdVisitedKey: householdsVisitedByDate[d]?.length ?? 0,
          householdBednetDeliveredKey: householdBednetDeliveredByDate[d] ?? 0,
        },
    };

    emit(SummaryReportDataState(data: data));
  }

  Future<void> _handleLoadingEvent(
    SummaryReportLoadingEvent event,
    SummaryReportEmitter emit,
  ) async {
    emit(const SummaryReportLoadingState());
  }
}

@freezed
class SummaryReportEvent with _$SummaryReportEvent {
  const factory SummaryReportEvent.loadSummaryData({
    required String userId,
  }) = SummaryReportLoadDataEvent;

  const factory SummaryReportEvent.loading() = SummaryReportLoadingEvent;
}

@freezed
class SummaryReportState with _$SummaryReportState {
  const factory SummaryReportState.loading() = SummaryReportLoadingState;
  const factory SummaryReportState.empty() = SummaryReportEmptyState;

  const factory SummaryReportState.data({
    @Default({}) Map<String, Map<String, int>> data,
  }) = SummaryReportDataState;
}
