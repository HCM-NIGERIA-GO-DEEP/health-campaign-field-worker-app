/// Single switch for the entire face-auth stack.
///
/// Set to `false` to fully disable face-gate, re-verification, face-session
/// home widgets, and non-mobile face flows.
class FaceAuthFeatureFlag {
  static const bool enabled = false;

  const FaceAuthFeatureFlag._();
}
