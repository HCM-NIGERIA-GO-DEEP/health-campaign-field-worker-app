import 'dart:async';

import 'package:digit_data_model/data/local_store/sql_store/sql_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../data/local_store/app_shared_preferences.dart';
import '../../data/repositories/local/localization.dart';
import '../../data/repositories/remote/localization.dart';
import '../../utils/utils.dart';
import 'app_localization.dart';

part 'localization.freezed.dart';

typedef LocalizationEmitter = Emitter<LocalizationState>;

// bauchi server stores localization under en_NG, matching the MDMS app config,
// so no remapping is needed. Kept empty as the single locale-alias chokepoint.
const _localeAliases = <String, String>{};

String _resolveLocale(String locale) => _localeAliases[locale] ?? locale;

class LocalizationBloc extends Bloc<LocalizationEvent, LocalizationState> {
  final LocalizationRepository localizationRepository;
  final LocalSqlDataStore sql;

  LocalizationBloc(
    super.initialState,
    this.localizationRepository,
    this.sql,
  ) {
    on(_onLoadLocalization);
    on(_onUpdateLocalizationIndex);
    on(_onRemoteLoadLocalization);
  }

  FutureOr<void> _onLoadLocalization(
    OnLoadLocalizationEvent event,
    LocalizationEmitter emit,
  ) async {
    emit(state.copyWith(loading: true, isLocalizationLoadCompleted: false));

    try {
      final boundaryModuleCheck =
          event.module.contains(Constants.boundaryLocalizationPath);
      final allModules = event.module.split(',');
      var boundaryModule;

      if (boundaryModuleCheck) {
        final boundaryModuleIndex =
            allModules.indexOf(Constants.boundaryLocalizationPath);
        boundaryModule = allModules[boundaryModuleIndex];
        allModules.removeAt(boundaryModuleIndex);
      }

      try {
        final resolvedLocale = _resolveLocale(event.locale);

        // Ensure every requested module (including the boundary module) is
        // present in the local store for this locale, and fetch from remote
        // ONLY the modules that are actually missing.
        //
        // The earlier logic checked `if (localResults.isEmpty)` on the whole
        // comma-joined module string: if even one module already had rows
        // cached, the remote fetch was skipped entirely, leaving the other
        // requested modules (e.g. hcm-attendance / hcm-common) permanently
        // unloaded and their keys rendered raw.
        final modulesToEnsure = <String>[
          ...allModules,
          if (boundaryModule != null) boundaryModule,
        ].where((m) => m.isNotEmpty).toList();

        final localResults =
            await LocalizationLocalRepository().fetchLocalization(
          sql: sql,
          locale: resolvedLocale,
          module: modulesToEnsure.join(','),
        );
        final cachedModules =
            localResults.map((e) => e.module).whereType<String>().toSet();
        final missingModules =
            modulesToEnsure.where((m) => !cachedModules.contains(m)).toList();

        if (missingModules.isNotEmpty) {
          final results = await localizationRepository.loadLocalization(
            path: event.path,
            locale: resolvedLocale,
            module: missingModules.join(','),
            tenantId: event.tenantId,
          );
          await LocalizationLocalRepository().create(results, sql);
        }
      } catch (error) {
        debugPrint('error in other modules localization $error');
        emit(state.copyWith(loading: false, retryModule: allModules.join(',')));
      }
    } catch (error) {
      rethrow;
    } finally {
      LocalizationParams().setModule(event.module, false);
      final List codes = _resolveLocale(event.locale).split('_');
      await _loadLocale(codes);
      emit(state.copyWith(
        loading: false,
        retryModule: null,
        isLocalizationLoadCompleted: true,
      ));
    }
  }

  FutureOr<void> _onRemoteLoadLocalization(
    OnRemoteLoadLocalizationEvent event,
    LocalizationEmitter emit,
  ) async {
    emit(state.copyWith(loading: true));

    try {
      final allModules = event.module.split(',');

      try {
        var localizationList;

        final resolvedLocale = _resolveLocale(event.locale);
        var results = await localizationRepository.loadLocalization(
          path: event.path,
          locale: resolvedLocale,
          module: allModules.join(','),
          tenantId: event.tenantId,
        );
        localizationList =
            await LocalizationLocalRepository().create(results, sql);
      } catch (error) {
        debugPrint('error in fetching modules localization $error');
        emit(state.copyWith(loading: false, retryModule: allModules.join(',')));
      }

      final List codes = event.locale.split('_');
      await _loadLocale(codes);
      emit(state.copyWith(
          loading: false,
          retryModule: null,
          isLocalizationLoadCompleted: true));
    } catch (error) {
      rethrow;
    } finally {
      emit(state.copyWith(loading: false));
    }
  }

  FutureOr<void> _onUpdateLocalizationIndex(
    OnUpdateLocalizationIndexEvent event,
    LocalizationEmitter emit,
  ) async {
    emit(state.copyWith(index: event.index));
    final List codes = event.code.split('_');
    AppSharedPreferences().setSelectedLocale(codes.join("_"));
    _loadLocale(codes);
  }

  FutureOr<void> _loadLocale(List codes) async {
    LocalizationParams().setLocale(Locale(codes.first, codes.last));
    await AppLocalizations(Locale(codes.first, codes.last), sql).load();
  }
}

@freezed
class LocalizationEvent with _$LocalizationEvent {
  const factory LocalizationEvent.onLoadLocalization({
    required String module,
    required String tenantId,
    required String locale,
    required String path,
  }) = OnLoadLocalizationEvent;

  const factory LocalizationEvent.onRemoteLoadLocalization({
    required String module,
    required String tenantId,
    required String locale,
    required String path,
  }) = OnRemoteLoadLocalizationEvent;

  const factory LocalizationEvent.onUpdateLocalizationIndex({
    required int index,
    required String code,
  }) = OnUpdateLocalizationIndexEvent;
}

@freezed
class LocalizationState with _$LocalizationState {
  const factory LocalizationState({
    @Default(false) bool loading,
    @Default(0) int index,
    @Default(false) bool isLocalizationLoadCompleted,
    String? retryModule,
  }) = _LocalizationState;
}
