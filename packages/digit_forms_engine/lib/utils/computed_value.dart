/// Divides [raw] by [divideBy] and formats it with exactly [decimals] decimals,
/// e.g. 60 pieces at 50 per bale → "1.20".
///
/// [raw] may be a number or numeric text, since form controls and popup fields
/// hold either. Returns null - never throws, because this runs while a field
/// builds - when [raw] is missing, not a finite number or negative, or when
/// [divideBy] or [decimals] cannot produce a result.
String? divideForDisplay(Object? raw, num divideBy, int decimals) {
  if (divideBy <= 0 || decimals < 0 || decimals > 20) return null;

  final num? value = raw is num ? raw : num.tryParse(raw?.toString().trim() ?? '');
  if (value == null || !value.isFinite || value < 0) return null;

  return (value / divideBy).toStringAsFixed(decimals);
}
