import 'package:digit_dedup_engine/digit_dedup_engine.dart';
import 'package:digit_forms_engine/forms_engine.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/atoms/pop_up_card.dart';
import 'package:digit_ui_components/widgets/molecules/show_pop_up.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../blocs/app_localization.dart';

/// Reserved keys carrying a corpus record's identity through the dedup engine,
/// which passes records back verbatim and ignores keys it does not score.
class DedupRecordKeys {
  const DedupRecordKeys._();

  /// The matched person's full name, ready to display.
  static const String displayName = '_displayName';

  /// The matched person's beneficiary ID, or null when they have none.
  static const String beneficiaryId = '_beneficiaryId';

  /// The matched record's client reference id.
  static const String clientReferenceId = '_clientReferenceId';
}

/// Localization codes used when a [DedupCheck] does not name its own, paired
/// with English copy.
///
/// [FlowBuilderLocalization.translate] echoes the code back when a string is
/// missing from the server-fetched table, so the fallback text is what keeps
/// the dialog legible until the translations are published.
class _Copy {
  const _Copy._();

  static const ({String code, String text}) title = (
    code: 'DEDUP_SIMILAR_BENEFICIARY_FOUND_TITLE',
    text: 'Similar beneficiary found',
  );
  static const ({String code, String text}) description = (
    code: 'DEDUP_SIMILAR_BENEFICIARY_FOUND_DESCRIPTION',
    text: 'A beneficiary with a similar name is already registered. '
        'Check the details below before you continue.',
  );
  static const ({String code, String text}) proceed = (
    code: 'DEDUP_SIMILAR_BENEFICIARY_PROCEED',
    text: 'Skip and Proceed',
  );
  static const ({String code, String text}) backToSearch = (
    code: 'DEDUP_SIMILAR_BENEFICIARY_BACK_TO_SEARCH',
    text: 'Back to Search',
  );
  static const ({String code, String text}) score = (
    code: 'DEDUP_SIMILAR_BENEFICIARY_SCORE',
    text: '{score}% match',
  );
  static const ({String code, String text}) missingId = (
    code: 'DEDUP_SIMILAR_BENEFICIARY_NO_ID',
    text: 'No beneficiary ID',
  );
  static const ({String code, String text}) beneficiaryIdLabel = (
    code: 'DEDUP_SIMILAR_BENEFICIARY_ID_LABEL',
    text: 'Beneficiary ID',
  );
  static const ({String code, String text}) copy = (
    code: 'DEDUP_SIMILAR_BENEFICIARY_COPY',
    text: 'Copy',
  );
  static const ({String code, String text}) copied = (
    code: 'DEDUP_SIMILAR_BENEFICIARY_COPIED',
    text: 'Copied',
  );
}

/// Translates [configKey] when the config names one, otherwise [copy]'s code,
/// falling back to [copy]'s English text if neither is in the table.
String _translate(
  FlowBuilderLocalization localizations,
  String? configKey,
  ({String code, String text}) copy,
) {
  final key = (configKey == null || configKey.isEmpty) ? copy.code : configKey;
  final translated = localizations.translate(key);
  return translated == key ? copy.text : translated;
}

/// Shows the similar-records warning and returns the user's decision.
///
/// The dialog cannot be dismissed by tapping outside, so the caller always
/// gets a deliberate answer. A dismissal that slips through anyway is read as
/// [DedupCheckOutcome.abort], since silently saving a possible duplicate is
/// the worse failure.
Future<DedupCheckOutcome> showDedupMatchDialog({
  required BuildContext context,
  required DedupAlertPopUp? alert,
  required List<DedupMatch> matches,
  required VoidCallback onBackToSearch,
}) async {
  final localizations = FlowBuilderLocalization.of(context);

  final outcome = await showCustomPopup(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Popup(
      title: _translate(localizations, alert?.title, _Copy.title),
      description:
          _translate(localizations, alert?.description, _Copy.description),
      additionalWidgets: [
        for (final match in matches)
          _DedupMatchTile(
            match: match,
            alert: alert,
            localizations: localizations,
          ),
      ],
      actions: [
        DigitButton(
          label: _translate(
              localizations, alert?.secondaryActionLabel, _Copy.backToSearch),
          type: DigitButtonType.secondary,
          size: DigitButtonSize.large,
          capitalizeLetters: false,
          onPressed: () {
            Navigator.of(dialogContext, rootNavigator: true)
                .pop(DedupCheckOutcome.abort);
            onBackToSearch();
          },
        ),
        DigitButton(
          label: _translate(localizations, alert?.primaryActionLabel, _Copy.proceed),
          type: DigitButtonType.primary,
          size: DigitButtonSize.large,
          capitalizeLetters: false,
          onPressed: () => Navigator.of(dialogContext, rootNavigator: true)
              .pop(DedupCheckOutcome.proceed),
        ),
      ],
    ),
  );

  return outcome is DedupCheckOutcome ? outcome : DedupCheckOutcome.abort;
}

