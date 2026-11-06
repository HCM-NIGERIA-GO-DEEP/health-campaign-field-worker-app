import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/data/local_store/secure_store/secure_store.dart';
import 'package:health_campaign_field_worker_app/data/repositories/api_interceptors.dart';
import 'package:health_campaign_field_worker_app/models/auth/auth_model.dart';
import 'package:health_campaign_field_worker_app/utils/environment_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => envConfig.initialize());

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      LocalSecureStore.accessTokenKey: 'old-access',
      LocalSecureStore.refreshTokenKey: 'old-refresh',
    });
  });

  test('concurrent 401s share a refresh and retry with the rotated token',
      () async {
    final bothRejected = Completer<void>();
    var rejected = 0;
    var refreshes = 0;
    final retriedPaths = <String>{};
    final dio = _client((request) async {
      if (request.path == '/token') {
        refreshes++;
        expect(request.data['grant_type'], 'refresh_token');
        expect(request.data['refresh_token'], 'old-refresh');
        expect(request.data.containsKey('RequestInfo'), isFalse);
        await bothRejected.future;
        return _json(
            200, '{"access_token":"new-access","refresh_token":"new-refresh"}');
      }
      final token = request.data['RequestInfo']['authToken'];
      if (token == 'old-access') {
        rejected++;
        if (rejected == 2) bothRejected.complete();
        return _json(401, '{}');
      }
      expect(token, 'new-access');
      expect(request.data['payload'], request.path);
      retriedPaths.add(request.path);
      return _json(200, '{}');
    });
    addTearDown(() => dio.close());

    await Future.wait([
      dio.post('/first', data: {'payload': '/first'}),
      dio.post('/second', data: {'payload': '/second'}),
    ]);

    expect(refreshes, 1);
    expect(retriedPaths, {'/first', '/second'});
    expect(await LocalSecureStore.instance.accessToken, 'new-access');
    expect(await LocalSecureStore.instance.refreshToken, 'new-refresh');
  });

  test('a second 401 is returned without another refresh', () async {
    var refreshes = 0;
    var requests = 0;
    final dio = _client((request) async {
      if (request.path == '/token') {
        refreshes++;
        return _json(200, '{"access_token":"new-access"}');
      }
      requests++;
      return _json(401, '{}');
    });
    addTearDown(() => dio.close());

    await expectLater(
      dio.post('/sync', data: <String, dynamic>{}),
      throwsA(isA<DioException>()
          .having((e) => e.response?.statusCode, 'status', 401)),
    );
    expect(refreshes, 1);
    expect(requests, 2);
    expect(await LocalSecureStore.instance.refreshToken, 'old-refresh');
  });

  test('a refresh response cannot replace a new login', () async {
    final refreshing = Completer<void>();
    final finishRefresh = Completer<void>();
    var requests = 0;
    final dio = _client((request) async {
      if (request.path == '/token') {
        refreshing.complete();
        await finishRefresh.future;
        return _json(200,
            '{"access_token":"stale-access","refresh_token":"stale-refresh"}');
      }
      requests++;
      return _json(401, '{}');
    });
    addTearDown(() => dio.close());

    final failedRequest = expectLater(
      dio.post('/sync', data: <String, dynamic>{}),
      throwsA(isA<DioException>()),
    );
    await refreshing.future;
    await LocalSecureStore.instance.setAuthCredentials(const AuthModel(
      accessToken: 'new-login-access',
      refreshToken: 'new-login-refresh',
      tokenType: 'bearer',
      expiresIn: 3600,
      userRequestModel: UserRequestModel(uuid: 'new-user'),
    ));
    finishRefresh.complete();

    await failedRequest;
    expect(requests, 1);
    expect(await LocalSecureStore.instance.accessToken, 'new-login-access');
    expect(await LocalSecureStore.instance.refreshToken, 'new-login-refresh');
  });
}

Dio _client(Future<ResponseBody> Function(RequestOptions) respond) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
  dio.httpClientAdapter = _FakeAdapter(respond);
  dio.interceptors.add(AuthTokenInterceptor(dio)..loginPath = '/token');
  return dio;
}

ResponseBody _json(int status, String body) => ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      respond(options);

  @override
  void close({bool force = false}) {}
}
