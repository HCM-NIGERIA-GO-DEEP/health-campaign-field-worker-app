import 'dart:async';

import 'package:digit_data_model/models/entities/user_action.dart';
import 'package:dio/dio.dart';

import '../../../models/auth/auth_model.dart';
import '../api_interceptors.dart';

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

    // Form-url-encoded map (not multipart FormData) so the backend's session
    // feature receives deviceId/clientType as plain params. A Map body would
    // otherwise be wrapped in RequestInfo and logged with the password by the
    // shared interceptors, hence both opt-outs.
    final response = await _client.post(
      loginPath,
      data: {
        ...loginModel.toJson(),
        'clientType': 'mobile',
      },
      options: Options(
        headers: headers,
        contentType: Headers.formUrlEncodedContentType,
        extra: {
          RequestExtras.skipRequestInfo: true,
          RequestExtras.redactBodyLog: true,
        },
      ),
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
        options: Options(
          headers: {
            "content-type": 'application/json',
          },
          // The body carries its own RequestInfo (see buildLogoutPayload).
          extra: {RequestExtras.skipRequestInfo: true},
        ),
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
