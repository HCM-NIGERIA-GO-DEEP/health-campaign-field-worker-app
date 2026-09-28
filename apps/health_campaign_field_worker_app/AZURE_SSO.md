# Azure Entra ID single sign-on

The login page can run in one of two modes, selected per build through `.env`:

| `AUTH_MODE` | Login page                                   | Session source                                   |
|-------------|----------------------------------------------|--------------------------------------------------|
| `PASSWORD`  | DIGIT user ID / password form (default)      | `user/oauth/token` password grant                |
| `SSO`       | Single **Sign in with Microsoft** button     | Azure ID token exchanged at `SSO_TOKEN_EXCHANGE_PATH` |

Everything after the token is obtained is identical in both modes: the DIGIT
`access_token`, `refresh_token` and `UserRequest` are stored in secure storage,
role actions are loaded from MDMS, and every API call keeps using the DIGIT
token. Azure tokens are never persisted on the device.

## Flow (SSO mode)

1. User taps **Sign in with Microsoft** (`AuthEvent.ssoLogin`).
2. `AzureSsoService` opens the system browser (Custom Tabs on Android,
   `ASWebAuthenticationSession` on iOS) on the Entra ID v2.0 authorize
   endpoint using the OpenID Connect authorization-code flow with PKCE
   (`flutter_appauth`). `prompt=select_account` is always sent because field
   devices are shared.
3. Entra ID redirects to `AZURE_REDIRECT_URI`; AppAuth exchanges the code for
   tokens natively and returns the **access token** (audience = this app
   registration, scope `access_as_user`) and the **ID token** to the app.
4. `AuthRepository.exchangeSsoToken` POSTs both to the DIGIT exchange
   endpoint through the app's pinned Dio client.
5. The response is parsed as the usual `AuthModel` and login completes.

The Azure ID token and refresh token are written to secure storage *before*
step 4, so the exchange and every later DIGIT call carry the `x-id-token`
header (see below). If the exchange or the post-login calls fail, both are
removed again.

The browser and the Microsoft token endpoint are reached by the native AppAuth
SDKs, not by Dio, so certificate pinning (which trusts only the DIGIT
certificate) is unaffected and needs no Microsoft certificates.

## `.env` keys

```
AUTH_MODE=SSO
AZURE_TENANT_ID=<directory (tenant) id>
AZURE_CLIENT_ID=<application (client) id>
AZURE_REDIRECT_URI=com.digit.hcm://oauth/callback
AZURE_SCOPES=openid profile offline_access api://<client id>/access_as_user
AZURE_END_SESSION_ON_LOGOUT=true
SSO_TOKEN_EXCHANGE_PATH=user/oauth/sso/_exchange
```

This repository is public, so **no tenant, client or API scope is committed**:
`AZURE_TENANT_ID` and `AZURE_CLIENT_ID` default to empty and the scopes to
`openid profile offline_access`. `offline_access` must stay in any custom
`AZURE_SCOPES`: without it Entra returns no refresh token and the
`x-id-token` header goes stale after about an hour. Each deployment supplies its own values through the
gitignored `.env` locally and through GitHub repository *variables* of the same
names in CI (they are identifiers, not secrets, so variables rather than
Secrets are appropriate; a client secret must never be added, see below).
The redirect URI, the exchange path and the logout flag have generic
defaults. A key that is present but blank keeps its default, which is what the
build workflow produces when a variable is unset. If `AUTH_MODE=SSO` and the
tenant or client is blank, the button shows a configuration error instead of
opening the browser. `AZURE_END_SESSION_ON_LOGOUT=false` turns the Entra
logout round-trip off and makes logout local-only.

## `x-id-token` header

During an SSO session every request on the shared Dio client to the
`BASE_URL` host carries the raw Azure ID token:

```
x-id-token: eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIs...
```

- It is **in addition to** the DIGIT token in `RequestInfo.authToken`; nothing
  about the DIGIT session changes.
