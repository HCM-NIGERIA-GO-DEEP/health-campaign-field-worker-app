// GENERATED using mason_cli
import 'dart:async';
import 'dart:convert';

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
    List<BoundaryModel> boundaryList = await boundaryRepository.search(
      BoundarySearchModel(
        codes: event.code,
        isSingle: true,
      ),
    );

    final List<String> boundaryLabelList = [];
    for (var element in boundaryList) {
      if (!boundaryLabelList.contains(element.label.toString())) {
        boundaryLabelList.add(element.label.toString());
      }
    }
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
    // Multi-select controls populate selectedLastLevelBoundaries. A
    // single-select leaf (used by distributor boundary selection) only
    // populates selectedBoundaryMap, so include its deepest selection too.
    final selectedBoundaries = state.selectedLastLevelBoundaries.isNotEmpty
        ? state.selectedLastLevelBoundaries
        : state.selectedBoundaryMap.values
            .whereType<BoundaryModel>()
            .toList()
            .reversed
            .take(1)
            .toList();

    // A distributor may submit a Distribution Point without choosing one
    // Community. Resolve that point to its direct Community children so
    // downsync uses the beneficiary locality level. The boundary list is
    // already flattened and loaded for the selected parent in the picker.
    final resolvedBoundaries = selectedBoundaries.length == 1 &&
            selectedBoundaries.single.label?.trim().toLowerCase() ==
                'distribution point'
        ? state.boundaryList.where((boundary) {
            final selected = selectedBoundaries.single;
            final path = boundary.materializedPath?.split('.') ?? const [];
            return boundary.label?.trim().toLowerCase() == 'community' &&
                boundary.boundaryNum == (selected.boundaryNum ?? 0) + 1 &&
                path.contains(selected.code);
          }).toList()
        : selectedBoundaries;

    // Keep selections from other branches, but discard an older parent or
    // child when the user changes to a more specific/broader boundary.
    final previousSelections = state.allSelectedLastLevelBoundaries.where((old) {
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
