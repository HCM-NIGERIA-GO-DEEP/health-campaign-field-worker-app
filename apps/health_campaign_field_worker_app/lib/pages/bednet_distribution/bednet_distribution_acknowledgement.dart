import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/bednet_distribution/bednet_distribution.dart';
import '../../models/bednet_distribution/bednet_distribution_models.dart';
import '../../router/app_router.dart';
import '../../widgets/header/back_navigation_help_header.dart';
import 'widgets/bednet_bloc_guard.dart';

/// Shown after the last class distribution summary is submitted, when all
/// pending classes for the school have been administered.
@RoutePage()
class BednetDistributionAcknowledgementPage extends StatelessWidget {
  const BednetDistributionAcknowledgementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = maybeBednetDistributionBloc(context);
    if (bloc == null) {
      return missingBednetDistributionBlocFallback(context);
    }
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);
    final school = bloc.state.selectedSchool;

    return Scaffold(
      body: ScrollableContent(
        enableFixedDigitButton: true,
        header: const BackNavigationHelpHeaderWidget(
          showHelp: false,
          showBackNavigation: false,
        ),
        footer: DigitCard(
          margin: const EdgeInsets.only(top: spacer2),
          children: [
            DigitButton(
              label: 'Continue',
              type: DigitButtonType.primary,
              size: DigitButtonSize.large,
              mainAxisSize: MainAxisSize.max,
              onPressed: () {
                context.router.push(const BednetDistributionSuccessRoute());
              },
            ),
          ],
        ),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(spacer4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_outlined,
                    color: theme.colorTheme.alert.success,
                    size: spacer10,
                  ),
                  const SizedBox(height: spacer3),
                  Text(
                    'Beneficiary acknowledgement',
                    textAlign: TextAlign.center,
                    style: textTheme.headingXl.copyWith(
                      color: theme.colorTheme.primary.primary2,
                    ),
                  ),
                  const SizedBox(height: spacer2),
                  Text(
                    school != null
                        ? 'All classes at "${school.bednetDisplayName}" have been '
                            'administered. Bednet distribution details have been '
                            'recorded for each class.'
                        : 'All classes for this school have been administered.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyL.copyWith(
                      color: theme.colorTheme.text.secondary,
                    ),
                  ),
                  const SizedBox(height: spacer2),
                  Text(
                    'You can continue to the completion screen or return home '
                    'from there.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyS.copyWith(
                      color: theme.colorTheme.text.secondary,
                    ),
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
