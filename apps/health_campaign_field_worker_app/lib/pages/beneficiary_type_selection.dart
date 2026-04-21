import 'package:auto_route/auto_route.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/atoms/pop_up_card.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:digit_ui_components/widgets/molecules/show_pop_up.dart';
import 'package:flutter/material.dart';

import '../blocs/localization/app_localization.dart';
import '../models/entities/roles_type.dart';
import '../router/app_router.dart';
import '../utils/registration_deliver_utils/i18_key_constants.dart' as i18;
import '../utils/utils.dart';
import '../widgets/registartion_deliver/back_navigation_help_header.dart';

@RoutePage()
class BeneficiaryTypeSelectionPage extends StatefulWidget {
  const BeneficiaryTypeSelectionPage({super.key});

  @override
  State<BeneficiaryTypeSelectionPage> createState() =>
      _BeneficiaryTypeSelectionPageState();
}

class _BeneficiaryTypeSelectionPageState
    extends State<BeneficiaryTypeSelectionPage> {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).digitTextTheme(context);
    final isCommunityDistributor = context.loggedInUserRoles.any(
      (role) => role.code == RolesType.communityDistributor.toValue(),
    );

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        context.router.replaceAll([HomeRoute()]);
      },
      child: Scaffold(
        body: ScrollableContent(
          enableFixedDigitButton: false,
          header: const BackNavigationHelpHeaderWidget(showHelp: false),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(spacer2),
                child: DigitCard(
                  children: [
                    Text(
                      'Choose your beneficiary type',
                      style: textTheme.headingXl.copyWith(
                        color: const Color(0xFF005A7A),
                      ),
                    ),
                    const SizedBox(height: spacer3),
                    Row(
                      children: [
                        Expanded(
                          child: _BeneficiaryTypeCard(
                            icon: Icons.storefront,
                            label: 'School',
                            enabled: !isCommunityDistributor,
                            onTap: () => _checkStockAndProceed(
                              context,
                              onSuccess: () => context.router
                                  .push(const SelectSchoolRoute()),
                              descriptionText:
                                  AppLocalizations.of(context).translate(
                                i18.beneficiaryDetails
                                    .insufficientStockDescription,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: spacer2),
                        Expanded(
                          child: _BeneficiaryTypeCard(
                            icon: Icons.house,
                            label: 'Household',
                            enabled: isCommunityDistributor,
                            onTap: () => _checkStockAndProceed(
                              context,
                              onSuccess: () =>
                                  context.router.push(SearchBeneficiaryRoute()),
                              descriptionText:
                                  AppLocalizations.of(context).translate(
                                i18.beneficiaryDetails
                                    .insufficientStockDescription,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkStockAndProceed(
    BuildContext context, {
    required VoidCallback onSuccess,
    required String descriptionText,
  }) async {
    final localizations = AppLocalizations.of(context);

    // Using the centralized stock count from the Singleton (updated by AuthBloc)
    final stockCount = RegistrationDeliverySingleton().stockCount;

    // If stock is specifically 0 (or less), show the blocking popup.
    // If it's null, we allow proceeding as the count might not be initialized yet.
    if (stockCount != null && stockCount <= 0) {
      showCustomPopup(
        context: context,
        builder: (popupContext) => Popup(
          title: localizations
              .translate(i18.beneficiaryDetails.insufficientStockHeading),
          onOutsideTap: () {
            Navigator.of(popupContext).pop(false);
          },
          description: descriptionText,
          type: PopUpType.simple,
          actions: [
            DigitButton(
              label: localizations.translate(i18.beneficiaryDetails.goToHome),
              onPressed: () {
                Navigator.of(
                  popupContext,
                  rootNavigator: true,
                ).pop();
                context.router.replaceAll([HomeRoute()]);
              },
              type: DigitButtonType.primary,
              size: DigitButtonSize.large,
            ),
          ],
        ),
      );
    } else {
      onSuccess();
    }
  }
}

class _BeneficiaryTypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  const _BeneficiaryTypeCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          child: SizedBox(
            height: 110,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: const Color(0xFFCC4C02),
                    size: 42,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF005A7A),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
