import 'package:auto_route/auto_route.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';

import '../router/app_router.dart';
import '../widgets/registartion_deliver/back_navigation_help_header.dart';

@RoutePage()
class BeneficiaryTypeSelectionPage extends StatelessWidget {
  const BeneficiaryTypeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

    return Scaffold(
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
                          onTap: () =>
                              context.router.push(const SelectSchoolRoute()),
                        ),
                      ),
                      const SizedBox(width: spacer2),
                      Expanded(
                        child: _BeneficiaryTypeCard(
                          icon: Icons.house,
                          label: 'Household',
                          onTap: () =>
                              context.router.push(SearchBeneficiaryRoute()),
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
    );
  }
}

class _BeneficiaryTypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BeneficiaryTypeCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
    );
  }
}
