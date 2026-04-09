import 'package:auto_route/auto_route.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/household_type.dart';
import 'package:digit_scanner/blocs/scanner.dart';
import 'package:digit_scanner/pages/qr_scanner.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/services/location_bloc.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/atoms/digit_search_bar.dart';
import 'package:digit_ui_components/widgets/atoms/switch.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:health_campaign_field_worker_app/blocs/registration_deliver/search_households/search_households.dart';
import 'package:health_campaign_field_worker_app/blocs/bednet_distribution/bednet_distribution.dart';
import 'package:health_campaign_field_worker_app/blocs/registration_deliver/beneficiary_registration/beneficiary_registration.dart';
import 'package:health_campaign_field_worker_app/models/registration_deliver_model/entities/status.dart';
import 'package:health_campaign_field_worker_app/router/app_router.dart';
import 'package:health_campaign_field_worker_app/utils/registration_deliver_utils/global_search_parameters.dart';
import 'package:health_campaign_field_worker_app/utils/registration_deliver_utils/i18_key_constants.dart'
    as i18;
import 'package:health_campaign_field_worker_app/utils/registration_deliver_utils/extensions/extensions.dart';
import 'package:health_campaign_field_worker_app/utils/registration_deliver_utils/utils.dart';
import 'package:health_campaign_field_worker_app/widgets/registartion_deliver/back_navigation_help_header.dart';
import 'package:health_campaign_field_worker_app/widgets/registartion_deliver/beneficiary/view_beneficiary_card.dart';
import 'package:health_campaign_field_worker_app/widgets/registartion_deliver/localized.dart';

import '../../blocs/registration_deliver/search_households/search_bloc_common_wrapper.dart';
import '../bednet_distribution/bednet_household_location.dart';

@RoutePage()
class SearchBeneficiaryPage extends LocalizedStatefulWidget {
  const SearchBeneficiaryPage({
    super.key,
    super.appLocalizations,
  });

  @override
  State<SearchBeneficiaryPage> createState() => _SearchBeneficiaryPageState();
}

