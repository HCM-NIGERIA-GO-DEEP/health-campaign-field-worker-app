part of 'extensions.dart';

extension ContextUtilityExtensions on BuildContext {
  int millisecondsSinceEpoch([DateTime? dateTime]) {
    return (dateTime ?? DateTime.now()).millisecondsSinceEpoch;
  }

  Future<String> get packageInfo async {
    final info = await PackageInfo.fromPlatform();

    return info.version;
  }

  ProjectModel get selectedProject {
    final projectBloc = _get<ProjectBloc>();

    final projectState = projectBloc.state;
    final selectedProject = projectState.selectedProject;

    if (selectedProject == null) {
      throw AppException('No project is selected');
    }

    return selectedProject;
  }

  String get projectId => selectedProject.id;

  String? get projectTypeCode {
    final projectType = selectedProject.projectType;

    if (projectType == null) {
      return "";
    }

    return projectType;
  }

  ProjectCycle? get selectedCycle {
    final projectBloc = _get<ProjectBloc>();

    final projectState = projectBloc.state;
    final selectedCycle =
        projectState.selectedProject?.additionalDetails?.projectType?.cycles
            ?.where(
              (e) =>
                  (e.startDate) < DateTime.now().millisecondsSinceEpoch &&
                  (e.endDate) > DateTime.now().millisecondsSinceEpoch,
            )
            .firstOrNull;

    return selectedCycle;
  }

  ProjectTypeModel? get selectedProjectType {
    final projectBloc = _get<ProjectBloc>();

    final projectState = projectBloc.state;
    final projectType =
        projectState.selectedProject?.additionalDetails?.projectType;

    return projectType;
  }

