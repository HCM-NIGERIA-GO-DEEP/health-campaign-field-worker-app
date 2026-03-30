import 'dart:async';

import 'package:collection/collection.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

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
          classIndividuals: [],
          teacherInfoByClass: [],
          classDetailsByClass: [],
          summariesByClass: [],
        ),
      );
      return;
    }

    final boundaryMeta = RegistrationDeliverySingleton().boundary;

    try {
      var allIndividuals = await individualLocalRepository.search(
        IndividualSearchModel(boundaryCode: state.boundaryCode),
      );

      final expectedClasses = event.school.bednetNumberOfClasses <= 0
          ? 1
          : event.school.bednetNumberOfClasses;

      for (var classIndex = 1; classIndex <= expectedClasses; classIndex++) {
        final existing = _findExistingClassRow(
          event.school,
          allIndividuals,
          classIndex,
        );
        if (existing != null) continue;

        await bednetDistributionRepository.createClassDistributionEntities(
          school: event.school,
          classIndex: classIndex,
          userUuid: userUuid,
          boundaryCode: state.boundaryCode ?? '',
          boundaryName: boundaryMeta?.name,
        );
      }

      allIndividuals = await individualLocalRepository.search(
        IndividualSearchModel(boundaryCode: state.boundaryCode),
      );

      final classes = _pendingClassIndividuals(event.school, allIndividuals);
      final totalClasses = classes.isEmpty
          ? event.school.bednetNumberOfClasses
          : classes.length;

      if (classes.isEmpty) {
        emit(
          state.copyWith(
            loading: false,
            error:
                'No pending classes for this school. All classes may already be administered.',
            selectedSchool: null,
            classIndividuals: [],
            teacherInfoByClass: [],
            classDetailsByClass: [],
            summariesByClass: [],
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          loading: false,
          error: null,
          selectedSchool: event.school,
          currentClassIndex: 0,
          classIndividuals: classes,
          teacherInfoByClass: List.generate(totalClasses, (_) => null),
          classDetailsByClass: List.generate(totalClasses, (_) => null),
          summariesByClass: List.generate(totalClasses, (_) => null),
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
          classIndividuals: [],
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
    if (event.classIndex >= 0 && event.classIndex < updated.length) {
      updated[event.classIndex] = event.info;
      final classIndividual = state.classIndividuals.elementAtOrNull(
        event.classIndex,
      );
      var nextIndividuals = state.classIndividuals;
      if (classIndividual != null) {
        final merged = await _updateClassIndividual(
          classIndividual,
          {
            'teacherName': event.info.name,
            'teacherGender': event.info.gender,
            'teacherMobileNumber': event.info.mobileNumber,
          },
        );
        nextIndividuals = [...state.classIndividuals];
        nextIndividuals[event.classIndex] = merged;
      }
      emit(state.copyWith(
        teacherInfoByClass: updated,
        classIndividuals: nextIndividuals,
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

    var nextIndividuals = state.classIndividuals;
    String? taskError;

    if (event.classIndex >= 0 && event.classIndex < details.length) {
      details[event.classIndex] = event.details;
      summaries[event.classIndex] = DistributionSummaryModel(
        resourceName: 'Bednet',
        boysReceived: event.details.boysPresent,
        girlsReceived: event.details.girlsPresent,
        totalDelivered: event.details.boysPresent + event.details.girlsPresent,
      );

      final classIndividual = state.classIndividuals.elementAtOrNull(
        event.classIndex,
      );
      if (classIndividual != null) {
        final merged = await _updateClassIndividual(
          classIndividual,
          {
            'distributionDate':
                event.details.distributionDate.millisecondsSinceEpoch,
            'pupilCount': event.details.pupilCount,
            'numberOfBoys': event.details.numberOfBoys,
            'numberOfGirls': event.details.numberOfGirls,
            'pupilsPresent': event.details.pupilsPresent,
            'boysPresent': event.details.boysPresent,
            'girlsPresent': event.details.girlsPresent,
            'pupilsAbsent': event.details.pupilsAbsent,
          },
        );
        nextIndividuals = [...state.classIndividuals];
        nextIndividuals[event.classIndex] = merged;

        final userUuid = RegistrationDeliverySingleton().loggedInUserUuid;
        if (userUuid == null || userUuid.isEmpty) {
          taskError = 'Cannot save distribution task: user is not logged in.';
        } else {
          try {
            await bednetDistributionRepository.createOrUpdateBednetTaskForClassDetails(
              school: state.selectedSchool!,
              classIndividual: merged,
              details: event.details,
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
      }
    }

    emit(
      state.copyWith(
        classDetailsByClass: details,
        summariesByClass: summaries,
        classIndividuals: nextIndividuals,
        error: taskError,
      ),
    );
  }

  Future<void> _onCompleteClassAdministration(
    BednetDistributionCompleteClassAdministrationEvent event,
    BednetDistributionEmitter emit,
  ) async {
    if (state.selectedSchool == null) return;
    final classIndividual =
        state.classIndividuals.elementAtOrNull(event.classIndex);
    if (classIndividual == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    await _updateClassIndividual(
      classIndividual,
      {
        kBednetClassAdministeredKey: true,
        kBednetClassAdministeredAtKey: now,
      },
    );

    final allIndividuals = await individualLocalRepository.search(
      IndividualSearchModel(boundaryCode: state.boundaryCode),
    );
    final pending =
        _pendingClassIndividuals(state.selectedSchool!, allIndividuals);

    emit(
      state.copyWith(
        classIndividuals: pending,
        teacherInfoByClass: List.generate(pending.length, (_) => null),
        classDetailsByClass: List.generate(pending.length, (_) => null),
        summariesByClass: List.generate(pending.length, (_) => null),
        currentClassIndex: 0,
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
    if (linked.length < expected) return false;
    return linked.every((i) => i.bednetClassAdministered);
  }

  bool _individualMatchesSchool(
    HouseholdModel school,
    IndividualModel individual,
  ) {
    final fields =
        individual.additionalFields?.fields ?? const <AdditionalField>[];
    final map = <String, Object?>{
      for (final field in fields)
        field.key.toLowerCase(): field.value as Object?,
    };
    final linkedSchool = map['schoolid']?.toString() ??
        map['school_id']?.toString() ??
        map['schoolclientreferenceid']?.toString() ??
        map['householdclientreferenceid']?.toString() ??
        map['household_id']?.toString();
    final hasLink = linkedSchool != null && linkedSchool.isNotEmpty;
    final matchesSchool = !hasLink ||
        linkedSchool == school.bednetSchoolId ||
        linkedSchool == school.clientReferenceId ||
        linkedSchool == school.id;
    return matchesSchool;
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
    @Default([]) List<IndividualModel> classIndividuals,
    HouseholdModel? selectedSchool,
    @Default(0) int currentClassIndex,
    @Default([]) List<ClassTeacherInfoModel?> teacherInfoByClass,
    @Default([]) List<ClassDetailsModel?> classDetailsByClass,
    @Default([]) List<DistributionSummaryModel?> summariesByClass,
    String? error,
    @Default(BednetNavIntent.none) BednetNavIntent navIntent,

    /// Incremented on each successful [BednetDistributionEvent.selectSchool] for UI navigation.
    @Default(0) int schoolSelectionSeq,
  }) = _BednetDistributionState;
}
