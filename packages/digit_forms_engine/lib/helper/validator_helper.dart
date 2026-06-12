import 'package:digit_forms_engine/helper/form_builder_helper.dart';
import 'package:digit_formula_parser/digit_formula_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../models/property_schema/property_schema.dart';

// Global registry for page schemas - used by validators to access cross-page values
final Map<String, Map<String, PropertySchema>> _pagesRegistry = {};

// Global registry for navigation params - used by validators to access navigation values
final Map<String, Map<String, dynamic>> _navigationParamsRegistry = {};

void registerPagesForValidation(
    String schemaKey, Map<String, PropertySchema> pages) {
  _pagesRegistry[schemaKey] = pages;
}

void unregisterPagesForValidation(String schemaKey) {
  _pagesRegistry.remove(schemaKey);
}

void registerNavigationParams(
    String schemaKey, Map<String, dynamic> navigationParams) {
  _navigationParamsRegistry[schemaKey] = navigationParams;
}

void unregisterNavigationParams(String schemaKey) {
  _navigationParamsRegistry.remove(schemaKey);
}

/// Resolves a value that may be a navigation param reference (e.g., "navigation.stockBalance")
/// Returns the resolved value or null if not found
dynamic _resolveNavigationValue(dynamic value, String? schemaKey) {
  if (value is! String || schemaKey == null) return value;
  if (!value.startsWith('navigation.')) return value;

  final navParams = _navigationParamsRegistry[schemaKey];
  if (navParams == null) return null;

  // Extract the key after "navigation."
  final key = value.substring('navigation.'.length);
  return navParams[key];
}

