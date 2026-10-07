import 'dart:async';
import 'dart:convert';

import 'package:digit_ui_components/utils/app_logger.dart';

import '../local_store/secure_store/secure_store.dart';
import 'azure_sso_service.dart';

/// Supplies the Azure ID token sent as the `x-id-token` header and cookie,
/// renewing it with the stored refresh token when it is about to expire.
///
/// Behaviour:
/// - Returns null when there is no SSO session (password login, logged out).
/// - Returns the stored token as-is while it has more than [refreshSkew] left.
/// - Otherwise refreshes once, however many requests ask at the same time
///   (the AppAuth plugin rejects concurrent token calls), and returns the new
///   token.
/// - If the refresh fails (offline, Microsoft unreachable, revoked refresh
///   token) it returns the stale token so the call still goes out and the
///   backend decides, and waits [failureBackoff] before trying again so an
///   unreachable Microsoft endpoint does not slow down every sync request.
///
/// One instance lives per isolate (UI and background sync). Both read and
/// write the same secure store; Entra keeps a redeemed refresh token valid,
/// so a refresh in each isolate at the same moment is harmless.
class SsoIdTokenProvider {
  final LocalSecureStore store;
  final SsoAuthenticator authenticator;
  final Duration refreshSkew;
  final Duration failureBackoff;
  final DateTime Function() _now;

  Future<String?>? _inFlight;
  DateTime? _lastFailure;

  SsoIdTokenProvider({
    required this.store,
    required this.authenticator,
    this.refreshSkew = const Duration(minutes: 5),
    this.failureBackoff = const Duration(minutes: 1),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  Future<String?> currentIdToken() async {
    final idToken = await store.ssoIdToken;
    if (idToken == null || idToken.isEmpty) return null;
    if (!_needsRefresh(idToken)) return idToken;

    return await _refreshOnce() ?? idToken;
  }

  bool _needsRefresh(String idToken) {
    final expiry = jwtExpiry(idToken);
    // An unreadable token cannot be trusted to be valid; try to replace it.
    if (expiry == null) return true;
    return !expiry.isAfter(_now().add(refreshSkew));
  }

  Future<String?> _refreshOnce() {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final lastFailure = _lastFailure;
    if (lastFailure != null &&
        _now().difference(lastFailure) < failureBackoff) {
      return Future.value(null);
    }

    final future = _refresh();
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  Future<String?> _refresh() async {
    final refreshToken = await store.ssoRefreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      final identity = await authenticator.refresh(refreshToken: refreshToken);

      // The user may have logged out, or another user logged in, while the
      // refresh was in flight. Never resurrect tokens for a closed session.
      if (await store.ssoRefreshToken != refreshToken) return null;

      await store.setSsoTokens(
        idToken: identity.idToken,
        refreshToken: identity.refreshToken,
      );
      _lastFailure = null;
      return identity.idToken;
    } catch (error) {
      _lastFailure = _now();
      AppLogger.instance.error(
        title: 'SSO token refresh failed',
        message: '$error',
      );
      return null;
    }
  }

  /// Reads the `exp` claim of a JWT without verifying it. Verification is the
  /// backend's job; the app only needs to know when to renew. Returns null if
  /// the token is not a readable JWT.
  static DateTime? jwtExpiry(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) return null;
    try {
      final payload =
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final claims = jsonDecode(payload);
      if (claims is! Map) return null;
      final exp = claims['exp'];
      if (exp is! num) return null;
      return DateTime.fromMillisecondsSinceEpoch(
        (exp * 1000).toInt(),
        isUtc: true,
      );
    } catch (_) {
      return null;
    }
  }
}
