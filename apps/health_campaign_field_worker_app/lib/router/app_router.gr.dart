// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

abstract class _$AppRouter extends RootStackRouter {
  // ignore: unused_element
  _$AppRouter({super.navigatorKey});

  @override
  final Map<String, PageFactory> pagesMap = {
    AcknowledgementRoute.name: (routeData) {
      final args = routeData.argsAs<AcknowledgementRouteArgs>(
          orElse: () => const AcknowledgementRouteArgs());
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: AcknowledgementPage(
          key: args.key,
          appLocalizations: args.appLocalizations,
          isDataRecordSuccess: args.isDataRecordSuccess,
          label: args.label,
          description: args.description,
          descriptionTableData: args.descriptionTableData,
        ),
      );
    },
    AttendanceDigitScannerRoute.name: (routeData) {
      final args = routeData.argsAs<AttendanceDigitScannerRouteArgs>();
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: AttendanceDigitScannerPage(
          key: args.key,
          enableDynamicQRScanning: args.enableDynamicQRScanning,
          attendees: args.attendees,
          onScanResult: args.onScanResult,
          quantity: args.quantity,
          singleValue: args.singleValue,
          isGS1code: args.isGS1code,
        ),
      );
    },
    AuthenticatedRouteWrapper.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const AuthenticatedPageWrapper(),
      );
    },
    BednetDistributionAcknowledgementRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const BednetDistributionAcknowledgementPage(),
      );
    },
    BednetDistributionSuccessRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const BednetDistributionSuccessPage(),
      );
    },
    BednetDistributionWrapperRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: WrappedRoute(child: const BednetDistributionWrapperPage()),
      );
    },
    BeneficiariesReportRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const BeneficiariesReportPage(),
      );
    },
    BeneficiaryAcknowledgementRoute.name: (routeData) {
      final args = routeData.argsAs<BeneficiaryAcknowledgementRouteArgs>(
          orElse: () => const BeneficiaryAcknowledgementRouteArgs());
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: BeneficiaryAcknowledgementPage(
          key: args.key,
          appLocalizations: args.appLocalizations,
          enableViewHousehold: args.enableViewHousehold,
        ),
      );
    },
    BoundarySelectionRoute.name: (routeData) {
      final args = routeData.argsAs<BoundarySelectionRouteArgs>(
          orElse: () => const BoundarySelectionRouteArgs());
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: BoundarySelectionPage(
          key: args.key,
          appLocalizations: args.appLocalizations,
        ),
      );
    },
    ClassConfirmationRoute.name: (routeData) {
      final args = routeData.argsAs<ClassConfirmationRouteArgs>();
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: ClassConfirmationPage(
          key: args.key,
          classIndex: args.classIndex,
          totalClasses: args.totalClasses,
        ),
      );
    },
    ClassDetailsRoute.name: (routeData) {
      final args = routeData.argsAs<ClassDetailsRouteArgs>();
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: ClassDetailsPage(
          key: args.key,
          classIndex: args.classIndex,
          totalClasses: args.totalClasses,
        ),
      );
    },
    ClassTeacherInfoRoute.name: (routeData) {
      final args = routeData.argsAs<ClassTeacherInfoRouteArgs>();
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: ClassTeacherInfoPage(
          key: args.key,
          classIndex: args.classIndex,
          totalClasses: args.totalClasses,
        ),
      );
    },
    CustomSummaryReportRoute.name: (routeData) {
      final args = routeData.argsAs<CustomSummaryReportRouteArgs>(
          orElse: () => const CustomSummaryReportRouteArgs());
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: CustomSummaryReportPage(
          key: args.key,
          appLocalizations: args.appLocalizations,
        ),
      );
    },
    CurrentBoundaryRoute.name: (routeData) {
      final args = routeData.argsAs<CurrentBoundaryRouteArgs>(
          orElse: () => const CurrentBoundaryRouteArgs());
      return AutoRoutePage<BoundaryModel>(
        routeData: routeData,
        child: CurrentBoundaryPage(
          key: args.key,
          appLocalizations: args.appLocalizations,
          onBoundarySelected: args.onBoundarySelected,
        ),
      );
    },
    DataReceiverRoute.name: (routeData) {
      final args = routeData.argsAs<DataReceiverRouteArgs>();
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: DataReceiverPage(
          key: args.key,
          connectedDevice: args.connectedDevice,
          nearbyService: args.nearbyService,
        ),
      );
    },
    DataShareHomeRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const DataShareHomePage(),
      );
    },
    DataTransferRoute.name: (routeData) {
      final args = routeData.argsAs<DataTransferRouteArgs>();
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: DataTransferPage(
          key: args.key,
          nearbyService: args.nearbyService,
          connectedDevices: args.connectedDevices,
        ),
      );
    },
    DevicesListRoute.name: (routeData) {
      final args = routeData.argsAs<DevicesListRouteArgs>();
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: DevicesListPage(
          key: args.key,
          deviceType: args.deviceType,
        ),
      );
    },
    DistributionSummaryRoute.name: (routeData) {
      final args = routeData.argsAs<DistributionSummaryRouteArgs>();
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: DistributionSummaryPage(
          key: args.key,
          classIndex: args.classIndex,
          totalClasses: args.totalClasses,
        ),
      );
    },
    HomeRoute.name: (routeData) {
      final args =
          routeData.argsAs<HomeRouteArgs>(orElse: () => const HomeRouteArgs());
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: HomePage(
          key: args.key,
          appLocalizations: args.appLocalizations,
        ),
      );
    },
    LanguageSelectionRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const LanguageSelectionPage(),
      );
    },
    LoginRoute.name: (routeData) {
      final args = routeData.argsAs<LoginRouteArgs>(
          orElse: () => const LoginRouteArgs());
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: LoginPage(
          key: args.key,
          appLocalizations: args.appLocalizations,
        ),
      );
    },
    NonMobileUserListRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const NonMobileUserListPage(),
      );
    },
    PeerToPeerWrapperRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: WrappedRoute(child: const PeerToPeerWrapperPage()),
      );
    },
    PermissionsRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const PermissionsPage(),
      );
    },
    ProfileRoute.name: (routeData) {
      final args = routeData.argsAs<ProfileRouteArgs>(
          orElse: () => const ProfileRouteArgs());
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: ProfilePage(
          key: args.key,
          appLocalizations: args.appLocalizations,
        ),
      );
    },
    ProjectFacilitySelectionRoute.name: (routeData) {
      final args = routeData.argsAs<ProjectFacilitySelectionRouteArgs>();
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: ProjectFacilitySelectionPage(
          key: args.key,
          projectFacilities: args.projectFacilities,
        ),
      );
    },
    ProjectSelectionRoute.name: (routeData) {
      final args = routeData.argsAs<ProjectSelectionRouteArgs>(
          orElse: () => const ProjectSelectionRouteArgs());
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: ProjectSelectionPage(
          key: args.key,
          appLocalizations: args.appLocalizations,
        ),
      );
    },
    SchoolDetailsRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const SchoolDetailsPage(),
      );
    },
    SelectSchoolRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const SelectSchoolPage(),
      );
    },
    UnauthenticatedRouteWrapper.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const UnauthenticatedPageWrapper(),
      );
    },
    UserQRDetailsRoute.name: (routeData) {
      final args = routeData.argsAs<UserQRDetailsRouteArgs>(
          orElse: () => const UserQRDetailsRouteArgs());
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: UserQRDetailsPage(
          key: args.key,
          appLocalizations: args.appLocalizations,
        ),
      );
    },
    ...AttendanceRoute().pagesMap,
    ...DigitScannerPackageRoute().pagesMap,
    ...DashboardRoute().pagesMap,
    ...SurveyFormRoute().pagesMap,
    ...TransitPostRoute().pagesMap,
    ...FormsRoute().pagesMap,
    ...FlowBuilderRoute().pagesMap,
  };
}

