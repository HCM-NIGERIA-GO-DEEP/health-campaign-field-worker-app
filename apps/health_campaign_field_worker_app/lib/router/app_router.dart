import 'package:auto_route/auto_route.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/attendee.dart';
import 'package:digit_data_model/models/entities/scanned_individual_data.dart';
import 'package:digit_dss/router/dashboard_router.dart';
import 'package:digit_dss/router/dashboard_router.gm.dart';
import 'package:digit_flow_builder/router/flow_builder_routes.dart';
import 'package:digit_flow_builder/router/flow_builder_routes.gm.dart';
import 'package:digit_forms_engine/router/forms_router.dart';
import 'package:digit_scanner/router/digit_scanner_router.dart';
import 'package:digit_scanner/router/digit_scanner_router.gm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:survey_form/router/survey_form_router.dart';
import 'package:survey_form/router/survey_form_router.gm.dart';
import 'package:transit_post/router/transit_post_router.dart';

import '../blocs/localization/app_localization.dart';
import '../blocs/registration_deliver/app_localization.dart';
import '../pages/acknowledgement.dart';
import '../pages/attendance_qr_scanner.dart';
import '../pages/authenticated.dart';
import '../pages/bednet_distribution/bednet_distribution_success.dart';
import '../pages/bednet_distribution/bednet_distribution_wrapper.dart';
import '../pages/bednet_distribution/bednet_household_overview_wrapper.dart';
import '../pages/bednet_distribution/bednet_individual_details_wrapper.dart';
import '../pages/bednet_distribution/school_details.dart';
import '../pages/bednet_distribution/select_school.dart';
import '../pages/beneficiary_type_selection.dart';
import '../pages/boundary_selection.dart';
import '../pages/bednet_distribution/bednet_distribution_success.dart';
import '../pages/bednet_distribution/bednet_distribution_wrapper.dart';
import '../pages/bednet_distribution/school_details.dart';
import '../pages/bednet_distribution/select_school.dart';
import '../pages/current_boundary.dart';
import '../pages/home.dart';
import '../pages/language_selection.dart';
import '../pages/login.dart';
import '../pages/non_mobile_user/non_mobile_user_list.dart';
import '../pages/peer_to_peer/data_receiver.dart';
import '../pages/peer_to_peer/data_share_home.dart';
import '../pages/peer_to_peer/data_transfer.dart';
import '../pages/peer_to_peer/devices_list.dart';
import '../pages/peer_to_peer/peer_to_peer_wrapper.dart';
import '../pages/permissions_handler.dart';
import '../pages/profile.dart';
import '../pages/project_facility_selection.dart';
import '../pages/project_selection.dart';
import '../pages/qr_details_page.dart';
import '../pages/registration_deliver_pages/beneficiary/beneficiary_checklist.dart';
import '../pages/registration_deliver_pages/beneficiary/beneficiary_checklist.dart';
import '../pages/registration_deliver_pages/beneficiary/beneficiary_details.dart';
import '../pages/registration_deliver_pages/beneficiary/deliver_intervention.dart';
import '../pages/registration_deliver_pages/beneficiary/delivery_summary_page.dart';
import '../pages/registration_deliver_pages/beneficiary/household_overview.dart';
import '../pages/registration_deliver_pages/beneficiary/refused_delivery.dart';
import '../pages/registration_deliver_pages/beneficiary/widgets/household_acknowledgement.dart';
import '../pages/registration_deliver_pages/beneficiary/widgets/splash_acknowledgement.dart';
import '../pages/registration_deliver_pages/beneficiary_registration/beneficiary_acknowledgement.dart';
import '../pages/registration_deliver_pages/beneficiary_registration/house_details.dart';
import '../pages/registration_deliver_pages/beneficiary_registration/household_details.dart';
import '../pages/registration_deliver_pages/beneficiary_registration/individual_details.dart';
import '../pages/registration_deliver_pages/search_beneficiary.dart';
import '../pages/registration_deliver_pages/summary_page.dart';
import '../pages/reports/beneficiary/beneficaries_report.dart';
import '../pages/reports/summary_report/custom_summary_report.dart';
import '../pages/unauthenticated.dart';
import '../pages/registration_deliver_pages/beneficiary_registration/custom_household_overview.dart';

export 'package:auto_route/auto_route.dart';
import '../pages/beneficiary_type_selection.dart';

part 'app_router.gr.dart';

@AutoRouterConfig(
  modules: [
    DigitScannerPackageRoute,
    DashboardRoute,
    SurveyFormRoute,
    TransitPostRoute,
    FormsRoute,
    FlowBuilderRoute,
  ],
)
class AppRouter extends _$AppRouter {
  @override
  RouteType get defaultRouteType => const RouteType.material();

