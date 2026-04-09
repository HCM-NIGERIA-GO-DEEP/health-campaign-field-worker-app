import 'package:auto_route/auto_route.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/widgets/molecules/panel_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_campaign_field_worker_app/blocs/registration_deliver/household_overview/household_overview.dart';
import 'package:health_campaign_field_worker_app/blocs/registration_deliver/search_households/search_households.dart';
import 'package:health_campaign_field_worker_app/router/app_router.dart';
import 'package:health_campaign_field_worker_app/utils/registration_deliver_utils/i18_key_constants.dart';
import 'package:health_campaign_field_worker_app/widgets/registartion_deliver/localized.dart';

@RoutePage()
class HouseholdAcknowledgementPage extends LocalizedStatefulWidget {
  final bool? enableViewHousehold;

  const HouseholdAcknowledgementPage({
    super.key,
    super.appLocalizations,
    this.enableViewHousehold,
  });

  @override
  State<HouseholdAcknowledgementPage> createState() =>
      HouseholdAcknowledgementPageState();
}

class HouseholdAcknowledgementPageState
    extends LocalizedState<HouseholdAcknowledgementPage> {
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: BlocBuilder<HouseholdOverviewBloc, HouseholdOverviewState>(
          builder: (context, householdState) {
            return Padding(
              padding: const EdgeInsets.all(spacer2),
              child: PanelCard(
                type: PanelType.success,
                description: localizations.translate(
                  acknowledgementSuccess.acknowledgementDescriptionText,
                ),
                title: localizations.translate(
                  acknowledgementSuccess.acknowledgementLabelText,
                ),
                actions: [
                  DigitButton(
                      label: localizations.translate(
                        householdDetails.viewHouseHoldDetailsAction,
                      ),
                      // isDisabled: !(widget.enableViewHousehold ?? false),
                      onPressed: () {
                        final parent = context.router.parent() as StackRouter;
                        // Pop twice to navigate back to the previous screen
                        parent.popUntilRoot();
                        context.router.push(HouseHoldDetailsRoute());
                      },
                      type: DigitButtonType.primary,
                      size: DigitButtonSize.large),
                  DigitButton(
                      label: localizations
                          .translate(acknowledgementSuccess.actionLabelText),
                      onPressed: () {
                        context
                            .read<SearchHouseholdsBloc>()
                            .add(const SearchHouseholdsEvent.clear());
                        final parent = context.router.parent() as StackRouter;
                        // Pop twice to navigate back to the previous screen
                        parent.popUntilRoot();
                        context.router.push(SearchBeneficiaryRoute());
                      },
                      type: DigitButtonType.secondary,
                      size: DigitButtonSize.large),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
