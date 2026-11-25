import 'dart:async';

import 'package:reactive_forms/reactive_forms.dart';

import '../models/property_schema/property_schema.dart';
import '../utils/computed_value.dart';

/// Keeps a read-only form field equal to another field's value multiplied by
/// [ComputedValueConfig.multiplyBy] and divided by
/// [ComputedValueConfig.divideBy] (e.g. pieces shown as bales, or bales shown
/// as pieces).
///
/// It listens to the source control instead of recomputing in build(),
/// because a page rebuilds its fields on value changes only when some field
/// on it has a visibility condition.
class ComputedValueBinding {
  ComputedValueBinding({
    required this.form,
    required this.targetControlName,
    required this.config,
  });

  final FormGroup form;
  final String targetControlName;
  final ComputedValueConfig config;

  StreamSubscription<Object?>? _subscription;

  /// The control the value is worked out from. On a multi-entity page every
  /// editable field is renamed per entity (quantityReceived →
  /// quantityReceived_item_0), so a target named `<field>_item_N` reads the
  /// source of the same entity when the form has one.
  String get _sourceControlName {
    final suffix =
        RegExp(r'_item_\d+$').firstMatch(targetControlName)?.group(0);
    if (suffix != null && !config.sourceField.endsWith(suffix)) {
      final entitySource = '${config.sourceField}$suffix';
      if (form.contains(entitySource)) return entitySource;
    }
    return config.sourceField;
  }

  /// Fills the target now and on every later change of the source field.
  /// Does nothing when either field is missing from [form].
  void start() {
    final source = _sourceControlName;
    if (!form.contains(source) || !form.contains(targetControlName)) {
      return;
    }
    apply();
    _subscription?.cancel();
    _subscription = form.control(source).valueChanges.listen((_) => apply());
  }

  /// Writes the computed value, clearing the target when the source holds
  /// nothing it can work with, so a stale value never stays on screen. Writes
  /// only on a change, so calling it again is harmless.
  void apply() {
    final source = _sourceControlName;
    if (!form.contains(source) || !form.contains(targetControlName)) {
      return;
    }
    final computed = divideForDisplay(
      form.control(source).value,
      config.divideBy,
      config.decimals,
      multiplyBy: config.multiplyBy,
    );
    final target = form.control(targetControlName);
    if (target.value != computed) {
      target.value = computed;
      // Nobody types into a computed field, so it is never touched and its
      // errors (e.g. over stock in hand) would stay hidden until submit.
      if (computed != null) target.markAsTouched();
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
