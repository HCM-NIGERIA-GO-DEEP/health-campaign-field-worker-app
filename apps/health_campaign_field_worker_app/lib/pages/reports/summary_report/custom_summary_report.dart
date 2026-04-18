// import 'package:attendance_management/widgets/labelled_toggle.dart';
import 'package:digit_ui_components/enum/app_enums.dart';
import 'package:digit_ui_components/theme/spacers.dart';
import 'package:digit_ui_components/widgets/atoms/digit_button.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:digit_ui_components/widgets/scrollable_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_campaign_field_worker_app/widgets/localized.dart';
import 'package:health_campaign_field_worker_app/widgets/reports/readonly_pluto_grid.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../../blocs/summary_report/custom_summary_report_bloc.dart';
import '../../../router/app_router.dart';
import '../../../utils/utils.dart';
import '../../../utils/i18_key_constants.dart' as i18Local;
import '../../../widgets/header/back_navigation_help_header.dart';
import '../../registration_deliver_pages/beneficiary_registration/refer_beneficiary_page.dart'
    show contextIsCommunityDistributor;

@RoutePage()
class CustomSummaryReportPage extends LocalizedStatefulWidget {
  const CustomSummaryReportPage({
    Key? key,
    super.appLocalizations,
  }) : super(key: key);

  @override
  State<CustomSummaryReportPage> createState() => _CustomSummaryReportState();
}

class _CustomSummaryReportState
    extends LocalizedState<CustomSummaryReportPage> {
  @override
  void initState() {
    super.initState();
    // Load data when the page is initialized
    _loadData();
  }

  void _loadData() {
    final bloc = BlocProvider.of<SummaryReportBloc>(context);
    bloc.add(const SummaryReportLoadingEvent());
    Future.delayed(const Duration(milliseconds: 500), () {
      bloc.add(SummaryReportLoadDataEvent(
        userId: context.loggedInUserUuid,
      ));
    });
  }

  static const _dateKey = 'dateKey';
  static const _schoolVisitedKey = 'schoolVisitedKey';
  static const _schoolBednetDeliveredKey = 'schoolBednetDeliveredKey';
  static const _householdVisitedKey = 'householdVisitedKey';
  static const _householdBednetDeliveredKey = 'householdBednetDeliveredKey';
  static const _bednetRemainigKey = 'bednetRemainigKey';

  String _calculatePercentage(dynamic value, int total) {
    if (value == null) return "0%";

    final quantity = value is num ? value : int.tryParse(value.toString()) ?? 0;

    final percent = (quantity / total) * 100;
    return "${percent.toStringAsFixed(1)}%";
  }

  FormGroup _form() {
    return fb.group({});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<SummaryReportBloc, SummaryReportState>(
        builder: (context, summaryReportState) {
          if (summaryReportState is SummaryReportLoadingState) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          return ScrollableContent(
            footer: DigitCard(
                margin: const EdgeInsets.only(top: spacer2),
                children: [
                  DigitButton(
                    mainAxisSize: MainAxisSize.max,
                    label: localizations.translate(
                      i18Local.acknowledgementSuccess.goToHome,
                    ),
                    type: DigitButtonType.primary,
                    size: DigitButtonSize.large,
                    onPressed: () {
                      context.router.popUntilRouteWithName(HomeRoute.name);
                    },
                  ),
                ]),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BackNavigationHelpHeaderWidget(),
              Container(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    localizations
                        .translate(i18Local.homeShowcase.summaryReport),
                    maxLines: 1,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ),
              if (summaryReportState is SummaryReportDataState)
                ReactiveFormBuilder(
                  form: _form,
                  builder: (ctx, form, child) {
                    return Column(
                      children: [
                        // Conditional Rendering based on Role
                        if (contextIsCommunityDistributor(context))
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle(
                                  'Household Distribution Report'),
                              SizedBox(
                                height: 300,
                                child: _ReportDetailsContent(
                                  title: 'Household Distribution Report',
                                  data: DigitGridData(
                                    columns: [
                                      DigitGridColumn(
                                        label: 'Date',
                                        key: _dateKey,
                                        width: 120,
                                      ),
                                      DigitGridColumn(
                                        label: 'No. of household visited',
                                        key: _householdVisitedKey,
                                        width: 180,
                                      ),
                                      DigitGridColumn(
                                        label: 'No. of Bednet delivered',
                                        key: _householdBednetDeliveredKey,
                                        width: 180,
                                      ),
                                    ],
                                    rows: summaryReportState.data.entries
                                        .toList()
                                        .reversed
                                        .map((entry) {
                                      final metrics = entry.value;
                                      return DigitGridRow([
                                        DigitGridCell(
                                            key: _dateKey, value: entry.key),
                                        DigitGridCell(
                                          key: _householdVisitedKey,
                                          value:
                                              '${metrics[_householdVisitedKey] ?? 0}',
                                        ),
                                        DigitGridCell(
                                          key: _householdBednetDeliveredKey,
                                          value:
                                              '${metrics[_householdBednetDeliveredKey] ?? 0}',
                                        ),
                                      ]);
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle('School Distribution Report'),
                              SizedBox(
                                height: 300,
                                child: _ReportDetailsContent(
                                  title: 'School Distribution Report',
                                  data: DigitGridData(
                                    columns: [
                                      DigitGridColumn(
                                        label: 'Date',
                                        key: _dateKey,
                                        width: 120,
                                      ),
                                      DigitGridColumn(
                                        label: 'No. of school visited',
                                        key: _schoolVisitedKey,
                                        width: 180,
                                      ),
                                      DigitGridColumn(
                                        label: 'No. of Bednet delivered',
                                        key: _schoolBednetDeliveredKey,
                                        width: 180,
                                      ),
                                    ],
                                    rows: summaryReportState.data.entries
                                        .toList()
                                        .reversed
                                        .map((entry) {
                                      final metrics = entry.value;
                                      return DigitGridRow([
                                        DigitGridCell(
                                            key: _dateKey, value: entry.key),
                                        DigitGridCell(
                                          key: _schoolVisitedKey,
                                          value:
                                              '${metrics[_schoolVisitedKey] ?? 0}',
                                        ),
                                        DigitGridCell(
                                          key: _schoolBednetDeliveredKey,
                                          value:
                                              '${metrics[_schoolBednetDeliveredKey] ?? 0}',
                                        ),
                                      ]);
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF005A7A),
            ),
      ),
    );
  }
}

class _ReportDetailsContent extends StatelessWidget {
  final String title;
  final DigitGridData data;

  const _ReportDetailsContent({
    Key? key,
    required this.title,
    required this.data,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16 * 2),
          Flexible(
            child: ReadonlyDigitGrid(
              data: data,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoReportContent extends StatelessWidget {
  final String title;
  final String message;

  const _NoReportContent({
    Key? key,
    required this.title,
    required this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          height: 16 * 2,
          width: double.maxFinite,
        ),
        Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.disabledColor,
            ),
          ),
        ),
      ],
    );
  }
}
