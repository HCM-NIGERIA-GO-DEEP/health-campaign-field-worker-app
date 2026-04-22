import 'package:auto_route/auto_route.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/widgets/molecules/panel_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_campaign_field_worker_app/blocs/registration_deliver/household_overview/household_overview.dart';
import 'package:health_campaign_field_worker_app/blocs/registration_deliver/search_households/search_households.dart';
import 'package:health_campaign_field_worker_app/utils/registration_deliver_utils/i18_key_constants.dart'
    as i18;

import '../../../router/app_router.dart';
import '../../../widgets/localized.dart';

/// Success screen after registering a member on a **school** household.
/// Regular (non-school) households use [HouseholdAcknowledgementPage] instead.
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
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: BlocBuilder<HouseholdOverviewBloc, HouseholdOverviewState>(
          builder: (context, householdState) {
            return Padding(
              padding: const EdgeInsets.all(spacer2),
              child: PanelCard(
                type: PanelType.success,
                title: localizations
                    .translate(i18.acknowledgementSuccess.acknowledgementLabelText),
                description: localizations.translate(
                  i18.acknowledgementSuccess.acknowledgementDescriptionText,
                ),
                actions: [
                  DigitButton(
                    label: 'View School Details',
                    onPressed: () async {
                      context
                          .read<SearchHouseholdsBloc>()
                          .add(const SearchHouseholdsEvent.clear());
                      await context.router.navigate(
                        BednetHouseholdOverviewWrapperRoute(
                          children: [
                            const SchoolDetailsRoute(),
                          ],
                        ),
                      );
                    },
                    type: DigitButtonType.primary,
                    size: DigitButtonSize.large,
                  ),
                  DigitButton(
                    label: 'Back to School Selection',
                    onPressed: () async {
                      context
                          .read<SearchHouseholdsBloc>()
                          .add(const SearchHouseholdsEvent.clear());
                      final parent = context.router.parent() as StackRouter;
                      parent.popUntilRoot();
                      context.router.push(const SelectSchoolRoute());
                    },
                    type: DigitButtonType.secondary,
                    size: DigitButtonSize.large,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
