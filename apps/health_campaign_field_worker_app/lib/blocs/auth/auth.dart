import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/user_action.dart';
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
import '../../services/device_id_service.dart';
import '../../utils/constants.dart';
import '../../utils/environment_config.dart';
import '../../utils/session/login_rejection.dart';
import '../../utils/session/logout_payload.dart';

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

  AuthBloc({
    required this.authRepository,
    required this.mdmsRepository,
    required this.individualRemoteRepository,
    LocalSecureStore? localSecureStore,
  })  : localSecureStore = localSecureStore ?? LocalSecureStore.instance,
        super(const AuthUnauthenticatedState()) {
    on(_onLogin);
    // Logouts run one at a time, never dropped: a dropped event would leave
    // its caller's [AuthLogoutEvent.result] waiting forever. A second logout
    // queued behind a successful one finds no stored token and clears the
    // local session again without a backend call; behind a failed one it is
    // a legitimate retry.
    on<AuthLogoutEvent>(_onLogout, transformer: sequential());
    on(_onAutoLogin);
    on(_onCheckOtherDeviceLogin);
    on(_onDeviceSwitch);
    on(_onDeviceSwitchUserAction);
    on(_onReset);
    on(_onAllow);
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
      final deviceId = await DeviceIdService.getDeviceId();
      final AuthModel result = await authRepository.fetchAuthToken(
        loginModel: LoginModel(
          username: event.userId,
          password: event.password,
          tenantId: event.tenantId,
          deviceId: deviceId,
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
        ),
      );
    } on DioException catch (error) {
      // Only the single-active-session rejection gets a distinct message;
      // every other failure keeps the localized "unable to login" toast.
      emit(AuthErrorState(
        isActiveSessionRejection(error.response?.data)
            ? activeSessionExistsCode
            : null,
      ));
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

  //_onLogout event closes the backend session, then deletes the saved user
  // details from local storage. Callers have already confirmed connectivity
  // (performAppLogout → ensureOnlineOrAlert); if the backend still cannot be
  // reached, the local session is left untouched so the user can retry, and
  // the caller learns the result through [AuthLogoutEvent.result]. No state
  // is emitted on failure: any non-authenticated state would flip the app
  // router to the login route (app.dart, routes: maybeWhen orElse).
  FutureOr<void> _onLogout(AuthLogoutEvent event, AuthEmitter emit) async {
    final outcome = await _logoutOnServer();
    if (outcome == LogoutServerOutcome.failed) {
      event.result?.complete(false);
      return;
    }

    try {
      try {
        await localSecureStore.deleteAll();
        await localSecureStore.setBoundaryRefetch(true);
      } catch (error) {
        // The server session is already closed; leaving the user on the
        // authenticated route with a dead token and a half-wiped store is
        // the one outcome that must not happen, so sign out regardless.
        AppLogger.instance.error(
          title: 'Logout local clear error',
          message: '$error',
        );
      }
      emit(const AuthUnauthenticatedState());
    } finally {
      // Never leave the caller waiting.
      event.result?.complete(true);
    }
  }

  /// Never throws — the outcome decides what happens to the local session.
  Future<LogoutServerOutcome> _logoutOnServer() async {
    try {
      final accessToken = await localSecureStore.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        AppLogger.instance.error(
          title: 'Logout',
          message: 'No access token stored; clearing the local session only',
        );
        return LogoutServerOutcome.sessionAlreadyInvalid;
      }

      final user = await localSecureStore.userRequestModel;
      await authRepository.logOutUser(
        logoutPath: Constants.logoutUserPath,
        body: buildLogoutPayload(
          accessToken: accessToken,
          userTenantId: user?.tenantId,
          envTenantId: envConfig.variables.tenantId,
        ),
      );
      return LogoutServerOutcome.loggedOut;
    } on DioException catch (error) {
      final outcome = classifyLogoutStatus(error.response?.statusCode);
      AppLogger.instance.error(
        title: 'Logout API error',
        message:
            '${error.response?.statusCode}: ${error.response?.data} → $outcome',
      );
      return outcome;
    } catch (error) {
      AppLogger.instance.error(
        title: 'Logout API error',
        message: '$error',
      );
      return LogoutServerOutcome.failed;
    }
  }

  FutureOr<void> _onReset(AuthResetEvent event, AuthEmitter emit) async {
    await localSecureStore.deleteAll();
    await localSecureStore.setBoundaryRefetch(true);
    emit(const AuthUnauthenticatedState());
  }

  FutureOr<void> _onAllow(AuthAllowEvent event, AuthEmitter emit) async {
    emit(const AuthAllowState());
  }

  FutureOr<void> _onDeviceSwitch(
      AuthSwitchDeviceEventSwitchDevice event, AuthEmitter emit) async {
    try {
      emit(const AuthLoadingState());
      final result = await authRepository.switchDevice(
        endpoint: event.apiEndPoint, // Use the endpoint from the event
        payload: {
          "deviceSwitchReason": event.selectedReason,
          "username": event.username,
          "tenantId": event.tenantId,
          "password": event.password,
          "deviceSwitchComment": event.deviceSwitchComment,
        },
      );

      await localSecureStore.setAuthCredentials(result);
      await localSecureStore.setBoundaryRefetch(true);
      await localSecureStore.setDeviceSwitchReason(
          (event.deviceSwitchComment != null &&
                  event.deviceSwitchComment!.isNotEmpty)
              ? event.deviceSwitchComment!
              : event.selectedReason);

      final actionsWrapper = await mdmsRepository
          .searchRoleActions(envConfig.variables.actionMapApiPath, {
        "roleCodes": result.userRequestModel.roles.map((e) => e.code).toList(),
        "tenantId": envConfig.variables.tenantId,
        "actionMaster": "actions-test",
        "enabled": true,
      });

      await localSecureStore.setBoundaryRefetch(true);

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
        ),
      );
    } on DioException catch (error) {
      emit(const AuthErrorState());
      AppLogger.instance.error(
        title: 'Login error',
        message: error.response?.data.toString(),
      );
    } catch (_) {
      emit(const AuthErrorState());
      rethrow;
    }
  }

  FutureOr<void> _onCheckOtherDeviceLogin(
      AuthCheckOtherDeviceLoginEvent event, AuthEmitter emit) async {
    emit(const AuthLoadingState());
    final deviceToken = await localSecureStore.getDeviceToken(event.username);
    final payload = {
      'username': event.username,
      "tenantId": event.tenantId,
      "deviceToken": deviceToken,
    };

    try {
      final validateResponseModel =
          await authRepository.isLoggedInOnOtherDevice(
        endpoint: event.apiEndPoint, // Use dynamic endpoint from event
        payload: payload,
      );

      if (validateResponseModel.isDuplicateLogin) {
        if (validateResponseModel.existingDeviceToken != null) {
          await localSecureStore.setExistingDeviceToken(
              validateResponseModel.existingDeviceToken!);
        }
        emit(const AuthState.otherDevice());
      } else {
        emit(const AuthState.allow());
      }
    } catch (e) {
      emit(const AuthState.allow());
    }
  }

  FutureOr<void> _onDeviceSwitchUserAction(
      AuthSwitchDeviceUserActionEvent event, AuthEmitter emit) async {
    try {
      await authRepository.switchDeviceUserAction(
        endpoint: event.apiEndPoint, // Use dynamic endpoint from event
        userActionModel: event.userActionModel,
      );

      await localSecureStore.deleteDeviceSwitchReason();
      await localSecureStore.deleteExistingDeviceToken();
    } catch (e) {
      AppLogger.instance.error(
        title: 'User Action error',
        message: '$e',
      );
    }
  }
}

