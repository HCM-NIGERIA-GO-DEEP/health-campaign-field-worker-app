import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/utils/date_utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../models/bednet_distribution/bednet_distribution_models.dart';

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
      kBednetTaskSchoolNameKey,
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

    final taskListData = await taskLocalRepository.search(
      TaskSearchModel(
        createdBy: event.userId,
      ),
    );

    final schoolsVisitedByDate = <String, Set<String>>{};

    final bednetDeliveredByDate = <String, int>{};
    final bednetRemainingByDate = <String, int>{};

    const totalPupilKeys = [
      kBednetTaskTotalPupilKey,
      'totalpupilcount',
    ];
    const presentPupilKeys = [
      kBednetTaskPupilsPresentKey,
      'pupilspresent',
      'totalpupilpreset',
      'totalPupilPresent',
    ];

    for (final task in taskListData) {
      final dateKey = _dateKeyFromClientAudit(task.clientAuditDetails);
      if (dateKey == null) continue;

      final schoolId = _schoolVisitedIdentityFromTask(task);
      if (schoolId != null) {
        schoolsVisitedByDate.putIfAbsent(dateKey, () => <String>{}).add(schoolId);
      }

      final totalPupils = _readIntFromTaskFields(
        task.additionalFields,
        totalPupilKeys,
      );
      final presentPupils = _readIntFromTaskFields(
        task.additionalFields,
        presentPupilKeys,
      );

      bednetDeliveredByDate.update(
        dateKey,
        (v) => v + presentPupils,
        ifAbsent: () => presentPupils,
      );

      final remaining = totalPupils - presentPupils;
      final remainingNonNegative = remaining < 0 ? 0 : remaining;
      bednetRemainingByDate.update(
        dateKey,
        (v) => v + remainingNonNegative,
        ifAbsent: () => remainingNonNegative,
      );
    }

    final schoolVisitedByDate = <String, int>{
      for (final e in schoolsVisitedByDate.entries) e.key: e.value.length,
    };

    final allDates = <String>{
      ...schoolVisitedByDate.keys,
      ...bednetDeliveredByDate.keys,
      ...bednetRemainingByDate.keys,
    };

    // Inner keys align with [CustomSummaryReportPage] grid column keys.
    const schoolVisitedKey = 'schoolVisitedKey';
    const bednetDeliveredKey = 'bednetDeliveredKey';
    const bednetRemainigKey = 'bednetRemainigKey';

    final data = <String, Map<String, int>>{
      for (final d in allDates)
        d: {
          schoolVisitedKey: schoolVisitedByDate[d] ?? 0,
          bednetDeliveredKey: bednetDeliveredByDate[d] ?? 0,
          bednetRemainigKey: bednetRemainingByDate[d] ?? 0,
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
