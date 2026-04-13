import 'package:digit_data_model/data_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../models/bednet_distribution/bednet_distribution_models.dart';

part 'bednet_distribution.freezed.dart';

typedef BednetDistributionEmitter = Emitter<BednetDistributionState>;

class BednetDistributionBloc
    extends Bloc<BednetDistributionEvent, BednetDistributionState> {
  final LocalRepository<HouseholdModel, HouseholdSearchModel>
      householdLocalRepository;

  BednetDistributionBloc({
    required this.householdLocalRepository,
  }) : super(const BednetDistributionState()) {
    on<BednetDistributionInitializeEvent>(_onInitialize);
    on<BednetDistributionReloadEvent>(_onReload);
    on<BednetDistributionSelectSchoolEvent>(_onSelectSchool);
    on<BednetDistributionUpdateSelectedSchoolEvent>(_onUpdateSelectedSchool);
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
    emit(state.copyWith(loading: true, error: null));

    try {
      final households = await householdLocalRepository.search(
        HouseholdSearchModel(
          boundaryCode: boundaryCode,
        ),
      );

      var schools = households
          .where((household) => _isSchoolHousehold(household))
          .toList()
        ..sort(
          (a, b) => a.bednetDisplayName
              .toLowerCase()
              .compareTo(b.bednetDisplayName.toLowerCase()),
        );

      // Do not clear [selectedSchool] here. [_loadSchools] runs async after
      // [initialize]; if the user registers a household meanwhile,
      // [updateSelectedSchool] can run first and would be wiped by
      // `selectedSchool: null`, leading to "No school selected" on the overview.
      emit(state.copyWith(
        loading: false,
        schools: schools,
        boundaryCode: boundaryCode,
        selectedSchool: state.selectedSchool,
      ));
    } catch (error, stackTrace) {
      debugPrint('Bednet school load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      emit(state.copyWith(
        loading: false,
        error: 'Unable to load schools for bednet distribution: $error',
      ));
    }
  }

  void _onSelectSchool(
    BednetDistributionSelectSchoolEvent event,
    BednetDistributionEmitter emit,
  ) {
    emit(
      state.copyWith(
        loading: false,
        error: null,
        selectedSchool: event.school,
        schoolSelectionSeq: state.schoolSelectionSeq + 1,
      ),
    );
  }

  /// Syncs school data (e.g. after saving a member) without incrementing
  /// [schoolSelectionSeq], so [SelectSchoolPage] does not push school details.
  void _onUpdateSelectedSchool(
    BednetDistributionUpdateSelectedSchoolEvent event,
    BednetDistributionEmitter emit,
  ) {
    emit(
      state.copyWith(
        loading: false,
        error: null,
        selectedSchool: event.school,
      ),
    );
  }

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

  /// Same as [selectSchool] for stored data, but does not bump [BednetDistributionState.schoolSelectionSeq].
  const factory BednetDistributionEvent.updateSelectedSchool(
      {required HouseholdModel school}) = BednetDistributionUpdateSelectedSchoolEvent;
}

@freezed
class BednetDistributionState with _$BednetDistributionState {
  const BednetDistributionState._();

  const factory BednetDistributionState({
    @Default(false) bool loading,
    String? boundaryCode,
    @Default([]) List<HouseholdModel> schools,
    HouseholdModel? selectedSchool,
    String? error,

    /// Incremented on each successful [BednetDistributionEvent.selectSchool] for UI navigation.
    @Default(0) int schoolSelectionSeq,
  }) = _BednetDistributionState;
}
