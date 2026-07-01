import 'package:collection/collection.dart';
import 'package:digit_forms_engine/blocs/forms/forms.dart';
import 'package:digit_forms_engine/models/property_schema/property_schema.dart';
import 'package:digit_forms_engine/widgets/json_schema_builder.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../blocs/localization/app_localization.dart';
import '../../utils/hf_referral_cdd_singleton.dart';
import '../localized.dart';

/// Combined input for a stock delivery-team code field (`deliveryTeam` on the
/// stockDetails page, `teamCode` on the warehouseDetails page).
///
/// Renders two mutually-exclusive ways of identifying the delivery team on a
/// single required form control:
///  * a dropdown of CDD users fetched for the logged-in Health Facility
///    Supervisor (see [HFReferralCddSingleton]), and
///  * the existing QR scanner for the team code.
///
/// Whichever input is filled disables the other. Because both write to the same
/// control, the field's `required` validation already enforces that exactly one
/// of them is provided, and downstream transformers keep reading a single
/// value unchanged.
class DeliveryTeamField extends LocalizedStatefulWidget {
  /// The active form's schema key (e.g. `RECORDSTOCK`). Used to resolve the
  /// field schema (validations / label) from the cached schemas.
  final String schemaName;

  /// The form control this field is bound to (e.g. `deliveryTeam`, `teamCode`).
  final String fieldName;

  const DeliveryTeamField({
    super.key,
    super.appLocalizations,
    required this.schemaName,
    required this.fieldName,
  });

  @override
  State<DeliveryTeamField> createState() => _DeliveryTeamFieldState();
}

class _DeliveryTeamFieldState extends LocalizedState<DeliveryTeamField> {
  String get _fieldName => widget.fieldName;

  /// Locate this field's schema in the cached page tree so we can reuse its
  /// validations and label for the embedded scanner.
  PropertySchema? _findFieldSchema(BuildContext context) {
    final pages =
        context.read<FormsBloc>().state.cachedSchemas[widget.schemaName]?.pages;
    if (pages == null) return null;

    PropertySchema? found;
    void walk(Map<String, PropertySchema> node) {
      for (final entry in node.entries) {
        if (found != null) return;
        if (entry.key == _fieldName) {
          found = entry.value;
          return;
        }
        final children = entry.value.properties;
        if (children != null && children.isNotEmpty) walk(children);
      }
    }

    walk(pages);
    return found;
  }

  void _updateValue(BuildContext context, String? value) {
    context.read<FormsBloc>().add(
          FormsEvent.updateField(
            schemaKey: widget.schemaName,
            context: context,
            key: _fieldName,
            value: value,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final fieldSchema = _findFieldSchema(context);
    final cddUsers = HFReferralCddSingleton().cddUsers;

    final scannerLabel = fieldSchema?.label != null
        ? localizations.translate(fieldSchema!.label!)
        : localizations.translateWithDefault(
            'APPONE_MANAGESTOCK_WAREHOUSE_label_deliveryTeamCode',
            fallback: 'Delivery team code',
          );

    return ReactiveFormConsumer(
      builder: (context, form, _) {
        if (!form.contains(_fieldName)) return const SizedBox.shrink();
        final control = form.control(_fieldName);
        final rawValue = control.value;
        final value = rawValue is String ? rawValue : rawValue?.toString();
        final hasValue = value != null && value.trim().isNotEmpty;

        final options = cddUsers
            .map((u) => DropdownItem(code: u.deliveryTeamCode, name: u.name))
            .toList();

        // No CDD users available (e.g. non-supervisor) → fall back to the plain
        // scanner so behaviour is unchanged for those users.
        if (options.isEmpty) {
          return _buildScanner(form, fieldSchema, scannerLabel);
        }

        final selected = options.firstWhereOrNull((o) => o.code == value);
        final isFromDropdown = selected != null;
        final isFromScan = hasValue && !isFromDropdown;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LabeledField(
              label: scannerLabel,
              capitalizedFirstLetter: false,
              isRequired: true,
              child: DigitDropdown<String>(
                key: ValueKey('${_fieldName}Cdd_${value ?? ''}'),
                sentenceCaseEnabled: false,
                readOnly: isFromScan,
                isDisabled: isFromScan,
                emptyItemText: localizations.translate('NO_OPTIONS_AVAILABLE'),
                items: options,
                selectedOption: selected,
                onSelect: (option) {
                  control.markAsTouched();
                  control.value = option.code;
                  _updateValue(context, option.code);
                },
                onChange: (selectedCode) {
                  // Fires with an empty string when the selection is cleared.
                  if (selectedCode.isEmpty) {
                    control.value = null;
                    _updateValue(context, null);
                  }
                },
              ),
            ),
            _orSeparator(context),
            // Only mount the real scanner when the value did not come from the
            // dropdown; otherwise show a disabled scan button to signal
            // input is unavailable until the CDD user is cleared.
            if (!isFromDropdown)
              _buildScanner(form, fieldSchema, scannerLabel)
            else
              DigitButton(
                capitalizeLetters: false,
                mainAxisSize: MainAxisSize.max,
                size: DigitButtonSize.large,
                type: DigitButtonType.secondary,
                prefixIcon: Icons.qr_code,
                isDisabled: true,
                label: scannerLabel,
                onPressed: () {},
              ),
          ],
        );
      },
    );
  }

  Widget _buildScanner(
    FormGroup form,
    PropertySchema? fieldSchema,
    String scannerLabel,
  ) {
    return JsonSchemaScannerBuilder(
      form: form,
      formControlName: _fieldName,
      label: scannerLabel,
      value: fieldSchema?.value as String?,
      validations: fieldSchema?.validations,
      summaryData: fieldSchema?.includeInSummary ?? true,
    );
  }

  Widget _orSeparator(BuildContext context) {
    final theme = Theme.of(context);
    final divider = Expanded(
      child: Divider(color: theme.colorScheme.outline),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          divider,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              localizations.translateWithDefault('CORE_COMMON_OR',
                  fallback: 'OR'),
              style: theme.textTheme.bodySmall,
            ),
          ),
          divider,
        ],
      ),
    );
  }
}