  ProjectTypeModel? get vasProjectType {
    return ProjectTypeModel(
      id: 'ba15b5df-9333-425c-b2ee-d4719e723fd4',
      code: 'VAS',
      name: 'Configuration for Multi Round Campaigns',
      group: 'MALARIA',
      beneficiaryType: BeneficiaryType.individual,
      validMaxAge: 60,
      validMinAge: 3,
      cycles: [
        ProjectCycle(
          id: 1,
          startDate: 1781202600000,
          endDate: 1783276199000,
          deliveries: [
            ProjectCycleDelivery(
              id: 1,
              deliveryStrategy: 'VAS',
              doseCriteria: [
                DeliveryDoseCriteria(
                  condition: '6<=ageandage<=11',
                  productVariants: [
                    DeliveryProductVariant(
                      quantity: 1,
                      productVariantId: 'PVAR-2025-05-22-000009',
                      name: 'Blue VAS',
                    ),
                  ],
                ),
                DeliveryDoseCriteria(
                  condition: '12<=ageandage<=59',
                  productVariants: [
                    DeliveryProductVariant(
                      quantity: 1,
                      productVariantId: 'PVAR-2025-05-22-000010',
                      name: 'Red VAS',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
      resources: [
        ProjectProductVariantModel(
          productVariantId: 'PVAR-2025-05-22-000009',
          name: 'Blue VAS',
          isBaseUnitVariant: false,
        ),
        ProjectProductVariantModel(
          productVariantId: 'PVAR-2025-05-22-000010',
          name: 'Red VAS',
          isBaseUnitVariant: true,
        ),
      ],
    );
  }

  List<String> get cycles {
    final projectBloc = _get<ProjectBloc>();

    final projectState = projectBloc.state;
    var projectCycles =
        projectState.selectedProject?.additionalDetails?.projectType?.cycles;

    if (projectCycles != null && (projectCycles.isNotEmpty)) {
      List<String> resultList = [];

      for (int i = 1; i <= (projectCycles.length); i++) {
        resultList.add('0${i.toString()}');
      }

      return resultList;
    } else {
      return [];
    }
  }

  BeneficiaryType get beneficiaryType {
    final projectBloc = _get<ProjectBloc>();

    final projectState = projectBloc.state;

    final BeneficiaryType? selectedBeneficiary = projectState
        .selectedProject?.additionalDetails?.projectType?.beneficiaryType;

    if (selectedBeneficiary == null) {
      throw AppException('No beneficiary type is selected');
    }

    return selectedBeneficiary;
  }

  BoundaryModel get boundary {
    final boundaryBloc = _get<BoundaryBloc>();
    final boundaryState = boundaryBloc.state;

    final selectedBoundary = boundaryState.selectedBoundaryMap.entries
        .where((element) => element.value != null)
        .lastOrNull
        ?.value;

    if (selectedBoundary == null) {
      throw AppException('No boundary is selected');
    }
    // INFO: Set Boundary for packages
    SurveyFormSingleton().setBoundary(boundary: selectedBoundary);
    AttendanceSingleton().setBoundary(boundary: selectedBoundary);
    TransitPostSingleton().setBoundary(boundary: selectedBoundary);
    LocationTrackerSingleton()
        .setBoundaryName(boundaryName: selectedBoundary.code!);
    FlowBuilderSingleton().setBoundary(boundary: selectedBoundary);
    return selectedBoundary;
  }

  void setBoundary(BoundaryModel selectedBoundary) {
    SurveyFormSingleton().setBoundary(boundary: selectedBoundary);
    AttendanceSingleton().setBoundary(boundary: selectedBoundary);
    TransitPostSingleton().setBoundary(boundary: selectedBoundary);
    LocationTrackerSingleton()
        .setBoundaryName(boundaryName: selectedBoundary.code!);
    FlowBuilderSingleton().setBoundary(boundary: selectedBoundary);
  }

  BoundaryModel? get boundaryOrNull {
    try {
      return boundary;
    } catch (_) {
      return null;
    }
  }

  List<UserRoleModel> get loggedInUserRoles {
    final authBloc = _get<AuthBloc>();
    final userRequestObject = authBloc.state.whenOrNull(
      authenticated:
          (accessToken, refreshToken, userModel, actionsWrapper, individualId) {
        return userModel.roles;
      },
    );

    if (userRequestObject == null) {
      throw AppException('User not authenticated');
    }

    return userRequestObject;
  }

  String? get loggedInIndividualId {
    final authBloc = _get<AuthBloc>();
    final individualUUID = authBloc.state.whenOrNull(
      authenticated:
          (accessToken, refreshToken, userModel, actionsWrapper, individualId) {
        return individualId;
      },
    );

    if (individualUUID == null) {
      return null;
    }

    return individualUUID;
  }

  int? get currentCycleIndex => selectedCycle?.id;

  String? get currentRegisteredToken {
    final authBloc = _get<PushNotificationBloc>();
    final fcmToken = authBloc.state.whenOrNull(
      initialized: (fcmToken) {
        return fcmToken;
      },
    );

    if (fcmToken == null) {
      return null;
    }

    return fcmToken;
  }

  UserModel? get loggedInUserModel {
    final userRequestModel = loggedInUser;
    final userModel = UserModel(
      userName: userRequestModel.userName,
      name: userRequestModel.name,
      uuid: userRequestModel.uuid,
      mobileNumber: userRequestModel.mobileNumber,
      gender: userRequestModel.gender,
      active: userRequestModel.active,
      tenantId: userRequestModel.tenantId,
    );

    return userModel;
  }

  String get loggedInUserUuid => loggedInUser.uuid;

  UserRequestModel get loggedInUser {
    final authBloc = _get<AuthBloc>();
    final userRequestObject = authBloc.state.whenOrNull(
      authenticated:
          (accessToken, refreshToken, userModel, actions, individualId) {
        return userModel;
      },
    );

    if (userRequestObject == null) {
      throw AppException('User not authenticated');
    }

    return userRequestObject;
  }

  bool get showProgressBar {
    UserRequestModel loggedInUser;

    try {
      loggedInUser = this.loggedInUser;
    } catch (_) {
      return false;
    }

    for (final role in loggedInUser.roles) {
      switch (role.code) {
        case "REGISTRAR":
        case "DISTRIBUTOR":
          return true;
        default:
          break;
      }
    }

    return false;
  }

  bool get isWarehouseManager {
    try {
      bool isWarehouseManager = loggedInUserRoles
          .where((role) => role.code == RolesType.warehouseManager.toValue())
          .toList()
          .isNotEmpty;

      return isWarehouseManager;
    } catch (_) {
      return false;
    }
  }

  bool get isHealthFacilitySupervisor {
    try {
      // todo : verify this make this healthFacilitySupervsior as per kebbi
      bool isDownSyncEnabled = loggedInUserRoles
          .where(
            (role) =>
                role.code == RolesType.healthFacilityWorker.toValue() ||
                role.code == RolesType.healthFacilitySupervisor.toValue(),
          )
          .toList()
          .isNotEmpty;

      return isDownSyncEnabled;
    } catch (_) {
      return false;
    }
  }

  NetworkManager get networkManager => read<NetworkManager>();

  DataRepository<D, R>
      repository<D extends EntityModel, R extends EntitySearchModel>() =>
          networkManager.repository<D, R>(this);

  T _get<T extends BlocBase>() {
    try {
      final bloc = read<T>();

      return bloc;
    } on ProviderNotFoundException catch (_) {
      throw AppException(
        '${T.runtimeType} not found in the current context',
      );
    } catch (error) {
      throw AppException('Could not fetch ${T.runtimeType}');
    }
  }

  // sync refresh
  void syncRefresh() {
    final syncBloc = _get<SyncBloc>();
    syncBloc.add(SyncRefreshEvent(loggedInUserUuid));
  }

  // insert sync count
  Stream<SyncState> syncCount() {
    final syncBloc = _get<SyncBloc>();
    return syncBloc.stream;
  }
}
