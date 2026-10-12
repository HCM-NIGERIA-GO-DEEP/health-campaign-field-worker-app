import 'package:digit_dedup_engine/digit_dedup_engine.dart';
import 'package:digit_forms_engine/forms_engine.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/atoms/pop_up_card.dart';
import 'package:digit_ui_components/widgets/molecules/show_pop_up.dart';
import 'package:flutter/material.dart';

import '../action_handler/action_config.dart';
import '../action_handler/action_handler.dart';
import '../blocs/app_localization.dart';
import '../blocs/flow_crud_bloc.dart';
import '../utils/interpolation.dart';
import '../widget_registry.dart';
import 'flow_widget_interface.dart';
import 'dedup_match_dialog.dart';
import 'localization_context.dart';

/// Keys each match row exposes to `body` templates, e.g.
/// `{{item.beneficiaryId}}`.
///
/// Deliberately plain names rather than the underscore-prefixed
/// [DedupRecordKeys] the engine carries internally, so config reads naturally.
class DedupMatchRowKeys {
  const DedupMatchRowKeys._();

  static const String displayName = 'displayName';
  static const String beneficiaryId = 'beneficiaryId';

  /// Lets a row hide its ID value and copy button with
  /// `"visible": "{{item.hasBeneficiaryId}}==true"`.
  static const String hasBeneficiaryId = 'hasBeneficiaryId';

  static const String clientReferenceId = 'clientReferenceId';
  static const String score = 'score';
  static const String scorePercentage = 'scorePercentage';

  /// The score already formatted and localized, e.g. "92% match". Config can
  /// use [scorePercentage] instead to compose its own wording, but then the
  /// surrounding words are not translatable.
  static const String scoreText = 'scoreText';
}

/// Localization code for the formatted score, with the copy used until that
/// string is published. `{score}` is replaced with the whole percentage.
const String dedupScoreCode = 'DEDUP_SIMILAR_BENEFICIARY_SCORE';
const String dedupScoreFallback = '{score}% match';

/// Shows the dedup warning described by a page's `dedupAlertPopUp` config.
///
/// The dialog chrome and the match rows come from config; the two buttons stay
/// in Dart because the caller has to be told whether to continue the
/// submission. Returns [DedupCheckOutcome.abort] for any exit that is not an
/// explicit tap on the primary action, so a stray dismissal never saves a
/// possible duplicate.
Future<DedupCheckOutcome> showConfigDedupAlert({
  required BuildContext context,
  required DedupAlertPopUp alert,
  required List<DedupMatch> matches,
  required String stateKey,
  required VoidCallback onBackToSearch,
}) async {
  final localization = FlowBuilderLocalization.of(context);

  // Publish the matches under a key of their own. Writing them into the form
  // screen's state would clobber whatever its own widgets are bound to.
  final alertStateKey = '$stateKey#dedupAlert';
  FlowCrudStateRegistry().update(
    alertStateKey,
    FlowCrudState(
      stateWrapper: [
        {
          alert.matchesKey: [
            for (final match in matches) toMatchRow(match, localization),
          ],
        },
      ],
    ),
  );

  try {
    final stateData = extractCrudStateData(alertStateKey);

    final outcome = await showCustomPopup(
      context: context,
      barrierDismissible: alert.barrierDismissible,
      builder: (dialogContext) => Popup(
        title: localization.translate(alert.title),
        description: alert.description == null
            ? null
            : localization.translate(alert.description!),
        titleIcon: alert.titleIcon == null
            ? null
            : Icon(
                DigitIconMapping.getIcon(alert.titleIcon!),
                color: Theme.of(dialogContext).colorTheme.primary.primary1,
              ),
        onCrossTap: alert.showCloseButton
            ? () => Navigator.of(dialogContext, rootNavigator: true)
                .pop(DedupCheckOutcome.abort)
            : null,
        additionalWidgets: [
          for (final widgetJson in alert.body.whereType<Map>())
            _DedupBodyWidget(
              widgetJson: Map<String, dynamic>.from(widgetJson),
              stateData: stateData,
              stateKey: alertStateKey,
              localization: localization,
            ),
        ],
        actions: [
          DigitButton(
            label: localization.translate(alert.secondaryActionLabel),
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
            label: localization.translate(alert.primaryActionLabel),
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
  } finally {
    FlowCrudStateRegistry().dispose(alertStateKey);
  }
}

/// Flattens a [DedupMatch] into the map its row template binds against.
Map<String, dynamic> toMatchRow(
  DedupMatch match,
  FlowBuilderLocalization localization,
) {
  final beneficiaryId =
      (match.record[DedupRecordKeys.beneficiaryId] as String?)?.trim();

  // translate() echoes an unknown code back, so fall back to readable copy.
  final scoreTemplate = localization.translate(dedupScoreCode);

  return {
    DedupMatchRowKeys.displayName: match.record[DedupRecordKeys.displayName],
    DedupMatchRowKeys.beneficiaryId: beneficiaryId,
    DedupMatchRowKeys.hasBeneficiaryId:
        beneficiaryId != null && beneficiaryId.isNotEmpty,
    DedupMatchRowKeys.clientReferenceId:
        match.record[DedupRecordKeys.clientReferenceId],
    DedupMatchRowKeys.score: match.score,
    DedupMatchRowKeys.scorePercentage: match.scorePercentage,
    DedupMatchRowKeys.scoreText:
        (scoreTemplate == dedupScoreCode ? dedupScoreFallback : scoreTemplate)
            .replaceAll('{score}', match.scorePercentage.toString()),
  };
}

/// Renders one entry of the config `body`.
///
/// Supplies the [CrudItemContext] that flow builder widgets read their state
/// from -- `listView` in particular dereferences it without a null check --
/// plus the localization those widgets expect.
class _DedupBodyWidget extends StatelessWidget {
  final Map<String, dynamic> widgetJson;
  final CrudStateData stateData;
  final String stateKey;
  final FlowBuilderLocalization localization;

  const _DedupBodyWidget({
    required this.widgetJson,
    required this.stateData,
    required this.stateKey,
    required this.localization,
  });

  @override
  Widget build(BuildContext context) {
    return LocalizationContext(
      localization: localization,
      child: CrudItemContext(
        stateData: stateData,
        screenKey: stateKey,
        compositeKey: stateKey,
        child: Builder(
          builder: (innerContext) => FlowWidgetFactory.build(
            widgetJson,
            innerContext,
            (action) => _handleAction(innerContext, action),
          ),
        ),
      ),
    );
  }

  /// Runs a body widget's action, e.g. COPY_TO_CLIPBOARD from a copy button.
  ///
  /// Body actions are kept separate from the footer buttons so config can
  /// never resolve the dialog's outcome by accident.
  void _handleAction(BuildContext context, ActionConfig action) {
    ActionHandler.execute(action, context, const {}).ignore();
  }
}
