import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/data/services/azure_sso_service.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterAppAuth extends Mock implements FlutterAppAuth {}

void main() {
  late MockFlutterAppAuth appAuth;

  const tenant = '11111111-2222-3333-4444-555555555555';
  const client = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
  const redirect = 'com.digit.hcm://oauth/callback';
  const scopes = [
    'openid',
    'profile',
    'api://aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/access_as_user',
  ];

  AuthorizationTokenResponse response({String? idToken}) =>
      AuthorizationTokenResponse(
        'azure-access',
        null,
        DateTime(2030),
        idToken,
        'Bearer',
        scopes,
        null,
        null,
      );

  setUpAll(() {
    registerFallbackValue(
      EndSessionRequest(
        discoveryUrl:
            'https://example.invalid/.well-known/openid-configuration',
      ),
    );
    registerFallbackValue(
      AuthorizationTokenRequest(
        client,
        redirect,
        discoveryUrl:
            'https://example.invalid/.well-known/openid-configuration',
      ),
    );
  });

  setUp(() {
    appAuth = MockFlutterAppAuth();
  });

  AzureSsoService service({
    String tenantId = tenant,
    String clientId = client,
    String redirectUri = redirect,
  }) =>
      AzureSsoService(
        tenantId: tenantId,
        clientId: clientId,
        redirectUri: redirectUri,
        scopes: scopes,
        appAuth: appAuth,
      );

  group('AzureSsoService', () {
    test('builds the Entra ID v2.0 discovery URL for the tenant', () {
      expect(
        service().discoveryUrl,
        'https://login.microsoftonline.com/$tenant/v2.0/.well-known/openid-configuration',
      );
    });

    test(
        'throws SsoConfigurationException before opening the browser when '
        'tenant or client are blank', () async {
      for (final svc in [
        service(tenantId: ''),
        service(clientId: ''),
        service(redirectUri: ''),
      ]) {
        expect(svc.isConfigured, isFalse);
        await expectLater(
          svc.signIn(),
          throwsA(isA<SsoConfigurationException>()),
        );
      }
      verifyNever(() => appAuth.authorizeAndExchangeCode(any()));
    });

    test('runs the auth-code flow with discovery, scopes and account picker',
        () async {
      when(() => appAuth.authorizeAndExchangeCode(any()))
          .thenAnswer((_) async => response(idToken: 'id.token.value'));

      final identity = await service().signIn();

      expect(identity.idToken, 'id.token.value');
      expect(identity.accessToken, 'azure-access');

      final request =
          verify(() => appAuth.authorizeAndExchangeCode(captureAny()))
              .captured
              .single as AuthorizationTokenRequest;
      expect(request.clientId, client);
      expect(request.redirectUrl, redirect);
      expect(request.discoveryUrl, service().discoveryUrl);
      expect(request.scopes, scopes);
      expect(request.promptValues, ['select_account']);
      expect(request.clientSecret, isNull);
    });

    test('maps a user-cancelled browser session to SsoCancelledException',
        () async {
      when(() => appAuth.authorizeAndExchangeCode(any())).thenThrow(
        FlutterAppAuthUserCancelledException(
          code: 'authorize_and_exchange_code_failed',
          platformErrorDetails: FlutterAppAuthPlatformErrorDetails(
            type: 'user_cancelled',
          ),
        ),
      );

      await expectLater(
        service().signIn(),
        throwsA(isA<SsoCancelledException>()),
      );
    });

    test('maps a platform failure to SsoException carrying the description',
        () async {
      when(() => appAuth.authorizeAndExchangeCode(any())).thenThrow(
        FlutterAppAuthPlatformException(
          code: 'authorize_and_exchange_code_failed',
          platformErrorDetails: FlutterAppAuthPlatformErrorDetails(
            error: 'invalid_client',
            errorDescription: 'AADSTS700016: application not found',
          ),
        ),
      );

      await expectLater(
        service().signIn(),
        throwsA(
          isA<SsoException>().having(
            (e) => e.message,
            'message',
            contains('AADSTS700016'),
          ),
        ),
      );
    });

    test('rejects a token response that carries no ID token', () async {
      when(() => appAuth.authorizeAndExchangeCode(any()))
          .thenAnswer((_) async => response(idToken: null));

      await expectLater(
        service().signIn(),
        throwsA(isA<SsoException>()),
      );
    });
  });

  group('AzureSsoService.signOut', () {
    test('calls the end-session endpoint with the ID token hint and redirect',
        () async {
      when(() => appAuth.endSession(any()))
          .thenAnswer((_) async => EndSessionResponse(null));

      await service().signOut(idTokenHint: 'id.token.value');

      final request = verify(() => appAuth.endSession(captureAny()))
          .captured
          .single as EndSessionRequest;
      expect(request.idTokenHint, 'id.token.value');
      expect(request.postLogoutRedirectUrl, redirect);
      expect(request.discoveryUrl, service().discoveryUrl);
    });

    test('does nothing without a token hint or configuration', () async {
      await service().signOut(idTokenHint: '');
      await service(clientId: '').signOut(idTokenHint: 'x');
      verifyNever(() => appAuth.endSession(any()));
    });

    test('swallows cancellation and platform failures', () async {
      when(() => appAuth.endSession(any())).thenThrow(
        FlutterAppAuthUserCancelledException(
          code: 'end_session_failed',
          platformErrorDetails: FlutterAppAuthPlatformErrorDetails(),
        ),
      );
      await expectLater(service().signOut(idTokenHint: 'x'), completes);

      when(() => appAuth.endSession(any())).thenThrow(
        FlutterAppAuthPlatformException(
          code: 'end_session_failed',
          platformErrorDetails: FlutterAppAuthPlatformErrorDetails(
            errorDescription: 'offline',
          ),
        ),
      );
      await expectLater(service().signOut(idTokenHint: 'x'), completes);
    });
  });
}
