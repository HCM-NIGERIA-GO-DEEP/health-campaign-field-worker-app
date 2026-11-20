/// Multiplies [raw] by [multiplyBy], divides it by [divideBy] and formats it
/// with exactly [decimals] decimals, e.g. 60 pieces at 50 per bale → "1.20",
/// or 3 bales at 50 pieces each (multiplyBy 50, divideBy 1, decimals 0) →
/// "150".
///
/// [raw] may be a number or numeric text, since form controls and popup fields
/// hold either. Returns null - never throws, because this runs while a field
/// builds - when [raw] is missing, not a finite number or negative, or when
/// [divideBy], [multiplyBy] or [decimals] cannot produce a result.
String? divideForDisplay(
  Object? raw,
  num divideBy,
  int decimals, {
  num multiplyBy = 1,
}) {
  if (divideBy <= 0 || multiplyBy <= 0 || decimals < 0 || decimals > 20) {
    return null;
  }

  final num? value = raw is num ? raw : num.tryParse(raw?.toString().trim() ?? '');
  if (value == null || !value.isFinite || value < 0) return null;

  return (value * multiplyBy / divideBy).toStringAsFixed(decimals);
}