/// generated route for
/// [AcknowledgementPage]
class AcknowledgementRoute extends PageRouteInfo<AcknowledgementRouteArgs> {
  AcknowledgementRoute({
    Key? key,
    AppLocalizations? appLocalizations,
    bool isDataRecordSuccess = false,
    String? label,
    String? description,
    Map<String, dynamic>? descriptionTableData,
    List<PageRouteInfo>? children,
  }) : super(
          AcknowledgementRoute.name,
          args: AcknowledgementRouteArgs(
            key: key,
            appLocalizations: appLocalizations,
            isDataRecordSuccess: isDataRecordSuccess,
            label: label,
            description: description,
            descriptionTableData: descriptionTableData,
          ),
          initialChildren: children,
        );

  static const String name = 'AcknowledgementRoute';

  static const PageInfo<AcknowledgementRouteArgs> page =
      PageInfo<AcknowledgementRouteArgs>(name);
}

class AcknowledgementRouteArgs {
  const AcknowledgementRouteArgs({
    this.key,
    this.appLocalizations,
    this.isDataRecordSuccess = false,
    this.label,
    this.description,
    this.descriptionTableData,
  });

  final Key? key;

  final AppLocalizations? appLocalizations;

  final bool isDataRecordSuccess;

  final String? label;

  final String? description;

