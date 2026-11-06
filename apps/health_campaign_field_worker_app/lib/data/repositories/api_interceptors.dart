import 'dart:async';
import 'dart:convert';

import 'package:digit_ui_components/utils/app_logger.dart';
import 'package:dio/dio.dart';

import '../../models/request_info/request_info_model.dart';
import '../../utils/constants.dart';
import '../../utils/environment_config.dart';
import '../local_store/secure_store/secure_store.dart';
import 'remote/auth.dart';

class AuthTokenInterceptor extends Interceptor {
  final Dio _client;
  final LocalSecureStore localSecureStore;
  String? loginPath;

  ({String rejectedToken, Future<String?> result})? _refresh;
  ({String rejectedToken, String accessToken})? _lastRefresh;

  static const _retriedKey = 'authRetried';
  static const _skipRequestInfoKey = 'skipRequestInfo';

  AuthTokenInterceptor(
    this._client, {
    LocalSecureStore? localSecureStore,
  }) : localSecureStore = localSecureStore ?? LocalSecureStore.instance;

  @override
  Future<dynamic> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final skipRequestInfo = options.extra[_skipRequestInfoKey] == true;
    if (skipRequestInfo || options.extra[_retriedKey] == true) {
      return super.onRequest(options, handler);
    }

    final authToken = await localSecureStore.accessToken;
    final userInfo = await localSecureStore.userRequestModel;
    if (options.data is Map) {
      options.data = {
        ...options.data,
        "RequestInfo": RequestInfoModel(
                apiId: RequestInfoData.apiId,
                ver: RequestInfoData.ver,
                ts: DateTime.now().millisecondsSinceEpoch,
                action: options.path.split('/').last,
                did: RequestInfoData.did,
                key: "1",
                authToken: authToken,
                userInfo: userInfo,
                tenantId: envConfig.variables.tenantId)
            .toJson(),
      };
    }
    super.onRequest(options, handler);
  }

  @override
  Future<void> onError(
      DioException error, ErrorInterceptorHandler handler) async {
    final request = error.requestOptions;
    final data = request.data;
    final requestInfo = data is Map ? data['RequestInfo'] : null;
    final rejectedToken = requestInfo is Map ? requestInfo['authToken'] : null;
    final path = loginPath;
    if (error.response?.statusCode != 401 ||
        request.extra[_skipRequestInfoKey] == true ||
        request.extra[_retriedKey] == true ||
        rejectedToken is! String ||
        rejectedToken.isEmpty ||
        path == null ||
        path.isEmpty) {
      return handler.next(error);
    }

    String? accessToken;
    try {
      accessToken = await _refreshAccessToken(rejectedToken, path);
      if (accessToken == null ||
          await localSecureStore.accessToken != accessToken) {
        return handler.next(error);
      }
    } on DioException catch (refreshError) {
      final status = refreshError.response?.statusCode;
      return handler
          .next(status == null || status >= 500 ? refreshError : error);
    } catch (_) {
      return handler.next(error);
    }

    // Keep the original request and user context. Replace only the token.
    final retry = request.copyWith(
      data: {
        ...(data as Map),
        'RequestInfo': {...(requestInfo as Map), 'authToken': accessToken},
      },
      extra: {...request.extra, _retriedKey: true},
    );
    try {
      handler.resolve(await _client.fetch<dynamic>(retry));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<String?> _refreshAccessToken(String rejectedToken, String path) async {
    final currentToken = await localSecureStore.accessToken;
    final pending = _refresh;
    if (pending != null && pending.rejectedToken == rejectedToken) {
      return pending.result;
    }

    if (currentToken != rejectedToken) {
      // A delayed 401 can use the token refreshed for that exact session.
      final last = _lastRefresh;
      return last?.rejectedToken == rejectedToken &&
              last?.accessToken == currentToken
          ? currentToken
          : null;
    }

    final result = _exchangeRefreshToken(rejectedToken, path);
    _refresh = (rejectedToken: rejectedToken, result: result);
    try {
      return await result;
    } finally {
      if (identical(_refresh?.result, result)) _refresh = null;
    }
  }

  Future<String?> _exchangeRefreshToken(
      String rejectedToken, String path) async {
    final refreshToken =
        await localSecureStore.refreshTokenForAccessToken(rejectedToken);
    if (refreshToken == null || refreshToken.isEmpty) return null;

    final tokens = await AuthRepository(_client, loginPath: path)
        .refreshAuthToken(refreshToken);
    final updated = await localSecureStore.replaceAuthTokens(
      previousAccessToken: rejectedToken,
      previousRefreshToken: refreshToken,
      newAccessToken: tokens.accessToken,
      newRefreshToken: tokens.refreshToken,
    );
    if (!updated) return null;
    _lastRefresh =
        (rejectedToken: rejectedToken, accessToken: tokens.accessToken);
    return tokens.accessToken;
  }
}

class ApiLoggerInterceptor extends Interceptor {
  @override
  Future<dynamic> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['skipApiLogging'] != true &&
        (options.data is Map || options.data is List)) {
      AppLogger.instance.info(
        _getIndentedJson(json.encode(options.data)),
        title: '[REQUEST] ${options.uri.toString()}',
      );
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    super.onResponse(response, handler);

    if (response.requestOptions.extra['skipApiLogging'] == true ||
        response.requestOptions.path.contains('boundarys')) return;

    try {
      AppLogger.instance.info(
        _getIndentedJson(json.encode(response.data)),
        title:
            '[RESPONSE - ${response.statusCode}] ${response.requestOptions.uri.toString()}',
      );
    } catch (error) {
      AppLogger.instance.info(
        // ignore: avoid_dynamic_calls
        '${response.data.runtimeType} ${response.statusCode.toString()}',
        title: '[RESPONSE (error)] ${response.requestOptions.path}',
      );
    }
  }

  String _getIndentedJson(String json) {
    return const JsonEncoder.withIndent('  ').convert(jsonDecode(json));
  }
}
