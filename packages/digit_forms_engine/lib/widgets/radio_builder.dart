part of 'json_schema_builder.dart';

class JsonSchemaRadioBuilder extends JsonSchemaBuilder<bool> {
  final List<Option> enums;
  final bool isBoolean;

  const JsonSchemaRadioBuilder({
    required super.formControlName,
    required super.form,
    this.enums = const [],
    super.key,
    super.value,
    super.label,
    super.readOnly,
    this.isBoolean = false,
    super.validations,
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
      builder: (field) {
        return LabeledField(
          charCondition: true,
          isRequired: hasRequiredValidation(validations),
          capitalizedFirstLetter: false,
          label: label,
          infoText: tooltipText,
          child: RadioList(
            // Per-option resource-ids (`<formControlName>_<code>`) so UI tests
            // and TalkBack can address a specific radio. The field-level
            // Semantics(identifier:) in JsonFormBuilder lands on the merged
            // label block, which is not clickable and whose centre falls
            // between the options - it cannot select one. Scoping by form
            // control name keeps ids unique when several groups on one page
            // share option codes (eligibility ec1..ec5 are all YES/NO).
            semanticsIdentifierPrefix: formControlName,
            containerPadding:
                const EdgeInsets.only(bottom: spacer4, top: spacer2),
            readOnly: readOnly,
            groupValue: form.control(formControlName).value.toString(),
            errorMessage: field.errorText,
            radioDigitButtons: enums
                .map(
                  (e) => RadioButtonModel(
                    code: e.code,
                    name: loc.translate(e.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              form.control(formControlName).markAsTouched();
              if (isBoolean) {
                form.control(formControlName).value = value.code == 'true';
              } else {
                form.control(formControlName).value = value.code;
              }
            },
          ),
        );
      },
    );
  }
}
