import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/security/security.dart';

void main() {
  // AppSecurity is a singleton, so reset to a known state before each case.
  setUp(() {
    AppSecurity.instance.configure(level: AppSecurityLevel.low);
  });

  group('level presets', () {
    test('low selects nothing', () {
      AppSecurity.instance.configure(level: AppSecurityLevel.low);

      expect(AppSecurity.instance.enabledFeatures, isEmpty);
      expect(AppSecurity.instance.isEnabled(AppSecurityFeature.sslPinning),
          isFalse);
      expect(AppSecurity.instance.isDeviceIntegrityEnabled, isFalse);
    });

    test('medium pins TLS and suppresses logs but runs no device checks', () {
      AppSecurity.instance.configure(level: AppSecurityLevel.medium);

      expect(AppSecurity.instance.isEnabled(AppSecurityFeature.sslPinning),
          isTrue);
      expect(
        AppSecurity.instance
            .isEnabled(AppSecurityFeature.debugPrintSuppression),
        isTrue,
      );
      expect(AppSecurity.instance.isDeviceIntegrityEnabled, isFalse);
    });

    test('high selects every feature', () {
      AppSecurity.instance.configure(level: AppSecurityLevel.high);

      expect(
        AppSecurity.instance.enabledFeatures,
        containsAll(AppSecurityFeature.values),
      );
      expect(AppSecurity.instance.isDeviceIntegrityEnabled, isTrue);
    });
  });

  group('individual selection', () {
    test('an explicit feature set selects exactly those features', () {
      AppSecurity.instance.configure(features: {
        AppSecurityFeature.sslPinning,
        AppSecurityFeature.rootDetection,
      });

      expect(AppSecurity.instance.enabledFeatures, {
        AppSecurityFeature.sslPinning,
        AppSecurityFeature.rootDetection,
      });
      expect(AppSecurity.instance.securityLevel, AppSecurityLevel.custom);
      // not selected, so it must stay off
      expect(AppSecurity.instance.isEnabled(AppSecurityFeature.hookDetection),
          isFalse);
    });

    test('disable subtracts from a preset', () {
      AppSecurity.instance.configure(
        level: AppSecurityLevel.high,
        disable: {
          AppSecurityFeature.emulatorDetection,
          AppSecurityFeature.debuggerDetection,
        },
      );

      expect(
        AppSecurity.instance.isEnabled(AppSecurityFeature.emulatorDetection),
        isFalse,
      );
      expect(
        AppSecurity.instance.isEnabled(AppSecurityFeature.debuggerDetection),
        isFalse,
      );
      // the rest of the preset survives
      expect(AppSecurity.instance.isEnabled(AppSecurityFeature.rootDetection),
          isTrue);
      expect(AppSecurity.instance.isDeviceIntegrityEnabled, isTrue);
    });

    test('enable and disable flip a single feature', () {
      AppSecurity.instance.configure(level: AppSecurityLevel.low);

      AppSecurity.instance.enable(AppSecurityFeature.sslPinning);
      expect(AppSecurity.instance.isEnabled(AppSecurityFeature.sslPinning),
          isTrue);

      AppSecurity.instance.disable(AppSecurityFeature.sslPinning);
      expect(AppSecurity.instance.isEnabled(AppSecurityFeature.sslPinning),
          isFalse);
    });

    test('device integrity is off once the last check is disabled', () {
      AppSecurity.instance.configure(features: {
        AppSecurityFeature.rootDetection,
      });
      expect(AppSecurity.instance.isDeviceIntegrityEnabled, isTrue);

      AppSecurity.instance.disable(AppSecurityFeature.rootDetection);
      expect(AppSecurity.instance.isDeviceIntegrityEnabled, isFalse);
    });

    test('enabledFeatures is not modifiable by callers', () {
      AppSecurity.instance.configure(level: AppSecurityLevel.medium);

      expect(
        () => AppSecurity.instance.enabledFeatures.add(
          AppSecurityFeature.rootDetection,
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('runtime vs build-time', () {
    test('build-time mitigations are flagged as not runtime enforced', () {
      expect(AppSecurityFeature.codeObfuscation.isRuntimeEnforced, isFalse);
      expect(
        AppSecurityFeature.broadcastReceiverHardening.isRuntimeEnforced,
        isFalse,
      );
      expect(
        AppSecurityFeature.platformUsageHardening.isRuntimeEnforced,
        isFalse,
      );
    });

    test('runtime mitigations are flagged as enforced', () {
      expect(AppSecurityFeature.sslPinning.isRuntimeEnforced, isTrue);
      expect(AppSecurityFeature.rootDetection.isRuntimeEnforced, isTrue);
    });

    test('every feature has a label', () {
      for (final feature in AppSecurityFeature.values) {
        expect(feature.label, isNotEmpty,
            reason: '${feature.name} has no label');
      }
    });

    test('verification reports nothing when no build-time feature is selected',
        () async {
      AppSecurity.instance.configure(features: {
        AppSecurityFeature.sslPinning,
      });

      final report = await AppSecurity.instance.verifyBuildTimeMitigations();

      expect(report, isNotNull);
      expect(report!.isSatisfied, isTrue);
      expect(report.violations, isEmpty);
    });
  });

  group('expectedAppSignature', () {
    test('is null by default, leaving repackaging detection inert', () {
      expect(AppSecurity.instance.expectedAppSignature, isNull);
    });

    test('is retained when supplied', () {
      AppSecurity.instance.configure(
        level: AppSecurityLevel.high,
        expectedAppSignature: 'DEADBEEF',
      );

      expect(AppSecurity.instance.expectedAppSignature, 'DEADBEEF');
    });
  });

  group('SecurityCheckResult', () {
    test('an unavailable check is not a threat', () {
      // Regression guard: a plugin or channel failure used to become an
      // `unknown` threat, which reached exit(0) in production.
      final result = SecurityCheckResult(
        threats: const [],
        unavailableChecks: const ['root', 'hook'],
        timestamp: DateTime.now(),
      );

      expect(result.isPassed, isTrue);
      expect(result.threats, isEmpty);
      expect(result.unavailableChecks, ['root', 'hook']);
    });

    test('a confirmed threat fails the pass', () {
      final result = SecurityCheckResult(
        threats: const [SecurityThreatType.root],
        timestamp: DateTime.now(),
      );

      expect(result.isPassed, isFalse);
    });

    test('fingerprint is deterministic and order independent', () {
      final a = SecurityCheckResult(
        threats: const [SecurityThreatType.root, SecurityThreatType.hook],
        timestamp: DateTime.now(),
      );
      final b = SecurityCheckResult(
        threats: const [SecurityThreatType.hook, SecurityThreatType.root],
        timestamp: DateTime.now().add(const Duration(seconds: 30)),
      );

      // Previously the digest mixed in DateTime.now(), so it could never be
      // compared against anything.
      expect(a.fingerprint, b.fingerprint);
    });

    test('fingerprint differs for a different threat set', () {
      final a = SecurityCheckResult(
        threats: const [SecurityThreatType.root],
        timestamp: DateTime.now(),
      );
      final b = SecurityCheckResult(
        threats: const [SecurityThreatType.emulator],
        timestamp: DateTime.now(),
      );

      expect(a.fingerprint, isNot(b.fingerprint));
    });
  });

  group('ThreatResponse', () {
    test('restrict marks the session compromised without terminating', () {
      final handler = ThreatResponseHandler();
      final result = SecurityCheckResult(
        threats: const [SecurityThreatType.root],
        timestamp: DateTime.now(),
      );

      handler.apply(
        result,
        const ThreatResponse(mode: ThreatResponseMode.restrict),
      );

      // Reachable now: this assignment used to sit after an unconditional
      // exit(0) and could never run in release.
      expect(handler.isCompromised, isTrue);
    });

    test('reportOnly notifies the reporter', () {
      final handler = ThreatResponseHandler();
      SecurityCheckResult? reported;
      final result = SecurityCheckResult(
        threats: const [SecurityThreatType.hook],
        timestamp: DateTime.now(),
      );

      handler.apply(
        result,
        ThreatResponse(
          mode: ThreatResponseMode.reportOnly,
          onThreat: (r) => reported = r,
        ),
      );

      expect(reported, same(result));
      expect(handler.isCompromised, isTrue);
    });

    test('defaults to exitApp so restructuring cannot weaken enforcement', () {
      expect(const ThreatResponse().mode, ThreatResponseMode.exitApp);
    });
  });

  group('enforcement gating', () {
    test('is off when the environment is uninitialised', () {
      // envConfig.variables throws until initialize() runs; that must read as
      // "not production" rather than crash.
      AppSecurity.instance.enforcementOverride = null;

      expect(AppSecurity.instance.isEnforcementEnabled, isFalse);
    });

    test('can be forced on for tests', () {
      AppSecurity.instance.enforcementOverride = true;
      expect(AppSecurity.instance.isEnforcementEnabled, isTrue);

      AppSecurity.instance.enforcementOverride = null;
    });
  });
}