  final Map<String, dynamic>? descriptionTableData;

  @override
  String toString() {
    return 'AcknowledgementRouteArgs{key: $key, appLocalizations: $appLocalizations, isDataRecordSuccess: $isDataRecordSuccess, label: $label, description: $description, descriptionTableData: $descriptionTableData}';
  }
}

/// generated route for
/// [AttendanceDigitScannerPage]
class AttendanceDigitScannerRoute
    extends PageRouteInfo<AttendanceDigitScannerRouteArgs> {
  AttendanceDigitScannerRoute({
    Key? key,
    required bool enableDynamicQRScanning,
    required List<AttendeeModel> attendees,
    required void Function(
      ScannedIndividualDataModel,
      AttendanceValidationResult,
    ) onScanResult,
    required int quantity,
    bool singleValue = false,
    required bool isGS1code,
    List<PageRouteInfo>? children,
  }) : super(
          AttendanceDigitScannerRoute.name,
          args: AttendanceDigitScannerRouteArgs(
            key: key,
            enableDynamicQRScanning: enableDynamicQRScanning,
            attendees: attendees,
            onScanResult: onScanResult,
            quantity: quantity,
            singleValue: singleValue,
            isGS1code: isGS1code,
          ),
          initialChildren: children,
        );

  static const String name = 'AttendanceDigitScannerRoute';

  static const PageInfo<AttendanceDigitScannerRouteArgs> page =
      PageInfo<AttendanceDigitScannerRouteArgs>(name);
}

class AttendanceDigitScannerRouteArgs {
  const AttendanceDigitScannerRouteArgs({
    this.key,
    required this.enableDynamicQRScanning,
    required this.attendees,
    required this.onScanResult,
    required this.quantity,
    this.singleValue = false,
    required this.isGS1code,
  });

  final Key? key;

  final bool enableDynamicQRScanning;

  final List<AttendeeModel> attendees;

  final void Function(
    ScannedIndividualDataModel,
    AttendanceValidationResult,
  ) onScanResult;

  final int quantity;

  final bool singleValue;

  final bool isGS1code;

  @override
  String toString() {
    return 'AttendanceDigitScannerRouteArgs{key: $key, enableDynamicQRScanning: $enableDynamicQRScanning, attendees: $attendees, onScanResult: $onScanResult, quantity: $quantity, singleValue: $singleValue, isGS1code: $isGS1code}';
  }
}

/// generated route for
/// [AuthenticatedPageWrapper]
class AuthenticatedRouteWrapper extends PageRouteInfo<void> {
  const AuthenticatedRouteWrapper({List<PageRouteInfo>? children})
      : super(
          AuthenticatedRouteWrapper.name,
          initialChildren: children,
        );

  static const String name = 'AuthenticatedRouteWrapper';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [BednetDistributionAcknowledgementPage]
class BednetDistributionAcknowledgementRoute extends PageRouteInfo<void> {
  const BednetDistributionAcknowledgementRoute({List<PageRouteInfo>? children})
      : super(
          BednetDistributionAcknowledgementRoute.name,
          initialChildren: children,
        );

  static const String name = 'BednetDistributionAcknowledgementRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [BednetDistributionSuccessPage]
class BednetDistributionSuccessRoute extends PageRouteInfo<void> {
  const BednetDistributionSuccessRoute({List<PageRouteInfo>? children})
      : super(
          BednetDistributionSuccessRoute.name,
          initialChildren: children,
        );

  static const String name = 'BednetDistributionSuccessRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [BednetDistributionWrapperPage]
class BednetDistributionWrapperRoute extends PageRouteInfo<void> {
  const BednetDistributionWrapperRoute({List<PageRouteInfo>? children})
      : super(
          BednetDistributionWrapperRoute.name,
          initialChildren: children,
        );

  static const String name = 'BednetDistributionWrapperRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [BeneficiariesReportPage]
class BeneficiariesReportRoute extends PageRouteInfo<void> {
  const BeneficiariesReportRoute({List<PageRouteInfo>? children})
      : super(
          BeneficiariesReportRoute.name,
          initialChildren: children,
        );

  static const String name = 'BeneficiariesReportRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [BeneficiaryAcknowledgementPage]
class BeneficiaryAcknowledgementRoute
    extends PageRouteInfo<BeneficiaryAcknowledgementRouteArgs> {
  BeneficiaryAcknowledgementRoute({
    Key? key,
    AppLocalizations? appLocalizations,
    bool? enableViewHousehold,
    List<PageRouteInfo>? children,
  }) : super(
          BeneficiaryAcknowledgementRoute.name,
          args: BeneficiaryAcknowledgementRouteArgs(
            key: key,
            appLocalizations: appLocalizations,
            enableViewHousehold: enableViewHousehold,
          ),
          initialChildren: children,
        );

  static const String name = 'BeneficiaryAcknowledgementRoute';

  static const PageInfo<BeneficiaryAcknowledgementRouteArgs> page =
      PageInfo<BeneficiaryAcknowledgementRouteArgs>(name);
}

class BeneficiaryAcknowledgementRouteArgs {
  const BeneficiaryAcknowledgementRouteArgs({
    this.key,
    this.appLocalizations,
    this.enableViewHousehold,
  });

  final Key? key;

  final AppLocalizations? appLocalizations;

  final bool? enableViewHousehold;

  @override
  String toString() {
    return 'BeneficiaryAcknowledgementRouteArgs{key: $key, appLocalizations: $appLocalizations, enableViewHousehold: $enableViewHousehold}';
  }
}

/// generated route for
/// [BoundarySelectionPage]
class BoundarySelectionRoute extends PageRouteInfo<BoundarySelectionRouteArgs> {
  BoundarySelectionRoute({
    Key? key,
    AppLocalizations? appLocalizations,
    List<PageRouteInfo>? children,
  }) : super(
          BoundarySelectionRoute.name,
          args: BoundarySelectionRouteArgs(
            key: key,
            appLocalizations: appLocalizations,
          ),
          initialChildren: children,
        );

  static const String name = 'BoundarySelectionRoute';

  static const PageInfo<BoundarySelectionRouteArgs> page =
      PageInfo<BoundarySelectionRouteArgs>(name);
}

class BoundarySelectionRouteArgs {
  const BoundarySelectionRouteArgs({
    this.key,
    this.appLocalizations,
  });

  final Key? key;

  final AppLocalizations? appLocalizations;

  @override
  String toString() {
    return 'BoundarySelectionRouteArgs{key: $key, appLocalizations: $appLocalizations}';
  }
}

/// generated route for
/// [ClassConfirmationPage]
class ClassConfirmationRoute extends PageRouteInfo<ClassConfirmationRouteArgs> {
  ClassConfirmationRoute({
    Key? key,
    required int classIndex,
    required int totalClasses,
    List<PageRouteInfo>? children,
  }) : super(
          ClassConfirmationRoute.name,
          args: ClassConfirmationRouteArgs(
            key: key,
            classIndex: classIndex,
            totalClasses: totalClasses,
          ),
          initialChildren: children,
        );

  static const String name = 'ClassConfirmationRoute';

  static const PageInfo<ClassConfirmationRouteArgs> page =
      PageInfo<ClassConfirmationRouteArgs>(name);
}

class ClassConfirmationRouteArgs {
  const ClassConfirmationRouteArgs({
    this.key,
    required this.classIndex,
    required this.totalClasses,
  });

  final Key? key;

  final int classIndex;

  final int totalClasses;

