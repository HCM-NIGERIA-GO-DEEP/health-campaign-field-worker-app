import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/bednet_distribution/bednet_distribution.dart';
import '../../models/bednet_distribution/bednet_distribution_models.dart';
import '../../router/app_router.dart';
import '../../widgets/header/back_navigation_help_header.dart';

@RoutePage()
class ClassConfirmationPage extends StatelessWidget {
  final int classIndex;
  final int totalClasses;

  const ClassConfirmationPage({
    super.key,
    required this.classIndex,
    required this.totalClasses,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);
    final isLastClass = totalClasses > 0 && classIndex >= totalClasses - 1;

    return BlocListener<BednetDistributionBloc, BednetDistributionState>(
      listenWhen: (prev, curr) =>
          curr.navIntent != BednetNavIntent.none &&
          prev.navIntent != curr.navIntent,
      listener: (context, state) {
        if (!context.mounted) return;
        if (state.navIntent == BednetNavIntent.none) return;
        switch (state.navIntent) {
          case BednetNavIntent.none:
            break;
          case BednetNavIntent.openSuccess:
            context.read<BednetDistributionBloc>().add(
                  const BednetDistributionEvent.clearNavIntent(),
                );
            if (isLastClass) {
              context.router.popUntilRouteWithName(SelectSchoolRoute.name);
              if (context.router.current.name != SelectSchoolRoute.name) {
                context.router.push(const SelectSchoolRoute());
              }
            } else {
              context.router.popUntilRouteWithName(SchoolDetailsRoute.name);
              context.router.push(const BednetDistributionSuccessRoute());
            }
            break;
          case BednetNavIntent.continueNextClass:
            context.read<BednetDistributionBloc>().add(
                  const BednetDistributionEvent.clearNavIntent(),
                );
            context.router.popUntilRouteWithName(SchoolDetailsRoute.name);
            context.router.push(
              ClassDetailsRoute(
                classIndex: 0,
                totalClasses: state.classIndividuals.length,
              ),
            );
            break;
        }
      },
      child: Scaffold(
        body: ScrollableContent(
          enableFixedDigitButton: true,
          header: const BackNavigationHelpHeaderWidget(showHelp: false),
          footer: DigitCard(
            margin: const EdgeInsets.only(top: spacer2),
            children: [
              DigitButton(
                label: isLastClass ? 'Next School' : 'Next Class',
                type: DigitButtonType.primary,
                size: DigitButtonSize.large,
                mainAxisSize: MainAxisSize.max,
                onPressed: () {
                  context.read<BednetDistributionBloc>().add(
                        BednetDistributionEvent.completeClassAdministration(
                          classIndex: classIndex,
                        ),
                      );
                },
              ),
            ],
          ),
          slivers: [
            SliverToBoxAdapter(
              child: DigitCard(
                margin: const EdgeInsets.all(spacer2),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: spacer4,
                      vertical: spacer6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B6B3A),
                      borderRadius: BorderRadius.circular(spacer2),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Data Saved\nSuccessfully!',
                          textAlign: TextAlign.center,
                          style: textTheme.headingXl.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: spacer4),
                        Container(
                          padding: const EdgeInsets.all(spacer2),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: spacer6,
                            color: Color(0xFF0B6B3A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: spacer2),
                  Text(
                    'Data has been recorded successfully.',
                    style: textTheme.bodyL.copyWith(
                      color: theme.colorTheme.text.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

