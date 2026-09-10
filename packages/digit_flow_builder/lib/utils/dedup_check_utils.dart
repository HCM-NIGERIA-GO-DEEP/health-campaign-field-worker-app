import 'dart:async';

import 'package:digit_crud_bloc/digit_crud_bloc.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_dedup_engine/digit_dedup_engine.dart';
import 'package:digit_forms_engine/forms_engine.dart';
import 'package:digit_ui_components/utils/component_utils.dart';
import 'package:flutter/material.dart';

import '../blocs/app_localization.dart';
import '../navigation_service/navigation_service.dart';
import '../widgets/dedup_alert_popup.dart';
import '../widgets/dedup_match_dialog.dart';
import 'utils.dart';

/// Runs the pre-submit duplicate warning for pages carrying a [DedupCheck].
///
/// Registered into [DedupCheckRegistry] from screen_builder, because the
/// similarity search needs the local database and the form engine has no
/// access to it. The matching itself is delegated to `digit_dedup_engine`.
class DedupCheckUtils {
  const DedupCheckUtils._();

  /// Identifier type holding the beneficiary ID shown alongside a match.
  static const String beneficiaryIdentifierType = 'UNIQUE_BENEFICIARY_ID';

  /// Localization code for the loader shown during the search, with the copy
  /// used until that string is published.
  static const String searchingLabelCode =
      'DEDUP_SIMILAR_BENEFICIARY_SEARCHING';
  static const String searchingLabelText = 'Checking for similar beneficiaries';

  /// How long the search may run before the loader appears. Under this the
  /// loader would only flash, so a project with nothing to search against
  /// submits with no dialog at all.
  static const Duration loaderDelay = Duration(milliseconds: 250);

  /// Entry point for [DedupCheckRegistry].
  ///
  /// Never throws: a failed check returns [DedupCheckOutcome.proceed] so a
  /// database or config problem cannot stop a field worker from registering a
  /// beneficiary. The trade-off is deliberate -- this is a warning, not a
  /// gate.
  static Future<DedupCheckOutcome> run(
    BuildContext context,
    DedupCheckRequest request,
  ) async {
    try {
      return await _run(context, request);
    } catch (e, stackTrace) {
      debugPrint('DedupCheckUtils: check failed, allowing submission.\n'
          'Error: $e\n'
          'StackTrace: $stackTrace');
      return DedupCheckOutcome.proceed;
    }
  }

  static Future<DedupCheckOutcome> _run(
    BuildContext context,
    DedupCheckRequest request,
  ) async {
    final config = request.config;

    final probe = buildProbe(config, request.formValues);
    if (probe.isEmpty) {
      debugPrint(
          'DedupCheckUtils: no probe attributes for ${request.pageName}, '
          'skipping the check.');
      return DedupCheckOutcome.proceed;
    }

    final filters = resolveFilters(config, request);
    if (filters.isEmpty) {
      // An unfiltered search is rejected by the repository, and searching the
      // whole device would be wrong anyway.
      debugPrint('DedupCheckUtils: no scoping filters resolved for '
          '${request.pageName}, skipping the check.');
      return DedupCheckOutcome.proceed;
    }

    // translate() echoes the code back when the string is missing from the
    // server-fetched table, so fall back to readable copy.
    final searching =
        FlowBuilderLocalization.of(context).translate(searchingLabelCode);

    final matches = await _withLoader(
      context,
      label: searching == searchingLabelCode ? searchingLabelText : searching,
      task: () => findMatches(config, probe, filters),
    );

    if (matches.isEmpty) return DedupCheckOutcome.proceed;
    if (!context.mounted) return DedupCheckOutcome.proceed;

    // Prefer the page's own dialog config. The built-in dialog stays as the
    // fallback so a page that has not declared `dedupAlertPopUp` still warns.
    final alert = request.alert;
    if (alert != null && alert.body.isNotEmpty) {
      return showConfigDedupAlert(
        context: context,
        alert: alert,
        matches: matches,
        stateKey: '${request.schemaKey}::${request.pageName}',
        onBackToSearch: () => _navigateToSearch(config),
      );
    }

    return showDedupMatchDialog(
      context: context,
      alert: alert,
      matches: matches,
      onBackToSearch: () => _navigateToSearch(config),
    );
  }