  @override
  String toString() {
    return 'ClassConfirmationRouteArgs{key: $key, classIndex: $classIndex, totalClasses: $totalClasses}';
  }
}

/// generated route for
/// [ClassDetailsPage]
class ClassDetailsRoute extends PageRouteInfo<ClassDetailsRouteArgs> {
  ClassDetailsRoute({
    Key? key,
    required int classIndex,
    required int totalClasses,
    List<PageRouteInfo>? children,
  }) : super(
          ClassDetailsRoute.name,
          args: ClassDetailsRouteArgs(
            key: key,
            classIndex: classIndex,
            totalClasses: totalClasses,
          ),
          initialChildren: children,
        );

  static const String name = 'ClassDetailsRoute';

  static const PageInfo<ClassDetailsRouteArgs> page =
      PageInfo<ClassDetailsRouteArgs>(name);
}

class ClassDetailsRouteArgs {
  const ClassDetailsRouteArgs({
    this.key,
    required this.classIndex,
    required this.totalClasses,
  });

  final Key? key;

  final int classIndex;

  final int totalClasses;

  @override
  String toString() {
    return 'ClassDetailsRouteArgs{key: $key, classIndex: $classIndex, totalClasses: $totalClasses}';
  }
}

/// generated route for
/// [ClassTeacherInfoPage]
class ClassTeacherInfoRoute extends PageRouteInfo<ClassTeacherInfoRouteArgs> {
  ClassTeacherInfoRoute({
    Key? key,
    required int classIndex,
    required int totalClasses,
    List<PageRouteInfo>? children,
  }) : super(
          ClassTeacherInfoRoute.name,
          args: ClassTeacherInfoRouteArgs(
            key: key,
            classIndex: classIndex,
            totalClasses: totalClasses,
          ),
          initialChildren: children,
        );

  static const String name = 'ClassTeacherInfoRoute';

  static const PageInfo<ClassTeacherInfoRouteArgs> page =
      PageInfo<ClassTeacherInfoRouteArgs>(name);
}

class ClassTeacherInfoRouteArgs {
  const ClassTeacherInfoRouteArgs({
    this.key,
    required this.classIndex,
    required this.totalClasses,
  });

  final Key? key;

  final int classIndex;

  final int totalClasses;

  @override
  String toString() {
    return 'ClassTeacherInfoRouteArgs{key: $key, classIndex: $classIndex, totalClasses: $totalClasses}';
  }
}

/// generated route for
/// [CustomSummaryReportPage]
class CustomSummaryReportRoute
    extends PageRouteInfo<CustomSummaryReportRouteArgs> {
  CustomSummaryReportRoute({
    Key? key,
    AppLocalizations? appLocalizations,
    List<PageRouteInfo>? children,
  }) : super(
          CustomSummaryReportRoute.name,
          args: CustomSummaryReportRouteArgs(
            key: key,
            appLocalizations: appLocalizations,
          ),
          initialChildren: children,
        );

  static const String name = 'CustomSummaryReportRoute';

  static const PageInfo<CustomSummaryReportRouteArgs> page =
      PageInfo<CustomSummaryReportRouteArgs>(name);
}

class CustomSummaryReportRouteArgs {
  const CustomSummaryReportRouteArgs({
    this.key,
    this.appLocalizations,
  });

  final Key? key;

  final AppLocalizations? appLocalizations;

  @override
  String toString() {
    return 'CustomSummaryReportRouteArgs{key: $key, appLocalizations: $appLocalizations}';
  }
}

/// generated route for
/// [CurrentBoundaryPage]
class CurrentBoundaryRoute extends PageRouteInfo<CurrentBoundaryRouteArgs> {
  CurrentBoundaryRoute({
    Key? key,
    AppLocalizations? appLocalizations,
    dynamic Function(BuildContext)? onBoundarySelected,
    List<PageRouteInfo>? children,
  }) : super(
          CurrentBoundaryRoute.name,
          args: CurrentBoundaryRouteArgs(
            key: key,
            appLocalizations: appLocalizations,
            onBoundarySelected: onBoundarySelected,
          ),
          initialChildren: children,
        );

  static const String name = 'CurrentBoundaryRoute';

  static const PageInfo<CurrentBoundaryRouteArgs> page =
      PageInfo<CurrentBoundaryRouteArgs>(name);
}

class CurrentBoundaryRouteArgs {
  const CurrentBoundaryRouteArgs({
    this.key,
    this.appLocalizations,
    this.onBoundarySelected,
  });

  final Key? key;

  final AppLocalizations? appLocalizations;

  final dynamic Function(BuildContext)? onBoundarySelected;