- It is added by `AuthTokenInterceptor`, so it covers foreground calls and
  background sync, which runs in its own isolate on the same client.
- It is **never** sent to any other host, and not at all in password mode or
  before sign-in. Image downloads use a separate client and never carry it.
- **Renewal.** Entra ID tokens live about one hour. `SsoIdTokenProvider`
  reads the token's `exp` claim and, when less than 5 minutes remain, redeems
  the stored refresh token through AppAuth (no Activity needed, so this works
  in background sync too). Concurrent requests share a single refresh, and
  a rotated refresh token is stored.
- **When renewal fails** (device offline, Microsoft unreachable, refresh
  token revoked or expired after 90 days of inactivity) the stale token is
  still sent, so the call goes out and the backend decides. The app waits one
  minute before trying again. The app has no handling for a backend
  rejection; the user signs in again after logging out.
- Tokens are not logged: headers are never logged, and the SSO exchange body
  has `idToken` and `accessToken` masked in the request log.

What the backend should check on `x-id-token`: signature against the tenant
JWKS, `iss` = `https://login.microsoftonline.com/<tenant>/v2.0`, `aud` = the
client ID, `exp`/`nbf`, and optionally that the `oid` or `preferred_username`
claim matches the DIGIT user behind `RequestInfo.authToken`.

## Security notes for a public repository

- The app is an OAuth **public client** using PKCE. Its client ID and tenant
  ID are not confidential (they are visible in the browser on every sign-in
  and extractable from any APK), but they are deployment identifiers and are
  kept out of source so the codebase is not tied to one organisation.
- **Never add a client secret.** A secret embedded in a mobile app is
  extractable and gives no protection; PKCE is the correct mechanism.
- Because anyone with an account in the tenant can obtain a token for the
  app's audience, **the DIGIT exchange endpoint is the real gatekeeper**: it
  must map the token to an existing, active DIGIT employee and reject all
  others, and it should be rate-limited.
- On the Entra side set *Assignment required* = Yes on the Enterprise
  application so only assigned users can sign in, and apply Conditional
  Access where licensed.
- Custom-scheme redirects (`com.digit.hcm://`) can be claimed by another app
  on Android; PKCE makes an intercepted code useless. For defence in depth,
  switch to an `https://` App Link with `assetlinks.json` later.

## Entra ID app registration

1. **Azure portal → Entra ID → App registrations → New registration.**
   Supported account types: usually *Accounts in this organizational
   directory only*.
2. **Authentication → Add a platform → Mobile and desktop applications.**
   Add the custom redirect URI `com.digit.hcm://oauth/callback` (must equal
   `AZURE_REDIRECT_URI`). No Android signature hash is needed for a custom
   scheme redirect; only the MSAL broker flow requires that.
3. Under **Advanced settings** set *Allow public client flows* to **Yes**.
4. Under **Implicit grant and hybrid flows** leave both boxes unchecked; the
   ID token is returned from the token endpoint via the code flow, so nothing
   needs enabling there.
5. **Expose an API**: set the Application ID URI to `api://<client id>` and
   add a scope named `access_as_user`; then include
   `api://<client id>/access_as_user` in `AZURE_SCOPES`. This is what makes
   Entra return an access token addressed to the DIGIT backend.
6. **Token configuration** (optional): add the `email` and
   `preferred_username` claims if the backend maps users by email/UPN.
7. Copy the *Directory (tenant) ID* and *Application (client) ID* into `.env`
   and into the CI repository variables.

The redirect scheme is also declared in the app:

- Android: `manifestPlaceholders += [appAuthRedirectScheme: 'com.digit.hcm']`
  in `android/app/build.gradle`.
- iOS: `CFBundleURLTypes` entry with scheme `com.digit.hcm` in
  `ios/Runner/Info.plist`.

If you change the redirect scheme, change all three places together.

## Backend exchange contract (to be implemented server-side)

