import 'dart:async';

import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/utils/app_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../data/local_store/secure_store/secure_store.dart';
import '../../data/repositories/remote/auth.dart';
import '../../data/repositories/remote/mdms.dart';
import '../../models/auth/auth_model.dart';
import '../../models/entities/roles_type.dart';
import '../../models/role_actions/role_actions_model.dart';
import '../../utils/environment_config.dart';
import '../../utils/typedefs.dart';
import '../../utils/utils.dart';

// part 'auth.freezed.dart' need to be added to auto generate the files for freezed model
part 'auth.freezed.dart';

typedef AuthEmitter = Emitter<AuthState>;

//Auth Bloc will be used to handle user authentication services
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LocalSecureStore localSecureStore;
  final AuthRepository authRepository;
  final MdmsRepository mdmsRepository;
  final RemoteRepository<IndividualModel, IndividualSearchModel>
      individualRemoteRepository;
  final TaskDataRepository taskRepository;

  AuthBloc({
    required this.authRepository,
    required this.mdmsRepository,
    required this.individualRemoteRepository,
    required this.taskRepository,
    LocalSecureStore? localSecureStore,
  })  : localSecureStore = LocalSecureStore.instance,
        super(const AuthUnauthenticatedState()) {
    on(_onLogin);
    on(_onLogout);
    on(_onAutoLogin);
    on(_onAddProductCounts);
    on(_onDeliveryProductCounts);
  }

  //_onAutoLogin event handles auto-login of the user when the user is already logged in and token is not expired, AuthenticatedWrapper is returned in UI
  FutureOr<void> _onAutoLogin(
    AuthAutoLoginEvent event,
    AuthEmitter emit,
  ) async {
    emit(const AuthLoadingState());

    try {
      final accessToken = await localSecureStore.accessToken;
      final refreshToken = await localSecureStore.refreshToken;
      final userObject = await localSecureStore.userRequestModel;
      final actionsList = await localSecureStore.savedActions;
      final userIndividualId = await localSecureStore.userIndividualId;
      final bednet = await localSecureStore.bednet;
      if (accessToken == null ||
          refreshToken == null ||
          userObject == null ||
          actionsList == null) {
        emit(const AuthUnauthenticatedState());
      } else {
        emit(AuthAuthenticatedState(
          accessToken: accessToken,
          refreshToken: refreshToken,
          userModel: userObject,
          individualId: userIndividualId,
          actionsWrapper: actionsList,
          bednetCount: bednet,
        ));
      }
    } catch (_) {
      emit(const AuthUnauthenticatedState());
      rethrow;
    }
  }

  //_onLogin event handles login of the user
  // Here we set the authToken and loggedIn user details in local storage and allow the user to perform actions
  FutureOr<void> _onLogin(AuthLoginEvent event, AuthEmitter emit) async {
    emit(const AuthLoadingState());

    try {
      final AuthModel result = await authRepository.fetchAuthToken(
        loginModel: LoginModel(
          username: event.userId,
          password: event.password,
          tenantId: event.tenantId,
        ),
      );
      await localSecureStore.setAuthCredentials(result);
      await localSecureStore.setBoundaryRefetch(true);

      final actionsWrapper = await mdmsRepository
          .searchRoleActions(envConfig.variables.actionMapApiPath, {
        "roleCodes": result.userRequestModel.roles.map((e) => e.code).toList(),
        "tenantId": envConfig.variables.tenantId,
        "actionMaster": "actions-test",
        "enabled": true,
      });

      await localSecureStore.setBoundaryRefetch(true);
      final bednet = await localSecureStore.bednet;

      await localSecureStore.setRoleActions(actionsWrapper);
      if (result.userRequestModel.roles
          .where((role) =>
              role.code == RolesType.districtSupervisor.toValue() ||
              role.code ==
                  RolesType.distributor
                      .toValue()) // NOTE: Savings distributor user details for fetching non mobile users
          .toList()
          .isNotEmpty) {
        final loggedInIndividual = await individualRemoteRepository.search(
          IndividualSearchModel(
            userUuid: [result.userRequestModel.uuid],
          ),
        );
        await localSecureStore
            .setSelectedIndividual(loggedInIndividual.firstOrNull?.id);
      }

      emit(
        AuthAuthenticatedState(
          accessToken: result.accessToken,
          refreshToken: result.refreshToken,
          userModel: result.userRequestModel,
          actionsWrapper: actionsWrapper,
          individualId: await localSecureStore.userIndividualId,
          bednetCount: bednet,
        ),
      );
    } on DioException catch (error) {
      emit(const AuthErrorState());
      emit(const AuthUnauthenticatedState());

      AppLogger.instance.error(
        title: 'Login error',
        message: error.response?.data.toString(),
      );
    } catch (_) {
      emit(const AuthErrorState());
      emit(const AuthUnauthenticatedState());
      rethrow;
    }
  }

  //_onLogout event logs out the user and deletes the saved user details from local storage
  FutureOr<void> _onLogout(AuthLogoutEvent event, AuthEmitter emit) async {
    try {
      emit(const AuthLoadingState());
      await localSecureStore.deleteAll();
      await localSecureStore.setBoundaryRefetch(true);
    } catch (error) {
      rethrow;
    }
    emit(const AuthUnauthenticatedState());
  }

  FutureOr<void> _onAddProductCounts(
    AuthAddProductCountsEvent event,
    AuthEmitter emit,
  ) async {
    // emit(const AuthLoadingState());

    try {
      int bednet = await localSecureStore.bednet;

      int additionBednetCount = event.bednetCount ?? 0;

      bednet = bednet + additionBednetCount;

      RegistrationDeliverySingleton().setStockCount(bednet);
      localSecureStore.setSpaqCounts(bednet);

      final accessToken = await localSecureStore.accessToken;
      final refreshToken = await localSecureStore.refreshToken;
      final userObject = await localSecureStore.userRequestModel;
      final actionsList = await localSecureStore.savedActions;
      final userIndividualId = await localSecureStore.userIndividualId;

      if (accessToken == null ||
          refreshToken == null ||
          userObject == null ||
          actionsList == null) {
        emit(const AuthUnauthenticatedState());
      } else {
        emit(AuthAuthenticatedState(
          accessToken: accessToken,
          refreshToken: refreshToken,
          userModel: userObject,
          individualId: userIndividualId,
          actionsWrapper: actionsList,
          bednetCount: bednet,
        ));
      }
    } catch (_) {
      await localSecureStore.deleteAll();
      emit(const AuthUnauthenticatedState());
      rethrow;
    }
  }

  FutureOr<void> _onDeliveryProductCounts(
    AuthDeliveryProductCountsEvent event,
    AuthEmitter emit,
  ) async {
    // emit(const AuthLoadingState());

    List<TaskModel> taskList = await taskRepository
        .search(TaskSearchModel(clientReferenceId: [event.clientReferenceId]));
    int bednetCount = 0;
    if (taskList.isNotEmpty) {
      bednetCount = _resourceDistributed(taskList.first.resources);
    }

    try {
      int bednet = await localSecureStore.bednet;

      bednet = bednet - bednetCount;

      localSecureStore.setSpaqCounts(bednet);
      RegistrationDeliverySingleton().setStockCount(bednet);

      final accessToken = await localSecureStore.accessToken;
      final refreshToken = await localSecureStore.refreshToken;
      final userObject = await localSecureStore.userRequestModel;
      final actionsList = await localSecureStore.savedActions;
      final userIndividualId = await localSecureStore.userIndividualId;

      if (accessToken == null ||
          refreshToken == null ||
          userObject == null ||
          actionsList == null) {
        emit(const AuthUnauthenticatedState());
      } else {
        emit(AuthAuthenticatedState(
          accessToken: accessToken,
          refreshToken: refreshToken,
          userModel: userObject,
          individualId: userIndividualId,
          actionsWrapper: actionsList,
          bednetCount: bednet,
        ));
      }
    } catch (_) {
      await localSecureStore.deleteAll();
      emit(const AuthUnauthenticatedState());
      rethrow;
    }
  }

  int _resourceDistributed(List<TaskResourceModel>? taskResources) {
    int resourceDistributed = 0;
    RegExp intPattern = RegExp(r'^\d+$');
    RegExp doublePattern = RegExp(r'^\d+\.\d+$');
    if (taskResources != null) {
      for (var resource in taskResources) {
        // Info quantity is string type as per model
        String quantity = resource.quantity ?? "0";
        try {
          if (intPattern.hasMatch(quantity)) {
            resourceDistributed = resourceDistributed + int.parse(quantity);
          } else if (doublePattern.hasMatch(quantity)) {
            //info will round the decimal and convert to int
            double parsedQuantity = double.parse(quantity);
            if (parsedQuantity.isNaN ||
                parsedQuantity.isInfinite ||
                parsedQuantity.isNegative) {
              continue;
            } else {
              int correctedQuantity = parsedQuantity.ceil();
              resourceDistributed = resourceDistributed + correctedQuantity;
            }
          } else {
            continue;
          }
        } catch (e) {
          continue;
        }
      }
    }
    return resourceDistributed;
  }
}

@freezed
class AuthEvent with _$AuthEvent {
  const factory AuthEvent.login({
    required String userId,
    required String password,
    required String tenantId,
  }) = AuthLoginEvent;

  const factory AuthEvent.addProductCounts({
    int? bednetCount,
  }) = AuthAddProductCountsEvent;

  const factory AuthEvent.autoLogin({
    required String tenantId,
  }) = AuthAutoLoginEvent;

  const factory AuthEvent.deliveryProductCounts({
    required String clientReferenceId,
  }) = AuthDeliveryProductCountsEvent;

  const factory AuthEvent.logout() = AuthLogoutEvent;
}

@freezed
class AuthState with _$AuthState {
  const factory AuthState.unauthenticated() = AuthUnauthenticatedState;

  const factory AuthState.loading() = AuthLoadingState;

  const factory AuthState.authenticated({
    required String accessToken,
    required String refreshToken,
    required UserRequestModel userModel,
    required RoleActionsWrapperModel actionsWrapper,
    String? individualId,
    final int? bednetCount,
  }) = AuthAuthenticatedState;

  const factory AuthState.error([String? error]) = AuthErrorState;
}
