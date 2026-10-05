import 'package:collection/collection.dart';
import 'package:digit_forms_engine/forms_engine.dart';
import 'package:digit_forms_engine/helper/validator_helper.dart';
import 'package:digit_forms_engine/utils/utils.dart';
import 'package:reactive_forms/reactive_forms.dart';

typedef FormData = Map<String, dynamic>;

/// Visibility and validation rules last applied to each control.
///
/// `toggleControlVisibility` runs from the form builder's `build()` for every
/// field with a `visibilityCondition`. Acting only when either of them
/// changes keeps `updateValueAndValidity` (whose status event rebuilds the
/// `ReactiveFormConsumer` that called us) from re-triggering the same build
/// on every frame. Keyed on the control object, so a fresh form starts clean.
///
/// The rules are part of the key because a schema can gain rules after its
/// controls exist, e.g. the stock-in-hand `max` on a quantity field that
/// arrives once an async stock search finishes. Those must still reach the
/// control even though its visibility never changed.
final Expando<_AppliedVisibility> _appliedVisibility =
    Expando<_AppliedVisibility>('appliedVisibility');

class _AppliedVisibility {
  final bool isVisible;
  final List<ValidationRule>? validations;

  const _AppliedVisibility(this.isVisible, this.validations);

  bool matches(bool visible, List<ValidationRule>? rules) =>
      isVisible == visible &&
      const DeepCollectionEquality().equals(validations, rules);
}

class VisibilityManager {
  final Map<String, PropertySchema> schemaMap;
  final FormGroup form;
  final Map<String, dynamic> formData;
  final Map<String, dynamic>? navigationParams;

  VisibilityManager({
    required this.schemaMap,
    required this.form,
    required this.formData,
    this.navigationParams,
  });

  void evaluateVisibility() {
    final flatValues = flattenMap(formData);

    // Add navigation params to the evaluation context
    if (navigationParams != null) {
      navigationParams!.forEach((key, value) {
        flatValues['navigation.$key'] = value;
      });
    }

    for (final entry in schemaMap.entries) {
      final key = entry.key;
      final schema = entry.value;

      final visibilityCondition = schema.visibilityCondition;
      if (visibilityCondition == null ||
          visibilityCondition.expression.isEmpty) {
        continue;
      }

      final isVisible = evaluateVisibilityExpression(
          visibilityCondition.expression, flatValues);

      toggleControlVisibility(key, isVisible, schema);
    }
  }

  Map<String, dynamic> flattenMap(Map<String, dynamic> map,
      [String parentKey = '']) {
    final result = <String, dynamic>{};
    map.forEach((key, value) {
      final fullKey = parentKey.isEmpty ? key : '$parentKey.$key';
      if (value is Map<String, dynamic>) {
        result.addAll(flattenMap(value, fullKey));
      } else {
        result[fullKey] = value;
      }
    });
    return result;
  }

  void toggleControlVisibility(
    String key,
    bool isVisible,
    PropertySchema schema,
  ) {
    // Skip if control doesn't exist (hidden field without includeInForm: true)
    if (!form.contains(key)) return;

    final control = form.control(key);

    // Same visibility and rules as last time: nothing to apply, and emitting
    // a status event here would rebuild the page that is evaluating us.
    if (_appliedVisibility[control]?.matches(isVisible, schema.validations) ==
        true) {
      return;
    }
    _appliedVisibility[control] =
        _AppliedVisibility(isVisible, schema.validations);

    if (isVisible) {
      control.setValidators(buildValidators(schema));
    } else {
      control
        ..clearValidators()
        ..reset(); // 👈 clears value and marks untouched
    }

    control.updateValueAndValidity();
  }
}
