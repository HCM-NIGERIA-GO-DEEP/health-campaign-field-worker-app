import 'dart:async';

import 'package:digit_data_model/models/entities/user_action.dart';
import 'package:dio/dio.dart';

import '../../../models/auth/auth_model.dart';

class AuthRepository {
  final Dio _client;
  final String loginPath;

  const AuthRepository(this._client, {required this.loginPath});

  Future<AuthModel> fetchAuthToken({required LoginModel loginModel}) async {
    final headers = <String, String>{
      "content-type": 'application/x-www-form-urlencoded',
      "Access-Control-Allow-Origin": "*",
      "authorization": "Basic ZWdvdi11c2VyLWNsaWVudDo=",
    };

    final formData = FormData.fromMap(loginModel.toJson());

    final response = await _client.post(
      loginPath,
      data: formData,
      options: Options(headers: headers),
    );

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid response');
    }

    try {
      return AuthModel.fromJson(data);
    } catch (error) {
      rethrow;
    }
  }

  /// Exchanges an Azure Entra ID token for a DIGIT session.
  ///
  /// [exchangePath] is relative to the client's base URL and comes from
  /// `SSO_TOKEN_EXCHANGE_PATH`. The response must match the shape returned by
  /// the password grant so the rest of the auth stack is unchanged.
  Future<AuthModel> exchangeSsoToken({
    required SsoExchangeRequestModel request,
    required String exchangePath,
  }) async {
    final response = await _client.post(
      exchangePath,
      data: request.toJson(),
      options: Options(headers: const {
        "content-type": 'application/json',
      }),
    );

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid response');
    }

    return AuthModel.fromJson(data);
  }

  Future logOutUser({
    Map<String, String>? queryParameters,
    dynamic body,
    required String logoutPath,
  }) async {
    try {
      await _client.post(
        logoutPath,
        queryParameters: queryParameters,
        data: body ?? {},
      );
    } catch (error) {
      rethrow;
    }
  }

  Future<ValidateResponseModel> isLoggedInOnOtherDevice({
    required String endpoint,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client.post(endpoint, data: payload);
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid response');
    }

    try {
      return ValidateResponseModel.fromJson(data);
    } catch (error) {
      rethrow;
    }
  }

  Future<AuthModel> switchDevice({
    required String endpoint,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client.post(endpoint, data: payload);

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid response');
    }

    try {
      return AuthModel.fromJson(data);
    } catch (error) {
      rethrow;
    }
  }

  Future<void> switchDeviceUserAction({
    required String endpoint,
    required UserActionModel userActionModel,
  }) async {
    if (userActionModel.tenantId == null) {
      throw ArgumentError('tenantId is required for switchDeviceUserAction');
    }
    try {
      await _client.post(
        endpoint,
        data: {
          "UserActions": [
            userActionModel.toMap(),
          ],
        },
        queryParameters: {
          "tenantId": userActionModel.tenantId!,
        },
        options: Options(headers: {
          "content-type": 'application/json',
        }),
      );
    } catch (error) {
      rethrow;
    }
  }
}
