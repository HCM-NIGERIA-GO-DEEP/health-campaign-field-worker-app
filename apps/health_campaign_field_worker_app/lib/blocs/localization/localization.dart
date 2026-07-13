import 'dart:async';

import 'package:digit_data_model/data/local_store/sql_store/sql_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../data/local_store/app_shared_preferences.dart';
import '../../data/repositories/local/localization.dart';
import '../../data/repositories/remote/localization.dart';
import 'package:digit_flow_builder/blocs/app_localization.dart' as flow_builder;
import 'package:digit_forms_engine/blocs/app_localization.dart' as forms_engine;
import '../../utils/utils.dart';
import 'app_localization.dart';

part 'localization.freezed.dart';

typedef LocalizationEmitter = Emitter<LocalizationState>;

class LocalizationBloc extends Bloc<LocalizationEvent, LocalizationState> {
  final LocalizationRepository localizationRepository;
  final LocalSqlDataStore sql;

  LocalizationBloc(
    super.initialState,
    this.localizationRepository,
    this.sql,
  ) {
    on(_onLoadLocalization);
    on(_onLoadLocalizationByCodes);
    on(_onUpdateLocalizationIndex);
    on(_onRemoteLoadLocalization);
  }

  FutureOr<void> _onLoadLocalization(
    OnLoadLocalizationEvent event,
    LocalizationEmitter emit,
  ) async {
    emit(state.copyWith(loading: true));

    try {
      final allModules = event.module
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      // Boundary localizations live under a per-hierarchy module (e.g.
      // hcm-boundary-admin) and must be loaded INDEPENDENTLY of the other
      // modules' cache state. The other modules are already cached from app
      // startup, so previously the boundary fetch (nested inside their
      // empty-check) never ran -- leaving boundary codes untranslated
      // (the stock flow's "Administrative Area" showed the raw code).
      // Match by the "boundary" substring so this is hierarchy-agnostic and
      // not tied to a hard-coded module name.
      final boundaryModules =
          allModules.where((m) => m.contains('boundary')).toList();
      final otherModules =
          allModules.where((m) => !m.contains('boundary')).toList();

      // Non-boundary modules, fetched ONE MODULE PER REQUEST (never combined).
      // A single combined request pulls thousands of codes in one response; on
      // a flaky connection that large download is interrupted (see the
      // connection-abort errors in logs) and only part of it persists -- e.g.
      // an inventory module stored 62 of 484 codes, so field helptexts were
      // missing. Small per-module responses complete reliably, and each fetch
      // retries so a transient abort does not silently drop a module.
      //
      // Every module is cache-checked and fetched only when missing, so
      // repeat flow entries do no network work. Force-refresh of per-project
      // modules happens once per login via onRemoteLoadLocalization (project
      // selection), not on every card tap.
      for (final m in otherModules) {
        // Fetch only modules not already cached, so repeat flow entries hit no
        // network. Per-module + retry (see _fetchAndStoreModule) makes the
        // initial load complete, so a module is either fully present or fetched
        // fresh -- no forced re-download on every entry.
        final cached = await LocalizationLocalRepository().fetchLocalization(
            sql: sql, locale: event.locale, module: m);
        if (cached.isEmpty) {
          final ok = await _fetchAndStoreModule(
            module: m,
            locale: event.locale,
            tenantId: event.tenantId,
            path: event.path,
          );
          if (!ok) emit(state.copyWith(loading: false, retryModule: m));
        }
      }

      // Boundary modules: each keyed off its OWN local cache, always checked.
      for (final boundaryModule in boundaryModules) {
        try {
          final localResults = await LocalizationLocalRepository()
              .fetchLocalization(
                  sql: sql, locale: event.locale, module: boundaryModule);
          if (localResults.isEmpty) {
            final results = await localizationRepository.loadLocalization(
              path: event.path,
              locale: event.locale,
              module: boundaryModule,
              tenantId: event.tenantId,
            );
            await LocalizationLocalRepository().create(results, sql);
          }
        } catch (error) {
          debugPrint('error in boundary module localization $error');
          emit(state.copyWith(loading: false, retryModule: boundaryModule));
        }
      }
    } catch (error) {
      rethrow;
    } finally {
      LocalizationParams().setModule(event.module, false);
      final List codes = event.locale.split('_');
      await _loadLocale(codes);
      emit(state.copyWith(loading: false, retryModule: null));
    }
  }

