import 'dart:async';

import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/user_action.dart';
import 'package:digit_ui_components/utils/app_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../data/local_store/secure_store/secure_store.dart';
import '../../data/repositories/remote/auth.dart';
import '../../data/repositories/remote/mdms.dart';
import '../../data/services/azure_sso_service.dart';
import '../../models/auth/auth_model.dart';
import '../../models/entities/roles_type.dart';
import '../../models/role_actions/role_actions_model.dart';
import '../../utils/environment_config.dart';

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

  /// Interactive single sign-on provider used by [AuthSsoLoginEvent].
  /// Null when the build runs in password mode.
  final SsoAuthenticator? ssoAuthenticator;

  AuthBloc({
    required this.authRepository,
    required this.mdmsRepository,
    required this.individualRemoteRepository,
    this.ssoAuthenticator,
    LocalSecureStore? localSecureStore,
  })  : localSecureStore = localSecureStore ?? LocalSecureStore.instance,
        super(const AuthUnauthenticatedState()) {
    on(_onLogin);
    on(_onSsoLogin);
    on(_onLogout);
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
      final AuthModel result = await authRepository.fetchAuthToken(
        loginModel: LoginModel(
          username: event.userId,
          password: event.password,
          tenantId: event.tenantId,
        ),
      );
      await _completeLogin(result, emit);
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

  //_onSsoLogin runs the external single sign-on flow (Azure Entra ID), then
  // exchanges the resulting ID token for a DIGIT session. From that point on
  // the app behaves exactly as after a password login.
  FutureOr<void> _onSsoLogin(AuthSsoLoginEvent event, AuthEmitter emit) async {
    final authenticator = ssoAuthenticator;
    if (authenticator == null) {
      emit(const AuthErrorState('SSO is not available in this build'));
      emit(const AuthUnauthenticatedState());
      return;
    }

    emit(const AuthLoadingState());

    try {
      final identity = await authenticator.signIn();

      final AuthModel result = await authRepository.exchangeSsoToken(
        request: SsoExchangeRequestModel(
          idToken: identity.idToken,
          accessToken: identity.accessToken,
          tenantId: event.tenantId,
        ),
        exchangePath: envConfig.variables.ssoTokenExchangePath,
      );
      await _completeLogin(result, emit);
      // Kept after _completeLogin so a failed exchange leaves nothing behind.
      await localSecureStore.setSsoIdToken(identity.idToken);
    } on SsoCancelledException {
      // The user closed the browser sheet; nothing to report.
      emit(const AuthUnauthenticatedState());
    } on SsoConfigurationException catch (error) {
      AppLogger.instance.error(
        title: 'SSO configuration error',
        message: error.message,
      );
      emit(AuthErrorState(error.message));
      emit(const AuthUnauthenticatedState());
    } on SsoException catch (error) {
      AppLogger.instance.error(
        title: 'SSO login error',
        message: '${error.message} ${error.cause ?? ''}'.trim(),
      );
      emit(const AuthErrorState());
      emit(const AuthUnauthenticatedState());
    } on DioException catch (error) {
      emit(const AuthErrorState());
      emit(const AuthUnauthenticatedState());

      AppLogger.instance.error(
        title: 'SSO token exchange error',
        message: error.response?.data.toString(),
      );
    } catch (_) {
      emit(const AuthErrorState());
      emit(const AuthUnauthenticatedState());
      rethrow;
    }
  }

  /// Shared tail of every successful token acquisition (password, SSO):
  /// persists credentials, loads role actions, resolves the linked individual
  /// for supervisor/distributor roles and emits [AuthAuthenticatedState].
  Future<void> _completeLogin(AuthModel result, AuthEmitter emit) async {
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
  }

  //_onLogout event logs out the user and deletes the saved user details from local storage
  FutureOr<void> _onLogout(AuthLogoutEvent event, AuthEmitter emit) async {
    await _endSsoSession();
    await localSecureStore.deleteAll();
    await localSecureStore.setBoundaryRefetch(true);
    emit(const AuthUnauthenticatedState());
  }

  /// If the current session came from SSO, also sign the user out of Entra ID
  /// so a shared device does not silently reuse the browser session. Failures
  /// are logged and never block the local logout.
  Future<void> _endSsoSession() async {
    final authenticator = ssoAuthenticator;
    if (authenticator == null || !envConfig.variables.azureEndSessionOnLogout) {
      return;
    }

    try {
      final idToken = await localSecureStore.ssoIdToken;
      if (idToken == null || idToken.isEmpty) return;
      await authenticator.signOut(idTokenHint: idToken);
    } catch (error) {
      AppLogger.instance.error(
        title: 'SSO end-session error',
        message: '$error',
      );
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

  /// Interactive single sign-on (Azure Entra ID) followed by a DIGIT token
  /// exchange. Requires [AuthBloc.ssoAuthenticator].
  const factory AuthEvent.ssoLogin({
    required String tenantId,
  }) = AuthSsoLoginEvent;

  const factory AuthEvent.autoLogin({
    required String tenantId,
  }) = AuthAutoLoginEvent;

  const factory AuthEvent.logout() = AuthLogoutEvent;

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