class _SearchBeneficiaryPageState
    extends LocalizedState<SearchBeneficiaryPage> {
  final TextEditingController searchController = TextEditingController();
  bool isProximityEnabled = false;
  bool isNameSearchEnabled = false;
  int offset = 0;
  int limit = 10;

  double lat = 0.0;
  double long = 0.0;
  List<String> selectedFilters = [];

  SearchHouseholdsState searchHouseholdsState = const SearchHouseholdsState(
    loading: false,
    householdMembers: [],
  );

  late final SearchBlocWrapper blocWrapper; // Declare BlocWrapper

  @override
  void initState() {
    // Initialize the BlocWrapper with instances of SearchHouseholdsBloc, SearchMemberBloc, and ProximitySearchBloc
    blocWrapper = context.read<SearchBlocWrapper>();
    context.read<LocationBloc>().add(const LoadLocationEvent());
    // Listen to state changes
    blocWrapper.stateChanges.listen((state) {
      if (mounted) {
        setState(() {
          searchHouseholdsState = state;
        });
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

    return KeyboardVisibilityBuilder(
      builder: (context, isKeyboardVisible) => Scaffold(
        body: NotificationListener<ScrollNotification>(
          onNotification: (scrollNotification) {
            if (scrollNotification is ScrollUpdateNotification) {
              final metrics = scrollNotification.metrics;
              if (metrics.atEdge && metrics.pixels != 0) {
                triggerGlobalSearchEvent(isPagination: true);
              }
            }
            return true;
          },
          child: ScrollableContent(
            header: const Column(children: [
              BackNavigationHelpHeaderWidget(showHelp: true),
            ]),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(spacer2),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(spacer2),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            localizations.translate(
                              RegistrationDeliverySingleton().householdType !=
                                          null &&
                                      RegistrationDeliverySingleton()
                                              .householdType ==
                                          HouseholdType.community
                                  ? i18.searchBeneficiary.searchCLFLabel
                                  : RegistrationDeliverySingleton()
                                              .beneficiaryType !=
                                          BeneficiaryType.individual
                                      ? i18
                                          .searchBeneficiary.statisticsLabelText
                                      : i18.searchBeneficiary
                                          .searchIndividualLabelText,
                            ),
                            style: textTheme.headingXl.copyWith(
                              color: const Color(0xFF005A7A),
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ),
                      BlocBuilder<LocationBloc, LocationState>(
                        builder: (context, locationState) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(spacer2),
                                child: DigitSearchBar(
                                  controller: searchController,
                                  hintText: 'To start, enter the Beneficiary ID',
                                  textCapitalization: TextCapitalization.words,
                                  onChanged: (value) {
                                    if (!isNameSearchEnabled && value.isNotEmpty) {
                                      return;
                                    }
                                    if (value.isEmpty || value.trim().length > 2) {
                                      triggerGlobalSearchEvent();
                                    }
                                  },
                                ),
                              ),
                              locationState.latitude != null
                                  ? Padding(
                                      padding: const EdgeInsets.all(spacer2),
                                      child: DigitSwitch(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        label: (RegistrationDeliverySingleton()
                                                    .householdType ==
                                                HouseholdType.community)
                                            ? localizations.translate(
                                                i18.searchBeneficiary
                                                    .communityProximityLabel,
                                              )
                                            : localizations.translate(
                                                i18.searchBeneficiary
                                                    .proximityLabel,
                                              ),
                                        value: isProximityEnabled,
                                        onChanged: (value) {
                                          searchController.clear();
                                          setState(() {
                                            isProximityEnabled = value;
                                            lat = locationState.latitude!;
                                            long = locationState.longitude!;
                                          });

                                          if (locationState.hasPermissions &&
                                              value &&
                                              locationState.latitude != null &&
                                              locationState.longitude != null &&
                                              RegistrationDeliverySingleton()
                                                      .maxRadius !=
                                                  null &&
                                              isProximityEnabled) {
                                            triggerGlobalSearchEvent();
                                          } else {
                                            blocWrapper.clearEvent();
                                            triggerGlobalSearchEvent();
                                          }
                                        },
                                      ),
                                    )
                                  : const Offstage(),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: spacer2,
                                ),
                                child: DigitSwitch(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  label: 'Search by Name',
                                  value: isNameSearchEnabled,
                                  onChanged: (value) {
                                    setState(() {
                                      isNameSearchEnabled = value;
                                    });
                                    if (!value) {
                                      searchController.clear();
                                      blocWrapper.clearEvent();
                                      triggerGlobalSearchEvent();
                                    }
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      if (searchHouseholdsState.resultsNotFound &&
                          !searchHouseholdsState.loading)
                        Padding(
                          padding: const EdgeInsets.only(
                              left: spacer2, top: spacer2, right: spacer2),
                          child: InfoCard(
                            type: InfoType.info,
                            description: (RegistrationDeliverySingleton()
                                        .householdType ==
                                    HouseholdType.community)
                                ? localizations.translate(
                                    i18.searchBeneficiary.clfInfoTitle)
                                : localizations.translate(
                                    i18.searchBeneficiary
                                        .beneficiaryInfoDescription,
                                  ),
                            title: localizations.translate(
                              i18.searchBeneficiary.beneficiaryInfoTitle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (searchHouseholdsState.loading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              BlocListener<DigitScannerBloc, DigitScannerState>(
                listener: (context, scannerState) {
                  if (scannerState.qrCodes.isNotEmpty) {
                    context.read<SearchBlocWrapper>().tagSearchBloc.add(
                          SearchHouseholdsEvent.searchByTag(
                            tag: scannerState.qrCodes.isNotEmpty
                                ? scannerState.qrCodes.lastOrNull!
                                : '',
                            projectId:
                                RegistrationDeliverySingleton().projectId!,
                          ),
                        );
                  }
                },
                child: BlocBuilder<LocationBloc, LocationState>(
                  builder: (context, locationState) {
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, index) {
                          final i = searchHouseholdsState.householdMembers
                              .elementAt(index);
                          final distance = calculateDistance(
                            Coordinate(
                              lat,
                              long,
                            ),
                            Coordinate(
                              i.household?.address?.latitude,
                              i.household?.address?.longitude,
                            ),
                          );

                          return Container(
                            margin: const EdgeInsets.only(bottom: spacer2),
                            child: ViewBeneficiaryCard(
                              distance: isProximityEnabled ? distance : null,
                              householdMember: i,
                              onOpenPressed: () async {
                                final scannerBloc =
                                    context.read<DigitScannerBloc>();

                                scannerBloc.add(
                                  const DigitScannerEvent.handleScanner(),
                                );

                                if ((i.tasks != null &&
                                        i.tasks?.lastOrNull!.status ==
                                            Status.closeHousehold.toValue() &&
                                        (i.tasks ?? []).isNotEmpty) ||
                                    (i.projectBeneficiaries ?? []).isEmpty) {
                                  setState(() {
                                    selectedFilters = [];
                                  });
                                  blocWrapper.clearEvent();
                                  if (i.household != null) {
                                    context.read<BednetDistributionBloc>().add(
                                          BednetDistributionEvent.selectSchool(
                                            school: i.household!,
                                          ),
                                        );
                                    await context.router.push(
                                      const BednetHouseholdOverviewWrapperRoute(),
                                    );
                                  }
                                } else {
                                  if (i.household != null) {
                                    context.read<BednetDistributionBloc>().add(
                                          BednetDistributionEvent.selectSchool(
                                            school: i.household!,
                                          ),
                                        );
                                    await context.router.push(
                                      const BednetHouseholdOverviewWrapperRoute(),
                                    );
                                  }
                                }
                                setState(() {
                                  isProximityEnabled = false;
                                });
                                searchController.clear();
                                selectedFilters.clear();
                                blocWrapper.clearEvent();
                              },
                            ),
                          );
                        },
                        childCount:
                            searchHouseholdsState.householdMembers.length,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Offstage(
          offstage: RegistrationDeliverySingleton().householdType ==
                  HouseholdType.community &&
              searchController.text.length < 3,
          child: DigitCard(
              margin: const EdgeInsets.only(top: spacer2),
              padding: const EdgeInsets.all(spacer4),
              children: [
                DigitButton(
                  capitalizeLetters: false,
                  label: (RegistrationDeliverySingleton().householdType ==
                          HouseholdType.community)
                      ? localizations
                          .translate(i18.searchBeneficiary.clfAddActionLabel)
                      : localizations.translate(
                          i18.searchBeneficiary.beneficiaryAddActionLabel,
                        ),
                  mainAxisSize: MainAxisSize.max,
                  type: DigitButtonType.primary,
                  size: DigitButtonSize.large,
                  isDisabled: searchHouseholdsState.searchQuery != null &&
                          searchHouseholdsState.searchQuery!.isNotEmpty
                      ? false
                      : false,
                  onPressed: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    context.read<DigitScannerBloc>().add(
                          const DigitScannerEvent.handleScanner(),
                        );
                    final registrationBloc = BeneficiaryRegistrationBloc(
                      BeneficiaryRegistrationState.create(
                        searchQuery: searchHouseholdsState.searchQuery ??
                            searchController.text.trim(),
                      ),
                      individualRepository:
                          context.repository<IndividualModel, IndividualSearchModel>(context),
                      householdRepository:
                          context.repository<HouseholdModel, HouseholdSearchModel>(context),
                      householdMemberRepository: context.repository<
                          HouseholdMemberModel,
                          HouseholdMemberSearchModel>(context),
                      projectBeneficiaryRepository: context.repository<
                          ProjectBeneficiaryModel,
                          ProjectBeneficiarySearchModel>(context),
                      taskDataRepository:
                          context.repository<TaskModel, TaskSearchModel>(context),
                      beneficiaryType:
                          RegistrationDeliverySingleton().beneficiaryType!,
                    );
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: registrationBloc,
                          child: const BednetHouseholdLocationPage(),
                        ),
                      ),
                    );
                    searchController.clear();
                    selectedFilters = [];
                    blocWrapper.clearEvent();
                  },
                ),
                DigitButton(
                  capitalizeLetters: false,
                  type: DigitButtonType.secondary,
                  size: DigitButtonSize.large,
                  mainAxisSize: MainAxisSize.max,
                  onPressed: () {
                    blocWrapper.clearEvent();
                    selectedFilters = [];
                    searchController.clear();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const DigitScannerPage(
                          quantity: 1,
                          isGS1code: false,
                          singleValue: true,
                        ),
                        settings: const RouteSettings(name: '/qr-scanner'),
                      ),
                    );
                  },
                  prefixIcon: Icons.qr_code,
                  label: localizations.translate(
                    i18.deliverIntervention.scannerLabel,
                  ),
                ),
              ]),
        ),
      ),
    );
  }

  void triggerGlobalSearchEvent({bool isPagination = false}) {
    if (!isPagination) {
      blocWrapper.clearEvent();
    }
    if (RegistrationDeliverySingleton().beneficiaryType ==
        BeneficiaryType.individual) {
      if (isProximityEnabled ||
          selectedFilters.isNotEmpty ||
          searchController.text.isNotEmpty) {
        blocWrapper.individualGlobalSearchBloc
            .add(SearchHouseholdsEvent.individualGlobalSearch(
                globalSearchParams: GlobalSearchParameters(
          isProximityEnabled: isProximityEnabled,
          latitude: lat,
          projectId: RegistrationDeliverySingleton().projectId!,
          longitude: long,
          maxRadius: RegistrationDeliverySingleton().maxRadius,
          nameSearch: searchController.text.trim().length > 2
              ? searchController.text.trim()
              : blocWrapper.searchHouseholdsBloc.state.searchQuery,
          filter: selectedFilters,
          offset: isPagination
              ? blocWrapper.individualGlobalSearchBloc.state.offset
              : offset,
          limit: isPagination
              ? blocWrapper.individualGlobalSearchBloc.state.limit
              : limit,
          householdType: RegistrationDeliverySingleton().householdType,
        )));
      }
    } else {
      if (isProximityEnabled ||
          selectedFilters.isNotEmpty ||
          searchController.text.isNotEmpty) {
        blocWrapper.houseHoldGlobalSearchBloc
            .add(SearchHouseholdsEvent.houseHoldGlobalSearch(
                globalSearchParams: GlobalSearchParameters(
          isProximityEnabled: isProximityEnabled,
          latitude: lat,
          longitude: long,
          projectId: RegistrationDeliverySingleton().projectId!,
          maxRadius: RegistrationDeliverySingleton().maxRadius,
          nameSearch: searchController.text.trim().length > 2
              ? searchController.text.trim()
              : blocWrapper.searchHouseholdsBloc.state.searchQuery,
          filter: selectedFilters,
          offset: isPagination
              ? blocWrapper.houseHoldGlobalSearchBloc.state.offset
              : offset,
          limit: isPagination
              ? blocWrapper.houseHoldGlobalSearchBloc.state.limit
              : limit,
          householdType: RegistrationDeliverySingleton().householdType,
        )));
      }
    }
  }
}
