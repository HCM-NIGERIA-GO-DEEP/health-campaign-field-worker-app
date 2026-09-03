import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../app_security.dart';
import '../models/app_security_feature.dart';

/// Thrown for every request made through a client whose pin could not be
/// established.
///
/// Carrying a reason matters: without it the failure surfaces as a generic
/// socket error and looks like poor connectivity rather than a packaging
/// mistake.
class SslPinningUnavailableException implements Exception {
  final String reason;

  const SslPinningUnavailableException(this.reason);

  @override
  String toString() =>
      'SslPinningUnavailableException: refusing to send traffic because SSL '
      'pinning could not be established. $reason';
}

/// Certificate pinning primitives.
///
/// Returns a plain [HttpClient] rather than mutating a Dio instance, so the
/// HTTP stack stays the caller's concern and this stays testable without one.
class SslPinning {
  const SslPinning._();

  /// Builds an [HttpClient] that trusts *only* the certificate at
  /// [certificateAssetPath].
  ///
  /// The bundled certificate is the issuing **intermediate CA**, not the server
  /// leaf. That is deliberate. Pinning the leaf meant every renewal took every
  /// installed build offline, because pinning fails closed and field devices do
  /// not update on demand: the leaf expires within months, the issuer within
  /// years. Trust stays narrow — one CA, not the system or user store — so an
  /// attacker-installed device CA is still rejected, which is the threat this
  /// exists to stop. Hostname verification continues to apply to the leaf, so
  /// certificates for other hosts are not accepted.
  ///
  /// `withTrustedRoots: false` plus a non-self-signed anchor works because
  /// BoringSSL accepts a partial chain. `tools/security/test_ssl_pinning.sh`
  /// reproduces exactly these semantics when it verifies the live chain.
  ///
  /// Returns null when [AppSecurityFeature.sslPinning] is not selected, in
  /// which case the caller keeps its default client.
  static Future<HttpClient?> createPinnedHttpClient({
    required String certificateAssetPath,
  }) async {
    if (!AppSecurity.instance.isEnabled(AppSecurityFeature.sslPinning)) {
      debugPrint(
          'SSL Certificate Pinning not enabled: sslPinning feature is off');
      return null;
    }

    final HttpClient httpClient;
    try {
      final certData = await rootBundle.load(certificateAssetPath);

      final securityContext = SecurityContext(withTrustedRoots: false);
      securityContext.setTrustedCertificatesBytes(
        certData.buffer.asUint8List(),
      );

      httpClient = HttpClient(context: securityContext)
        ..badCertificateCallback = (cert, host, port) {
          // Never relax this: a pinned client that accepts a bad certificate is
          // not pinned at all.
          debugPrint('Bad certificate for $host');
          return false;
        };
    } catch (e) {
      // A missing or malformed asset is normally a packaging or rotation
      // mistake. It must never fall back to the default client: that would
      // silently restore system and user CA trust and turn a build error into
      // an undetected loss of pinning.
      //
      // Nor should it crash the app. This is an offline-first field app, so
      // taking the whole process down would block local data entry over what is
      // usually a bad file. Instead the pin failure is recorded and a client
      // that refuses every connection is returned: nothing is sent over an
      // unpinned channel, and the app stays usable offline.
      final reason =
          'Pinned certificate "$certificateAssetPath" could not be loaded: $e';
      AppSecurity.instance.sslPinningFailure = reason;
      debugPrint('SSL Certificate Pinning FAILED: $reason');

      return _refusingClient(reason);
    }

    AppSecurity.instance.sslPinningFailure = null;
    debugPrint('SSL Certificate Pinning enabled');

    return httpClient;
  }

  /// A client that fails every request rather than sending it unpinned.
  static HttpClient _refusingClient(String reason) {
    return HttpClient(context: SecurityContext(withTrustedRoots: false))
      // Blocks TLS: no trust anchors are configured, so validation always
      // fails and this callback refuses the certificate.
      // Block body, not `=> false`: an arrow body would extend across the
      // following cascade and parse as `false..connectionFactory = ...`.
      ..badCertificateCallback = (cert, host, port) {
        return false;
      }
      // Blocks everything else, including plain HTTP, before a socket is even
      // opened. Without this a cleartext request could still leave the device
      // on a platform whose network security config permitted it.
      ..connectionFactory =
          (uri, proxyHost, proxyPort) => Future<ConnectionTask<Socket>>.error(
                SslPinningUnavailableException(reason),
              );
  }
}
