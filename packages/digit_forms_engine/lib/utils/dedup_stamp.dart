import '../models/property_schema/property_schema.dart';
import '../widgets/dedup_check_provider.dart';

/// Hidden form fields that record a "Skip and Proceed" on the duplicate
/// warning, so the decision travels with the registration.
///
/// They are added to the submitting page as hidden `includeInForm` properties,
/// which `FormsBloc` emits like any other value (`<page>.<field>`); the
/// transformer config maps them onto the Individual's `additionalFields`.
/// A "Back to Search" creates no record, so it is never stamped.
abstract final class DedupStampFields {
  static const String decision = 'dedupDecision';
  static const String topScore = 'dedupTopScore';
  static const String matchCount = 'dedupMatchCount';
  static const String topMatchId = 'dedupTopMatchId';

  static const List<String> all = [decision, topScore, matchCount, topMatchId];

  /// Value of [decision] when the user registered despite the warning.
  static const String skippedValue = 'SKIPPED';
}

/// The stamp properties for [result], or an empty map when there is nothing
/// to record.
///
/// Merge into the page's properties with [applyDedupStamp] rather than
/// directly: page properties persist in the cached schema, so a stamp from an
/// earlier submit attempt has to be cleared when the current one shows no
/// dialog, or a stale decision would be written.
Map<String, PropertySchema> dedupStampProperties(DedupCheckResult result) {
  if (result.decision != DedupDecision.skipped) return const {};

  PropertySchema hidden(String? value) => PropertySchema(
        type: PropertySchemaType.string,
        value: value,
        hidden: true,
        includeInForm: true,
      );

  final topScore = result.topScore;

  return {
    DedupStampFields.decision: hidden(DedupStampFields.skippedValue),
    DedupStampFields.topScore:
        hidden(topScore == null ? null : (topScore * 100).round().toString()),
    DedupStampFields.matchCount: hidden(result.matchCount.toString()),
    DedupStampFields.topMatchId: hidden(result.topMatchClientReferenceId),
  };
}

/// Replaces any earlier stamp in [properties] with the one for [result].
void applyDedupStamp(
  Map<String, PropertySchema> properties,
  DedupCheckResult result,
) {
  properties.removeWhere((key, _) => DedupStampFields.all.contains(key));
  properties.addAll(dedupStampProperties(result));
}
