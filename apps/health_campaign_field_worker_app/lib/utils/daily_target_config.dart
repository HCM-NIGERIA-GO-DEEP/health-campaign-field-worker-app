/// Daily target for the home progress bar, read from the REGISTRATION flow
/// config instead of the project record.
///
/// Config shape (top-level key of the flow config):
///
/// ```json
/// "dailyTarget": { "registrar": 65, "distributor": 65 }
/// ```
///
/// Import-free on purpose, so its tests compile on their own.
library;

/// Top-level key of the flow config that holds the per-role targets.
const String dailyTargetConfigKey = 'dailyTarget';

/// Key of the registrar's target inside [dailyTargetConfigKey].
const String dailyTargetRegistrarKey = 'registrar';

/// Key of the distributor's target inside [dailyTargetConfigKey].
const String dailyTargetDistributorKey = 'distributor';

/// Which role's target applies. Mirrors the progress bar's count rule: a
/// registrar-only user counts registrations, every other user (distributor
/// or combined) counts deliveries.
String dailyTargetRoleKey({
  required bool isRegistrar,
  required bool isDistributor,
}) =>
    isRegistrar && !isDistributor
        ? dailyTargetRegistrarKey
        : dailyTargetDistributorKey;

/// The configured daily target for the role, or null when the config holds
/// no usable value (key missing, wrong shape, not a number, zero or
/// negative). Callers fall back to the project target on null. Never throws.
double? dailyTargetFromFlowConfig(
  dynamic flowConfig, {
  required bool isRegistrar,
  required bool isDistributor,
}) {
  if (flowConfig is! Map) return null;
  final targets = flowConfig[dailyTargetConfigKey];
  if (targets is! Map) return null;

  final raw = targets[dailyTargetRoleKey(
    isRegistrar: isRegistrar,
    isDistributor: isDistributor,
  )];

  final double? value;
  if (raw is num) {
    value = raw.toDouble();
  } else if (raw is String) {
    value = double.tryParse(raw.trim());
  } else {
    value = null;
  }

  if (value == null || !value.isFinite || value <= 0) return null;
  return value;
}