  @override
  String toString() {
    return 'CurrentBoundaryRouteArgs{key: $key, appLocalizations: $appLocalizations, onBoundarySelected: $onBoundarySelected}';
  }
}

/// generated route for
/// [DataReceiverPage]
class DataReceiverRoute extends PageRouteInfo<DataReceiverRouteArgs> {
  DataReceiverRoute({
    Key? key,
    required Device connectedDevice,
    required NearbyService nearbyService,
    List<PageRouteInfo>? children,
  }) : super(
          DataReceiverRoute.name,
          args: DataReceiverRouteArgs(
            key: key,
            connectedDevice: connectedDevice,
            nearbyService: nearbyService,
          ),
          initialChildren: children,
        );

  static const String name = 'DataReceiverRoute';

  static const PageInfo<DataReceiverRouteArgs> page =
      PageInfo<DataReceiverRouteArgs>(name);
}

class DataReceiverRouteArgs {
  const DataReceiverRouteArgs({
    this.key,
    required this.connectedDevice,
    required this.nearbyService,
  });

  final Key? key;

  final Device connectedDevice;

  final NearbyService nearbyService;

  @override
  String toString() {
    return 'DataReceiverRouteArgs{key: $key, connectedDevice: $connectedDevice, nearbyService: $nearbyService}';
  }
}

/// generated route for
/// [DataShareHomePage]
class DataShareHomeRoute extends PageRouteInfo<void> {
  const DataShareHomeRoute({List<PageRouteInfo>? children})
      : super(
          DataShareHomeRoute.name,
          initialChildren: children,
        );

  static const String name = 'DataShareHomeRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [DataTransferPage]
class DataTransferRoute extends PageRouteInfo<DataTransferRouteArgs> {
  DataTransferRoute({
    Key? key,
    required NearbyService nearbyService,
    required List<Device> connectedDevices,
    List<PageRouteInfo>? children,
  }) : super(
          DataTransferRoute.name,
          args: DataTransferRouteArgs(
            key: key,
            nearbyService: nearbyService,
            connectedDevices: connectedDevices,
          ),
          initialChildren: children,
        );

  static const String name = 'DataTransferRoute';

  static const PageInfo<DataTransferRouteArgs> page =
      PageInfo<DataTransferRouteArgs>(name);
}

class DataTransferRouteArgs {
  const DataTransferRouteArgs({
    this.key,
    required this.nearbyService,
    required this.connectedDevices,
  });

  final Key? key;

  final NearbyService nearbyService;

  final List<Device> connectedDevices;

  @override
  String toString() {
    return 'DataTransferRouteArgs{key: $key, nearbyService: $nearbyService, connectedDevices: $connectedDevices}';
  }
}

/// generated route for
/// [DevicesListPage]
class DevicesListRoute extends PageRouteInfo<DevicesListRouteArgs> {
  DevicesListRoute({
    Key? key,
    required DeviceType deviceType,
    List<PageRouteInfo>? children,
  }) : super(
          DevicesListRoute.name,
          args: DevicesListRouteArgs(
            key: key,
            deviceType: deviceType,
          ),
          initialChildren: children,
        );

  static const String name = 'DevicesListRoute';

  static const PageInfo<DevicesListRouteArgs> page =
      PageInfo<DevicesListRouteArgs>(name);
}

class DevicesListRouteArgs {
  const DevicesListRouteArgs({
    this.key,
    required this.deviceType,
  });

  final Key? key;

  final DeviceType deviceType;

  @override
  String toString() {
    return 'DevicesListRouteArgs{key: $key, deviceType: $deviceType}';
  }
}

/// generated route for
/// [DistributionSummaryPage]
class DistributionSummaryRoute
    extends PageRouteInfo<DistributionSummaryRouteArgs> {
  DistributionSummaryRoute({
    Key? key,
    required int classIndex,
    required int totalClasses,
    List<PageRouteInfo>? children,
  }) : super(
          DistributionSummaryRoute.name,
          args: DistributionSummaryRouteArgs(
            key: key,
            classIndex: classIndex,
            totalClasses: totalClasses,
          ),
          initialChildren: children,
        );

  static const String name = 'DistributionSummaryRoute';

  static const PageInfo<DistributionSummaryRouteArgs> page =
      PageInfo<DistributionSummaryRouteArgs>(name);
}

class DistributionSummaryRouteArgs {
  const DistributionSummaryRouteArgs({
    this.key,
    required this.classIndex,
    required this.totalClasses,
  });

