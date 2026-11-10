import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/widgets/atoms/pop_up_card.dart';
import 'package:digit_ui_components/widgets/molecules/show_pop_up.dart';
import 'package:flutter/material.dart';

import '../models/property_schema/property_schema.dart';

final _navigationToken = RegExp(r'\{\{\s*navigation\.([A-Za-z0-9_]+)\s*\}\}');
const _valueSlots = ['{value}', '{}'];

/// Builds the description of a next-page alert from its already translated
/// [description] text.
///
/// The value comes from the first `DEFAULT` entry of [conditions] (other
/// expressions are not evaluated here). It may reference the parameters the
/// next page will receive - `{{navigation.beneficiaryId}}` is the e-token the
/// page navigation interceptor has just reserved - or be a plain localisation
/// key. It replaces every `{value}` (or `{}`) slot in the text. When the text
/// has no slot - a missing or blank localisation, or a translation that
/// dropped it - the value is appended in bold (Popup renders `**x**` bold),
/// because a value the user is asked to note down must never be hidden.
///
/// Returns null when there is a DEFAULT entry but its value cannot be filled
/// (a referenced parameter is missing or blank), or when the text has a slot
/// and no DEFAULT entry: the caller then skips the popup instead of asking
/// the user to note down an empty value.
String? resolveNextPageAlertDescription({
  required String description,
  required List<AlertCondition>? conditions,
  required Map<String, dynamic> nextNavParams,
  required String Function(String key) translate,
}) {
  final hasSlot = _valueSlots.any(description.contains);

  AlertCondition? source;
  for (final condition in conditions ?? const <AlertCondition>[]) {
    if (condition.expression.trim() == 'DEFAULT') {
      source = condition;
      break;
    }
  }
  if (source == null) return hasSlot ? null : description;

  final raw = source.value;
  final String value;
  if (_navigationToken.hasMatch(raw)) {
    var missing = false;
    value = raw.replaceAllMapped(_navigationToken, (match) {
      final resolved = nextNavParams[match.group(1)]?.toString().trim() ?? '';
      if (resolved.isEmpty) missing = true;
      return resolved;
    });
    if (missing) return null;
  } else {
    value = translate(raw);
  }
  if (value.trim().isEmpty) return null;

  if (!hasSlot) {
    return description.trim().isEmpty
        ? '**$value**'
        : '${description.trimRight()}\n\n**$value**';
  }
  var filled = description;
  for (final slot in _valueSlots) {
    filled = filled.replaceAll(slot, value);
  }
  return filled;
}

/// Shows [popup] before the next form page opens.
///
/// Completes true when the user picks the primary action, or when the popup
/// has nothing to show (see [resolveNextPageAlertDescription]); false when
/// they pick the secondary action or tap outside it.
Future<bool> confirmNextPage({
  required BuildContext context,
  required ShowAlertPopUp popup,
  required Map<String, dynamic> nextNavParams,
  required String Function(String key) translate,
}) async {
  final descriptionKey = popup.description?.trim() ?? '';
  final description = resolveNextPageAlertDescription(
    description: descriptionKey.isEmpty ? '' : translate(descriptionKey),
    conditions: popup.conditions,
    nextNavParams: nextNavParams,
    translate: translate,
  );
  if (description == null) return true;

  final choice = await showCustomPopup(
    context: context,
    builder: (popupContext) => Popup(
      title: translate(popup.title),
      description: description.trim().isEmpty ? null : description,
      actions: [
        DigitButton(
          label: translate(popup.primaryActionLabel),
          onPressed: () =>
              Navigator.of(popupContext, rootNavigator: true).pop(true),
          type: DigitButtonType.primary,
          size: DigitButtonSize.large,
        ),
        DigitButton(
          label: translate(popup.secondaryActionLabel),
          onPressed: () =>
              Navigator.of(popupContext, rootNavigator: true).pop(false),
          type: DigitButtonType.secondary,
          size: DigitButtonSize.large,
        ),
      ],
    ),
  );
  return choice == true;
}
