/// Daily delivery cap shared between the home progress bar and the
/// flow-builder gate on the DELIVERY button.
///
/// Deliberately import-free (like working_hours.dart) so its unit tests
/// compile standalone even when unrelated lib files are broken, and so it
/// can never throw into a flow-builder `fn:` (an uncaught throw there
/// blanks the whole TEMPLATE screen body).
library;

class DailyDeliveryLimit {
  DailyDeliveryLimit._();

  /// Fallback when the config value is missing or unusable. Must match the
  /// literal shipped in REGISTRATION.json ({{fn:isDailyDeliveryLimitReached('100')}}).
  static const int defaultTarget = 100;

  /// Today's successful-delivery count for the logged-in user.
  /// Written by BeneficiaryProgressBar (the single existing computation:
  /// server rollup + local ADMINISTRATION_SUCCESS tasks, deduped per
  /// beneficiary); read synchronously by fn:isDailyDeliveryLimitReached.
  /// Starts at 0 so a fresh session never blocks (fail-open).
  static int count = 0;

  /// num or numeric String -> positive int; anything else -> [defaultTarget].
  /// Never throws.
  static int parseTarget(dynamic raw) {
    final parsed = _toInt(raw);
    if (parsed == null || parsed <= 0) return defaultTarget;
    return parsed;
  }

  /// True when [rawCount] >= [rawTarget]. An unusable count returns false
  /// (fail-open: never block fieldwork on bad data); an unusable target
  /// falls back to [defaultTarget]. Never throws.
  static bool isLimitReached(dynamic rawCount, dynamic rawTarget) {
    final parsedCount = _toInt(rawCount);
    if (parsedCount == null) return false;
    return parsedCount >= parseTarget(rawTarget);
  }

  static int? _toInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is double) {
      final rounded = raw.round();
      return rounded.toDouble() == raw ? rounded : null;
    }
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }
}
