import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/bednet_distribution/bednet_distribution.dart';
import '../../blocs/registration_deliver/household_overview/household_overview.dart';
import '../../models/bednet_distribution/bednet_distribution_models.dart';
import '../../router/app_router.dart';
import '../../widgets/header/back_navigation_help_header.dart';
import 'widgets/bednet_info_card.dart';

@RoutePage()
class SchoolDetailsPage extends StatelessWidget {
  const SchoolDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BednetDistributionBloc, BednetDistributionState>(
      builder: (context, distributionState) {
        final school = distributionState.selectedSchool;
        if (school == null) {
          return const Scaffold(body: SizedBox.shrink());
        }

        return BlocBuilder<HouseholdOverviewBloc, HouseholdOverviewState>(
          builder: (context, overviewState) {
            final head = overviewState.householdMemberWrapper.headOfHousehold;
            final headName = [
              head?.name?.givenName,
              head?.name?.familyName,
            ].whereType<String>().join(' ').trim();

            return Scaffold(
              body: ScrollableContent(
                enableFixedDigitButton: true,
                header: const BackNavigationHelpHeaderWidget(showHelp: false),
                footer: DigitCard(
                  margin: const EdgeInsets.only(top: spacer2),
                  children: [
                    DigitButton(
                      label: 'Next',
                      type: DigitButtonType.primary,
                      size: DigitButtonSize.large,
                      mainAxisSize: MainAxisSize.max,
                      onPressed: () {
                        context.router.push(HouseholdOverviewRoute());
                      },
                    )
                  ],
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: BednetInfoCard(
                      title: 'School Details',
                      items: [
                        MapEntry('School Name', school.bednetDisplayName),
                        MapEntry(
                          'School Head',
                          headName.isNotEmpty
                              ? headName
                              : school.bednetSchoolHead,
                        ),
                        MapEntry(
                          'Student Total Count',
                          school.memberCount.toString(),
                        ),
                        MapEntry(
                          'Community',
                          school.boundaryCode ?? school.bednetCommunity,
                        ),
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}
