// GENERATED using mason_cli
import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:digit_data_model/models/entities/boundary.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../utils/typedefs.dart';

part 'boundary.freezed.dart';

typedef BoundaryEmitter = Emitter<BoundaryState>;

class BoundaryBloc extends Bloc<BoundaryEvent, BoundaryState> {
  final BoundaryDataRepository boundaryRepository;

  BoundaryBloc(
    super.initialState, {
    required this.boundaryRepository,
  }) {
    on(_handleReset);
    on(_handleSearch);
    on(_handleSelect);
    on(_handleMultiSelect);
    on(_handleSubmit);
    on(_handlefind);
  }

  Future<void> _handleReset(
    BoundaryResetEvent event,
    BoundaryEmitter emit,
  ) async {
    await boundaryRepository.delete(BoundaryModel());
    emit(const BoundaryState());
  }

  Future<void> _handlefind(
    BoundaryFindEvent event,
    BoundaryEmitter emit,
  ) async {
    final initialBoundaries = await boundaryRepository.search(
      BoundarySearchModel(
        codes: event.code,
        isSingle: true,
      ),
    );

    // The picker can start at Distribution Point without selecting its parent.
    final projectBoundaries = await boundaryRepository.search(
      BoundarySearchModel(codes: event.code),
    );
    final knownCodes =
        initialBoundaries.map((boundary) => boundary.code).toSet();
    final distributionPoints = projectBoundaries.where(
      (boundary) =>
          boundary.label?.trim().toLowerCase() == 'distribution point' &&
          (boundary.materializedPath?.split('.').contains(event.code) ??
              false) &&
          knownCodes.add(boundary.code),
    );
    final boundaryList = [...initialBoundaries, ...distributionPoints];
    final orderedBoundaries = [...boundaryList]
      ..sort((a, b) => (a.boundaryNum ?? 0).compareTo(b.boundaryNum ?? 0));
    final boundaryLabelList =
        orderedBoundaries.map((boundary) => boundary.label.toString()).toSet();
    emit(
      state.copyWith(
        boundaryList: boundaryList,
        selectedBoundaryMap: Map.fromEntries(
          boundaryLabelList.map(
            (e) => MapEntry(e, null),
          ),
        ),
        loading: false,
      ),
    );
  }

  FutureOr<void> _handleSearch(
    BoundarySearchEvent event,
    BoundaryEmitter emit,
  ) async {
    emit(state.copyWith(loading: true));
    List<BoundaryModel> boundaryList = await boundaryRepository.search(
      BoundarySearchModel(
        codes: event.code,
        boundaryNum: event.boundaryNum,
        isSingle: false,
      ),
    );

    final r = [...state.boundaryList, ...boundaryList];

    emit(
      state.copyWith(
        boundaryList: Set.of(r).toList(),
        selectedBoundaryMap: state.selectedBoundaryMap,
        loading: false,
      ),
    );
  }

  FutureOr<void> _handleSelect(
    BoundarySelectEvent event,
    BoundaryEmitter emit,
  ) async {
    bool hasChanged = false;
    final selectedBoundaryMap = Map.fromEntries(
      state.selectedBoundaryMap.entries.map(
        (e) {
          if (hasChanged) {
            return MapEntry(e.key, null);
          }
          if (e.key == event.label) {
            hasChanged = true;

            return MapEntry(e.key, event.selectedBoundary);
          }

          return e;
        },
      ),
    );

    final hasSelectedBoundaryChanged = const DeepCollectionEquality().equals(
      selectedBoundaryMap,
      state.selectedBoundaryMap,
    );

    if (hasSelectedBoundaryChanged) {
      return;
    }

    emit(state.copyWith(
      selectedBoundaryMap: selectedBoundaryMap,
      selectedLastLevelBoundaries: [],
      hasSubmitted: false,
    ));
  }

  FutureOr<void> _handleMultiSelect(
    BoundaryMultiSelectEvent event,
    BoundaryEmitter emit,
  ) async {
    emit(state.copyWith(
      selectedLastLevelBoundaries: event.selectedBoundaries,
      hasSubmitted: false,
    ));
  }

  FutureOr<void> _handleSubmit(
    BoundarySubmitEvent event,
    BoundaryEmitter emit,
  ) async {
    final resolvedBoundaries = state.effectiveSelectedBoundaries;
    // Keep selections from other branches, but discard an older parent or
    // child when the user changes to a more specific/broader boundary.
    final previousSelections =
        state.allSelectedLastLevelBoundaries.where((old) {
      return !resolvedBoundaries.any((current) {
        final oldPath = old.materializedPath?.split('.') ?? const [];
        final currentPath = current.materializedPath?.split('.') ?? const [];
        return old.code == current.code ||
            oldPath.contains(current.code) ||
            currentPath.contains(old.code);
      });
    });
    final merged = [
      ...resolvedBoundaries,
      ...previousSelections,
    ];
    emit(state.copyWith(
      hasSubmitted: true,
      allSelectedLastLevelBoundaries: merged,
    ));
  }
}

@freezed
class BoundaryEvent with _$BoundaryEvent {
  const factory BoundaryEvent.reset() = BoundaryResetEvent;

  const factory BoundaryEvent.search(
      {required String code, required int boundaryNum}) = BoundarySearchEvent;

  const factory BoundaryEvent.select({
    required String label,
    required BoundaryModel selectedBoundary,
  }) = BoundarySelectEvent;

  const factory BoundaryEvent.findBoundary({required String code}) =
      BoundaryFindEvent;

  const factory BoundaryEvent.selectMultipleBoundaries({
    required String label,
    required List<BoundaryModel> selectedBoundaries,
  }) = BoundaryMultiSelectEvent;

  const factory BoundaryEvent.submit() = BoundarySubmitEvent;
}

@freezed
class BoundaryState with _$BoundaryState {
  const BoundaryState._();

  const factory BoundaryState({
    @Default(false) bool loading,
    @Default([]) List<BoundaryModel> boundaryList,
    @Default([]) List<BoundaryModel> projectBoundaryList,
    @Default({}) Map<String, BoundaryModel?> selectedBoundaryMap,
    @Default([]) List<BoundaryModel> selectedLastLevelBoundaries,
    @Default([]) List<BoundaryModel> allSelectedLastLevelBoundaries,
    @Default(false) bool hasSubmitted,
  }) = _BoundaryState;

  List<BoundaryModel> get effectiveSelectedBoundaries {
    if (selectedLastLevelBoundaries.isNotEmpty) {
      return selectedLastLevelBoundaries;
    }

    final selected =
        selectedBoundaryMap.values.whereType<BoundaryModel>().lastOrNull;
    if (selected == null) return [];
    if (selected.label?.trim().toLowerCase() != 'distribution point') {
      return [selected];
    }

    // Beneficiary downsync uses Community localities.
    final communities = boundaryList
        .where((boundary) =>
            boundary.label?.trim().toLowerCase() == 'community' &&
            boundary.boundaryNum == (selected.boundaryNum ?? 0) + 1 &&
            (boundary.materializedPath?.split('.').contains(selected.code) ??
                false))
        .toList();
    return communities.isEmpty ? [selected] : communities;
  }

  @override
  String toString() => const JsonEncoder.withIndent('  ').convert({
        'loading': loading,
        'selectedBoundaryMap': Map.fromEntries(
          selectedBoundaryMap.entries.map(
            (e) => MapEntry(
              e.key,
              e.value?.toMap(),
            ),
          ),
        ),
        'hasSubmitted': hasSubmitted,
        'boundaryList.length': boundaryList.length,
      });
}
