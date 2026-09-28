/// Host-app injectable hooks used by built-in forms-engine functions
/// (see `functionRegistry` in `utils.dart`).
///
/// The forms engine is intentionally app-agnostic, so any data that lives in
/// the host app (e.g. stock balances, campaign unit settings) is provided
/// through these hooks instead of importing app code. The host registers them
/// once at startup.
class FormsFunctionConfig {
  FormsFunctionConfig._();

  static final FormsFunctionConfig instance = FormsFunctionConfig._();

  /// Resolves the current stock balance for a product variant. Used by the
  /// `calculateWastage` function. Returns 0 when no resolver is registered.
  num Function(String productVariantId)? stockBalanceResolver;

  /// Resolves how many display units make up one base stock unit, e.g. `30`
  /// when a campaign records stock in bottles but accounts for it in ml.
  ///
  /// Registered as a callback rather than a plain value so the host can load
  /// the campaign config after the registry has been wired up, and so a config
  /// refresh is picked up without re-registering.
  double Function()? unitMultiplierResolver;

  /// Display units per base unit. Defaults to `1` (no conversion), which is
  /// what a campaign counting whole units wants.
  double get unitMultiplier {
    final resolved = unitMultiplierResolver?.call();
    if (resolved == null || resolved <= 0) return 1.0;
    return resolved;
  }
}
