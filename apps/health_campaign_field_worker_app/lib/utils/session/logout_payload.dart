// Pure pieces of the backend logout call: the request body and the
// mapping from an HTTP status to what the app should do with the local
// session. Import-free on purpose so both are unit-testable.

enum LogoutServerOutcome {
  /// Backend marked the session LOGGED_OUT.
  loggedOut,

  /// Backend no longer recognises the token (expired / revoked / already
  /// logged out). There is nothing left to close server-side, so the local
  /// session is cleared as for a successful logout.
  sessionAlreadyInvalid,

  /// Transport or server failure. The local session is kept so the user can
  /// retry; nothing was changed on either side.
  failed,
}

/// Body for `/user/_logout` as the backend's session feature expects it:
/// the token twice (top-level `access_token`, and `RequestInfo.authToken`
/// since the request bypasses the RequestInfo interceptor) plus the tenant.
Map<String, dynamic> buildLogoutPayload({
  required String? accessToken,
  required String? userTenantId,
  required String envTenantId,
}) {
  final token = accessToken ?? '';
  final tenantId = (userTenantId != null && userTenantId.trim().isNotEmpty)
      ? userTenantId
      : envTenantId;

  return {
    if (token.isNotEmpty) 'access_token': token,
    'tenantId': tenantId,
    'RequestInfo': {
      'apiId': '',
      'authToken': token,
      'msgId': '',
      'plainAccessRequest': <String, dynamic>{},
    },
  };
}

/// 401/403 mean the token is dead on the server; anything else (5xx,
/// timeouts surface as null) is a failure that must keep the session.
LogoutServerOutcome classifyLogoutStatus(int? statusCode) {
  switch (statusCode) {
    case 401:
    case 403:
      return LogoutServerOutcome.sessionAlreadyInvalid;
    default:
      return LogoutServerOutcome.failed;
  }
}
