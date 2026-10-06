part of 'json_schema_builder.dart';

/// `type: string` + `format: checkbox` + `enums`: a vertical list of
/// [DigitCheckbox] options bound to ONE String control.
///
/// Value convention mirrors [JsonSchemaSelectionBuilder] and the multi-select
/// dropdown: the selected enum codes joined with '.', kept in enum order so the
/// stored value does not depend on the order the user ticked them in; `null`
/// when nothing is selected, so `required` fails and the transformer omits the
/// key. Codes not present in [enums] (stale stored values) render unchecked and
/// are dropped on the next toggle.
class JsonSchemaCheckboxGroupBuilder extends JsonSchemaBuilder<String> {
  final List<Option> enums;

  const JsonSchemaCheckboxGroupBuilder({
    required super.formControlName,
    required super.form,
    required this.enums,
    super.key,
    super.label,
    super.tooltipText,
    super.readOnly,
    super.validations,
  });

  static const _separator = '.';

  static List<String> decode(String? raw) => (raw ?? '')
      .split(_separator)
      .map((code) => code.trim())
      .where((code) => code.isNotEmpty)
      .toList();

  String? encode(Iterable<String> codes) {
    final selected = codes.toSet();
    final ordered =
        enums.map((e) => e.code).where(selected.contains).toList();
    return ordered.isEmpty ? null : ordered.join(_separator);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);
    final loc = FormLocalization.of(context);
    final validationMessages = buildValidationMessages(validations, loc);

    return ReactiveFormField<String, String>(
      formControlName: formControlName,
      validationMessages: validationMessages,
      showErrors: (control) => control.invalid && control.touched,
      builder: (field) {
        final selected = decode(field.value);

        void toggle(String code, bool checked) {
          if (readOnly) return;
          field.control.markAsTouched();
          final next = selected.toSet();
          if (checked) {
            next.add(code);
          } else {
            next.remove(code);
          }
          field.didChange(encode(next));
        }

        return LabeledField(
          label: label,
          infoText: tooltipText,
          charCondition: true,
          capitalizedFirstLetter: false,
          isRequired: hasRequiredValidation(validations),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final option in enums)
                Padding(
                  padding: const EdgeInsets.only(bottom: spacer2),
                  child: Semantics(
                    container: true,
                    identifier: '${formControlName}_${option.code}',
                    child: GestureDetector(
                      // DigitCheckbox only makes its square tappable; let the
                      // label toggle too. On the square itself the inner
                      // InkWell wins the gesture arena, so there is no double
                      // toggle.
                      behavior: HitTestBehavior.translucent,
                      onTap: readOnly
                          ? null
                          : () => toggle(
                                option.code,
                                !selected.contains(option.code),
                              ),
                      child: DigitCheckbox(
                        key: ValueKey('${formControlName}_${option.code}'),
                        capitalizeFirstLetter: false,
                        readOnly: readOnly,
                        label: loc.translate(option.name),
                        value: selected.contains(option.code),
                        onChanged: (checked) => toggle(option.code, checked),
                      ),
                    ),
                  ),
                ),
              if (field.errorText != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: spacer4,
                      width: spacer4,
                      child: Icon(
                        Icons.info,
                        color: theme.colorTheme.alert.error,
                        size: BaseConstants.errorIconSize,
                      ),
                    ),
                    const SizedBox(width: spacer1),
                    Flexible(
                      fit: FlexFit.tight,
                      child: Text(
                        truncateWithEllipsis(256, field.errorText!),
                        style: textTheme.bodyS.copyWith(
                          color: theme.colorTheme.alert.error,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
