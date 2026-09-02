import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../app_security.dart';
import '../models/app_security_feature.dart';

/// Certificate pinning primitives.
///
/// Returns a plain [HttpClient] rather than mutating a Dio instance, so the
/// HTTP stack stays the caller's concern and this stays testable without one.
class SslPinning {
  const SslPinning._();

  /// Builds an [HttpClient] that trusts *only* the certificate at
  /// [certificateAssetPath].
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

    final certData = await rootBundle.load(certificateAssetPath);

    final securityContext = SecurityContext(withTrustedRoots: false);
    securityContext.setTrustedCertificatesBytes(
      certData.buffer.asUint8List(),
    );

    final httpClient = HttpClient(context: securityContext)
      ..badCertificateCallback = (cert, host, port) {
        // Never relax this: a pinned client that accepts a bad certificate is
        // not pinned at all.
        debugPrint('Bad certificate for $host');
        return false;
      };

    debugPrint('SSL Certificate Pinning enabled');

    return httpClient;
  }
}
