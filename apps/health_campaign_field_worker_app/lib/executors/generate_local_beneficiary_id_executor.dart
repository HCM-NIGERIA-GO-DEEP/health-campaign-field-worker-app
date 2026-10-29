import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/id_status.dart';
import 'package:digit_flow_builder/action_handler/action_config.dart';
import 'package:digit_flow_builder/action_handler/executors/action_executor.dart';
import 'package:digit_flow_builder/blocs/flow_crud_bloc.dart';
import 'package:digit_flow_builder/utils/interpolation.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:digit_flow_builder/widget_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/local_store/app_shared_preferences.dart';
import '../data/repositories/local/localization.dart';
import '../services/device_id_service.dart';

/// Generates a `unique_beneficiary_id` locally instead of popping one off the
/// server-downloaded `UniqueIdPool`. Replaces `LOAD_UNIQUE_ID_POOL` 1:1: it
/// writes the same `latestBeneficiaryId` / `uniqueIdPoolCount` keys into
/// `FlowCrudStateRegistry` widget data and `contextData`, so the rest of the
/// flow (hidden `idPopulator` field, `UNIQUE_BENEFICIARY_ID` nav param,
/// `buildIdentifierEntries` mapping) keeps working unmodified.
///
/// Current format:
/// `<DIS>_<CHI>_<PHU>_<DP>_<COM>_<F><L>_DDMMYYYY_HHMMSS`, e.g. `BOM_BIR_KAM_KAM_YEB_JD_15102026_143715`
/// - DIS/CHI/PHU/DP/COM: first 3 letters of the District/Chiefdom/PHU/
///   Distribution Point/Community names, resolved from
///   `FlowBuilderSingleton().fullBoundary`'s `materializedPath` (ancestor
///   boundary codes, set in `project.dart`'s `_loadProjectFacilities` from
///   the full remote boundary tree) via the local localization cache - see
///   `_resolveBoundaryNamePrefixes`. Assumes these 5 are always the LAST 5
///   entries of the materialized path (the lowest 5 hierarchy levels), e.g.
///   `...KAMBIA.TONKO_LIMBA_CHIEFDOM.YEBAYA_MCHP.YEBAYA_MCHP.YEBAYA` for
///   District/Chiefdom/PHU/DistributionPoint/Community respectively.
/// - F/L: first letters of the household head's first/last name, read off
///   `contextData['formData']['householdDetails']` - this action now runs as
///   part of the HOUSEHOLD form's final (4th page) submit, not at
///   `searchBeneficiary` init time, specifically so that data exists yet.
///
/// The timestamp is second-granular and includes the date. It previously
/// dropped the date entirely and used minute granularity, so two
/// registrations at the same clock minute - even on different days - in the
/// same boundary whose heads shared initials (namePart is only two INITIALS,
/// so "John Doe" and "Jane Davis" both give "JD") produced the SAME id. That
/// is what made a registration started right after backing out of another
/// reuse its id.
///
/// Second granularity narrows that window but cannot close it, so every
/// generated id is additionally checked against the local UniqueIdPool via
/// `_disambiguateAgainstLocalPool` and suffixed if this device has already
/// issued it. Cross-DEVICE collisions remain possible (two offline devices,
/// same boundary, same initials, same second) - the local table cannot see
/// another device's ids. Still flagged for a future revision.
///
/// The generated id is also persisted locally as an `UN_ASSIGNED`
/// `UniqueIdPoolModel` row (`createOpLog: false` - this never goes through
/// the server pool, so it must never sync up) purely as a local audit trail
/// and so the existing `UPDATE_IDENTIFIER_STATUS` step (which looks a
/// submitted identifier up in this same table) has a row to flip to
/// `ASSIGNED` instead of silently finding nothing.
class GenerateLocalBeneficiaryIdExecutor extends ActionExecutor {
  @override
  bool canHandle(String actionType) =>
      actionType == 'GENERATE_LOCAL_BENEFICIARY_ID';

