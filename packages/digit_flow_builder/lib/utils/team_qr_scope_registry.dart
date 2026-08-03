/// Singleton registry for an app-supplied scan-time scope check on
/// delivery-team QR scanner fields.
///
/// The flow builder cannot resolve the scanning user's boundary/tenant scope
/// itself (that knowledge lives in the app), so the app registers a validator
/// once (see the home page's custom-component registration) together with the
/// scanner field names it applies to and the localization key for the
/// rejection toast. The FORM screen wrapper consults this registry inside the
/// scanner `duplicateCheckFn` seam, so a failing scan is rejected on the
/// scanner page itself (buzzer + error toast, value never stored) on both the
/// camera and manual-entry paths.
class TeamQrScopeRegistry {
  static final TeamQrScopeRegistry _instance =
      TeamQrScopeRegistry._internal();
  factory TeamQrScopeRegistry() => _instance;
  TeamQrScopeRegistry._internal();

  Future<bool> Function(String scannedValue)? _validator;
  Set<String> _fieldNames = const {};
  String? _errorMessageKey;

  /// Registers the scope [validator] for the given scanner [fieldNames]
  /// (form control names, e.g. {'teamCode', 'deliveryTeam'}). [errorMessageKey]
  /// is the localization key shown when a scan is rejected. Re-registering
  /// replaces the previous registration.
  void register({
    required Future<bool> Function(String scannedValue) validator,
    required Set<String> fieldNames,
    required String errorMessageKey,
  }) {
    _validator = validator;
    _fieldNames = fieldNames;
    _errorMessageKey = errorMessageKey;
  }

  /// Whether the scope check applies to the scanner field [fieldName].
  bool appliesTo(String fieldName) =>
      _validator != null && _fieldNames.contains(fieldName);

  /// The rejection message key for [fieldName], or null when the scope check
  /// does not apply to it.
  String? errorMessageFor(String fieldName) =>
      appliesTo(fieldName) ? _errorMessageKey : null;

  /// Runs the registered validator for a scanned value. FAILS CLOSED: any
  /// missing validator or thrown error counts as out-of-scope (returns false),
  /// because this check exists to keep foreign/random QR codes out — the
  /// opposite of the duplicate check, which fails open.
  Future<bool> isInScope(String scannedValue) async {
    final validator = _validator;
    if (validator == null) return false;
    try {
      return await validator(scannedValue);
    } catch (_) {
      return false;
    }
  }

  /// Clears the registration (used by tests).
  void clear() {
    _validator = null;
    _fieldNames = const {};
    _errorMessageKey = null;
  }
}
