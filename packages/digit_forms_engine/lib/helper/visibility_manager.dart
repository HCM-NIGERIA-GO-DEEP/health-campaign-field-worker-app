import 'package:digit_forms_engine/forms_engine.dart';
import 'package:digit_forms_engine/helper/validator_helper.dart';
import 'package:digit_forms_engine/utils/utils.dart';
import 'package:reactive_forms/reactive_forms.dart';

typedef FormData = Map<String, dynamic>;

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

  /// The value a control held when it was last hidden, keyed by the control
  /// itself. Static because a new VisibilityManager is created on every build.
  static final Expando<_HiddenValue> _hiddenValues =
      Expando<_HiddenValue>('hiddenValue');

  void toggleControlVisibility(
    String key,
    bool isVisible,
    PropertySchema schema,
  ) {
    // Skip if control doesn't exist (hidden field without includeInForm: true)
    if (!form.contains(key)) return;

    final control = form.control(key);

    if (isVisible) {
      control.setValidators(buildValidators(schema));
      // Put back what the field held before it was hidden: a prefilled
      // default (e.g. the name typed in the search bar) or what the user
      // typed. Only into an empty control, and only once.
      final hidden = _hiddenValues[control];
      if (hidden != null) {
        _hiddenValues[control] = null;
        control.value ??= hidden.value;
      }
    } else {
      // This runs on every build while hidden; once reset, the value is null,
      // so the kept value is not overwritten.
      if (control.value != null) {
        _hiddenValues[control] = _HiddenValue(control.value);
      }
      control
        ..clearValidators()
        ..reset(); // clears value so a hidden field is never saved
    }

    control.updateValueAndValidity();
  }
}

class _HiddenValue {
  const _HiddenValue(this.value);

  final Object? value;
}
