import 'dart:async';
import 'dart:convert';

import 'package:digit_ui_components/utils/app_logger.dart';
import 'package:dio/dio.dart';

import '../../models/request_info/request_info_model.dart';
import '../../utils/constants.dart';
import '../../utils/environment_config.dart';
import '../local_store/secure_store/secure_store.dart';
import '../services/azure_sso_service.dart';
import '../services/sso_id_token_provider.dart';

class AuthTokenInterceptor extends Interceptor {
  /// Header carrying the raw Azure ID token (JWT) on every DIGIT call made
  /// during an SSO session.
  static const idTokenHeader = 'x-id-token';

  final LocalSecureStore localSecureStore;
  SsoIdTokenProvider? _ssoIdTokenProvider;
  bool _ssoResolved;

  AuthTokenInterceptor({
    LocalSecureStore? localSecureStore,
    SsoIdTokenProvider? ssoIdTokenProvider,
  })  : localSecureStore = localSecureStore ?? LocalSecureStore.instance,
        _ssoIdTokenProvider = ssoIdTokenProvider,
        _ssoResolved = ssoIdTokenProvider != null;

  /// Created on first use rather than in the constructor so the environment
  /// is guaranteed to be loaded; null in password mode.
  SsoIdTokenProvider? get _ssoProvider {
    if (!_ssoResolved) {
      _ssoResolved = true;
      if (envConfig.variables.authMode == AuthMode.sso) {
        _ssoIdTokenProvider = SsoIdTokenProvider(
          store: localSecureStore,
          authenticator: AzureSsoService.fromEnvironment(envConfig.variables),
        );
      }
    }
    return _ssoIdTokenProvider;
  }

  /// Only requests to the DIGIT host get the ID token, never other hosts.
  bool _isDigitRequest(RequestOptions options) {
    final digitHost = Uri.tryParse(envConfig.variables.baseUrl)?.host;
    return digitHost != null &&
        digitHost.isNotEmpty &&
        options.uri.host == digitHost;
  }

  @override
  Future<dynamic> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final ssoProvider = _ssoProvider;
    if (ssoProvider != null && _isDigitRequest(options)) {
      final idToken = await ssoProvider.currentIdToken();
      if (idToken != null) {
        options.headers[idTokenHeader] = idToken;
      }
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
}

class ApiLoggerInterceptor extends Interceptor {
  @override
  Future<dynamic> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.data is Map || options.data is List) {
      AppLogger.instance.info(
        _getIndentedJson(json.encode(_redact(options.data))),
        title: '[REQUEST] ${options.uri.toString()}',
      );
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    super.onResponse(response, handler);

    if (response.requestOptions.path.contains('boundarys')) return;

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

  /// Azure tokens posted by the SSO exchange must never reach the device log.
  static const _redactedKeys = {'idToken', 'accessToken', 'refreshToken'};

  static dynamic _redact(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, v) => MapEntry(
          key,
          _redactedKeys.contains(key) && v != null ? '***' : _redact(v),
        ),
      );
    }
    if (value is List) return value.map(_redact).toList();
    return value;
  }
}
