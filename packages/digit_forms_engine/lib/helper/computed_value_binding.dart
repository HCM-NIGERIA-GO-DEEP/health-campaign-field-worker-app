import 'dart:async';

import 'package:reactive_forms/reactive_forms.dart';

import '../models/property_schema/property_schema.dart';
import '../utils/computed_value.dart';

/// Keeps a read-only form field equal to another field's value divided by
/// [ComputedValueConfig.divideBy] (e.g. pieces shown as bales).
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

  /// Fills the target now and on every later change of the source field.
  /// Does nothing when either field is missing from [form].
  void start() {
    if (!form.contains(config.sourceField) ||
        !form.contains(targetControlName)) {
      return;
    }
    apply();
    _subscription?.cancel();
    _subscription =
        form.control(config.sourceField).valueChanges.listen((_) => apply());
  }

  /// Writes the computed value, clearing the target when the source holds
  /// nothing it can divide, so a stale value never stays on screen. Writes
  /// only on a change, so calling it again is harmless.
  void apply() {
    if (!form.contains(config.sourceField) ||
        !form.contains(targetControlName)) {
      return;
    }
    final computed = divideForDisplay(
      form.control(config.sourceField).value,
      config.divideBy,
      config.decimals,
    );
    final target = form.control(targetControlName);
    if (target.value != computed) target.value = computed;
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
