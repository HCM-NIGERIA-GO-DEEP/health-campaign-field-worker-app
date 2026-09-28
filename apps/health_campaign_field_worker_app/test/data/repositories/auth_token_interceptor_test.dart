import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/data/local_store/secure_store/secure_store.dart';
import 'package:health_campaign_field_worker_app/data/repositories/api_interceptors.dart';
import 'package:health_campaign_field_worker_app/data/services/sso_id_token_provider.dart';
import 'package:health_campaign_field_worker_app/utils/environment_config.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalSecureStore extends Mock implements LocalSecureStore {}

class MockSsoIdTokenProvider extends Mock implements SsoIdTokenProvider {}

class CapturingHandler extends RequestInterceptorHandler {
  RequestOptions? forwarded;

  @override
  void next(RequestOptions requestOptions) => forwarded = requestOptions;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLocalSecureStore store;
  late MockSsoIdTokenProvider sso;

  setUpAll(() async {
    await envConfig.initialize();
  });

  setUp(() {
    store = MockLocalSecureStore();
    sso = MockSsoIdTokenProvider();
    when(() => store.accessToken).thenAnswer((_) async => 'digit-access');
    when(() => store.userRequestModel).thenAnswer((_) async => null);
  });

  Future<RequestOptions> send(
    RequestOptions options, {
    bool withSso = true,
  }) async {
    final interceptor = AuthTokenInterceptor(
      localSecureStore: store,
      ssoIdTokenProvider: withSso ? sso : null,
    );
    final handler = CapturingHandler();
    await interceptor.onRequest(options, handler);
    return handler.forwarded!;
  }

  RequestOptions digit(String path) => RequestOptions(
        path: path,
        baseUrl: envConfig.variables.baseUrl,
        data: <String, dynamic>{'x': 1},
      );

  test('adds the raw ID token as x-id-token on DIGIT calls', () async {
    when(() => sso.currentIdToken()).thenAnswer((_) async => 'eyJ.id.token');

    final sent = await send(digit('project/v1/_search'));

    expect(sent.headers[AuthTokenInterceptor.idTokenHeader], 'eyJ.id.token');
    expect(AuthTokenInterceptor.idTokenHeader, 'x-id-token');
    // The DIGIT token still travels in RequestInfo as before.
    final data = sent.data as Map;
    expect((data['RequestInfo'] as Map)['authToken'], 'digit-access');
  });

  test('never sends the ID token to another host', () async {
    when(() => sso.currentIdToken()).thenAnswer((_) async => 'eyJ.id.token');

    final sent = await send(
      RequestOptions(path: 'https://images.example.org/logo.png'),
    );

    expect(
        sent.headers.containsKey(AuthTokenInterceptor.idTokenHeader), isFalse);
    verifyNever(() => sso.currentIdToken());
  });

  test('omits the header when there is no SSO session', () async {
    when(() => sso.currentIdToken()).thenAnswer((_) async => null);

    final sent = await send(digit('project/v1/_search'));

    expect(
        sent.headers.containsKey(AuthTokenInterceptor.idTokenHeader), isFalse);
  });

  test('omits the header when no provider is injected and none is stored',
      () async {
    // Without an injected provider the interceptor builds one only when
    // AUTH_MODE=SSO; either way, no stored token means no header.
    when(() => store.ssoIdToken).thenAnswer((_) async => null);

    final sent = await send(digit('project/v1/_search'), withSso: false);

    expect(
        sent.headers.containsKey(AuthTokenInterceptor.idTokenHeader), isFalse);
  });
}
