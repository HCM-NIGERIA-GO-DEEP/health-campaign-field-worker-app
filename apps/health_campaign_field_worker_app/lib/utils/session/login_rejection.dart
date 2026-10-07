/// Recognises the backend's single-active-session login rejection.
///
/// Import-free on purpose: it is exercised by unit tests on every branch
/// regardless of the state of the rest of lib/.
const activeSessionExistsCode = 'ACTIVE_SESSION_EXISTS';

/// True when the token endpoint refused the login because the user already
/// holds an active session elsewhere.
///
/// The backend reports the code in `error_description` (OAuth error body);
/// `error`, `message`, the DIGIT `Errors[]` envelope and a plain-text body are
/// also accepted so a later backend change in envelope does not silently turn
/// the rejection into a generic "unable to login". The literal is distinctive
/// enough that none of these produce false positives. Never throws.
bool isActiveSessionRejection(Object? responseData) {
  if (responseData is String) return _carriesCode(responseData);
  if (responseData is! Map) return false;

  for (final key in const ['error_description', 'error', 'message']) {
    if (_carriesCode(responseData[key])) return true;
  }

  final errors = responseData['Errors'];
  if (errors is List) {
    for (final error in errors) {
      if (error is! Map) continue;
      if (_carriesCode(error['code']) || _carriesCode(error['message'])) {
        return true;
      }
    }
  }

  return false;
}

bool _carriesCode(Object? value) =>
    value is String && value.contains(activeSessionExistsCode);
