/// Coarse presets, each mapping to a set of `AppSecurityFeature`s.
///
/// See `AppSecurity.levelPresets` for the mapping.
enum AppSecurityLevel {
  low,
  medium,
  high,

  /// Set automatically when features are chosen individually rather than
  /// through a preset.
  custom,
}