  /// Runs [task], showing a blocking loader only once it has run long enough
  /// to be noticed.
  static Future<T> _withLoader<T>(
    BuildContext context, {
    required String label,
    required Future<T> Function() task,
  }) async {
    var loaderVisible = false;

    final timer = Timer(loaderDelay, () {
      if (!context.mounted) return;
      loaderVisible = true;
      DigitSyncDialog.show(
        context,
        type: DialogType.inProgress,
        label: label,
      );
    });

    try {
      return await task();
    } finally {
      timer.cancel();
      if (loaderVisible && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  /// Builds the record scored against the corpus, keyed by dedup engine
  /// attribute rather than form field name.
  static Map<String, dynamic> buildProbe(
    DedupCheck config,
    Map<String, dynamic> formValues,
  ) {
    final probe = <String, dynamic>{};

    void take(Map<String, String> mapping) {
      mapping.forEach((attribute, fieldName) {
        final value = formValues[fieldName];
        if (value == null) return;
        final asText = value.toString().trim();
        if (asText.isEmpty) return;
        probe[attribute] = asText;
      });
    }

    take(config.fields);
    // Absent optional values simply never reach the probe, and the matcher
    // skips any attribute missing from either side.
    take(config.optionalFields);

    return probe;
  }

  /// Resolves the config's scoping filters against the current form and
  /// navigation data. Filters resolving to nothing are dropped.
  static List<SearchFilter> resolveFilters(
    DedupCheck config,
    DedupCheckRequest request,
  ) {
    final contextData = <String, dynamic>{
      'formData': request.formValues,
      'navigation': request.navigationParams,
    };

    final filters = <SearchFilter>[];

    for (final filter in config.filters) {
      var template = filter.value;

      if (filter.switchOn != null && filter.cases != null) {
        final switchKey =
            resolveValue(filter.switchOn!, contextData)?.toString();
        if (switchKey != null && filter.cases!.containsKey(switchKey)) {
          template = filter.cases![switchKey]!;
        }
      }

      final resolved = resolveValue(template, contextData)?.toString().trim();
      if (resolved == null || resolved.isEmpty) {
        debugPrint('DedupCheckUtils: filter ${filter.key} resolved to nothing, '
            'dropping it.');
        continue;
      }

      filters.add(SearchFilter(
        field: filter.key,
        operator: filter.operation,
        value: resolved,
        root: filter.root ?? config.model,
      ));
    }

    return filters;
  }

  /// Loads the scoped corpus and scores [probe] against it.
  static Future<List<DedupMatch>> findMatches(
    DedupCheck config,
    Map<String, dynamic> probe,
    List<SearchFilter> filters,
  ) async {
    final service = CrudBlocSingleton().crudService;
    // Lazily initialize if not yet ready (matches CrudBloc._onSearch pattern)
    if (!service.isInitialized) service.init();

    final (results, _) = await service.searchEntities(
      query: GlobalSearchParameters(
        filters: filters,
        select: [config.model],
        primaryModel: config.model,
        pagination: PaginationParams(
          limit: config.effectiveMaxCandidates,
          offset: 0,
        ),
      ),
    );

    final corpus = projectCorpus(results[config.model] ?? const []);
    debugPrint('DedupCheckUtils: scoring against ${corpus.length} candidates');
    if (corpus.isEmpty) return const [];

    return DedupEngine(matchThreshold: config.effectiveMatchThreshold)
        .findMatchesFor(
      probe,
      corpus,
      maxResults: config.effectiveMaxResults,
    );
  }

  /// Projects entities onto the attribute maps the dedup engine scores.
  ///
  /// Only [IndividualModel] is handled: name similarity is the whole point of
  /// the check, and no other entity carries a person's name. Records with no
  /// name at all are dropped since there is nothing to score them on.
  static List<Map<String, dynamic>> projectCorpus(List<EntityModel> entities) {
    final corpus = <Map<String, dynamic>>[];

    for (final entity in entities) {
      if (entity is! IndividualModel) continue;

      final givenName = entity.name?.givenName?.trim();
      final familyName = entity.name?.familyName?.trim();
      final nameParts = [givenName, familyName]
          .whereType<String>()
          .where((part) => part.isNotEmpty)
          .toList();
      if (nameParts.isEmpty) continue;

      corpus.add({
        'givenName': givenName,
        'familyName': familyName,
        'fatherName': entity.fatherName,
        'dateOfBirth': entity.dateOfBirth,
        'gender': entity.gender?.name,
        // Nullable on the model and optional on the form; the matcher skips
        // it unless both sides have one.
        'mobileNumber': entity.mobileNumber,
        DedupRecordKeys.displayName: nameParts.join(' '),
        DedupRecordKeys.beneficiaryId: beneficiaryIdOf(entity),
        DedupRecordKeys.clientReferenceId: entity.clientReferenceId,
      });
    }

    return corpus;
  }

  /// The individual's beneficiary ID, or null when they have not been issued
  /// one yet.
  static String? beneficiaryIdOf(IndividualModel individual) {
    for (final identifier
        in individual.identifiers ?? const <IdentifierModel>[]) {
      if (identifier.identifierType != beneficiaryIdentifierType) continue;
      final id = identifier.identifierId?.trim();
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  /// Abandons the form for the search screen the config names, popping the
  /// form pages on the way. Does nothing when no page is configured, leaving
  /// the user on the form.
  static void _navigateToSearch(DedupCheck config) {
    final page = config.backToSearchPage;
    if (page == null || page.isEmpty) {
      debugPrint('DedupCheckUtils: no backToSearchPage configured, staying on '
          'the form.');
      return;
    }

    NavigationRegistry.navigateTo({
      'type': 'TEMPLATE',
      'name': page,
      'navigationMode': 'popUntil',
      'popUntilPageName': page,
    });
  }
}