/// One matched record: the person's name and beneficiary ID, each selectable
/// and each with a trailing copy button so a field worker can lift the value
/// straight out to look the person up.
class _DedupMatchTile extends StatelessWidget {
  final DedupMatch match;
  final DedupAlertPopUp? alert;
  final FlowBuilderLocalization localizations;

  const _DedupMatchTile({
    required this.match,
    required this.alert,
    required this.localizations,
  });

  String get _name =>
      (match.record[DedupRecordKeys.displayName] as String?)?.trim() ?? '';

  String? get _beneficiaryId =>
      (match.record[DedupRecordKeys.beneficiaryId] as String?)?.trim();

  /// The score line, with `{score}` replaced by the whole percentage.
  String get _scoreText =>
      _translate(localizations, alert?.scoreLabel, _Copy.score)
          .replaceAll('{score}', match.scorePercentage.toString());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

    final name = _name;
    final beneficiaryId = _beneficiaryId;
    final hasBeneficiaryId = beneficiaryId != null && beneficiaryId.isNotEmpty;
    final idLabel = _translate(localizations, null, _Copy.beneficiaryIdLabel);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: spacer2),
      padding: const EdgeInsets.all(spacer2),
      decoration: BoxDecoration(
        color: theme.colorTheme.paper.secondary,
        border: Border.all(color: theme.colorTheme.generic.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // The name and its copy button stay adjacent, so the score is
              // pushed to the far edge rather than sandwiched between them.
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: SelectableText(
                        name,
                        style: textTheme.headingS.copyWith(
                          color: theme.colorTheme.text.primary,
                        ),
                      ),
                    ),
                    if (name.isNotEmpty)
                      _CopyIconButton(
                        value: name,
                        valueLabel: name,
                        localizations: localizations,
                      ),
                  ],
                ),
              ),
              if (alert?.showScore ?? true)
                Padding(
                  padding: const EdgeInsets.only(left: spacer2),
                  child: Text(
                    _scoreText,
                    style: textTheme.bodyS.copyWith(
                      color: theme.colorTheme.text.secondary,
                    ),
                  ),
                ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '$idLabel: ',
                style: textTheme.bodyS.copyWith(
                  color: theme.colorTheme.text.secondary,
                ),
              ),
              Flexible(
                child: hasBeneficiaryId
                    ? SelectableText(
                        beneficiaryId,
                        style: textTheme.bodyS.copyWith(
                          color: theme.colorTheme.text.primary,
                        ),
                      )
                    : Text(
                        _translate(localizations, alert?.missingIdLabel,
                            _Copy.missingId),
                        style: textTheme.bodyS.copyWith(
                          color: theme.colorTheme.text.disabled,
                        ),
                      ),
              ),
              // Nothing to copy when the person has no ID yet.
              if (hasBeneficiaryId)
                _CopyIconButton(
                  value: beneficiaryId,
                  valueLabel: idLabel,
                  localizations: localizations,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A trailing icon button that copies [value] to the clipboard.
///
/// Confirms inline by swapping to a tick for [_confirmationDuration]. A toast
/// would be the usual choice, but this button lives inside a modal dialog
/// where `Toast.showToast` passes its animation duration as the visible
/// duration, so the confirmation is kept self-contained instead.
class _CopyIconButton extends StatefulWidget {
  /// The text placed on the clipboard.
  final String value;

  /// Names the value for screen readers, e.g. "Beneficiary ID".
  final String valueLabel;

  final FlowBuilderLocalization localizations;

  const _CopyIconButton({
    required this.value,
    required this.valueLabel,
    required this.localizations,
  });

  @override
  State<_CopyIconButton> createState() => _CopyIconButtonState();
}

class _CopyIconButtonState extends State<_CopyIconButton> {
  /// How long the tick stays up before reverting to the copy icon.
  static const Duration _confirmationDuration = Duration(seconds: 2);
  static const double _iconSize = 16;

  /// Keeps the tap target at the 32px minimum even though the icon is 16px.
  static const double _hitSize = 32;

  Timer? _resetTimer;
  bool _copied = false;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) return;

    setState(() => _copied = true);
    _resetTimer?.cancel();
    _resetTimer = Timer(_confirmationDuration, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = _translate(
      widget.localizations,
      null,
      _copied ? _Copy.copied : _Copy.copy,
    );

    return Tooltip(
      message: action,
      child: Semantics(
        button: true,
        label: '$action ${widget.valueLabel}',
        child: InkWell(
          onTap: _copyToClipboard,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: _hitSize,
            height: _hitSize,
            child: Center(
              child: Icon(
                _copied ? Icons.check : Icons.content_copy_outlined,
                size: _iconSize,
                color: _copied
                    ? theme.colorTheme.alert.success
                    : theme.colorTheme.primary.primary1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