  final Key? key;

  final int classIndex;

  final int totalClasses;

  @override
  String toString() {
    return 'DistributionSummaryRouteArgs{key: $key, classIndex: $classIndex, totalClasses: $totalClasses}';
  }
}

/// generated route for
/// [HomePage]
class HomeRoute extends PageRouteInfo<HomeRouteArgs> {
  HomeRoute({
    Key? key,
    AppLocalizations? appLocalizations,
    List<PageRouteInfo>? children,
  }) : super(
          HomeRoute.name,
          args: HomeRouteArgs(
            key: key,
            appLocalizations: appLocalizations,
          ),
          initialChildren: children,
        );

  static const String name = 'HomeRoute';

  static const PageInfo<HomeRouteArgs> page = PageInfo<HomeRouteArgs>(name);
}

class HomeRouteArgs {
  const HomeRouteArgs({
    this.key,
    this.appLocalizations,
  });

  final Key? key;

  final AppLocalizations? appLocalizations;

  @override
  String toString() {
    return 'HomeRouteArgs{key: $key, appLocalizations: $appLocalizations}';
  }
}

/// generated route for
/// [LanguageSelectionPage]
class LanguageSelectionRoute extends PageRouteInfo<void> {
  const LanguageSelectionRoute({List<PageRouteInfo>? children})
      : super(
          LanguageSelectionRoute.name,
          initialChildren: children,
        );

  static const String name = 'LanguageSelectionRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [LoginPage]
class LoginRoute extends PageRouteInfo<LoginRouteArgs> {
  LoginRoute({
    Key? key,
    AppLocalizations? appLocalizations,
    List<PageRouteInfo>? children,
  }) : super(
          LoginRoute.name,
          args: LoginRouteArgs(
            key: key,
            appLocalizations: appLocalizations,
          ),
          initialChildren: children,
        );

  static const String name = 'LoginRoute';

  static const PageInfo<LoginRouteArgs> page = PageInfo<LoginRouteArgs>(name);
}

class LoginRouteArgs {
  const LoginRouteArgs({
    this.key,
    this.appLocalizations,
  });

  final Key? key;

  final AppLocalizations? appLocalizations;

  @override
  String toString() {
    return 'LoginRouteArgs{key: $key, appLocalizations: $appLocalizations}';
  }
}

/// generated route for
/// [NonMobileUserListPage]
class NonMobileUserListRoute extends PageRouteInfo<void> {
  const NonMobileUserListRoute({List<PageRouteInfo>? children})
      : super(
          NonMobileUserListRoute.name,
          initialChildren: children,
        );

  static const String name = 'NonMobileUserListRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [PeerToPeerWrapperPage]
class PeerToPeerWrapperRoute extends PageRouteInfo<void> {
  const PeerToPeerWrapperRoute({List<PageRouteInfo>? children})
      : super(
          PeerToPeerWrapperRoute.name,
          initialChildren: children,
        );

  static const String name = 'PeerToPeerWrapperRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [PermissionsPage]
class PermissionsRoute extends PageRouteInfo<void> {
  const PermissionsRoute({List<PageRouteInfo>? children})
      : super(
          PermissionsRoute.name,
          initialChildren: children,
        );

  static const String name = 'PermissionsRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [ProfilePage]
class ProfileRoute extends PageRouteInfo<ProfileRouteArgs> {
  ProfileRoute({
    Key? key,
    AppLocalizations? appLocalizations,
    List<PageRouteInfo>? children,
  }) : super(
          ProfileRoute.name,
          args: ProfileRouteArgs(
            key: key,
            appLocalizations: appLocalizations,
          ),
          initialChildren: children,
        );

  static const String name = 'ProfileRoute';

  static const PageInfo<ProfileRouteArgs> page =
      PageInfo<ProfileRouteArgs>(name);
}

class ProfileRouteArgs {
  const ProfileRouteArgs({
    this.key,
    this.appLocalizations,
  });

  final Key? key;

  final AppLocalizations? appLocalizations;

