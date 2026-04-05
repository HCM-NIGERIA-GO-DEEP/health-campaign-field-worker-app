import 'package:auto_route/auto_route.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/widgets/molecules/panel_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_campaign_field_worker_app/blocs/registration_deliver/search_households/search_bloc_common_wrapper.dart';
import 'package:health_campaign_field_worker_app/utils/registration_deliver_utils/i18_key_constants.dart' as i18;

import '../../../widgets/localized.dart';

@RoutePage()
class BeneficiaryAcknowledgementPage extends LocalizedStatefulWidget {
  final bool? enableViewHousehold;

  const BeneficiaryAcknowledgementPage({
    super.key,
    super.appLocalizations,
    this.enableViewHousehold,
  });

  @override
  State<BeneficiaryAcknowledgementPage> createState() =>
      BeneficiaryAcknowledgementPageState();
}

class BeneficiaryAcknowledgementPageState
    extends LocalizedState<BeneficiaryAcknowledgementPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(spacer2),
        child: PanelCard(
          type: PanelType.success,
          title: localizations
              .translate(i18.acknowledgementSuccess.acknowledgementLabelText),
          actions: [
            DigitButton(
                label: localizations.translate(
                  i18.householdDetails.viewHouseHoldDetailsAction,
                ),
                onPressed: () {
                  final bloc = context.read<SearchBlocWrapper>();

                  // context.router.popAndPush(
                  //   BeneficiaryWrapperRoute(
                  //     wrapper: bloc.state.householdMembers.first,
                  //   ),
                  // );
                },
                type: DigitButtonType.primary,
                size: DigitButtonSize.large),
            DigitButton(
                label: localizations
                    .translate(i18.acknowledgementSuccess.actionLabelText),
                onPressed: () => context.router.maybePop(),
                type: DigitButtonType.secondary,
                size: DigitButtonSize.large),
          ],
          description: localizations.translate(
            i18.acknowledgementSuccess.acknowledgementDescriptionText,
          ),
        ),
      ),
    );
  }
}