List<Validator<T>> buildValidators<T>(PropertySchema schema,
    {String? schemaKey}) {
  final List<Validator<T>> validators = [];

  if (schema.validations != null) {
    for (final rule in schema.validations!) {
      switch (rule.type) {
        case 'minLength':
          final parsedValue = parseIntValue(rule.value);

          if (schema.type != PropertySchemaType.integer) {
            if (parsedValue != null) {
              validators.add(Validators.composeOR([
                Validators.minLength(parsedValue) as Validator<T>,
                Validators.composeOR(
                    [Validators.equals(''), Validators.equals(null)]),
              ]) as Validator<T>);
            }
          }

          break;

        case 'maxLength':
          final parsedValue = parseIntValue(rule.value);
          if (parsedValue != null &&
              schema.type != PropertySchemaType.integer) {
            validators.add(Validators.composeOR([
              Validators.maxLength(parsedValue) as Validator<T>,
              Validators.composeOR(
                  [Validators.equals(''), Validators.equals(null)]),
            ]) as Validator<T>);
          }
          break;

        case 'min':
        case 'minValue':
          // Check if value is a navigation param reference
          if (rule.value is String &&
              rule.value.startsWith('navigation.') &&
              schemaKey != null) {
            validators.add(Validators.delegate((control) {
              final resolvedValue =
                  _resolveNavigationValue(rule.value, schemaKey);
              final minVal = parseIntValue(resolvedValue);
              if (minVal == null || control.value == null) return null;
              final numValue = num.tryParse(control.value.toString());
              if (numValue == null) return null;
              if (numValue < minVal) {
                return {
                  'min': {'min': minVal, 'actual': numValue}
                };
              }
              return null;
            }) as Validator<T>);
          } else {
            final parsedValue = parseIntValue(rule.value);
            if (parsedValue != null) {
              // Use delegate validator to handle both numeric and string values
              validators.add(Validators.delegate((control) {
                if (control.value == null || control.value.toString().isEmpty) {
                  return null; // Allow null/empty values (required validation handles this)
                }
                final numValue = num.tryParse(control.value.toString());
                if (numValue == null) return null; // Not a valid number, skip
                if (numValue < parsedValue) {
                  return {
                    'min': {'min': parsedValue, 'actual': numValue}
                  };
                }
                return null;
              }) as Validator<T>);
            }
          }
          break;

        case 'max':
        case 'maxValue':
          // Check if value is a navigation param reference
          if (rule.value is String &&
              rule.value.startsWith('navigation.') &&
              schemaKey != null) {
            validators.add(Validators.delegate((control) {
              final resolvedValue =
                  _resolveNavigationValue(rule.value, schemaKey);
              final maxVal = parseIntValue(resolvedValue);
              if (maxVal == null || control.value == null) return null;
              final numValue = num.tryParse(control.value.toString());
              if (numValue == null) return null;
              if (numValue > maxVal) {
                return {
                  'max': {'max': maxVal, 'actual': numValue}
                };
              }
              return null;
            }) as Validator<T>);
          } else {
            final parsedValue = parseIntValue(rule.value);
            if (parsedValue != null) {
              // Use delegate validator to handle both numeric and string values
              validators.add(Validators.delegate((control) {
                if (control.value == null || control.value.toString().isEmpty) {
                  return null; // Allow null/empty values (required validation handles this)
                }
                final numValue = num.tryParse(control.value.toString());
                if (numValue == null) return null; // Not a valid number, skip
                if (numValue > parsedValue) {
                  return {
                    'max': {'max': parsedValue, 'actual': numValue}
                  };
                }
                return null;
              }) as Validator<T>);
            }
          }
          break;

        case 'pattern':
          if (rule.value is List && rule.value.isNotEmpty) {
            validators.add(Validators.composeOR([
              Validators.pattern(RegExp(rule.value.first)) as Validator<T>,
              Validators.composeOR(
                  [Validators.equals(''), Validators.equals(null)]),
            ]) as Validator<T>);
          } else if (rule.value is String && rule.value.isNotEmpty) {
            validators.add(Validators.composeOR([
              Validators.pattern(RegExp(rule.value)) as Validator<T>,
              Validators.composeOR(
                  [Validators.equals(''), Validators.equals(null)]),
            ]) as Validator<T>);
          }
          break;

        case 'regex':
          if (rule.value is String && (rule.value as String).isNotEmpty) {
            final pattern = RegExp(rule.value as String);
            validators.add(Validators.delegate((control) {
              final value = control.value?.toString();
              if (value == null || value.isEmpty) return null;
              return pattern.hasMatch(value) ? null : {'regex': true};
            }) as Validator<T>);
          }
          break;

        case 'required':
          if (rule.value == true) {
            validators.add(Validators.required as Validator<T>);
          }
          break;

        case 'notEqualTo':
          if (rule.value is String && schemaKey != null) {
            validators.add(Validators.delegate(
              (control) => _notEqualToValidator(
                  rule.value as String, control, schemaKey),
            ) as Validator<T>);
          }
          break;

        // Relative max bound: the maximum allowed value is an arithmetic
        // expression that may reference other fields, e.g. "{{memberCount - 1}}".
        // The expression is evaluated live against sibling field values via
        // FormulaParser; this field's value must be <= the evaluated bound.
        case 'relativeMax':
          if (rule.value is String) {
            validators.add(Validators.delegate((control) {
              if (control.value == null || control.value.toString().isEmpty) {
                return null;
              }
              final numValue = num.tryParse(control.value.toString());
              if (numValue == null) return null;
              final bound =
                  _evaluateRelativeBound(rule.value, control, schemaKey);
              if (bound == null) return null;
              if (numValue > bound) {
                return {
                  'relativeMax': {'max': bound, 'actual': numValue}
                };
              }
              return null;
            }) as Validator<T>);
          }
          break;

        // Relative min bound: the minimum allowed value is an arithmetic
        // expression that may reference other fields, e.g. "{{childrenCount + 1}}".
        // This field's value must be >= the evaluated bound.
        case 'relativeMin':
          if (rule.value is String) {
            validators.add(Validators.delegate((control) {
              if (control.value == null || control.value.toString().isEmpty) {
                return null;
              }
              final numValue = num.tryParse(control.value.toString());
              if (numValue == null) return null;
              final bound =
                  _evaluateRelativeBound(rule.value, control, schemaKey);
              if (bound == null) return null;
              if (numValue < bound) {
                return {
                  'relativeMin': {'min': bound, 'actual': numValue}
                };
              }
              return null;
            }) as Validator<T>);
          }
          break;

        default:
          if (kDebugMode) {
            // print('Unknown validation type: ${rule.type}');
          }
          break;
      }
    }
  }

  return validators;
}

/// Checks if the validations contain a rule of type 'required'.
bool hasRequiredValidation(List<ValidationRule>? validations) {
  if (validations == null) return false;

  return validations
      .any((rule) => rule.type == 'required' && rule.value == true);
}

