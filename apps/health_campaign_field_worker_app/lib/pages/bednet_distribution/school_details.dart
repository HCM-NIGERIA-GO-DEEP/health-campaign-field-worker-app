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
class SchoolDetailsPage extends StatelessWidget {
  const SchoolDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BednetDistributionBloc, BednetDistributionState>(
      builder: (context, state) {
        final school = state.selectedSchool;
        if (school == null) {
          return const Scaffold(body: SizedBox.shrink());
        }
        final pendingCount = state.classIndividuals.length;
        final totalClasses = school.bednetNumberOfClasses;

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
                    context.router.push(
                      ClassDetailsRoute(
                        classIndex: 0,
                        totalClasses: totalClasses,
                      ),
                    );
                  },
                )
              ],
            ),
            slivers: [
              SliverToBoxAdapter(
                child: BednetInfoCard(
                  title: 'School Details',
                  items: [
                    MapEntry(
                      'Classes to administer (pending)',
                      pendingCount > 0 ? pendingCount.toString() : '—',
                    ),
                    MapEntry('School Name', school.bednetDisplayName),
                    MapEntry('School Head', school.bednetSchoolHead),
                    MapEntry(
                      'Number of Classes',
                      totalClasses.toString(),
                    ),
                    MapEntry('Pupil Count', school.bednetPupilCount.toString()),
                    MapEntry(
                      'Number of Boys',
                      school.bednetNumberOfBoys.toString(),
                    ),
                    MapEntry(
                      'Number of Girls',
                      school.bednetNumberOfGirls.toString(),
                    ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
