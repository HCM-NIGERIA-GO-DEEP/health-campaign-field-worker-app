/// Pure helpers for RI (routine immunization) age eligibility.
///
/// Kept import-free so unit tests compile regardless of the state of the
/// wider package, and so the age policy is testable without singletons.
library ri_age_eligibility;

/// RI covers children from birth up to 59 months. This is the fallback used
/// whenever the config does not supply an explicit max age, including every
/// already-deployed config that calls `fn:checkRIEligibility` with 3 args.
///
/// Deliberately NOT derived from the campaign projectType's `validMaxAge`:
/// that field encodes SMC policy (aged-out continuation can push it past 59,
/// e.g. 64 on SMC-RI campaigns) and must not widen RI eligibility.
const int riDefaultMaxAgeMonths = 59;

/// Resolves the RI max-age ceiling (in months) from the optional 4th config
/// argument of `fn:checkRIEligibility(dob, tasks, cycle, maxAgeMonths)`.
///
/// Accepts int or numeric string; tolerates `{{ }}` template remnants and
/// surrounding quotes (same defensive stripping `formatDate` applies to its
/// type argument). Anything absent, unparseable, or non-positive falls back
/// to [riDefaultMaxAgeMonths].
int resolveRiMaxAgeMonths(dynamic raw) {
  if (raw == null) return riDefaultMaxAgeMonths;
  if (raw is int) return raw > 0 ? raw : riDefaultMaxAgeMonths;

  var value = raw.toString().trim();
  value = value.replaceAll(RegExp(r'^\{\{\s*|\s*\}\}$'), '').trim();
  value = value.replaceAll(RegExp('^[\'"]|[\'"]\$'), '').trim();

  final parsed = int.tryParse(value);
  if (parsed == null || parsed <= 0) return riDefaultMaxAgeMonths;
  return parsed;
}

/// Whether a child of [totalAgeMonths] is within the RI age band
/// (0 to the resolved ceiling, both inclusive).
bool isRiAgeEligible(int totalAgeMonths, {dynamic configMaxAge}) {
  if (totalAgeMonths < 0) return false;
  return totalAgeMonths <= resolveRiMaxAgeMonths(configMaxAge);
}