  @override
  List<AutoRoute> routes = [
    AutoRoute(
      page: UnauthenticatedRouteWrapper.page,
      path: '/',
      children: [
        // AutoRoute(
        //     page: LanguageSelectionRoute.page,
        //     path: 'language_selection',
        //     initial: true),
        AutoRoute(page: LoginRoute.page, path: 'login', initial: true),
        AutoRoute(page: DigitScannerRoute.page, path: 'scanner'),
      ],
    ),
    AutoRoute(
      page: AuthenticatedRouteWrapper.page,
      path: '/',
      children: [
        AutoRoute(
          page: PermissionsRoute.page,
          path: 'permissions-page',
        ),
        AutoRoute(page: HomeRoute.page, path: 'home'),
        AutoRoute(
          page: BeneficiaryTypeSelectionRoute.page,
          path: 'beneficiary-type-selection',
        ),
        AutoRoute(page: ProfileRoute.page, path: 'profile'),
        AutoRoute(page: UserQRDetailsRoute.page, path: 'user-qr-code'),
        AutoRoute(page: DigitScannerRoute.page, path: 'scanner'),
        AutoRoute(
          page: BeneficiariesReportRoute.page,
          path: 'beneficiary-downsync-report',
        ),

        // NonMobile User
        AutoRoute(
          page: NonMobileUserListRoute.page,
          path: 'non-mobile-users',
        ),
        // DSS Dashboard Routes
        AutoRoute(
          page: UserDashboardRoute.page,
          path: 'dashboard',
        ),

        AutoRoute(
          page: BednetDistributionWrapperRoute.page,
          path: 'bednet-distribution',
          children: [
            AutoRoute(
              page: BeneficiaryTypeSelectionRoute.page,
              path: '',
              initial: true,
            ),
            AutoRoute(
              page: SelectSchoolRoute.page,
              path: 'select-school',
            ),
            AutoRoute(
              page: SearchBeneficiaryRoute.page,
              path: 'search-beneficiary',
            ),
            AutoRoute(
              page: BednetHouseholdOverviewWrapperRoute.page,
              path: 'overview',
              children: [
                AutoRoute(
                  page: SchoolDetailsRoute.page,
                  path: 'details',
                ),
                AutoRoute(
                  page: HouseholdOverviewRoute.page,
                  path: '',
                  initial: true,
                ),
                AutoRoute(
                  page: CustomHouseholdOverviewRoute.page,
                  path: 'custom-household-route',
                ),
                AutoRoute(
                  page: BednetIndividualDetailsWrapperRoute.page,
                  path: 'individual-details',
                ),
                AutoRoute(
                  page: BeneficiaryDetailsRoute.page,
                  path: 'beneficiary-details',
                ),
                AutoRoute(
                  page: BeneficiaryChecklistRoute.page,
                  path: 'beneficiary-checklist',
                ),
                AutoRoute(
                  page: DeliverInterventionRoute.page,
                  path: 'deliver-intervention',
                ),
                AutoRoute(
                  page: HouseholdAcknowledgementRoute.page,
                  path: 'household-acknowledgement',
                ),
                AutoRoute(
                  page: BeneficiaryAcknowledgementRoute.page,
                  path: 'beneficiary-acknowledgement',
                ),
                // AutoRoute(
                //   page: DeliverySummaryRoute.page,
                //   path: 'delivery-summary',
                // ),
                // AutoRoute(
                //     page: DoseAdministeredRoute.page,
                //     path: 'dose-administered',
                //   ),
              ],
            ),
            AutoRoute(
              page: BednetDistributionSuccessRoute.page,
              path: 'success',
            ),
          ],
        ),

        AutoRoute(
            page: SurveyFormWrapperRoute.page,
            path: 'surveyForm',
            children: [
              AutoRoute(
                page: SurveyformRoute.page,
                path: '',
              ),
              AutoRoute(
                  page: SurveyFormBoundaryViewRoute.page,
                  path: 'view-boundary'),
              AutoRoute(page: SurveyFormViewRoute.page, path: 'view'),
              AutoRoute(page: SurveyFormPreviewRoute.page, path: 'preview'),
              AutoRoute(
                  page: SurveyFormAcknowledgementRoute.page,
                  path: 'surveyForm-acknowledgement'),
            ]),
        AutoRoute(page: AcknowledgementRoute.page, path: 'acknowledgement'),

        AutoRoute(
          page: ProjectFacilitySelectionRoute.page,
          path: 'select-project-facilities',
        ),



        AutoRoute(
          page: CustomSummaryReportRoute.page,
          path: 'custom-report-summary',
        ),

        /// Project Selection
        AutoRoute(
          page: ProjectSelectionRoute.page,
          path: 'select-project',
          initial: true,
        ),

        /// Boundary Selection
        AutoRoute(
          page: BoundarySelectionRoute.page,
          path: 'select-boundary',
        ),
        AutoRoute(
          page: CurrentBoundaryRoute.page,
          path: 'current-boundary',
        ),

        // // Attendance Route
        // ...AttendanceRoute().routes,

        // Forms Route
        ...FormsRoute().routes,
        AutoRoute(page: FlowBuilderHomeRoute.page, path: 'dynamic/:pageName'),

        ...TransitPostRoute().routes,
        AutoRoute(
          page: DataShareHomeRoute.page,
          path: 'data-share-home',
        ),
        AutoRoute(
            page: PeerToPeerWrapperRoute.page,
            path: 'peer-to-peer-wrapper',
            children: [
              AutoRoute(
                  page: DevicesListRoute.page,
                  path: 'devices-list',
                  initial: true),
              AutoRoute(page: DataTransferRoute.page, path: 'data-transfer'),
              AutoRoute(page: DataReceiverRoute.page, path: 'data-receiver'),
            ]),
      ],
    )
  ];
}
