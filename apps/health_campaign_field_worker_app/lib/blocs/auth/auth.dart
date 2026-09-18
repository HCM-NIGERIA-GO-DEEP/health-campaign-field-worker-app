import 'dart:async';

import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/user_action.dart';
import 'package:digit_ui_components/utils/app_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar/isar.dart';

import '../../data/local_store/secure_store/secure_store.dart';
import '../../data/repositories/remote/auth.dart';
import '../../data/repositories/remote/mdms.dart';
import '../../models/auth/auth_model.dart';
import '../../models/entities/roles_type.dart';
import '../../models/role_actions/role_actions_model.dart';
import '../../services/device_id_service.dart';
import '../../utils/constants.dart';
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
  final Isar isar;
  final LocalSqlDataStore sql;

  AuthBloc({
    required this.authRepository,
    required this.mdmsRepository,
    required this.individualRemoteRepository,
    required this.isar,
    required this.sql,
    LocalSecureStore? localSecureStore,
  })  : localSecureStore = LocalSecureStore.instance,
        super(const AuthUnauthenticatedState()) {
    on(_onLogin);
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
      emit(AuthErrorState(_extractLoginErrorMessage(error)));
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
  // Callers are expected to have already confirmed connectivity (see
  // ensureOnlineOrAlert) — if the API call still fails here, the local
  // session is left untouched so the user stays logged in.
  FutureOr<void> _onLogout(AuthLogoutEvent event, AuthEmitter emit) async {
    try {
      final payload = await _buildLogoutPayload();
      if (payload['access_token'] == null ||
          (payload['access_token'] as String).isEmpty) {
        _showLogoutFailureAlert('Unable to logout: missing access token.');
        return;
      }

      await authRepository.logOutUser(
        logoutPath: Constants.logoutUserPath,
        body: payload,
      );
    } on DioException catch (e) {
      final message = _extractDioErrorMessage(e);
      _showLogoutFailureAlert(message);
      AppLogger.instance.error(
        title: 'Logout API error',
        message: '${e.response?.statusCode}: ${e.response?.data}',
      );
      return;
    } catch (e) {
      _showLogoutFailureAlert('Logout failed. Please try again.');
      AppLogger.instance.error(
        title: 'Logout API error',
        message: '$e',
      );
      return;
    }

    await _deleteUserLocalDatabaseData();
    await localSecureStore.deleteAll();
    await localSecureStore.setBoundaryRefetch(true);
    // NOTE: do NOT clear isar.appConfigurations here. Its partner — the
    // login-time MDMS re-fetch (AppInitializationSetupEvent on re-auth) — was
    // removed to stop login-screen flicker, so clearing on logout left the
    // config empty on re-login. That made project.dart's `configs.first` throw
    // (surfacing as "Failed to fetch checklist") and caused the batch-size
    // crash. The app config is re-fetched fresh on every app start, so we keep
    // the cached copy across logout instead of wiping it.
    DigitDataModelSingleton().setHierarchyType(null);
    emit(const AuthUnauthenticatedState());
  }

  String _extractDioErrorMessage(DioException error) {
    final data = error.response?.data;

    if (data is Map<String, dynamic>) {
      final directMessage = data['message'];
      if (directMessage is String && directMessage.trim().isNotEmpty) {
        return directMessage;
      }

      final errors = data['Errors'];
      if (errors is List && errors.isNotEmpty) {
        final first = errors.first;
        if (first is Map<String, dynamic>) {
          final msg = first['message'];
          if (msg is String && msg.trim().isNotEmpty) {
            return msg;
          }
        }
      }
    }

    final fallback = error.response?.statusMessage;
    if (fallback != null && fallback.trim().isNotEmpty) {
      return fallback;
    }
    return 'Logout failed. Please try again.';
  }

  String _extractLoginErrorMessage(DioException error) {
    final data = error.response?.data;

    if (data is Map<String, dynamic>) {
      final errorDescription = data['error_description'];
      if (errorDescription is String &&
          errorDescription.contains('ACTIVE_SESSION_EXISTS')) {
        return 'ACTIVE_SESSION_EXISTS';
      }

      final directMessage = data['message'];
      if (directMessage is String && directMessage.trim().isNotEmpty) {
        return directMessage;
      }
    }

    return 'Unable to login. Please try again.';
  }

  void _showLogoutFailureAlert(String message) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  Future<Map<String, dynamic>> _buildLogoutPayload() async {
    final accessToken = await localSecureStore.accessToken;
    final userObject = await localSecureStore.userRequestModel;
    final tenantIdFromUser = userObject?.tenantId;
    final tenantId =
        (tenantIdFromUser != null && tenantIdFromUser.trim().isNotEmpty)
            ? tenantIdFromUser
            : envConfig.variables.tenantId;

    return {
      if (accessToken != null && accessToken.isNotEmpty)
        'access_token': accessToken,
      'tenantId': tenantId,
      'RequestInfo': {
        'apiId': '',
        'authToken': accessToken ?? '',
        'msgId': '',
        'plainAccessRequest': {},
      },
    };
  }

  Future<void> _deleteUserLocalDatabaseData() async {
    await _clearSqlTables();
    await _clearIsarUserSessionData();
  }

  Future<void> _clearSqlTables() async {
    await sql.transaction(() async {
      await sql.customStatement('PRAGMA foreign_keys = OFF;');
      try {
        final tables = await sql
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' "
              "AND name NOT LIKE 'sqlite_%' "
              "AND name != 'moor_schema' "
              "AND LOWER(name) != 'localization';",
            )
            .get();

        for (final row in tables) {
          final tableName = row.data['name'] as String?;
          if (tableName == null || tableName.isEmpty) continue;
          final escaped = tableName.replaceAll('"', '""');
          await sql.customStatement('DELETE FROM "$escaped";');
        }
      } finally {
        await sql.customStatement('PRAGMA foreign_keys = ON;');
      }
    });
  }

  Future<void> _clearIsarUserSessionData() async {
    await isar.writeTxn(() async {
      await isar.opLogs.clear();
    });
  }

  FutureOr<void> _onReset(AuthResetEvent event, AuthEmitter emit) async {
    await localSecureStore.deleteAll();
    await localSecureStore.setBoundaryRefetch(true);
    // NOTE: do NOT clear isar.appConfigurations here. Its partner — the
    // login-time MDMS re-fetch (AppInitializationSetupEvent on re-auth) — was
    // removed to stop login-screen flicker, so clearing on logout left the
    // config empty on re-login. That made project.dart's `configs.first` throw
    // (surfacing as "Failed to fetch checklist") and caused the batch-size
    // crash. The app config is re-fetched fresh on every app start, so we keep
    // the cached copy across logout instead of wiping it.
    DigitDataModelSingleton().setHierarchyType(null);
    emit(const AuthUnauthenticatedState());
  }

  FutureOr<void> _onAllow(AuthAllowEvent event, AuthEmitter emit) async {
    emit(const AuthAllowState());
  }

  FutureOr<void> _onDeviceSwitch(
      AuthSwitchDeviceEventSwitchDevice event, AuthEmitter emit) async {
    try {
      emit(const AuthLoadingState());
      final deviceId = await DeviceIdService.getDeviceId();
      final result = await authRepository.switchDevice(
        endpoint: event.apiEndPoint, // Use the endpoint from the event
        payload: {
          "deviceSwitchReason": event.selectedReason,
          "username": event.username,
          "tenantId": event.tenantId,
          "password": event.password,
          "deviceSwitchComment": event.deviceSwitchComment,
          "deviceId": deviceId,
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
    final deviceId = await DeviceIdService.getDeviceId();
    final payload = {
      'username': event.username,
      "tenantId": event.tenantId,
      "deviceToken": deviceToken,
      "deviceId": deviceId,
    };

    try {
      final validateResponseModel =
          await authRepository.isLoggedInOnOtherDevice(
        endpoint: event.apiEndPoint, // Use dynamic endpoint from event
        payload: payload,
      );

      if (validateResponseModel.isDuplicateLogin) {
        if (!validateResponseModel.canSwitchDevice) {
          // Backend disallows resolving this via device-switch — reuse the
          // existing error state so the login page just shows the message
          // and stays put (no switch-flow navigation).
          emit(AuthState.error(validateResponseModel.message));
          return;
        }
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
