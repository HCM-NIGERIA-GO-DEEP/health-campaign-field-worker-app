import 'package:collection/collection.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/bednet_distribution/bednet_distribution.dart';
import '../../models/bednet_distribution/bednet_distribution_models.dart';
import '../../router/app_router.dart';
import '../../widgets/header/back_navigation_help_header.dart';
import 'widgets/bednet_info_card.dart';

@RoutePage()
class DistributionSummaryPage extends StatelessWidget {
  final int classIndex;
  final int totalClasses;

  const DistributionSummaryPage({
    super.key,
    required this.classIndex,
    required this.totalClasses,
  });

  @override
  Widget build(BuildContext context) {
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
            context.router.popUntilRouteWithName(SchoolDetailsRoute.name);
            context.router.push(const BednetDistributionSuccessRoute());
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
      child: _DistributionSummaryBody(
        classIndex: classIndex,
        totalClasses: totalClasses,
      ),
    );
  }
}

class _DistributionSummaryBody extends StatelessWidget {
  final int classIndex;
  final int totalClasses;

  const _DistributionSummaryBody({
    required this.classIndex,
    required this.totalClasses,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BednetDistributionBloc>().state;
    final summary = state.summariesByClass.elementAt(classIndex);
    final classLabel = state.classIndividuals
                .elementAtOrNull(classIndex)
                ?.name
                ?.givenName
                ?.trim()
                .isNotEmpty ==
            true
        ? state.classIndividuals.elementAt(classIndex).name!.givenName!.trim()
        : 'Class ${classIndex + 1}';
    if (summary == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      body: ScrollableContent(
        enableFixedDigitButton: true,
        header: const BackNavigationHelpHeaderWidget(showHelp: false),
        footer: DigitCard(
          margin: const EdgeInsets.only(top: spacer2),
          children: [
            DigitButton(
              label: 'Submit',
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
            child: BednetInfoCard(
              title: '$classLabel Distribution Summary',
              showDivider: true,
              items: [
                MapEntry('Resources to be Delivered', summary.resourceName),
                MapEntry(
                  'Number Of Boys that received Bednets',
                  summary.boysReceived.toString(),
                ),
                MapEntry(
                  'Number Of Girls that received Bednets',
                  summary.girlsReceived.toString(),
                ),
                MapEntry(
                  'Total Number of Bednets Delivered',
                  summary.totalDelivered.toString(),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
