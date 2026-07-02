/// Host-app injectable hooks used by built-in forms-engine functions
/// (see `functionRegistry` in `utils.dart`).
///
/// The forms engine is intentionally app-agnostic, so any data that lives in
/// the host app (e.g. stock balances) is provided through these hooks instead
/// of importing app code. The host registers them once at startup.
class FormsFunctionConfig {
  FormsFunctionConfig._();

  static final FormsFunctionConfig instance = FormsFunctionConfig._();

  /// Resolves the current stock balance for a product variant. Used by the
  /// `calculateWastage` function. Returns 0 when no resolver is registered.
  num Function(String productVariantId)? stockBalanceResolver;
}
