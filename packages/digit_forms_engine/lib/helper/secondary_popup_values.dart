import '../models/property_schema/property_schema.dart';
import '../utils/computed_value.dart';

/// Whether a secondary-popup body field is a read-only computed row.
bool isComputedPopupField(SecondaryAlertBodyField field) =>
    field.computedValue != null;

/// The text a computed popup row shows for the values typed so far, or ''
/// while its source is empty or not a number. Null for a field that is not
/// computed.
String? computedPopupText(
  SecondaryAlertBodyField field,
  Map<String, String> values,
) {
  final config = field.computedValue;
  if (config == null) return null;
  return divideForDisplay(
        values[config.sourceField],
        config.divideBy,
        config.decimals,
      ) ??
      '';
}

/// What the popup hands to its confirm action: every typed field (trimmed),
/// plus a dropdown's revealed detail while its revealing option is picked.
/// Computed rows are left out - they only show a typed value differently.
///
/// The page the popup opened from is added under its [pageName], so the
/// action can read page fields as `formData.<page>.<field>` - the same path
/// the primary action uses (e.g. the stock Accept screen's scanned bales).
/// The action's form data otherwise holds only what navigation stored.
Map<String, dynamic> secondaryPopupData(
  List<SecondaryAlertBodyField> fields,
  Map<String, String> values, {
  String? pageName,
  Map<String, dynamic>? pageValues,
}) {
  return <String, dynamic>{
    if (pageName != null && pageName.isNotEmpty && pageValues != null)
      pageName: pageValues,
    for (final field in fields)
      if (!isComputedPopupField(field)) ...{
        field.fieldName: (values[field.fieldName] ?? '').trim(),
        if (field.revealsFreeTextOn != null &&
            values[field.fieldName] == field.revealsFreeTextOn)
          '${field.fieldName}Detail':
              (values['${field.fieldName}Detail'] ?? '').trim(),
      },
  };
}
