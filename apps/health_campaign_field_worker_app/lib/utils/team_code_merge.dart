import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/utils/team_ownership.dart';

/// Fields to persist on the logged-in user's Individual when appending a
/// `team_mapping_*` entry. The whole record syncs upstream afterwards, so the
/// server's `team_code` wins whenever the server could be reached; offline,
/// the local copy's code is kept. No other remote key is copied.
List<AdditionalField> mergeTeamCodeIntoFields({
  required List<AdditionalField> existing,
  required bool remoteReachable,
  required dynamic remoteFields,
  required AdditionalField mapping,
}) {
  final teamCode = remoteReachable
      ? readAdditionalField(remoteFields, kTeamCodeKey)
      : readAdditionalField(existing, kTeamCodeKey);

  return [
    ...existing.where((field) => field.key != kTeamCodeKey),
    if (teamCode != null) AdditionalField(kTeamCodeKey, teamCode),
    mapping,
  ];
}
