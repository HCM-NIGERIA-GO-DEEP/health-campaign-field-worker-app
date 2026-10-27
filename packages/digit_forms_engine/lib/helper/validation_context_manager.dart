import 'package:flutter/foundation.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../models/property_schema/property_schema.dart';
import 'validator_helper.dart';

/// Manages validation context and dependencies for cross-field validation
///
/// This class tracks which fields depend on other fields (via template variables)
/// and automatically re-validates dependent fields when source fields change.
///
/// Example:
/// ```json
/// {
///   "maxAllowedStock": {
///     "type": "integer",
///     "value": 100
///   },
///   "stockReceived": {
///     "type": "integer",
///     "validations": [
///       {
///         "type": "max",
///         "value": "{{maxAllowedStock}}"
///       }
///     ]
///   }
/// }
/// ```
///
/// When maxAllowedStock changes, stockReceived validators will be rebuilt
/// with the new value.
class ValidationContextManager {
  final FormGroup formGroup;
  final Map<String, PropertySchema> schemas;

  /// Maps source field -> Set of dependent fields
  /// e.g., {"maxAllowedStock": {"stockReceived", "stockIssued"}}
  final Map<String, Set<String>> _dependencyMap = {};
  bool _isRevalidatingDependents = false;

  ValidationContextManager({
    required this.formGroup,
    required this.schemas,
  }) {
    _analyzeDependencies();
    _setupListeners();
  }

  /// Analyze all schemas to find template variable dependencies
  void _analyzeDependencies() {
    schemas.forEach((fieldName, schema) {
      final validations = schema.validations;
      if (validations == null) return;

      for (final rule in validations) {
        final value = rule.value;
        if (value is String && value.contains('{{')) {
          // Extract dependencies from template variables
          final deps = _extractDependencies(value);

          for (final dep in deps) {
            _dependencyMap.putIfAbsent(dep, () => {}).add(fieldName);
          }

          if (kDebugMode && deps.isNotEmpty) {
            print(
                'ValidationContextManager: Field "$fieldName" depends on: ${deps.join(", ")}');
          }
        } else if ((rule.type == 'maxField' || rule.type == 'requiredIf') &&
            (value is String || value is Map)) {
          // Both maxField and requiredIf declare their dependency as the
          // sibling field name itself, e.g. childrenCount's maxField depends
          // on memberCount, identificationNumber's requiredIf depends on
          // identificationType - without this, editing the sibling after
          // this field was already filled/left blank kept the stale
          // (possibly now-invalid) validity cached until this field itself
          // was touched.
          //
          // maxField also accepts {"field": ..., "offset": ...} for a
          // ceiling that is a sibling shifted by a constant; the dependency
          // is the same sibling either way.
          final dependency =
              value is Map ? value['field']?.toString() : value as String;
          if (dependency != null && dependency.isNotEmpty) {
            _dependencyMap.putIfAbsent(dependency, () => {}).add(fieldName);
          }
        } else if (rule.type == 'maxFieldSum' && value is Map) {
          // Revalidate when either the shared cap or summed sibling changes.
          // A guard in _revalidateDependents prevents the mirrored sibling
          // dependencies from recursively revalidating each other.
          for (final dependency in [value['maxField'], value['with']]) {
            if (dependency is String && dependency.isNotEmpty) {
              _dependencyMap.putIfAbsent(dependency, () => {}).add(fieldName);
            }
          }
        } else if (rule.type == 'conditionalPattern' && value is Map) {
          // conditionalPattern declares its dependency as {"switchOn": "...",
          // "cases": {...}} rather than a {{template}} string, so it was
          // never picked up above - e.g. identificationNumber's pattern
          // depends on identificationType, but switching from National ID to
          // Voter's ID never re-ran identificationNumber's validators, so a
          // value valid for the old type could pass submission unnoticed
          // under the new one.
          final switchOn = value['switchOn'];
          if (switchOn is String && switchOn.isNotEmpty) {
            _dependencyMap.putIfAbsent(switchOn, () => {}).add(fieldName);
            if (kDebugMode) {
              print(
                  'ValidationContextManager: Field "$fieldName" depends on "$switchOn" (conditionalPattern)');
            }
          }
        }
      }
    });

    if (kDebugMode && _dependencyMap.isNotEmpty) {
      print('ValidationContextManager: Dependency map: $_dependencyMap');
    }
  }

