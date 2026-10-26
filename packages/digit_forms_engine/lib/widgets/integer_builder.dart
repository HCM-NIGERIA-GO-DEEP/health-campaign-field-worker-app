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
        child: DigitNumericFormInput(
          helpText: helpText,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          readOnly: readOnly,
          editable: !readOnly,
          errorMessage: field.errorText,
          minValue: relativeMinValue ?? minValue ?? 0,
          maxValue: relativeMaxValue ?? maxValue ?? 1000,
          maxLength: 5,
          step: 1,
          // An unanswered numeric field's FormControl<int> holds null (see
          // form_builder_helper's PropertySchemaFormat.numeric branch), and
          // `?? 0` turned that into a literal "0" sitting in the input.
          // BaseDigitFormInput seeds its controller via
          // `_controller.text = initialValue`, whose setter collapses the
          // selection to offset 0 - so the caret parked BEFORE that "0" and
          // the first digit typed landed in front of it ("5" became "50").
          // Rendering null as empty leaves the field genuinely blank, so the
          // caret and the typed digits line up.
          initialValue: form.control(formControlName).value?.toString() ?? '',
          onChange: (value) {
            form.control(formControlName).markAsTouched();
            if (value.isEmpty) {
              form.control(formControlName).value = 0;
              return;
            }
            form.control(formControlName).value = int.parse(value);
          },
        ),
      ),
    );
  }
}
