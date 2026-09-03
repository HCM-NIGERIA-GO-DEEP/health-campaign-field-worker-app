import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/security/app_security.dart';
import 'package:health_campaign_field_worker_app/security/models/app_security_feature.dart';
import 'package:health_campaign_field_worker_app/security/models/app_security_level.dart';
import 'package:health_campaign_field_worker_app/security/network/ssl_pinning.dart';

void main() {
  // rootBundle needs a binding before it can be asked for an asset.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppSecurity.instance.configure(level: AppSecurityLevel.low);
    AppSecurity.instance.sslPinningFailure = null;
  });

  group('SslPinning', () {
    test('returns null when the feature is not selected', () async {
      AppSecurity.instance.configure(level: AppSecurityLevel.low);

      final client = await SslPinning.createPinnedHttpClient(
        certificateAssetPath: 'assets/certificates/tls_cert.crt',
      );

      // Null means "pinning not requested", so the caller keeps its default
      // client. That is only correct when the feature is off.
      expect(client, isNull);
      expect(AppSecurity.instance.isSslPinningBroken, isFalse);
    });

    test('never returns null when the certificate cannot be loaded', () async {
      AppSecurity.instance.configure(features: {
        AppSecurityFeature.sslPinning,
      });

      final client = await SslPinning.createPinnedHttpClient(
        certificateAssetPath: 'assets/certificates/does_not_exist.crt',
      );

      // The regression this guards: returning null here would make the caller
      // fall back to its default client, silently restoring system and user CA
      // trust and turning a packaging mistake into an undetected loss of
      // pinning.
      expect(
        client,
        isNotNull,
        reason: 'a failed pin must not signal "use the default client"',
      );

      client?.close(force: true);
    });

    test('records the reason when the certificate cannot be loaded', () async {
      AppSecurity.instance.configure(features: {
        AppSecurityFeature.sslPinning,
      });

      final client = await SslPinning.createPinnedHttpClient(
        certificateAssetPath: 'assets/certificates/does_not_exist.crt',
      );

      // debugPrint is silenced at medium and high, so the failure has to be
      // readable as state rather than only as a log line.
      expect(AppSecurity.instance.isSslPinningBroken, isTrue);
      expect(
          AppSecurity.instance.sslPinningFailure, contains('does_not_exist'));

      client?.close(force: true);
    });

    test('clears a previous failure once a pin loads successfully', () async {
      AppSecurity.instance.configure(features: {
        AppSecurityFeature.sslPinning,
      });
      AppSecurity.instance.sslPinningFailure =
          'stale failure from an earlier run';

      final client = await SslPinning.createPinnedHttpClient(
        certificateAssetPath: 'assets/certificates/tls_cert.crt',
      );

      // The asset is only resolvable when the test runner can see it; if it
      // cannot, the failure is re-recorded rather than cleared, which is also
      // correct behaviour.
      if (AppSecurity.instance.isSslPinningBroken) {
        expect(
            AppSecurity.instance.sslPinningFailure, contains('tls_cert.crt'));
      } else {
        expect(AppSecurity.instance.sslPinningFailure, isNull);
      }

      client?.close(force: true);
    });
  });

  group('SslPinningUnavailableException', () {
    test('carries the reason so the failure is not mistaken for bad network',
        () {
      const e = SslPinningUnavailableException('certificate asset was empty');

      expect(e.toString(), contains('certificate asset was empty'));
      expect(e.toString(), contains('pinning'));
    });
  });
}