  @override
  Future<Map<String, dynamic>> execute(
    ActionConfig action,
    BuildContext context,
    Map<String, dynamic> contextData,
  ) async {
    final crudCtx = CrudItemContext.of(context);
    final compositeKey =
        crudCtx?.compositeKey ?? getEffectiveCompositeKey(context, contextData);

    final formData = contextData['formData'] as Map<String, dynamic>?;
    final householdDetails =
        formData?['householdDetails'] as Map<String, dynamic>?;
    final firstName = (householdDetails?['nameOfIndividual'] ?? '').toString();
    final lastName = (householdDetails?['familyname'] ?? '').toString();

    // Check if an ID was already generated during this registration session
    final currentState =
        compositeKey != null ? FlowCrudStateRegistry().get(compositeKey) : null;
    final existingFromRegistry =
        currentState?.widgetData?['latestBeneficiaryId']?.toString();
    final existingFromContext = contextData['latestBeneficiaryId']?.toString();
    final navMap = contextData['navigation'] as Map<String, dynamic>?;
    final existingFromNav = (navMap?['latestBeneficiaryId'] ??
            navMap?['UNIQUE_BENEFICIARY_ID'] ??
            navMap?['beneficiaryId'])
        ?.toString();

    final firstInitial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final lastInitial = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    final currentInitials = '$firstInitial$lastInitial';

    bool isReusable(String? id) {
      if (id == null || id.isEmpty) return false;
      // When we can't determine the registrant's initials (both names blank),
      // never reuse an existing ID — it might belong to a different household.
      if (currentInitials.isEmpty) return false;
      final parts = id.split('_');
      // Expected format: DIS_CHI_PHU_DP_COM_INITIALS_DATE_TIME
      // The initials segment sits 3 positions from the end.
      if (parts.length >= 3) {
        final idInitials = parts[parts.length - 3];
        return idInitials == currentInitials;
      }
      // Unrecognised format — don't risk reusing a mismatched ID.
      return false;
    }

    String beneficiaryId;
    if (isReusable(existingFromRegistry)) {
      beneficiaryId = existingFromRegistry!;
    } else if (isReusable(existingFromContext)) {
      beneficiaryId = existingFromContext!;
    } else if (isReusable(existingFromNav)) {
      beneficiaryId = existingFromNav!;
    } else {
      final boundaryPrefixes = await _resolveBoundaryNamePrefixes(context);
      beneficiaryId = generateBeneficiaryId(
        boundaryPrefixes: boundaryPrefixes,
        firstName: firstName,
        lastName: lastName,
      );
      beneficiaryId =
          await _disambiguateAgainstLocalPool(context, beneficiaryId);
      await _persistLocally(context, beneficiaryId);
    }

    if (compositeKey != null) {
      final currentWidgetData =
          Map<String, dynamic>.from(currentState?.widgetData ?? {});
      currentWidgetData['uniqueIdPoolCount'] = 1;
      currentWidgetData['latestBeneficiaryIdModel'] = null;
      currentWidgetData['latestBeneficiaryId'] = beneficiaryId;

      final updatedState = (currentState ?? const FlowCrudState()).copyWith(
        widgetData: currentWidgetData,
      );
      FlowCrudStateRegistry().update(compositeKey, updatedState);
    }

    final updatedFormData = Map<String, dynamic>.from(formData ?? {});
    final updatedHouseholdDetails =
        Map<String, dynamic>.from(householdDetails ?? {});
    updatedHouseholdDetails['identifiers'] =
        'UNIQUE_BENEFICIARY_ID,$beneficiaryId';
    updatedFormData['householdDetails'] = updatedHouseholdDetails;

    return {
      ...contextData,
      'formData': updatedFormData,
      'uniqueIdPoolCount': 1,
      'latestBeneficiaryId': beneficiaryId,
      'latestBeneficiaryIdModel': null,
    };
  }

  /// Returns [candidate] if this device has not already issued it, otherwise
  /// appends `_2`, `_3`, ... until an unused id is found.
  ///
  /// The generated format is deterministic - boundary prefixes, the head's
  /// two name INITIALS, and a timestamp - so distinct households can land on
  /// the same string (same boundary, same initials, same second; or a clock
  /// that stepped backwards). Every id is persisted to the local
  /// UniqueIdPool table, which makes that table the record of what this
  /// device has handed out and therefore a usable uniqueness check.
  ///
  /// Best-effort: if the lookup fails, return the candidate unchanged rather
  /// than blocking the registration - same policy as [_persistLocally].
  Future<String> _disambiguateAgainstLocalPool(
    BuildContext context,
    String candidate,
  ) async {
    try {
      final repository = context
          .read<LocalRepository<UniqueIdPoolModel, UniqueIdPoolSearchModel>>();

      var attempt = candidate;
      // Bounded so a misbehaving repository can never spin forever; two
      // collisions on a second-granular id already means something is very
      // wrong, and 50 gives enormous headroom over that.
      for (var suffix = 2; suffix <= 50; suffix++) {
        final existing =
            await repository.search(UniqueIdPoolSearchModel(id: attempt));
        if (existing.isEmpty) return attempt;
        debugPrint('GENERATE_LOCAL_BENEFICIARY_ID: $attempt already issued on '
            'this device, disambiguating');
        attempt = '${candidate}_$suffix';
      }
      return attempt;
    } catch (e) {
      debugPrint('GENERATE_LOCAL_BENEFICIARY_ID: uniqueness check failed for '
          '$candidate: $e');
      return candidate;
    }
  }