  /// Loads boundary localizations by their [codes] instead of pulling the
  /// entire boundary module (which is very large). Only the codes not already
  /// cached locally are requested from the server.
  FutureOr<void> _onLoadLocalizationByCodes(
    OnLoadLocalizationByCodesEvent event,
    LocalizationEmitter emit,
  ) async {
    emit(state.copyWith(loading: true));

    try {
      final codeList = event.codes
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();

      if (codeList.isNotEmpty) {
        // Skip codes already present in the local cache.
        final cached = await LocalizationLocalRepository()
            .fetchLocalizationByCodes(
                sql: sql, locale: event.locale, codes: codeList);
        final cachedCodes = cached.map((e) => e.code).toSet();
        final missing =
            codeList.where((c) => !cachedCodes.contains(c)).toList();

        if (missing.isNotEmpty) {
          try {
            // Fetch in chunks: an entire boundary subtree can be hundreds of
            // codes, and passing them all in a single `codes` query param can
            // exceed the server/proxy URL length limit and fail the request
            // (which previously left most boundaries untranslated).
            const chunkSize = 100;
            for (var i = 0; i < missing.length; i += chunkSize) {
              final end = (i + chunkSize) < missing.length
                  ? i + chunkSize
                  : missing.length;
              final chunk = missing.sublist(i, end);
              final results = await localizationRepository.loadLocalization(
                path: event.path,
                locale: event.locale,
                module: event.module,
                tenantId: event.tenantId,
                codes: chunk.join(','),
              );
              await LocalizationLocalRepository().create(results, sql);
            }
          } catch (error) {
            debugPrint('error loading boundary localization by codes: $error');
            emit(state.copyWith(loading: false, retryModule: event.module));
          }
        }
      }
    } catch (error) {
      rethrow;
    } finally {
      final List codes = event.locale.split('_');
      await _loadLocale(codes);
      emit(state.copyWith(loading: false, retryModule: null));
    }
  }

  FutureOr<void> _onRemoteLoadLocalization(
    OnRemoteLoadLocalizationEvent event,
    LocalizationEmitter emit,
  ) async {
    emit(state.copyWith(loading: true));

    try {
      // Force-refresh, ONE MODULE PER REQUEST with retry, so large combined
      // responses can't truncate and leave a module partially stored.
      final allModules = event.module
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      for (final m in allModules) {
        final ok = await _fetchAndStoreModule(
          module: m,
          locale: event.locale,
          tenantId: event.tenantId,
          path: event.path,
        );
        if (!ok) emit(state.copyWith(loading: false, retryModule: m));
      }

      final List codes = event.locale.split('_');
      await _loadLocale(codes);
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
    emit(state.copyWith(index: event.index, loading: true));
    final List codes = event.code.split('_');
    AppSharedPreferences().setSelectedLocale(codes.join("_"));
    await _loadLocale(codes);
    emit(state.copyWith(loading: false));
  }

  /// Refreshes the flow-builder's (JSON-driven flows) localization cache from
  /// the current SQL snapshot, without any MaterialApp rebuild. Awaitable so a
  /// screen can guarantee on-demand codes (e.g. boundary "Administrative Area")
  /// are localized before a JSON flow renders.
  Future<void> refreshFlowBuilderLocalization(String locale) async {
    await _loadLocale(locale.split('_'));
  }

  /// Fetches a SINGLE localization module and stores it, retrying a few times
  /// so a transient network abort does not silently drop the module. Returns
  /// true when stored (or the server returned nothing), false if all attempts
  /// failed. A module that still fails is re-attempted on the next entry.
  Future<bool> _fetchAndStoreModule({
    required String module,
    required String locale,
    required String tenantId,
    required String path,
    int attempts = 3,
  }) async {
    for (var i = 0; i < attempts; i++) {
      try {
        final results = await localizationRepository.loadLocalization(
          path: path,
          locale: locale,
          module: module,
          tenantId: tenantId,
        );
        await LocalizationLocalRepository().create(results, sql);
        return true;
      } catch (error) {
        debugPrint(
            'module "$module" localization load failed '
            '(attempt ${i + 1}/$attempts): $error');
      }
    }
    return false;
  }

  FutureOr<void> _loadLocale(List codes) async {
    LocalizationParams().setLocale(Locale(codes.first, codes.last));
    await AppLocalizations(Locale(codes.first, codes.last), sql).load();
    // Keep the flow-builder's (JSON-driven flows) localization cache in sync.
    // FlowBuilderLocalization reads a static snapshot captured once when the
    // MaterialApp delegates are first built (at login), and only refreshes on a
    // full MaterialApp rebuild -- which is intentionally gated to language
    // changes to avoid login flicker. So on-demand localizations loaded later
    // (e.g. hcm-boundary-admin for the stock flow's "Administrative Area")
    // never reached the flow builder and rendered as the raw code. Re-load its
    // cache here from the same fresh SQL source the app's own AppLocalizations
    // uses, so both stay consistent without any MaterialApp rebuild.
    try {
      final fbRows = await LocalizationLocalRepository().fetchAllForLocale(
          sql: sql, locale: '${codes.first}_${codes.last}');
      // TEMP diagnostic: confirm whether inventory helptext codes are in SQL.
      final loc = Locale(codes.first, codes.last);
      // Flow-builder renders screen chrome; the forms engine renders the actual
      // field labels AND helptexts. Each keeps its own static localization
      // snapshot that only refreshes on a full MaterialApp rebuild, so refresh
      // BOTH from the current SQL -- otherwise field helptexts stayed raw even
      // though the flow-builder chrome (e.g. Administrative Area) localized.
      await flow_builder.FlowBuilderLocalization(
        loc,
        Future.value(fbRows),
        const [],
      ).load();
      await forms_engine.FormLocalization(
        loc,
        Future.value(fbRows),
        const [],
      ).load();
    } catch (e) {
      debugPrint('flow/forms localization refresh skipped: $e');
    }
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

  const factory LocalizationEvent.onLoadLocalizationByCodes({
    required String codes,
    required String module,
    required String tenantId,
    required String locale,
    required String path,
  }) = OnLoadLocalizationByCodesEvent;

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