`POST {BASE_URL}{SSO_TOKEN_EXCHANGE_PATH}` with `Content-Type: application/json`

Request body (`SsoExchangeRequestModel`):

```json
{
  "idToken": "<Azure ID token (JWT)>",
  "accessToken": "<Azure access token for api://<client id> (JWT)>",
  "tenantId": "ng",
  "userType": "EMPLOYEE",
  "provider": "MICROSOFT"
}
```

Response body: identical to the DIGIT password grant response so the app
needs no other change.

```json
{
  "access_token": "...",
  "token_type": "bearer",
  "refresh_token": "...",
  "expires_in": 86400,
  "UserRequest": {
    "uuid": "...",
    "userName": "...",
    "name": "...",
    "emailId": "...",
    "tenantId": "ng",
    "roles": [{ "code": "DISTRIBUTOR", "name": "Distributor", "tenantId": "ng" }]
  }
}
```

The backend must:

- fetch the tenant's JWKS from
  `https://login.microsoftonline.com/{tenant}/discovery/v2.0/keys` and verify
  the **access token**: signature, `iss`
  (`https://login.microsoftonline.com/{tenant}/v2.0` or the v1 `sts.windows.net`
  issuer, depending on the registration's `accessTokenAcceptedVersion`),
  `aud` (= the client ID or `api://` + the client ID),
  `scp` containing `access_as_user`, `exp` and `nbf`;
- map the token's `oid` / `preferred_username` / `email` claim to a DIGIT
  employee of type `EMPLOYEE` in `tenantId` and reject unknown or inactive
  users with `401`; the ID token is sent as well for backends that prefer to
  read profile claims from it;
- issue DIGIT access/refresh tokens exactly as the password grant does.

Non-2xx responses are shown to the user as the generic "unable to login"
toast and logged with the response body.

## Behavioural differences in SSO mode

- **Single-device check / device switch** are skipped. Both backend calls
  require the raw password, which SSO never has. Re-enable them once the
  backend accepts an Azure-derived session.
- **Forgot password** is hidden; passwords are managed in Entra ID.
- **Logout** first opens the Entra end-session endpoint
  (`https://login.microsoftonline.com/<tenant>/oauth2/v2.0/logout`, resolved
  from discovery) with the stored ID token as `id_token_hint` and
  `post_logout_redirect_uri` = `AZURE_REDIRECT_URI`, then clears local state.
  The browser step is best effort: dismissing it or being offline never blocks
  the local logout. Set `AZURE_END_SESSION_ON_LOGOUT=false` to skip it.
  `prompt=select_account` is sent on every sign-in regardless.
- **Auto-login** on app start is unchanged: it uses the stored DIGIT tokens.
  The stored Azure refresh token renews `x-id-token` on the first call.
- **Logout** also deletes the stored Azure ID and refresh tokens.

## Troubleshooting

| Symptom | Likely cause |
|---------|--------------|
| Button shows a configuration error immediately | `AZURE_TENANT_ID` / `AZURE_CLIENT_ID` blank in the `.env` baked into the build |
| Browser shows `AADSTS50011` redirect URI mismatch | `AZURE_REDIRECT_URI` not registered on the app, or scheme differs from `appAuthRedirectScheme` / `CFBundleURLSchemes` |
| Browser shows `AADSTS7000218` | *Allow public client flows* is off on the registration |
| Sign-in completes, then "unable to login" toast | DIGIT exchange endpoint rejected the ID token; check backend logs |
| Browser never returns to the app on Android | Redirect scheme placeholder missing from `build.gradle`, or another app claims the same scheme |
| Calls work for about an hour, then the backend rejects `x-id-token` | `offline_access` missing from `AZURE_SCOPES`, or the session predates the refresh support, so there is no refresh token (sign in again); or the refresh fails (logcat: `SSO token refresh failed`) |
| `x-id-token` missing on a call | The request is not to the `BASE_URL` host, or the build is in password mode |
