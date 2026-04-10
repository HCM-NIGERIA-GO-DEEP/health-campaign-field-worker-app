import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/bednet_distribution/bednet_distribution.dart';
import '../../router/app_router.dart';
import '../../widgets/header/back_navigation_help_header.dart';
import 'widgets/bednet_bloc_guard.dart';
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
    return _DistributionSummaryBody(
      classIndex: classIndex,
      totalClasses: totalClasses,
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
    final bloc = maybeBednetDistributionBloc(context);
    if (bloc == null) {
      return missingBednetDistributionBlocFallback(context);
    }
    final state = bloc.state;
    final ordinalIndex = classIndex - 1;
    final summary = null;
    final classLabel = 'Class $classIndex';
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
              onPressed: () {},
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
