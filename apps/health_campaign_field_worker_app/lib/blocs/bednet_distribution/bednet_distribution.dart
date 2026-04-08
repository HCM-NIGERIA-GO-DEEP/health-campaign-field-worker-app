import 'dart:async';

import 'package:collection/collection.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../data/local_store/bednet_class_draft_store.dart';
import '../../data/repositories/bednet_distribution_repository.dart';
import '../../models/bednet_distribution/bednet_distribution_models.dart';
import '../../utils/utils.dart';

part 'bednet_distribution.freezed.dart';

typedef BednetDistributionEmitter = Emitter<BednetDistributionState>;

class BednetDistributionBloc
    extends Bloc<BednetDistributionEvent, BednetDistributionState> {
  final LocalRepository<HouseholdModel, HouseholdSearchModel>
      householdLocalRepository;
  final LocalRepository<IndividualModel, IndividualSearchModel>
      individualLocalRepository;
  final BednetDistributionRepository bednetDistributionRepository;
  final BednetClassDraftStore bednetClassDraftStore = BednetClassDraftStore();

  BednetDistributionBloc({
    required this.householdLocalRepository,
    required this.individualLocalRepository,
    required this.bednetDistributionRepository,
  }) : super(const BednetDistributionState()) {
    on<BednetDistributionInitializeEvent>(_onInitialize);
    on<BednetDistributionReloadEvent>(_onReload);
    on<BednetDistributionSelectSchoolEvent>(_onSelectSchool);
    on<BednetDistributionSaveTeacherInfoEvent>(_onSaveTeacherInfo);
    on<BednetDistributionSaveClassDetailsEvent>(_onSaveClassDetails);
    on<BednetDistributionCompleteClassAdministrationEvent>(
        _onCompleteClassAdministration);
    on<BednetDistributionClearNavIntentEvent>(_onClearNavIntent);
  }

  Future<void> _onInitialize(
    BednetDistributionInitializeEvent event,
    BednetDistributionEmitter emit,
  ) =>
      _loadSchools(emit, event.boundaryCode);

  Future<void> _onReload(
    BednetDistributionReloadEvent event,
    BednetDistributionEmitter emit,
  ) =>
      _loadSchools(emit, state.boundaryCode ?? '');

  Future<void> _loadSchools(
    BednetDistributionEmitter emit,
    String boundaryCode,
  ) async {
    emit(state.copyWith(
        loading: true, error: null, navIntent: BednetNavIntent.none));

    try {
      final households = await householdLocalRepository.search(
        HouseholdSearchModel(
          boundaryCode: boundaryCode,
        ),
      );

      final allIndividuals = await individualLocalRepository.search(
        IndividualSearchModel(boundaryCode: boundaryCode),
      );

      final schools = households
          .where((household) => _isSchoolHousehold(household))
          // todo add boundary condition
          // .where(
          //   (household) => _matchesBoundary(household, boundaryCode),
          // )
          .where(
            (household) =>
                !_isSchoolFullyAdministered(household, allIndividuals),
          )
          .toList()
        ..sort(
          (a, b) => a.bednetDisplayName
              .toLowerCase()
              .compareTo(b.bednetDisplayName.toLowerCase()),
        );

      emit(state.copyWith(
        loading: false,
        schools: schools,
        boundaryCode: boundaryCode,
        selectedSchool: null,
        classIndividualsByOrdinal: const {},
        pendingClassOrdinals: const [],
        totalClasses: 0,
        teacherInfoByClass: const [],
        classDetailsByClass: const [],
        summariesByClass: const [],
        navIntent: BednetNavIntent.none,
      ));
    } catch (error, stackTrace) {
      debugPrint('Bednet school load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      emit(state.copyWith(
        loading: false,
        error: 'Unable to load schools for bednet distribution: $error',
        navIntent: BednetNavIntent.none,
      ));
    }
  }

  FutureOr<void> _onSelectSchool(
    BednetDistributionSelectSchoolEvent event,
    BednetDistributionEmitter emit,
  ) async {
    emit(state.copyWith(loading: true, error: null));

    final userUuid = RegistrationDeliverySingleton().loggedInUserUuid;
    if (userUuid == null || userUuid.isEmpty) {
      emit(
        state.copyWith(
          loading: false,
          error: 'Cannot start distribution: logged-in user is unknown.',
          selectedSchool: null,
          classIndividualsByOrdinal: const {},
          pendingClassOrdinals: const [],
          totalClasses: 0,
          teacherInfoByClass: [],
          classDetailsByClass: [],
          summariesByClass: [],
        ),
      );
      return;
    }

    try {
      final allIndividuals = await individualLocalRepository.search(
        IndividualSearchModel(boundaryCode: state.boundaryCode),
      );

      final expectedClasses = event.school.bednetNumberOfClasses <= 0
          ? 1
          : event.school.bednetNumberOfClasses;

      final classByOrdinal = <int, IndividualModel>{};
      final administeredOrdinals = <int>{};

      for (final ind in allIndividuals) {
        if (!_individualMatchesSchool(event.school, ind)) continue;
        if (!_isClassIndividual(ind)) continue;
        final ordinal = ind.bednetClassIndex;
        if (ordinal == null || ordinal <= 0) continue;
        classByOrdinal.putIfAbsent(ordinal, () => ind);
        if (ind.bednetClassAdministered) administeredOrdinals.add(ordinal);
      }

      int? readSchoolInt(int ordinal, List<String> keys) {
        final schoolFieldMap = <String, Object?>{
          for (final field
              in event.school.additionalFields?.fields ?? const <AdditionalField>[])
            field.key.toLowerCase(): field.value as Object?,
        };
        for (final key in keys) {
          final raw = schoolFieldMap[key.replaceAll('{n}', ordinal.toString()).toLowerCase()];
          if (raw == null) continue;
          final parsed = int.tryParse(raw.toString());
          if (parsed != null) return parsed;
        }
        return null;
      }

      bool isZeroPupilClassOrdinal(int ordinal) {
        final totalPupils = readSchoolInt(ordinal, const [
          'class{n}_totalstudents',
          'class{n}_totalpupils',
          'class{n}_pupilcount',
          'class{n}_total',
        ]);
        final boys = readSchoolInt(ordinal, const [
          'class{n}_totalboys',
          'class{n}_numberofboys',
          'class{n}_boys',
        ]);
        final girls = readSchoolInt(ordinal, const [
          'class{n}_totalgirls',
          'class{n}_numberofgirls',
          'class{n}_girls',
        ]);
        final computed = (boys ?? 0) + (girls ?? 0);
        final resolved = totalPupils ?? (computed > 0 ? computed : null);
        return resolved != null && resolved == 0;
      }

      final pendingOrdinals = <int>[];
      for (var ordinal = 1; ordinal <= expectedClasses; ordinal++) {
        if (administeredOrdinals.contains(ordinal)) continue;
        if (isZeroPupilClassOrdinal(ordinal)) continue;
        pendingOrdinals.add(ordinal);
      }

      if (pendingOrdinals.isEmpty) {
        emit(
          state.copyWith(
            loading: false,
            error:
                'No pending classes for this school. All classes may already be administered.',
            selectedSchool: null,
            classIndividualsByOrdinal: {},
            pendingClassOrdinals: [],
            totalClasses: 0,
            teacherInfoByClass: const [],
            classDetailsByClass: const [],
            summariesByClass: const [],
          ),
        );
        return;
      }

      final teacherDrafts =
          List<ClassTeacherInfoModel?>.filled(expectedClasses, null);
      final detailsDrafts =
          List<ClassDetailsModel?>.filled(expectedClasses, null);
      final summaryDrafts =
          List<DistributionSummaryModel?>.filled(expectedClasses, null);

      for (var ordinal = 1; ordinal <= expectedClasses; ordinal++) {
        final draft = await bednetClassDraftStore.read(
          schoolClientRef: event.school.clientReferenceId,
          classOrdinal: ordinal,
        );
        if (draft?.teacher != null) teacherDrafts[ordinal - 1] = draft!.teacher;
        if (draft?.details != null) {
          detailsDrafts[ordinal - 1] = draft!.details;
          summaryDrafts[ordinal - 1] = DistributionSummaryModel(
            resourceName: 'Bednet',
            boysReceived: draft.details!.boysPresent,
            girlsReceived: draft.details!.girlsPresent,
            totalDelivered:
                draft.details!.boysPresent + draft.details!.girlsPresent,
          );
        }
      }

      emit(
        state.copyWith(
          loading: false,
          error: null,
          selectedSchool: event.school,
          currentClassIndex: 0,
          classIndividualsByOrdinal: classByOrdinal,
          pendingClassOrdinals: pendingOrdinals,
          totalClasses: expectedClasses,
          teacherInfoByClass: teacherDrafts,
          classDetailsByClass: detailsDrafts,
          summariesByClass: summaryDrafts,
          navIntent: BednetNavIntent.none,
          schoolSelectionSeq: state.schoolSelectionSeq + 1,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Bednet school selection persistence failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      emit(
        state.copyWith(
          loading: false,
          error:
              'Could not prepare class records for this school: $error',
          selectedSchool: null,
          classIndividualsByOrdinal: const {},
          pendingClassOrdinals: const [],
          totalClasses: 0,
          teacherInfoByClass: [],
          classDetailsByClass: [],
          summariesByClass: [],
        ),
      );
    }
  }

  FutureOr<void> _onSaveTeacherInfo(
    BednetDistributionSaveTeacherInfoEvent event,
    BednetDistributionEmitter emit,
  ) async {
    if (state.selectedSchool == null) return;

    final updated = [...state.teacherInfoByClass];

    final ordinal = event.classIndex;
    if (ordinal >= 1 && ordinal <= updated.length) {
      updated[ordinal - 1] = event.info;

      await bednetClassDraftStore.upsertTeacher(
        schoolClientRef: state.selectedSchool!.clientReferenceId,
        classOrdinal: ordinal,
        teacher: event.info,
      );

      emit(state.copyWith(
        teacherInfoByClass: updated,
        error: null,
      ));
    }
  }

  FutureOr<void> _onSaveClassDetails(
    BednetDistributionSaveClassDetailsEvent event,
    BednetDistributionEmitter emit,
  ) async {
    if (state.selectedSchool == null) return;

    final details = [...state.classDetailsByClass];
    final summaries = [...state.summariesByClass];

    final ordinal = event.classIndex;
    if (ordinal >= 1 && ordinal <= details.length) {
      details[ordinal - 1] = event.details;
      summaries[ordinal - 1] = DistributionSummaryModel(
        resourceName: 'Bednet',
        boysReceived: event.details.boysPresent,
        girlsReceived: event.details.girlsPresent,
        totalDelivered: event.details.boysPresent + event.details.girlsPresent,
      );

      await bednetClassDraftStore.upsertDetails(
        schoolClientRef: state.selectedSchool!.clientReferenceId,
        classOrdinal: ordinal,
        details: event.details,
      );
    }

    emit(
      state.copyWith(
        classDetailsByClass: details,
        summariesByClass: summaries,
        error: null,
      ),
    );
  }

  Future<void> _onCompleteClassAdministration(
    BednetDistributionCompleteClassAdministrationEvent event,
    BednetDistributionEmitter emit,
  ) async {
    if (state.selectedSchool == null) return;
    final ordinal = event.classIndex;
    if (ordinal < 1 || ordinal > state.totalClasses) return;

    final existingIndividual = state.classIndividualsByOrdinal[ordinal];

    final now = DateTime.now().millisecondsSinceEpoch;
    final classDetails = state.classDetailsByClass.elementAtOrNull(ordinal - 1);
    final teacherInfo = state.teacherInfoByClass.elementAtOrNull(ordinal - 1);

    String? taskError;

    IndividualModel? classIndividual = existingIndividual;
    if (classIndividual == null) {
      final userUuid = RegistrationDeliverySingleton().loggedInUserUuid;
      if (userUuid == null || userUuid.isEmpty) {
        emit(state.copyWith(error: 'Cannot save distribution: user is not logged in.'));
        return;
      }
      classIndividual = await bednetDistributionRepository.createClassDistributionEntities(
        school: state.selectedSchool!,
        classIndex: ordinal,
        userUuid: userUuid,
        boundaryCode: state.boundaryCode ?? '',
        boundaryName: RegistrationDeliverySingleton().boundary?.name,
      );
    }

    if (classDetails != null && teacherInfo != null) {
      final mobile = teacherInfo.mobileNumber.trim();
      final merged = await _updateClassIndividual(
        classIndividual,
        {
          'distributionDate':
              classDetails.distributionDate.millisecondsSinceEpoch,
          'pupilCount': classDetails.pupilCount,
          'numberOfBoys': classDetails.numberOfBoys,
          'numberOfGirls': classDetails.numberOfGirls,
          'pupilsPresent': classDetails.pupilsPresent,
          'boysPresent': classDetails.boysPresent,
          'girlsPresent': classDetails.girlsPresent,
          'pupilsAbsent': classDetails.pupilsAbsent,
          'teacherName': teacherInfo.name,
          'teacherGender': teacherInfo.gender,
          if (mobile.isNotEmpty) 'teacherMobileNumber': mobile,
          kBednetClassAdministeredKey: true,
          kBednetClassAdministeredAtKey: now,
        },
      );

      final userUuid = RegistrationDeliverySingleton().loggedInUserUuid;
      if (userUuid == null || userUuid.isEmpty) {
        taskError = 'Cannot save distribution task: user is not logged in.';
      } else {
        try {
          await bednetDistributionRepository.createOrUpdateBednetTaskForClassDetails(
            school: state.selectedSchool!,
            classIndividual: merged,
            details: classDetails,
            userUuid: userUuid,
            boundaryCode: state.boundaryCode ?? '',
            boundaryName: RegistrationDeliverySingleton().boundary?.name,
          );
        } catch (error, stackTrace) {
          debugPrint('Bednet task create/update failed: $error');
          debugPrintStack(stackTrace: stackTrace);
          taskError = 'Could not save distribution task: $error';
        }
      }

      await bednetClassDraftStore.clear(
        schoolClientRef: state.selectedSchool!.clientReferenceId,
        classOrdinal: ordinal,
      );
    } else {
      // If drafts are missing, still mark administered to avoid blocking the flow.
      await _updateClassIndividual(
        classIndividual,
        {
          kBednetClassAdministeredKey: true,
          kBednetClassAdministeredAtKey: now,
        },
      );
    }

    final pending = state.pendingClassOrdinals.where((e) => e != ordinal).toList();
    final byOrdinal = {...state.classIndividualsByOrdinal};
    byOrdinal[ordinal] = classIndividual;

    emit(
      state.copyWith(
        classIndividualsByOrdinal: byOrdinal,
        pendingClassOrdinals: pending,
        currentClassIndex: 0,
        error: taskError,
        navIntent: pending.isEmpty
            ? BednetNavIntent.openSuccess
            : BednetNavIntent.continueNextClass,
      ),
    );
  }

  void _onClearNavIntent(
    BednetDistributionClearNavIntentEvent event,
    BednetDistributionEmitter emit,
  ) {
    emit(state.copyWith(navIntent: BednetNavIntent.none));
  }

  /// School rows from server (see assets/sample_data/household.csv): [schoolName], [schoolId], [type], etc.
  bool _isSchoolHousehold(HouseholdModel household) {
    final fields =
        household.additionalFields?.fields ?? const <AdditionalField>[];
    final map = <String, Object?>{
      for (final field in fields)
        field.key.toLowerCase(): field.value as Object?,
    };
    final typeField = map['type']?.toString().toLowerCase();
    if (typeField == 'school') return true;
    if (map['schoolname'] != null &&
        map['schoolname'].toString().trim().isNotEmpty) {
      return true;
    }
    if (map['schoolid'] != null &&
        map['schoolid'].toString().trim().isNotEmpty) {
      return true;
    }
    return false;
  }

  bool _matchesBoundary(HouseholdModel household, String boundaryCode) {
    final directBoundary = household.address?.boundary;
    if (directBoundary == boundaryCode) return true;

    final map = <String, Object?>{
      for (final field
          in household.additionalFields?.fields ?? const <AdditionalField>[])
        field.key.toLowerCase(): field.value as Object?,
    };
    final fromAdditional = map['boundarycode']?.toString() ??
        map['boundary_code']?.toString() ??
        map['boundary']?.toString();
    return fromAdditional == boundaryCode;
  }

  /// Hide school from picker when every expected class row exists and is administered.
  bool _isSchoolFullyAdministered(
    HouseholdModel school,
    List<IndividualModel> allIndividuals,
  ) {
    final expected = school.bednetNumberOfClasses;
    if (expected <= 0) return false;
    final linked = _allClassIndividualsForSchool(school, allIndividuals);
    final administeredOrdinals = <int>{};
    for (final ind in linked) {
      if (!ind.bednetClassAdministered) continue;
      final ord = ind.bednetClassIndex;
      if (ord != null && ord > 0) administeredOrdinals.add(ord);
    }

    int? readSchoolInt(int ordinal, List<String> keys) {
      final schoolFieldMap = <String, Object?>{
        for (final field
            in school.additionalFields?.fields ?? const <AdditionalField>[])
          field.key.toLowerCase(): field.value as Object?,
      };
      for (final key in keys) {
        final raw = schoolFieldMap[key
            .replaceAll('{n}', ordinal.toString())
            .toLowerCase()];
        if (raw == null) continue;
        final parsed = int.tryParse(raw.toString());
        if (parsed != null) return parsed;
      }
      return null;
    }

    bool isZeroPupilOrdinal(int ordinal) {
      final totalPupils = readSchoolInt(ordinal, const [
        'class{n}_totalstudents',
        'class{n}_totalpupils',
        'class{n}_pupilcount',
        'class{n}_total',
      ]);
      final boys = readSchoolInt(ordinal, const [
        'class{n}_totalboys',
        'class{n}_numberofboys',
        'class{n}_boys',
      ]);
      final girls = readSchoolInt(ordinal, const [
        'class{n}_totalgirls',
        'class{n}_numberofgirls',
        'class{n}_girls',
      ]);
      final computed = (boys ?? 0) + (girls ?? 0);
      final resolved = totalPupils ?? (computed > 0 ? computed : null);
      return resolved != null && resolved == 0;
    }

    var effectiveExpected = 0;
    for (var ordinal = 1; ordinal <= expected; ordinal++) {
      if (isZeroPupilOrdinal(ordinal)) continue;
      effectiveExpected++;
    }

    return administeredOrdinals.length >= effectiveExpected &&
        effectiveExpected > 0;
  }

  bool _individualMatchesSchool(
    HouseholdModel school,
    IndividualModel individual,
  ) {
    String normalize(String? value) => value?.trim().toLowerCase() ?? '';

    final fields =
        individual.additionalFields?.fields ?? const <AdditionalField>[];
    final map = <String, Object?>{
      for (final field in fields)
        field.key.toLowerCase(): field.value as Object?,
    };
    final linkedSchoolRaw = map['schoolid']?.toString() ??
        map['school_id']?.toString() ??
        map['schoolclientreferenceid']?.toString() ??
        map['householdclientreferenceid']?.toString() ??
        map['household_id']?.toString();
    final linkedSchool = normalize(linkedSchoolRaw);
    final hasLink = linkedSchool.isNotEmpty;
    if (hasLink) {
      final candidates = <String>{
        normalize(school.bednetSchoolId),
        normalize(school.clientReferenceId),
        normalize(school.id),
      }..removeWhere((e) => e.isEmpty);
      return candidates.contains(linkedSchool);
    }

    // Do not treat unlinked class rows as belonging to every school.
    // Fallback to school-name matching only when that metadata is present.
    final linkedSchoolName = normalize(
      map['schoolname']?.toString() ?? map['school_name']?.toString(),
    );
    if (linkedSchoolName.isNotEmpty) {
      return linkedSchoolName == normalize(school.bednetDisplayName);
    }

    return false;
  }

  bool _isClassIndividual(IndividualModel individual) {
    final gn = individual.name?.givenName?.toLowerCase() ?? '';
    if (gn.startsWith('class')) return true;
    final fields =
        individual.additionalFields?.fields ?? const <AdditionalField>[];
    final map = <String, Object?>{
      for (final field in fields)
        field.key.toLowerCase(): field.value as Object?,
    };
    return map['classname'] != null ||
        map['class_id'] != null ||
        map['classid'] != null;
  }

  List<IndividualModel> _allClassIndividualsForSchool(
    HouseholdModel school,
    List<IndividualModel> allIndividuals,
  ) {
    final filtered = allIndividuals.where((individual) {
      return _individualMatchesSchool(school, individual) &&
          _isClassIndividual(individual);
    }).toList()
      ..sort((a, b) {
        final left = a.name?.givenName?.toLowerCase() ?? '';
        final right = b.name?.givenName?.toLowerCase() ?? '';
        return left.compareTo(right);
      });
    return filtered;
  }

  List<IndividualModel> _pendingClassIndividuals(
    HouseholdModel school,
    List<IndividualModel> allIndividuals,
  ) {
    return _allClassIndividualsForSchool(school, allIndividuals)
        .where((i) => !i.bednetClassAdministered)
        .toList();
  }

  /// Resolves an existing class row created for this school (synced or local).
  IndividualModel? _findExistingClassRow(
    HouseholdModel school,
    List<IndividualModel> allIndividuals,
    int classIndex,
  ) {
    for (final ind in allIndividuals) {
      if (!_individualMatchesSchool(school, ind)) continue;
      final fields =
          ind.additionalFields?.fields ?? const <AdditionalField>[];
      final map = <String, Object?>{
        for (final field in fields)
          field.key.toLowerCase(): field.value as Object?,
      };
      final raw = map[kBednetClassIndexKey.toLowerCase()] ??
          map['classindex'] ??
          map['class_index'];
      if (raw != null && int.tryParse(raw.toString()) == classIndex) {
        return ind;
      }
      final gn = ind.name?.givenName?.toLowerCase().trim() ?? '';
      if (gn == 'class $classIndex'.toLowerCase()) {
        return ind;
      }
    }
    return null;
  }

  /// Persists class-related data on [IndividualModel] only (household is read-only).
  Future<IndividualModel> _updateClassIndividual(
    IndividualModel individual,
    Map<String, dynamic> updates,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final modifiedBy = RegistrationDeliverySingleton().loggedInUserUuid ??
        individual.clientAuditDetails?.lastModifiedBy ??
        individual.clientAuditDetails?.createdBy ??
        individual.auditDetails?.lastModifiedBy ??
        individual.auditDetails?.createdBy ??
        '';

    final existingFields = individual.additionalFields?.fields ?? [];
    final map = {
      for (final field in existingFields) field.key: field.value,
    };

    map.addAll(updates);
    final mergedFields = map.entries
        .map((entry) => AdditionalField(entry.key, entry.value))
        .toList();

    final newClientAudit = individual.clientAuditDetails != null
        ? ClientAuditDetails(
            createdBy: individual.clientAuditDetails!.createdBy,
            createdTime: individual.clientAuditDetails!.createdTime,
            lastModifiedBy: modifiedBy.isNotEmpty
                ? modifiedBy
                : individual.clientAuditDetails!.lastModifiedBy,
            lastModifiedTime: now,
          )
        : null;

    final newAudit = individual.auditDetails != null
        ? AuditDetails(
            createdBy: individual.auditDetails!.createdBy,
            createdTime: individual.auditDetails!.createdTime,
            lastModifiedBy: modifiedBy.isNotEmpty
                ? modifiedBy
                : individual.auditDetails!.lastModifiedBy,
            lastModifiedTime: now,
          )
        : null;

    final forRepository = individual.copyWith(
      // Must keep [NameModel]; clearing it breaks API sync (name must not be null).
      name: individual.name,
      additionalFields: IndividualAdditionalFields(
        version: individual.additionalFields?.version ?? 1,
        fields: mergedFields,
      ),
      clientAuditDetails: newClientAudit,
      auditDetails: newAudit,
    );

    await individualLocalRepository.update(forRepository);

    return individual.copyWith(
      additionalFields: forRepository.additionalFields,
      clientAuditDetails: newClientAudit,
      auditDetails: newAudit,
    );
  }
}

@freezed
class BednetDistributionEvent with _$BednetDistributionEvent {
  const factory BednetDistributionEvent.initialize({
    required String boundaryCode,
  }) = BednetDistributionInitializeEvent;
  const factory BednetDistributionEvent.reload() =
      BednetDistributionReloadEvent;
  const factory BednetDistributionEvent.selectSchool(
      {required HouseholdModel school}) = BednetDistributionSelectSchoolEvent;
  const factory BednetDistributionEvent.saveTeacherInfo({
    required int classIndex,
    required ClassTeacherInfoModel info,
  }) = BednetDistributionSaveTeacherInfoEvent;
  const factory BednetDistributionEvent.saveClassDetails({
    required int classIndex,
    required ClassDetailsModel details,
  }) = BednetDistributionSaveClassDetailsEvent;
  const factory BednetDistributionEvent.completeClassAdministration({
    required int classIndex,
  }) = BednetDistributionCompleteClassAdministrationEvent;
  const factory BednetDistributionEvent.clearNavIntent() =
      BednetDistributionClearNavIntentEvent;
}

@freezed
class BednetDistributionState with _$BednetDistributionState {
  const BednetDistributionState._();

  const factory BednetDistributionState({
    @Default(false) bool loading,
    String? boundaryCode,
    @Default([]) List<HouseholdModel> schools,
    @Default({}) Map<int, IndividualModel> classIndividualsByOrdinal,
    HouseholdModel? selectedSchool,
    @Default(0) int currentClassIndex,
    @Default([]) List<int> pendingClassOrdinals,
    @Default(0) int totalClasses,
    @Default([]) List<ClassTeacherInfoModel?> teacherInfoByClass,
    @Default([]) List<ClassDetailsModel?> classDetailsByClass,
    @Default([]) List<DistributionSummaryModel?> summariesByClass,
    String? error,
    @Default(BednetNavIntent.none) BednetNavIntent navIntent,

    /// Incremented on each successful [BednetDistributionEvent.selectSchool] for UI navigation.
    @Default(0) int schoolSelectionSeq,
  }) = _BednetDistributionState;
}