int? getMinValue(List<ValidationRule>? validations) {
  if (validations == null) return null;

  for (final rule in validations) {
    if (rule.type == 'min' || rule.type == 'minValue') {
      return parseIntValue(rule.value);
    }
  }
  return null;
}

int? getMaxValue(List<ValidationRule>? validations) {
  if (validations == null) return null;

  for (final rule in validations) {
    if (rule.type == 'max' || rule.type == 'maxValue') {
      return parseIntValue(rule.value);
    }
  }
  return null;
}

int? getMinLength(List<ValidationRule>? validations) {
  if (validations == null) return null;

  for (final rule in validations) {
    if (rule.type == 'minLength') {
      return parseIntValue(rule.value);
    }
  }
  return null;
}

int? getMaxLength(List<ValidationRule>? validations) {
  if (validations == null) return null;

  for (final rule in validations) {
    if (rule.type == 'maxLength') {
      return parseIntValue(rule.value);
    }
  }
  return null;
}

/// Custom validator that checks if a field's value is not equal to another field's value
/// Supports both current page fields and cross-page references using dot notation (e.g., 'warehouseDetails.facilityFromWhich')
Map<String, dynamic>? _notEqualToValidator(
    String otherFieldName, AbstractControl<dynamic> control, String schemaKey) {
  final form = control.parent;
  if (form is! FormGroup) return null;

  final currentValue = control.value;

  // Build flat value map from all pages
  final pages = _pagesRegistry[schemaKey];
  if (pages == null) return null;

  final flatValues = <String, dynamic>{};

  // Add current form values
  form.controls.forEach((key, control) {
    flatValues[key] = control.value;
  });

  // Add all page values with dot notation
  pages.forEach((pageKey, pageSchema) {
    if (pageSchema.properties != null) {
      pageSchema.properties!.forEach((fieldKey, fieldSchema) {
        flatValues['$pageKey.$fieldKey'] = fieldSchema.value;
      });
    }
  });

  debugPrint('Flat Values $flatValues');
  debugPrint('Looking for otherFieldName: $otherFieldName');

  // Look up the other field's value
  final otherValue = flatValues[otherFieldName];
  debugPrint('Found otherValue: $otherValue');

  // Allow null or empty values to pass (required validation handles that separately)
  if (currentValue == null ||
      currentValue == '' ||
      otherValue == null ||
      otherValue == '') {
    return null;
  }

  // Check if values are equal
  if (currentValue == otherValue) {
    return {'notEqualTo': true};
  }

  return null;
}

/// Evaluates a relative numeric bound for `relativeMax` / `relativeMin`
/// validators.
///
/// The [template] is an arithmetic expression wrapped in `{{ }}` that may
/// reference other field names, e.g. `"{{memberCount - 1}}"`. Field references
/// are resolved against the sibling controls in the current page FormGroup
/// first (so the bound reflects live edits), then the cross-page
/// [_pagesRegistry] when a [schemaKey] is available, and the expression is
/// evaluated with [FormulaParser].
///
/// Returns null when the expression is empty, references an unresolved/empty
/// field, or fails to evaluate to a number — in which case the validator passes
/// (the referenced field's own validation handles its emptiness).
num? _evaluateRelativeBound(
    dynamic template, AbstractControl<dynamic> control, String? schemaKey) {
  if (template is! String) return null;

  var expr = template.trim();
  if (expr.startsWith('{{') && expr.endsWith('}}')) {
    expr = expr.substring(2, expr.length - 2).trim();
  }
  if (expr.isEmpty) return null;

  final values = <String, dynamic>{};

  // 1) Cross-page values from the registry (static schema values).
  if (schemaKey != null) {
    final pages = _pagesRegistry[schemaKey];
    pages?.forEach((pageKey, pageSchema) {
      pageSchema.properties?.forEach((fieldKey, fieldSchema) {
        values['$pageKey.$fieldKey'] = fieldSchema.value;
        values.putIfAbsent(fieldKey, () => fieldSchema.value);
      });
    });
  }

  // 2) Sibling (live) values take precedence over static registry values.
  final form = control.parent;
  if (form is FormGroup) {
    form.controls.forEach((key, c) {
      values[key] = c.value;
    });
  }

  try {
    final result =
        FormulaParser(expr, values.isEmpty ? {'dummy': {}} : values).parse;
    final value = result['value'];
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '');
  } catch (_) {
    return null;
  }
}