@freezed
class AuthEvent with _$AuthEvent {
  const factory AuthEvent.login({
    required String userId,
    required String password,
    required String tenantId,
  }) = AuthLoginEvent;

  const factory AuthEvent.autoLogin({
    required String tenantId,
  }) = AuthAutoLoginEvent;

  /// [result] completes with true once the local session is cleared (backend
  /// session closed or already invalid) and false when the backend logout
  /// failed and the user stays logged in.
  const factory AuthEvent.logout({Completer<bool>? result}) = AuthLogoutEvent;

  const factory AuthEvent.checkOtherDeviceLogin({
    required String username,
    required String tenantId,
    required String apiEndPoint,
  }) = AuthCheckOtherDeviceLoginEvent;

  const factory AuthEvent.switchDevice({
    required String selectedReason,
    required String? deviceSwitchComment,
    required String username,
    required String password,
    required String tenantId,
    required String apiEndPoint,
  }) = AuthSwitchDeviceEventSwitchDevice;

  const factory AuthEvent.reset() = AuthResetEvent;

  const factory AuthEvent.allow() = AuthAllowEvent;

  const factory AuthEvent.switchDeviceUserAction({
    required UserActionModel userActionModel,
    required String apiEndPoint,
  }) = AuthSwitchDeviceUserActionEvent;
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
  }) = AuthAuthenticatedState;

  const factory AuthState.error([String? error]) = AuthErrorState;

  const factory AuthState.otherDevice() = AuthOtherDeviceState;

  const factory AuthState.allow() = AuthAllowState;
}