  @override
  String toString() {
    return 'ProfileRouteArgs{key: $key, appLocalizations: $appLocalizations}';
  }
}

/// generated route for
/// [ProjectFacilitySelectionPage]
class ProjectFacilitySelectionRoute
    extends PageRouteInfo<ProjectFacilitySelectionRouteArgs> {
  ProjectFacilitySelectionRoute({
    Key? key,
    required List<ProjectFacilityModel> projectFacilities,
    List<PageRouteInfo>? children,
  }) : super(
          ProjectFacilitySelectionRoute.name,
          args: ProjectFacilitySelectionRouteArgs(
            key: key,
            projectFacilities: projectFacilities,
          ),
          initialChildren: children,
        );

  static const String name = 'ProjectFacilitySelectionRoute';

  static const PageInfo<ProjectFacilitySelectionRouteArgs> page =
      PageInfo<ProjectFacilitySelectionRouteArgs>(name);
}

class ProjectFacilitySelectionRouteArgs {
  const ProjectFacilitySelectionRouteArgs({
    this.key,
    required this.projectFacilities,
  });

  final Key? key;

  final List<ProjectFacilityModel> projectFacilities;

  @override
  String toString() {
    return 'ProjectFacilitySelectionRouteArgs{key: $key, projectFacilities: $projectFacilities}';
  }
}

/// generated route for
/// [ProjectSelectionPage]
class ProjectSelectionRoute extends PageRouteInfo<ProjectSelectionRouteArgs> {
  ProjectSelectionRoute({
    Key? key,
    AppLocalizations? appLocalizations,
    List<PageRouteInfo>? children,
  }) : super(
          ProjectSelectionRoute.name,
          args: ProjectSelectionRouteArgs(
            key: key,
            appLocalizations: appLocalizations,
          ),
          initialChildren: children,
        );

  static const String name = 'ProjectSelectionRoute';

  static const PageInfo<ProjectSelectionRouteArgs> page =
      PageInfo<ProjectSelectionRouteArgs>(name);
}

class ProjectSelectionRouteArgs {
  const ProjectSelectionRouteArgs({
    this.key,
    this.appLocalizations,
  });

  final Key? key;

  final AppLocalizations? appLocalizations;

  @override
  String toString() {
    return 'ProjectSelectionRouteArgs{key: $key, appLocalizations: $appLocalizations}';
  }
}

/// generated route for
/// [SchoolDetailsPage]
class SchoolDetailsRoute extends PageRouteInfo<void> {
  const SchoolDetailsRoute({List<PageRouteInfo>? children})
      : super(
          SchoolDetailsRoute.name,
          initialChildren: children,
        );

  static const String name = 'SchoolDetailsRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [SelectSchoolPage]
class SelectSchoolRoute extends PageRouteInfo<void> {
  const SelectSchoolRoute({List<PageRouteInfo>? children})
      : super(
          SelectSchoolRoute.name,
          initialChildren: children,
        );

  static const String name = 'SelectSchoolRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [UnauthenticatedPageWrapper]
class UnauthenticatedRouteWrapper extends PageRouteInfo<void> {
  const UnauthenticatedRouteWrapper({List<PageRouteInfo>? children})
      : super(
          UnauthenticatedRouteWrapper.name,
          initialChildren: children,
        );

  static const String name = 'UnauthenticatedRouteWrapper';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [UserQRDetailsPage]
class UserQRDetailsRoute extends PageRouteInfo<UserQRDetailsRouteArgs> {
  UserQRDetailsRoute({
    Key? key,
    AppLocalizations? appLocalizations,
    List<PageRouteInfo>? children,
  }) : super(
          UserQRDetailsRoute.name,
          args: UserQRDetailsRouteArgs(
            key: key,
            appLocalizations: appLocalizations,
          ),
          initialChildren: children,
        );

  static const String name = 'UserQRDetailsRoute';

  static const PageInfo<UserQRDetailsRouteArgs> page =
      PageInfo<UserQRDetailsRouteArgs>(name);
}

class UserQRDetailsRouteArgs {
  const UserQRDetailsRouteArgs({
    this.key,
    this.appLocalizations,
  });

  final Key? key;

  final AppLocalizations? appLocalizations;

  @override
  String toString() {
    return 'UserQRDetailsRouteArgs{key: $key, appLocalizations: $appLocalizations}';
  }
}