  /// Best-effort: a failure here (including a primary-key clash) must not
  /// block the user from continuing registration with the id they were
  /// already shown.
  Future<void> _persistLocally(
    BuildContext context,
    String beneficiaryId,
  ) async {
    try {
      final deviceUuid = await DeviceIdService.getDeviceId();
      final userUuid = FlowBuilderSingleton().loggedInUserUuid ?? '';
      final tenantId = FlowBuilderSingleton().selectedProject?.tenantId;
      final now = DateTime.now().millisecondsSinceEpoch;

      final model = UniqueIdPoolModel(
        id: beneficiaryId,
        status: IdStatus.unAssigned.toValue(),
        deviceUuid: deviceUuid,
        userUuid: userUuid,
        tenantId: tenantId,
        auditDetails: AuditDetails(
          createdBy: userUuid,
          createdTime: now,
        ),
      );

      final repository = context
          .read<LocalRepository<UniqueIdPoolModel, UniqueIdPoolSearchModel>>();
      await repository.create(model, createOpLog: false);
    } catch (e) {
      debugPrint(
          'GENERATE_LOCAL_BENEFICIARY_ID: failed to persist $beneficiaryId locally: $e');
    }
  }

  /// Walks `FlowBuilderSingleton().fullBoundary` (set in `project.dart`'s
  /// `_loadProjectFacilities` from the full remote boundary tree, so its
  /// `materializedPath` is the authoritative root-to-leaf chain) and resolves
  /// the lowest 5 ancestor codes' display names, in
  /// District/Chiefdom/PHU/DistributionPoint/Community order. Returns each
  /// name's first 3 letters uppercased.
  ///
  /// Tries the local localization cache first (`hcm-boundary-*` module), but
  /// that module only caches whatever boundary level was actually rendered
  /// on the picker screen - in practice that's the leaf the user drilled
  /// down to, not every ancestor they passed through. So any code missing
  /// from that cache falls back to a direct lookup against the local
  /// `Boundary` table, which holds every synced level's `name` regardless of
  /// what the picker UI ever displayed.
  ///
  /// Falls back to the raw boundary code (or 'XXX') per level if neither
  /// source has a name, rather than failing the whole id generation.
  @visibleForTesting
  Future<List<String>> resolveBoundaryNamePrefixes(BuildContext context) =>
      _resolveBoundaryNamePrefixes(context);

  /// Recovers the root-to-leaf boundary chain from the local Boundary table
  /// when FlowBuilderSingleton().fullBoundary is unset. Returns null when the
  /// selected boundary is unknown or its row carries no materializedPath.
  Future<String?> _materializedPathFromBoundaryTable(
    BuildContext context,
  ) async {
    final code = FlowBuilderSingleton().boundary?.code;
    if (code == null || code.isEmpty) return null;

    try {
      final boundaryRepo =
          context.read<LocalRepository<BoundaryModel, BoundarySearchModel>>();
      // search does a materializedPath LIKE match, so it can return several
      // descendants - filter to the exact row.
      final results =
          await boundaryRepo.search(BoundarySearchModel(codes: code));
      final exact = results.where((b) => b.code == code);
      if (exact.isEmpty) return null;
      final path = exact.first.materializedPath;
      if (path == null || path.isEmpty) return null;
      return path;
    } catch (e) {
      debugPrint(
          'GENERATE_LOCAL_BENEFICIARY_ID: boundary path recovery failed: $e');
      return null;
    }
  }

