import 'dart:async';

import 'package:digit_data_model/models/entities/user_action.dart';
import 'package:dio/dio.dart';

import '../../../models/auth/auth_model.dart';

class AuthRepository {
  final Dio _client;
  final String loginPath;

  const AuthRepository(this._client, {required this.loginPath});

  Future<Response<dynamic>> _requestToken(Map<String, dynamic> data) {
    return _client.post(
      loginPath,
      data: {...data, 'clientType': 'mobile'},
      options: Options(
        headers: {"authorization": "Basic ZWdvdi11c2VyLWNsaWVudDo="},
        contentType: Headers.formUrlEncodedContentType,
        extra: {'skipRequestInfo': true, 'skipApiLogging': true},
      ),
    );
  }

  Future<({String accessToken, String refreshToken})> refreshAuthToken(
    String refreshToken,
  ) async {
    final response = await _requestToken({
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
    });
    final data = response.data;
    if (data is! Map ||
        data['access_token'] is! String ||
        (data['access_token'] as String).isEmpty) {
      throw const FormatException('Invalid refresh response');
    }
    final rotatedToken = data['refresh_token'];
    return (
      accessToken: data['access_token'] as String,
      refreshToken: rotatedToken is String && rotatedToken.isNotEmpty
          ? rotatedToken
          : refreshToken,
    );
  }

  Future<AuthModel> fetchAuthToken({required LoginModel loginModel}) async {
    final response = await _requestToken(loginModel.toJson());

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
          extra: {'skipRequestInfo': true},
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
