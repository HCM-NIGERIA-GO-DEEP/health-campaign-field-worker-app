/// Campaign switch for how other teams' beneficiary records are filtered:
///
/// - `"SHOW"` (also when the key is missing or unknown): every result is
///   shown.
/// - `"HIDE"`: results are filtered to the logged-in team's records.
///
/// The switch drives only the filters. The disable gate ([mayActOn]) is on in
/// both modes, so a record that reaches the screen past the HIDE filter (the
/// proximity search is never team-filtered) still cannot be acted on.
///
/// Read from the top-level `teamRecordVisibility` key of the REGISTRATION flow
/// config (assets/configs/json/REGISTRATION.json, from HCM-SOLUTION-CONFIG),
/// each time the app opens the REGISTRATION module with that config. Users
/// without a team code see and may act on everything in both modes.
///
/// Free of project imports so its unit tests compile standalone, and written
/// so it can never throw into a flow-builder `fn:` (an uncaught throw there
/// blanks the whole TEMPLATE screen body). Lives in the flow-builder package
/// because `disableEdit` reads it alongside the app's registry functions.
library;

import 'team_ownership.dart';

enum TeamRecordMode {
  /// Show every result; disable actions on other teams' records.
  show,

  /// Show only the team's own results; disable anything else that shows up.
  hide,
}

class TeamRecordVisibility {
  TeamRecordVisibility._();

  static const String configKey = 'teamRecordVisibility';
  static const String schemaName = 'REGISTRATION';

  /// The active mode. Set when the REGISTRATION flow config is opened
  /// (FlowNavigationUtils) and read synchronously by the team functions.
  static TeamRecordMode mode = TeamRecordMode.show;

  /// `"HIDE"` (any case, padding ignored) -> hide; anything else -> show.
  static TeamRecordMode parse(dynamic raw) {
    if (raw is String && raw.trim().toUpperCase() == 'HIDE') {
      return TeamRecordMode.hide;
    }
    return TeamRecordMode.show;
  }

  /// The mode a flow config asks for: parsed from its [configKey] when it is
  /// the REGISTRATION config (missing key -> show), null for any other
  /// module's config or non-map input. Never throws.
  static TeamRecordMode? fromFlowConfig(dynamic config) {
    if (config is! Map || config['name'] != schemaName) return null;
    return parse(config[configKey]);
  }

  /// Applies [fromFlowConfig]; other modules' configs leave [mode] unchanged.
  static void applyFlowConfig(dynamic config) {
    final configured = fromFlowConfig(config);
    if (configured != null) mode = configured;
  }

  /// Team code for the result filters (teamFilterValue / isVisibleToMyTeam /
  /// individualsVisibleToMyTeam): the user's code in hide mode, null
  /// otherwise. Null means "no filter, show everything".
  static String? visibilityTeamCode(String? teamCode) =>
      mode == TeamRecordMode.hide ? teamCode : null;

  /// Whether the logged-in team may act on [projectBeneficiaries]: the disable
  /// gate behind `fn:isOwnedByMyTeam` and `disableEdit`'s third argument.
  ///
  /// Hide mode allows exactly what its filters would show
  /// ([isVisibleToMyTeam]), so other teams' records, untagged records and
  /// members without a record are disabled. Show mode disables only records
  /// tagged by another team ([isOwnedByMyTeam]). True in both modes when
  /// [teamCode] is null or blank.
  static bool mayActOn(
    dynamic projectBeneficiaries,
    String? teamCode, {
    String? projectId,
  }) {
    final strict = mode == TeamRecordMode.hide;
    try {
      return strict
          ? isVisibleToMyTeam(projectBeneficiaries, teamCode)
          : isOwnedByMyTeam(
              projectBeneficiaries,
              teamCode,
              projectId: projectId,
            );
    } catch (_) {
      return !strict;
    }
  }
}
