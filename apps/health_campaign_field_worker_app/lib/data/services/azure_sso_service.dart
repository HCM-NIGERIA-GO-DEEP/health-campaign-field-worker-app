import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

import '../../utils/environment_config.dart';

/// Identity returned by an external single sign-on provider.
///
/// [idToken] is the `assertion` of the DIGIT `jwt_exchange` token grant, is
/// sent as the `x-id-token` header and cookie on every DIGIT call and is the
/// `id_token_hint` for the Entra end-session call on logout. [accessToken] is
/// returned by Entra but not currently sent anywhere.
/// [refreshToken] (requires the `offline_access` scope) lets the app obtain a
/// fresh ID token when the ~1 hour one expires, including during background
/// sync. The DIGIT tokens remain the app's session source.
class SsoIdentity {
  final String idToken;
  final String? accessToken;
  final String? refreshToken;

  const SsoIdentity({
    required this.idToken,
    this.accessToken,
    this.refreshToken,
  });
}

/// Thrown when the user dismisses the provider's sign-in UI.
class SsoCancelledException implements Exception {
  const SsoCancelledException();

  @override
  String toString() => 'SsoCancelledException: user cancelled sign-in';
}

/// Thrown when SSO is selected but the Azure settings are missing.
class SsoConfigurationException implements Exception {
  final String message;

  const SsoConfigurationException(this.message);

  @override
  String toString() => 'SsoConfigurationException: $message';
}

/// Thrown when the provider completes but does not return a usable identity,
/// or when the underlying platform flow fails.
class SsoException implements Exception {
  final String message;
  final Object? cause;

  const SsoException(this.message, [this.cause]);

  @override
  String toString() => 'SsoException: $message';
}

/// Abstraction over the interactive sign-in so [AuthBloc] can be tested and
/// other providers can be plugged in without touching the bloc.
abstract class SsoAuthenticator {
  /// Runs the interactive sign-in and returns the resulting identity.
  ///
  /// Throws [SsoCancelledException], [SsoConfigurationException] or
  /// [SsoException].
  Future<SsoIdentity> signIn();

  /// Redeems [refreshToken] for a new identity without user interaction.
  /// Must not require an Activity so it can run in the background isolate.
  ///
  /// Throws [SsoConfigurationException] or [SsoException].
  Future<SsoIdentity> refresh({required String refreshToken});

  /// Ends the provider's browser session for the user identified by
  /// [idTokenHint]. Best effort: implementations must not throw when the
  /// user dismisses the browser or the provider is unreachable.
  Future<void> signOut({required String idTokenHint});
}

/// Azure Entra ID sign-in using the OpenID Connect authorization-code flow
/// with PKCE, driven by the system browser through `flutter_appauth`.
///
/// The browser and the token exchange with `login.microsoftonline.com` run
/// natively (AppAuth SDKs), so the app's certificate-pinned Dio client is not
/// involved and the pin set does not need the Microsoft certificates.
class AzureSsoService implements SsoAuthenticator {
  static const _authorityHost = 'https://login.microsoftonline.com';

  final FlutterAppAuth _appAuth;
  final String tenantId;
  final String clientId;
  final String redirectUri;
  final List<String> scopes;

  const AzureSsoService({
    required this.tenantId,
    required this.clientId,
    required this.redirectUri,
    required this.scopes,
    FlutterAppAuth appAuth = const FlutterAppAuth(),
  }) : _appAuth = appAuth;

  factory AzureSsoService.fromEnvironment(Variables variables) {
    return AzureSsoService(
      tenantId: variables.azureTenantId.trim(),
      clientId: variables.azureClientId.trim(),
      redirectUri: variables.azureRedirectUri.trim(),
      scopes: variables.azureScopes,
    );
  }

  /// Entra ID v2.0 OIDC discovery document for [tenantId].
  String get discoveryUrl =>
      '$_authorityHost/$tenantId/v2.0/.well-known/openid-configuration';

  bool get isConfigured =>
      tenantId.isNotEmpty && clientId.isNotEmpty && redirectUri.isNotEmpty;

  @override
  Future<SsoIdentity> signIn() async {
    if (!isConfigured) {
      throw const SsoConfigurationException(
        'AZURE_TENANT_ID, AZURE_CLIENT_ID and AZURE_REDIRECT_URI must be set '
        'when AUTH_MODE=SSO',
      );
    }

    final AuthorizationTokenResponse response;
    try {
      response = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          clientId,
          redirectUri,
          discoveryUrl: discoveryUrl,
          scopes: scopes,
          // Always show the account picker: field devices are often shared,
          // and a silently reused browser session would log in the wrong user.
          promptValues: const ['select_account'],
        ),
      );
    } on FlutterAppAuthUserCancelledException {
      throw const SsoCancelledException();
    } on FlutterAppAuthPlatformException catch (error) {
      throw SsoException(
        error.platformErrorDetails.errorDescription ??
            error.message ??
            'Azure sign-in failed',
        error,
      );
    }

    final idToken = response.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const SsoException(
        'Azure did not return an ID token; ensure the `openid` scope is '
        'requested and ID tokens are enabled on the app registration',
      );
    }

    return SsoIdentity(
      idToken: idToken,
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
    );
  }

  /// Refresh-token grant against the Entra token endpoint. AppAuth performs
  /// it with the application context, so it works from the background
  /// isolate. Entra rotates refresh tokens; the caller stores the new one.
  @override
  Future<SsoIdentity> refresh({required String refreshToken}) async {
    if (!isConfigured) {
      throw const SsoConfigurationException(
        'AZURE_TENANT_ID, AZURE_CLIENT_ID and AZURE_REDIRECT_URI must be set '
        'when AUTH_MODE=SSO',
      );
    }

    final TokenResponse response;
    try {
      response = await _appAuth.token(
        TokenRequest(
          clientId,
          redirectUri,
          refreshToken: refreshToken,
          discoveryUrl: discoveryUrl,
          scopes: scopes,
        ),
      );
    } on FlutterAppAuthPlatformException catch (error) {
      throw SsoException(
        error.platformErrorDetails.errorDescription ??
            error.message ??
            'Azure token refresh failed',
        error,
      );
    }

    final idToken = response.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const SsoException(
        'Azure did not return an ID token on refresh; ensure the `openid` '
        'scope is requested',
      );
    }

    return SsoIdentity(
      idToken: idToken,
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
    );
  }

  /// RP-initiated logout against
  /// `https://login.microsoftonline.com/<tenant>/oauth2/v2.0/logout`
  /// (resolved from the discovery document). Entra returns to
  /// `post_logout_redirect_uri`, which reuses [redirectUri] and therefore
  /// needs no extra registration.
  @override
  Future<void> signOut({required String idTokenHint}) async {
    if (!isConfigured || idTokenHint.isEmpty) return;

    try {
      await _appAuth.endSession(
        EndSessionRequest(
          idTokenHint: idTokenHint,
          postLogoutRedirectUrl: redirectUri,
          discoveryUrl: discoveryUrl,
        ),
      );
    } on FlutterAppAuthUserCancelledException {
      // User closed the browser before Entra finished; local logout proceeds.
    } on FlutterAppAuthPlatformException catch (error) {
      debugPrint(
        'Azure end-session failed: '
        '${error.platformErrorDetails.errorDescription ?? error.message}',
      );
    }
  }
}
