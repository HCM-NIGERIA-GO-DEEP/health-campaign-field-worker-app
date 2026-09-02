/// A confirmed device-integrity problem.
///
/// A check that could not *run* is not a threat — see
/// `SecurityCheckResult.unavailableChecks`.
enum SecurityThreatType {
  root,
  emulator,
  hook,
  debugger,
  repackaging,

  /// Reserved for a threat that does not fit the categories above. Note this
  /// is deliberately *not* produced when a check fails to execute.
  unknown,
}