  /// Extract field names from template variables like {{fieldName}}
  /// Supports both simple {{field}} and nested {{parent.child}}
  Set<String> _extractDependencies(String template) {
    final regex = RegExp(r'\{\{([^}]+)\}\}');
    final matches = regex.allMatches(template);

    return matches
        .map((m) {
          final fullPath = m.group(1)?.trim();
          if (fullPath == null) return null;

          // For nested paths like "parent.child", extract root field name
          final rootField = fullPath.split('.').first;
          return rootField;
        })
        .whereType<String>()
        .toSet();
  }

  /// Set up value change listeners for fields that others depend on
  void _setupListeners() {
    _dependencyMap.forEach((sourceField, dependentFields) {
      try {
        final sourceControl = formGroup.control(sourceField);

        // Listen to value changes and re-validate dependents
        sourceControl.valueChanges.listen((_) {
          _revalidateDependents(sourceField, dependentFields);
        });

        if (kDebugMode) {
          print(
              'ValidationContextManager: Set up listener for "$sourceField" -> ${dependentFields.join(", ")}');
        }
      } catch (e) {
        // Field doesn't exist in form, skip
        if (kDebugMode) {
          print(
              'ValidationContextManager: Warning - Source field "$sourceField" not found in form');
        }
      }
    });
  }

  /// Re-validate fields that depend on the changed field
  void _revalidateDependents(String sourceField, Set<String> dependentFields) {
    // Cross-field rules can be mutual (childrenCount and
    // pregnantWomenCount). Revalidation emits status/value events, so ignore
    // nested dependency callbacks while this pass is already updating fields.
    if (_isRevalidatingDependents) return;
    _isRevalidatingDependents = true;
    try {
      // Build current validation context from all form values
      final context = _buildValidationContext();

      if (kDebugMode) {
        print(
            'ValidationContextManager: Re-validating dependents of "$sourceField": ${dependentFields.join(", ")}');
      }

      for (final dependentField in dependentFields) {
        try {
          final control = formGroup.control(dependentField);
          final schema = schemas[dependentField];

          if (schema != null) {
            // Rebuild validators with updated context
            final newValidators = buildValidators(
              schema,
            );

            // Update validators and re-validate
            control.setValidators(newValidators);
            // These dependencies can be mutual (childrenCount and
            // pregnantWomenCount). Re-validating a dependent must not emit a
            // value/status event on that control, or it can schedule the
            // reciprocal dependency again after the revalidation guard exits.
            control.updateValueAndValidity(emitEvent: false);

            if (kDebugMode) {
              print(
                  'ValidationContextManager: Re-validated "$dependentField" with context: $context');
            }
          }
        } catch (e) {
          // Skip if field doesn't exist
          if (kDebugMode) {
            print(
                'ValidationContextManager: Warning - Dependent field "$dependentField" not found: $e');
          }
        }
      }

      // Refresh form-level validity once all dependent controls have been
      // recalculated, without emitting events from the individual controls.
      formGroup.updateValueAndValidity();
    } finally {
      _isRevalidatingDependents = false;
    }
  }

  /// Build validation context from current form values
  /// Returns a flat map of field -> value
  Map<String, dynamic> _buildValidationContext() {
    final context = <String, dynamic>{};

    formGroup.controls.forEach((key, control) {
      if (control is FormGroup) {
        // Nested form group - flatten with dot notation
        final nestedContext = _buildNestedContext(control);
        nestedContext.forEach((nestedKey, nestedValue) {
          context['$key.$nestedKey'] = nestedValue;
        });
      } else {
        context[key] = control.value;
      }
    });

    return context;
  }

  /// Build context for nested FormGroup
  Map<String, dynamic> _buildNestedContext(FormGroup formGroup) {
    final context = <String, dynamic>{};

    formGroup.controls.forEach((key, control) {
      if (control is FormGroup) {
        final nestedContext = _buildNestedContext(control);
        nestedContext.forEach((nestedKey, nestedValue) {
          context['$key.$nestedKey'] = nestedValue;
        });
      } else {
        context[key] = control.value;
      }
    });

    return context;
  }

  /// Get the dependency map (for debugging)
  Map<String, Set<String>> get dependencyMap => _dependencyMap;
}
