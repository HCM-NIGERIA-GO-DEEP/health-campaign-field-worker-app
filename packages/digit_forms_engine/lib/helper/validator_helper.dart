import 'package:digit_forms_engine/helper/form_builder_helper.dart';
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

        // Validates that this field's numeric value does not exceed a
        // sibling field's current value - e.g. childrenCount/
        // pregnantWomenCount must not exceed memberCount, both on the same
        // householdDetails page. rule.value: the sibling field's name.
        // Passes when either value is null/empty/non-numeric (required/
        // pattern validations handle those separately) so this only fires
        // once both fields actually have a comparable number.
        case 'maxField':
          if (rule.value is String) {
            final otherFieldName = rule.value as String;
            validators.add(Validators.delegate((control) {
              final form = control.parent;
              if (form is! FormGroup || !form.contains(otherFieldName)) {
                return null;
              }
              final currentValue =
                  num.tryParse(control.value?.toString() ?? '');
              final otherValue = num.tryParse(
                  form.control(otherFieldName).value?.toString() ?? '');
              if (currentValue == null || otherValue == null) return null;
              // Strict: the sibling is an exclusive upper bound, not an
              // inclusive one. childrenCount is the only consumer and a
              // household cannot be made up entirely of under-5s - there has
              // to be at least one non-child member - so children ==
              // memberCount is invalid, not just children > memberCount.
              if (currentValue >= otherValue) {
                return {
                  'maxField': {'max': otherValue, 'actual': currentValue}
                };
              }
              return null;
            }) as Validator<T>);
          }
          break;

        // Validates that this field has a value whenever a sibling field
        // does - e.g. identificationNumber must be filled in once
        // identificationType is picked, even though neither field is
        // unconditionally mandatory on its own (both optional otherwise,
        // for households with no ID at all). rule.value: the sibling
        // field's name. Passes when the sibling is empty (nothing triggers
        // the requirement) or when this field already has a value.
        case 'requiredIf':
          if (rule.value is String) {
            final otherFieldName = rule.value as String;
            validators.add(Validators.delegate((control) {
              final form = control.parent;
              if (form is! FormGroup || !form.contains(otherFieldName)) {
                return null;
              }
              final otherValue =
                  form.control(otherFieldName).value?.toString() ?? '';
              if (otherValue.isEmpty) return null;
              final value = control.value?.toString() ?? '';
              if (value.isEmpty) {
                return {'requiredIf': otherFieldName};
              }
              return null;
            }) as Validator<T>);
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

        // Validates against a different pattern depending on a sibling
        // field's current value - e.g. identificationNumber's expected
        // format depends on whichever identificationType was picked.
        // rule.value: {"switchOn": "identificationType", "cases": {
        //   "NATIONAL_ID": {"pattern": "...", "message": "..."}, ... }}
        // Skips (passes) when empty, when the sibling field isn't found, or
        // when the current switchOn value has no matching case.
        case 'conditionalPattern':
          if (rule.value is Map) {
            final config = rule.value as Map;
            final switchOnField = config['switchOn']?.toString();
            final cases = config['cases'];
            if (switchOnField != null && cases is Map) {
              validators.add(Validators.delegate((control) {
                final value = control.value?.toString();
                if (value == null || value.isEmpty) return null;

                final form = control.parent;
                if (form is! FormGroup || !form.contains(switchOnField)) {
                  return null;
                }
                final switchValue =
                    form.control(switchOnField).value?.toString();
                if (switchValue == null) return null;

                final caseConfig = cases[switchValue];
                if (caseConfig is! Map) return null;
                final patternStr = caseConfig['pattern']?.toString();
                if (patternStr == null || patternStr.isEmpty) return null;

                if (!RegExp(patternStr).hasMatch(value)) {
                  return {
                    'conditionalPattern': {
                      'messageKey': caseConfig['message']?.toString(),
                    }
                  };
                }
                return null;
              }) as Validator<T>);
            }
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
