import 'package:digit_forms_engine/helper/form_builder_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../models/property_schema/property_schema.dart';
import 'package:digit_ui_components/utils/date_utils.dart';
import 'package:intl/intl.dart';
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

/// Resolves a value that may be a field reference (e.g., "{{memberCount}}")
/// Returns the extracted field name or null if not a field reference
String? _extractFieldReference(dynamic value) {
  if (value is! String) return null;
  if (!value.startsWith('{{') || !value.endsWith('}}')) return null;

  // Extract field name from {{fieldName}}
  final fieldName = value.substring(2, value.length - 2).trim();
  return fieldName.isNotEmpty ? fieldName : null;
}

bool _evaluateConditionDelegate(
  String variable,
  FormGroup formGroup,
  Map<String, dynamic>? navParams,
) {
  if (navParams != null && navParams.containsKey(variable)) {
    final value = navParams[variable];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is num) return value != 0;
  }
  if (formGroup.contains(variable)) {
    final value = formGroup.control(variable).value;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is num) return value != 0;
  }
  return false;
}

(int years, int months)? _parseAgeConstraintDelegate(
  dynamic ruleValue,
  FormGroup formGroup,
  Map<String, dynamic>? navParams,
) {
  if (ruleValue == null) return null;
  String evaluated = ruleValue.toString().trim();

  if (evaluated.startsWith('{{') && evaluated.endsWith('}}')) {
    final expr = evaluated.substring(2, evaluated.length - 2).trim();
    final qIndex = expr.indexOf('?');
    final colonIndex = expr.lastIndexOf(':');

    if (qIndex > 0 && colonIndex > qIndex) {
      final condition = expr.substring(0, qIndex).trim();
      final truePart = expr.substring(qIndex + 1, colonIndex).trim();
      final falsePart = expr.substring(colonIndex + 1).trim();

      bool conditionResult = _evaluateConditionDelegate(condition, formGroup, navParams);
      evaluated = conditionResult ? truePart : falsePart;
    } else {
      evaluated = expr;
    }
  }

  final totalMonths = int.tryParse(evaluated.trim());
  if (totalMonths == null) return null;

  final years = totalMonths ~/ 12;
  final months = totalMonths % 12;

  return (years, months);
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
          } else if (rule.value is String &&
              (rule.value.startsWith('{{') && rule.value.endsWith('}}'))) {
            // Handle field reference like {{memberCount}}
            final fieldRef = _extractFieldReference(rule.value);
            if (fieldRef != null) {
              validators.add(Validators.delegate((control) {
                if (control.value == null) return null;
                final numValue = num.tryParse(control.value.toString());
                if (numValue == null) return null;

                // Try to get the referenced field's value from the form
                try {
                  final parent = control.parent;
                  if (parent is FormGroup &&
                      parent.controls.containsKey(fieldRef)) {
                    final refControl = parent.control(fieldRef);
                    final refValue = parseIntValue(refControl.value);
                    if (refValue != null && numValue < refValue) {
                      return {
                        'min': {'min': refValue, 'actual': numValue}
                      };
                    }
                  }
                } catch (e) {
                  // If field not found or error, skip validation
                  if (kDebugMode) {
                    print('Error resolving field reference "$fieldRef": $e');
                  }
                }
                return null;
              }) as Validator<T>);
            }
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
          } else if (rule.value is String &&
              (rule.value.startsWith('{{') && rule.value.endsWith('}}'))) {
            // Handle field reference like {{memberCount}}
            final fieldRef = _extractFieldReference(rule.value);
            if (fieldRef != null) {
              validators.add(Validators.delegate((control) {
                if (control.value == null) return null;
                final numValue = num.tryParse(control.value.toString());
                if (numValue == null) return null;

                // Try to get the referenced field's value from the form
                try {
                  final parent = control.parent;
                  if (parent is FormGroup &&
                      parent.controls.containsKey(fieldRef)) {
                    final refControl = parent.control(fieldRef);
                    final refValue = parseIntValue(refControl.value);
                    if (refValue != null && numValue > refValue) {
                      return {
                        'max': {'max': refValue, 'actual': numValue}
                      };
                    }
                  }
                } catch (e) {
                  // If field not found or error, skip validation
                  if (kDebugMode) {
                    print('Error resolving field reference "$fieldRef": $e');
                  }
                }
                return null;
              }) as Validator<T>);
            }
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

        case 'required':
          if (rule.value == true) {
            validators.add(Validators.required as Validator<T>);
          }
          break;

        case 'minAge':
          if (rule.value != null) {
            validators.add(Validators.delegate((control) {
              if (control.value == null || control.value.toString().isEmpty) return null;
              final formGroup = control.parent;
              if (formGroup is! FormGroup) return null;

              final navParams = schemaKey != null ? _navigationParamsRegistry[schemaKey] : null;

              final minAge = _parseAgeConstraintDelegate(rule.value, formGroup, navParams);
              if (minAge == null) return null;

              final dob = parseDateValue(control.value);
              if (dob == null) return null;

              final age = DigitDateUtils.calculateAge(dob);
              final minValid = age.years > minAge.$1 ||
                  (age.years == minAge.$1 && age.months >= minAge.$2);
              if (!minValid) {
                return {'minAge': true};
              }
              return null;
            }) as Validator<T>);
          }
          break;

        case 'maxAge':
          if (rule.value != null) {
            validators.add(Validators.delegate((control) {
              if (control.value == null || control.value.toString().isEmpty) return null;
              final formGroup = control.parent;
              if (formGroup is! FormGroup) return null;

              final navParams = schemaKey != null ? _navigationParamsRegistry[schemaKey] : null;

              final maxAge = _parseAgeConstraintDelegate(rule.value, formGroup, navParams);
              if (maxAge == null) return null;

              final dob = parseDateValue(control.value);
              if (dob == null) return null;

              final age = DigitDateUtils.calculateAge(dob);
              final maxValid = age.years < maxAge.$1 ||
                  (age.years == maxAge.$1 && age.months <= maxAge.$2);
              if (!maxValid) {
                return {'maxAge': true};
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
