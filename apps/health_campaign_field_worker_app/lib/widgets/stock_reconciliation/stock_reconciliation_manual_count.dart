import 'package:digit_forms_engine/blocs/app_localization.dart';
import 'package:digit_forms_engine/forms_engine.dart';
import 'package:digit_forms_engine/helper/validation_message_helper.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../utils/utils.dart';

class StockReconciliationManualCount extends StatelessWidget {
  const StockReconciliationManualCount({super.key, required this.pageSchema});

  final String pageSchema;

  @override
  Widget build(BuildContext context) {
    final unit = stockDisplayUnitForRoles(
      context.loggedInUserRoles.map((role) => role.code),
    );
    final inBales = unit == 'BALES';
    final locale = FormLocalization.of(context);
    final schema = context
        .read<FormsBloc>()
        .state
        .cachedSchemas[pageSchema]
        ?.pages['stockRecon']
        ?.properties?['manualCount'];

    String translate(String key, String fallback) {
      final text = locale.translate(key);
      return text == key || text.isEmpty ? fallback : text;
    }

    const labelKey =
        'STOCKRECONCILIATION_STOCKRECONCILIATION_manualCount_LABEL';
    const helpKey =
        'STOCKRECONCILIATION_STOCKRECONCILIATION_manualCount_HELP_TEXT';
    return LabeledField(
      isRequired: true,
      label: inBales
          ? translate('${labelKey}_BALES', 'Manual Count (Bales)')
          : translate('${labelKey}_PIECES', 'Manual Count (Pieces)'),
      child: ReactiveTextField<int>(
        formControlName: 'manualCount',
        valueAccessor: StockReconciliationCountAccessor(inBales: inBales),
        validationMessages:
            buildValidationMessages(schema?.validations, locale),
        keyboardType: TextInputType.numberWithOptions(decimal: inBales),
        inputFormatters: [
          if (!inBales) FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          helperText: inBales
              ? translate(
                  '${helpKey}_BALES', 'Enter bales in increments of 0.02.')
              : null,
        ),
      ),
    );
  }
}

/// The reactive form and transformer use pieces. Conversion is confined to
/// the text field so prefill, validation, comparison and persistence agree.
class StockReconciliationCountAccessor
    extends ControlValueAccessor<int, String> {
  StockReconciliationCountAccessor({required this.inBales});

  final bool inBales;
  static final _balesPattern = RegExp(r'^(\d*)(?:[.,](\d{0,2}))?$');

  @override
  String? modelToViewValue(int? modelValue) {
    if (modelValue == null) return null;
    return stockDisplayQuantity(modelValue, inBales ? 'BALES' : 'PIECES')
        .toString();
  }

  @override
  int? viewToModelValue(String? viewValue) {
    final text = viewValue?.trim() ?? '';
    if (!inBales) return int.tryParse(text);
    final match = _balesPattern.firstMatch(text);
    if (match == null) return null;

    final whole = match.group(1)!;
    final fraction = match.group(2) ?? '';
    if (whole.isEmpty && fraction.isEmpty) return null;
    final wholeBales = int.tryParse(whole.isEmpty ? '0' : whole);
    if (wholeBales == null || wholeBales > 10000000) return null;
    final fractionalPieces =
        int.parse(fraction.padRight(2, '0')) * itnPiecesPerBale;
    if (fractionalPieces % 100 != 0) return null;
    return wholeBales * itnPiecesPerBale + fractionalPieces ~/ 100;
  }
}
