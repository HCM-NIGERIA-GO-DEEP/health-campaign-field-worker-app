part of 'json_schema_builder.dart';

class JsonSchemaNumberBuilder extends JsonSchemaBuilder<int> {
  final TextInputType inputType;
  final String? prefixText;
  final String? suffixText;

  const JsonSchemaNumberBuilder({
    required super.formControlName,
    required super.form,
    super.key,
    super.value,
    super.disabled,
    super.helpText,
    super.innerLabel,
    super.onTap,
    super.label,
    this.prefixText,
    this.suffixText,
    super.readOnly,
    this.inputType = TextInputType.number,
    super.isRequired,
    super.validations,
    super.inputFormatter,
    super.tooltipText,
  });

  @override
  Widget build(BuildContext context) {
    final loc = FormLocalization.of(context);
    final validationMessages = buildValidationMessages(validations, loc);
    final inputFormatter = getPatternFormatter(validations);

    return ReactiveFormConsumer(
      builder: (context, formGroup, child) {
        return ReactiveWrapperField(
          formControlName: formControlName,
          validationMessages: validationMessages,
          showErrors: (control) => control.invalid && control.touched,
          builder: (field) => LabeledField(
            label: label,
            isRequired: hasRequiredValidation(validations),
            capitalizedFirstLetter: false,
            infoText: translateIfPresent(tooltipText, loc),
            child: DigitTextFormInput(
              maxLength: getMaxLength(validations),
              helpText: helpText,
              innerLabel: innerLabel,
              suffixText: suffixText,
              prefixText: prefixText,
              readOnly: readOnly,
              keyboardType: inputType,
              initialValue: form.control(formControlName).value?.toString(),
              onChange: (value) {
                final control = form.control(formControlName);
                control.markAsTouched();
                if (value.isEmpty) {
                  control.value = null;
                  return;
                }
                try {
                  control.value = int.parse(value);
                } catch (e) {
                  control.value = null;
                  control.setErrors({'invalidNumber': true});
                  return;
                }

                if (getMinLength(validations) != null &&
                    value.length < getMinLength(validations)!) {
                  // Merge with existing validator errors (e.g. regex) instead of replacing them
                  control.setErrors({...control.errors, 'minLength': true});
                } else {
                  control.removeError('minLength');
                }
              },
              errorMessage: field.errorText,
              inputFormatters: inputFormatter != null
                  ? [inputFormatter]
                  : [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
        );
      },
    );
  }
}
