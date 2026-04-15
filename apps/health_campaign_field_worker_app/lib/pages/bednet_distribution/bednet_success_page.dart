import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/registration_deliver/household_overview/household_overview.dart';
import '../../blocs/registration_deliver/search_households/search_households.dart';
import '../../router/app_router.dart';
import '../../utils/registration_deliver_utils/i18_key_constants.dart' as i18;
import '../../utils/registration_deliver_utils/utils.dart';
import '../../widgets/registartion_deliver/localized.dart';

/// Shown **only** after successful ITN / bednet **delivery** to the household —
/// i.e. after submitting [BednetInformHouseholdPage] (EOLIN → inform → success).
///
/// Normal **household registration** (search → location → household details) uses
/// [HouseholdAcknowledgementPage] instead.
///
/// Do not pop the auto-route stack twice when this overlay sits on
/// [SearchBeneficiaryPage]: use [StackRouter.root.navigate] for explicit targets.
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
  void _dispatchHouseholdOverviewReload() {
    final projectId = RegistrationDeliverySingleton().projectId;
    final beneficiaryType = RegistrationDeliverySingleton().beneficiaryType;
    if (projectId == null || beneficiaryType == null) return;
    try {
      context.read<HouseholdOverviewBloc>().add(
            HouseholdOverviewReloadEvent(
              projectId: projectId,
              projectBeneficiaryType: beneficiaryType,
              offset: 0,
              limit: 1000,
            ),
          );
    } catch (_) {}
  }

  void _onViewHouseholdDetails() {
    if (!mounted) return;
    _dispatchHouseholdOverviewReload();
    final root = context.router.root;
    final nav = Navigator.of(context);
    if (!nav.canPop()) return;
    // Dismiss this overlay only; the route below is often [SearchBeneficiaryPage].
    nav.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      root.navigate(
        BednetHouseholdOverviewWrapperRoute(
          children: [
            CustomHouseholdOverviewRoute(),
          ],
        ),
      );
    });
  }

  void _onBackToSearch() {
    if (!mounted) return;
    try {
      context
          .read<SearchHouseholdsBloc>()
          .add(const SearchHouseholdsEvent.clear());
    } catch (_) {}

    final root = context.router.root;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      root.navigate(SearchBeneficiaryRoute());
    });
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
                DigitCard(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(
                        left: spacer8,
                        right: spacer8,
                        top: spacer9,
                        bottom: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(spacer2),
                      ),
                      child: Column(
                        children: [
                          Text(
                            localizations
                                .translate(
                                  i18.bednetDistribution
                                      .informSuccessBednetsDelivered,
                                )
                                .replaceAll(
                                  '{count}',
                                  widget.itnForDelivery.toString(),
                                ),
                            style: textTheme.headingM.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: spacer2),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Color(0xFF0B8D46),
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: spacer1),
                          Text(
                            localizations.translate(
                              i18.bednetDistribution.informSuccessETokenLabel,
                            ),
                            style: textTheme.bodyS.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: spacer7),
                          SelectableText(
                            widget.eToken,
                            style: textTheme.headingL.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: spacer1),
                    Center(
                      child: Text(
                        localizations.translate(
                          i18.bednetDistribution.informSuccessMessage,
                        ),
                        style: textTheme.bodyS,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
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
                    i18.acknowledgementSuccess.acknowledgementLabelText,
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
