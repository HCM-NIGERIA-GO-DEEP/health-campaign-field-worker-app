import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/widgets/atoms/label_value_list.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:digit_ui_components/widgets/molecules/label_value_summary.dart';
import 'package:digit_ui_components/widgets/molecules/panel_cards.dart';
import 'package:flutter/material.dart';

import '../router/app_router.dart';
import '../utils/i18_key_constants.dart' as i18;
import '../widgets/localized.dart';

@RoutePage()
class AcknowledgementPage extends LocalizedStatefulWidget {
  bool isDataRecordSuccess;
  String? label;
  String? description;
  Map<String, dynamic>? descriptionTableData;

  AcknowledgementPage({
    super.key,
    super.appLocalizations,
    this.isDataRecordSuccess = false,
    this.label,
    this.description,
    this.descriptionTableData,
  });

  @override
  State<AcknowledgementPage> createState() => _AcknowledgementPageState();
}

class _AcknowledgementPageState extends LocalizedState<AcknowledgementPage> {
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: PanelCard(
        type: PanelType.success,
        title: widget.label ??
            localizations.translate(
              i18.acknowledgementSuccess.acknowledgementLabelText,
            ),
        additionWidgets: widget.isDataRecordSuccess
            ? [
                LabelValueSummary(
                  items: widget.descriptionTableData!.keys
                      .map((e) => LabelValueItem(
                          labelFlex: 5,
                          label: e,
                          maxLines: 3,
                          value: widget.descriptionTableData?[e].toString()))
                      .toList(),
                ),
              ]
            : null,
        actions: (!widget.isDataRecordSuccess)
            ? [
                DigitButton(
                  isDisabled: widget.isDataRecordSuccess,
                  type: DigitButtonType.primary,
                  size: DigitButtonSize.large,
                  label: localizations
                      .translate(i18.acknowledgementSuccess.actionLabelText),
                  onPressed: () {
                    context.router.maybePop();
                  },
                ),
              ]
            : null,
      ),
      bottomNavigationBar: Offstage(
        offstage: !widget.isDataRecordSuccess,
        // Show the bottom navigation bar if `isDataRecordSuccess` is true
        child:
            DigitCard(margin: const EdgeInsets.only(top: spacer2), children: [
          DigitButton(
            mainAxisSize: MainAxisSize.max,
            label: localizations.translate(i18.acknowledgementSuccess.goToHome),
            type: DigitButtonType.primary,
            size: DigitButtonSize.large,
            onPressed: () {
              // replaceAll, not popAndPushAll: HomeRoute is almost always
              // already on the stack (the flow was entered from Home), and
              // popAndPushAll only pops the current route before pushing - so
              // it left TWO HomePage instances mounted at once. Both carry the
              // same showcase GlobalKeys (HOME_DB_LABEL,
              // DISTRIBUTOR_HOME_SHOWCASE_*, ...), which is what raised
              // "Duplicate GlobalKeys detected in widget tree". Every other
              // route back to Home in this app already uses replaceAll - see
              // the contract noted at the top of home.dart.
              context.router.replaceAll([HomeRoute()]);
            },
          ),
          DigitButton(
            type: DigitButtonType.secondary,
            mainAxisSize: MainAxisSize.max,
            size: DigitButtonSize.large,
            onPressed: () {
              context.router.popAndPush(BoundarySelectionRoute());
            },
            label: localizations
                .translate(i18.acknowledgementSuccess.downloadmoredata),
          ),
        ]),
      ),
    );
  }
}
