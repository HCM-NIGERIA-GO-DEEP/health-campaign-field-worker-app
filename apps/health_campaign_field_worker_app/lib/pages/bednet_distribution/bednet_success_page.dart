import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:digit_ui_components/widgets/molecules/panel_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/registration_deliver/search_households/search_households.dart';
import '../../utils/registration_deliver_utils/i18_key_constants.dart' as i18;
import '../../widgets/registartion_deliver/localized.dart';

/// Success screen after bednet "inform household" submit.
///
/// Routing matches [HouseholdAcknowledgementPage]: this flow uses the
/// [Navigator] stack on top of [SearchBeneficiaryRoute], so "View household"
/// pops back to [HouseHoldDetailsPage] and "Back to search" clears search
/// state and pops to the search screen.
class BednetSuccessPage extends LocalizedStatefulWidget {
  final String eToken;
  final int itnForDelivery;

  const BednetSuccessPage({
    super.key,
    super.appLocalizations,
    required this.eToken,
    required this.itnForDelivery,
  });

  @override
  State<BednetSuccessPage> createState() => _BednetSuccessPageState();
}

class _BednetSuccessPageState extends LocalizedState<BednetSuccessPage> {
  void _onViewHouseholdDetails() {
    if (!mounted) return;
    // Success → review → household details (two routes below this one).
    Navigator.of(context).pop();
    if (mounted) Navigator.of(context).pop();
  }

  void _onBackToSearch() {
    if (!mounted) return;
    context.read<SearchHouseholdsBloc>().add(const SearchHouseholdsEvent.clear());
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(spacer2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PanelCard(
                  type: PanelType.success,
                  title: localizations.translate(
                    i18.acknowledgementSuccess.acknowledgementLabelText,
                  ),
                  description: localizations.translate(
                    i18.acknowledgementSuccess.acknowledgementDescriptionText,
                  ),
                  actions: const [],
                ),
                const SizedBox(height: spacer2),
                // DigitCard(
                //   children: [
                //     Text(
                //       localizations.translate(
                //         i18.bednetDistribution.informSuccessBednetsDelivered,
                //       ),
                //       style: textTheme.headingM.copyWith(
                //         color: theme.colorTheme.primary.primary2,
                //       ),
                //       textAlign: TextAlign.center,
                //     ),
                //     const SizedBox(height: spacer1),
                //     Text(
                //       '${widget.itnForDelivery}',
                //       style: textTheme.headingXl.copyWith(
                //         color: theme.colorTheme.primary.primary2,
                //         fontWeight: FontWeight.w700,
                //       ),
                //       textAlign: TextAlign.center,
                //     ),
                //     const SizedBox(height: spacer2),
                //     Text(
                //       localizations.translate(
                //         i18.bednetDistribution.informSuccessETokenLabel,
                //       ),
                //       style: textTheme.bodyL.copyWith(
                //         color: theme.colorTheme.primary.primary1,
                //       ),
                //       textAlign: TextAlign.center,
                //     ),
                //     const SizedBox(height: spacer1),
                //     SelectableText(
                //       widget.eToken,
                //       style: textTheme.headingL.copyWith(
                //         fontWeight: FontWeight.w700,
                //       ),
                //       textAlign: TextAlign.center,
                //     ),
                //     const SizedBox(height: spacer2),
                //     Text(
                //       localizations.translate(
                //         i18.bednetDistribution.informSuccessMessage,
                //       ),
                //       style: textTheme.bodyL,
                //       textAlign: TextAlign.center,
                //     ),
                //   ],
                // ),
                const SizedBox(height: spacer2),
                DigitButton(
                  label: localizations.translate(
                    i18.householdDetails.viewHouseHoldDetailsAction,
                  ),
                  type: DigitButtonType.primary,
                  size: DigitButtonSize.large,
                  mainAxisSize: MainAxisSize.max,
                  onPressed: _onViewHouseholdDetails,
                ),
                const SizedBox(height: spacer2),
                DigitButton(
                  label: localizations.translate(
                    i18.acknowledgementSuccess.actionLabelText,
                  ),
                  type: DigitButtonType.secondary,
                  size: DigitButtonSize.large,
                  mainAxisSize: MainAxisSize.max,
                  onPressed: _onBackToSearch,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