  Future<List<String>> _resolveBoundaryNamePrefixes(
    BuildContext context,
  ) async {
    // fullBoundary is in-memory only and is set in exactly one place -
    // project.dart's _loadProjectFacilities. A session that resumes without
    // re-running that path (relaunch on a cached project) therefore has a
    // correct `boundary` but a null `fullBoundary`, and every id generated
    // in that session came out as "ZZZ_ZZZ_ZZZ_ZZZ_ZZZ_..".
    //
    // The local Boundary table is synced and holds materializedPath for
    // every level, so the selected boundary's own code is enough to recover
    // the chain. Fall back to that before giving up.
    var materializedPath =
        FlowBuilderSingleton().fullBoundary?.materializedPath;
    if (materializedPath == null || materializedPath.isEmpty) {
      materializedPath = await _materializedPathFromBoundaryTable(context);
    }
    if (materializedPath == null || materializedPath.isEmpty) {
      return const ['ZZZ', 'ZZZ', 'ZZZ', 'ZZZ', 'ZZZ'];
    }

    final allCodes = materializedPath.split('.');
    // The 5 levels we want (District, Chiefdom, PHU, Distribution Point,
    // Community) are assumed to be the lowest 5 in the hierarchy, i.e. the
    // last 5 codes - e.g. for
    // ADMIN_KAMBIA_SI.ADMIN_KAMBIA_SI_01_NORTH_WEST.ADMIN_KAMBIA_SI_01_01_KAMBIA
    // .ADMIN_KAMBIA_SI_01_01_09_TONKO_LIMBA_CHIEFDOM
    // .ADMIN_KAMBIA_SI_01_01_09_17_YEBAYA_MCHP
    // .ADMIN_KAMBIA_SI_01_01_09_17_03_YEBAYA_MCHP
    // .ADMIN_KAMBIA_SI_01_01_09_17_03_03_YEBAYA
    // the last 5 codes are District=KAMBIA, Chiefdom=TONKO_LIMBA_CHIEFDOM,
    // PHU=YEBAYA_MCHP, DistributionPoint=YEBAYA_MCHP, Community=YEBAYA.
    final codes =
        allCodes.length >= 5 ? allCodes.sublist(allCodes.length - 5) : allCodes;

    final nameByCode = <String, String>{};

    try {
      final sql = context.read<LocalSqlDataStore>();
      final locale = AppSharedPreferences().getSelectedLocale ?? 'en_IN';

      final cached =
          await LocalizationLocalRepository().fetchLocalizationByCodes(
        sql: sql,
        locale: locale,
        codes: codes,
      );
      for (final l in cached) {
        nameByCode[l.code] = l.message;
      }
    } catch (e) {
      debugPrint(
          'GENERATE_LOCAL_BENEFICIARY_ID: localization lookup failed: $e');
    }

    final missingCodes = codes.where((c) => !nameByCode.containsKey(c));
    if (missingCodes.isNotEmpty) {
      try {
        final boundaryRepo =
            context.read<LocalRepository<BoundaryModel, BoundarySearchModel>>();
        for (final code in missingCodes) {
          // BoundaryLocalRepository.search does a materializedPath LIKE
          // match on `codes`, not a batch exact-code lookup, so it can
          // return several descendants of `code` - filter to the exact row.
          final results =
              await boundaryRepo.search(BoundarySearchModel(codes: code));
          final exact = results.where((b) => b.code == code);
          if (exact.isNotEmpty && exact.first.name != null) {
            nameByCode[code] = exact.first.name!;
          }
        }
      } catch (e) {
        debugPrint(
            'GENERATE_LOCAL_BENEFICIARY_ID: boundary table lookup failed: $e');
      }
    }

    final prefixes = codes.map((code) {
      final name = nameByCode[code] ?? code;
      return _firstThreeLetters(name);
    }).toList();
    return prefixes;
  }

  String _firstThreeLetters(String value) {
    final letters = value.toUpperCase();
    return letters.length >= 3 ? letters.substring(0, 3) : letters;
  }

  /// `<DIS>_<CHI>_<PHU>_<DP>_<COM>_<F><L>_DDMMYYYY_HHMMSS`,
  /// e.g. `BOM_BIR_KAM_KAM_YEB_JD_15102026_143715`.
  ///
  /// Callers must pass the result through [_disambiguateAgainstLocalPool]:
  /// this alone is NOT guaranteed unique.
  @visibleForTesting
  String generateBeneficiaryId({
    required List<String> boundaryPrefixes,
    required String firstName,
    required String lastName,
  }) {
    final boundaryPart = boundaryPrefixes.join('_');

    final firstInitial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final lastInitial = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    final namePart = '$firstInitial$lastInitial';

    final now = DateTime.now();
    final datePart = '${now.day.toString().padLeft(2, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.year.toString().padLeft(4, '0')}';
    final hourPart = now.hour.toString().padLeft(2, '0');
    final minutePart = now.minute.toString().padLeft(2, '0');
    // datePart was computed and then silently dropped from the returned
    // string, so two registrations at the same clock minute on DIFFERENT
    // DAYS produced byte-identical ids. Restored, as the documented format
    // above always said it should be.
    //
    // Seconds are included too: namePart is only the two INITIALS of the
    // head's first/last name, so "John Doe" and "Jane Davis" already
    // collapse to the same "JD". With minute-only granularity any two
    // households registered in the same boundary within the same minute
    // whose heads share initials got the same id - which is what made a
    // fresh registration right after backing out of one reuse its id.
    final secondPart = now.second.toString().padLeft(2, '0');

    return '${boundaryPart}_${namePart}_${datePart}_'
        '$hourPart$minutePart$secondPart';
  }
}
