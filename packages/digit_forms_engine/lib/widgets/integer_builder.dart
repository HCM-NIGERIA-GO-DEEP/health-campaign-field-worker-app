part of 'json_schema_builder.dart';

class JsonSchemaIntegerBuilder extends JsonSchemaBuilder<int> {
  final int? maxValue;
  final int? minValue;
  final int? relativeMinValue;
  final int? relativeMaxValue;

  const JsonSchemaIntegerBuilder({
    required super.formControlName,
    required super.form,
    super.key,
    super.value,
    this.maxValue,
    this.minValue,
    this.relativeMinValue,
    this.relativeMaxValue,
    super.label,
    super.helpText,
    super.innerLabel,
    super.readOnly,
    super.validations,
    super.isRequired,
    super.tooltipText,
  });

  @override
  Widget build(BuildContext context) {
    final loc = FormLocalization.of(context);
    final validationMessages = buildValidationMessages(validations, loc);

    return ReactiveWrapperField(
      formControlName: formControlName,
      validationMessages: validationMessages,
      showErrors: (control) => control.invalid && control.touched,
      builder: (field) => LabeledField(
        infoText: translateIfPresent(tooltipText, loc),
        label: label,
        capitalizedFirstLetter: false,
        isRequired: isRequired ?? false,
        child: _StableNumericFormInput(
          helpText: helpText,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          readOnly: readOnly,
          editable: !readOnly,
          errorMessage: field.errorText,
          minValue: relativeMinValue ?? minValue ?? 0,
          maxValue: relativeMaxValue ?? maxValue ?? 1000,
          maxLength: 5,
          step: 1,
          // Keep unanswered counters blank rather than displaying zero.
          initialValue: form.control(formControlName).value?.toString() ?? '',
          onChange: (value) {
            form.control(formControlName).markAsTouched();
            if (value.isEmpty) {
              form.control(formControlName).value = null;
              return;
            }
            form.control(formControlName).value = int.parse(value);
          },
        ),
      ),
    );
  }
}

// Use the existing input's styling with atomic text/selection updates. The
// upstream numeric stepper resets selection to zero; correcting it after a
// frame makes the caret visibly jump and also overrides deliberate edits.
class _StableNumericFormInput extends BaseDigitFormInput {
  const _StableNumericFormInput({
    super.helpText,
    super.inputFormatters,
    super.readOnly,
    required bool editable,
    super.errorMessage,
    super.minValue,
    super.maxValue,
    super.maxLength,
    super.step,
    super.initialValue,
    super.onChange,
  }) : super(
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          prefixText: '-',
          suffixText: '+',
          suffixPrefixWidth: 100,
          showCurser: editable,
          isEditable: editable,
        );

  @override
  _StableNumericFormInputState createState() => _StableNumericFormInputState();
}

class _StableNumericFormInputState extends BaseDigitFormInputState {
  bool _firstTapAfterFocus = true;

  void _moveToEnd() {
    controller.selection =
        TextSelection.collapsed(offset: controller.text.length);
  }

  @override
  void initState() {
    super.initState();
    _moveToEnd();
  }

  @override
  void didUpdateWidget(covariant BaseDigitFormInput oldWidget) {
    final previousText = controller.text;
    super.didUpdateWidget(oldWidget);
    if (previousText != controller.text) _moveToEnd();
  }

  @override
  void onFocusChange() {
    super.onFocusChange();
    if (myFocusNode.hasFocus) {
      _moveToEnd();
    } else {
      _firstTapAfterFocus = true;
    }
  }

  @override
  void onTap() {
    if (_firstTapAfterFocus && !widget.readOnly) _moveToEnd();
    _firstTapAfterFocus = false;
    super.onTap();
  }

  void _step(int direction) {
    if (widget.readOnly) return;
    final current = int.tryParse(controller.text) ?? 0;
    final next = current + direction * widget.step;
    if (next >= widget.minValue && next <= widget.maxValue) {
      final text = next.toString();
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    _firstTapAfterFocus = false;
    widget.onChange?.call(controller.text);
  }

  @override
  void onPrefixIconClick({void Function()? customFunction}) => _step(-1);

  @override
  void onSuffixIconClick({void Function()? customFunction}) => _step(1);
}
